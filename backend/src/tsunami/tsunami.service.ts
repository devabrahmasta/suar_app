import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TsunamiHazardPolygon } from '../alerts/entities/tsunami-hazard.entity';
import * as crypto from 'crypto';
import * as path from 'path';
import * as fs from 'fs';
import * as zlib from 'zlib';

export interface GeoJsonServiceResult {
  buffer: Buffer;
  etag: string;
  filename: string;
  sizeBytes: number;
}

@Injectable()
export class TsunamiService implements OnModuleInit {
  private readonly logger = new Logger(TsunamiService.name);
  private cachedGeoJson: GeoJsonServiceResult | null = null;

  constructor(
    @InjectRepository(TsunamiHazardPolygon)
    private readonly tsunamiRepository: Repository<TsunamiHazardPolygon>,
  ) {}

  async onModuleInit() {
    await this.checkTsunamiTableStatus();
    this.loadGeoJsonFile();
  }

  private async checkTsunamiTableStatus(): Promise<void> {
    try {
      const tableCheck = await this.tsunamiRepository.query(`
        SELECT EXISTS (
          SELECT 1 FROM information_schema.tables 
          WHERE table_name = 'tsunami_hazard_polygons'
        ) AS table_exists;
      `);

      if (tableCheck?.[0]?.table_exists) {
        const countResult = await this.tsunamiRepository.query(
          `SELECT COUNT(*) AS count FROM tsunami_hazard_polygons;`,
        );
        const count = parseInt(countResult?.[0]?.count || '0', 10);
        if (count > 0) {
          this.logger.log(
            `🌊 Tsunami hazard polygons active in PostGIS (${count} records).`,
          );
        } else {
          this.logger.warn(
            `⚠️ Table 'tsunami_hazard_polygons' exists in Supabase PostGIS but is empty.`,
          );
        }
      } else {
        this.logger.warn(
          `⚠️ Table 'tsunami_hazard_polygons' not found in Supabase PostGIS.`,
        );
      }
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      this.logger.error(
        `Failed to check Tsunami Hazard table in PostGIS: ${msg}`,
      );
    }
  }

  loadGeoJsonFile(): GeoJsonServiceResult | null {
    if (this.cachedGeoJson) return this.cachedGeoJson;

    const possiblePaths = [
      path.join('/app', 'data', 'tsunami', 'tsunami_jawa_bali_dissolved.geojson.gz'),
      path.join('/app', 'data', 'tsunami', 'tsunami_jawa_bali_dissolved.geojson'),
      path.join(process.cwd(), 'data', 'tsunami', 'tsunami_jawa_bali_dissolved.geojson.gz'),
      path.join(process.cwd(), 'data', 'tsunami', 'tsunami_jawa_bali_dissolved.geojson'),
      path.join(process.cwd(), 'backend', 'data', 'tsunami', 'tsunami_jawa_bali_dissolved.geojson.gz'),
      path.join(process.cwd(), 'backend', 'data', 'tsunami', 'tsunami_jawa_bali_dissolved.geojson'),
      path.join(__dirname, '..', '..', 'data', 'tsunami', 'tsunami_jawa_bali_dissolved.geojson.gz'),
      path.join(__dirname, '..', '..', 'data', 'tsunami', 'tsunami_jawa_bali_dissolved.geojson'),
      path.join(__dirname, '..', '..', '..', 'data', 'tsunami', 'tsunami_jawa_bali_dissolved.geojson.gz'),
    ];

    let foundPath: string | null = null;
    for (const p of possiblePaths) {
      if (fs.existsSync(p)) {
        foundPath = p;
        break;
      }
    }

    if (!foundPath) {
      this.logger.warn(
        `GeoJSON file 'tsunami_jawa_bali_dissolved.geojson' (or .gz) not found on disk.`,
      );
      return null;
    }

    try {
      let fileBuffer = fs.readFileSync(foundPath);
      if (foundPath.endsWith('.gz')) {
        fileBuffer = zlib.gunzipSync(fileBuffer);
      }
      const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
      const etag = `"${hash.substring(0, 16)}"`;

      this.cachedGeoJson = {
        buffer: fileBuffer,
        etag,
        filename: 'tsunami_jawa_bali_dissolved.geojson',
        sizeBytes: fileBuffer.length,
      };

      this.logger.log(
        `Loaded GeoJSON asset (${(fileBuffer.length / (1024 * 1024)).toFixed(2)} MB), ETag: ${etag}`,
      );
      return this.cachedGeoJson;
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      this.logger.error(`Error loading GeoJSON asset: ${msg}`);
      return null;
    }
  }

  async checkTsunamiHazard(latitude: number, longitude: number) {
    try {
      const query = `
        SELECT EXISTS (
          SELECT 1 FROM tsunami_hazard_polygons
          WHERE ST_Contains(geom, ST_SetSRID(ST_Point($1, $2), 4326))
        ) AS is_red_zone;
      `;
      const result = await this.tsunamiRepository.query(query, [
        longitude,
        latitude,
      ]);
      const isRedZone = Boolean(result?.[0]?.is_red_zone);

      return {
        isRedZone,
        hazardLevel: isRedZone ? 'HIGH' : 'SAFE',
        location: { latitude, longitude },
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      this.logger.error(`Error checking tsunami hazard: ${msg}`);
      return {
        isRedZone: false,
        hazardLevel: 'UNKNOWN',
        location: { latitude, longitude },
        error: msg,
      };
    }
  }

  private tile2deg(x: number, y: number, z: number) {
    const n = Math.pow(2, z);
    const lonDeg = (x / n) * 360 - 180;
    const latRad = Math.atan(Math.sinh(Math.PI * (1 - (2 * y) / n)));
    const latDeg = (latRad * 180) / Math.PI;
    return { lon: lonDeg, lat: latDeg };
  }

  getTileBounds(z: number, x: number, y: number) {
    const nw = this.tile2deg(x, y, z);
    const se = this.tile2deg(x + 1, y + 1, z);
    return {
      minLon: nw.lon,
      maxLat: nw.lat,
      maxLon: se.lon,
      minLat: se.lat,
    };
  }

  async getTsunamiMvtTile(z: number, x: number, y: number): Promise<Buffer> {
    try {
      const query = `
        WITH mvtgeom AS (
          SELECT 
            id, 
            hazard_level,
            ST_AsMVTGeom(
              ST_Transform(geom, 3857),
              ST_TileEnvelope($1, $2, $3),
              4096,
              256,
              true
            ) AS geom
          FROM tsunami_hazard_polygons
          WHERE ST_Intersects(ST_Transform(geom, 3857), ST_TileEnvelope($1, $2, $3))
        )
        SELECT ST_AsMVT(mvtgeom, 'tsunami_layer') AS mvt FROM mvtgeom;
      `;
      const result = await this.tsunamiRepository.query(query, [z, x, y]);
      return result?.[0]?.mvt || Buffer.alloc(0);
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      this.logger.error(`Error generating MVT tile: ${msg}`);
      return Buffer.alloc(0);
    }
  }

  async getTsunamiSvgTile(z: number, x: number, y: number): Promise<string> {
    try {
      const bounds = this.getTileBounds(z, x, y);
      const query = `
        SELECT ST_AsSVG(
          ST_TransScale(
            ST_Intersection(geom, ST_MakeEnvelope($1, $2, $3, $4, 4326)),
            -$1, -$4,
            256.0 / ($3 - $1),
            256.0 / ($2 - $4)
          ), 1, 1
        ) AS svg_path
        FROM tsunami_hazard_polygons
        WHERE ST_Intersects(geom, ST_MakeEnvelope($1, $2, $3, $4, 4326));
      `;
      const rows = await this.tsunamiRepository.query(query, [
        bounds.minLon,
        bounds.minLat,
        bounds.maxLon,
        bounds.maxLat,
      ]);

      if (!rows || rows.length === 0) {
        return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"></svg>`;
      }

      const paths = rows
        .map((r: any) => r.svg_path)
        .filter(Boolean)
        .map(
          (d: string) =>
            `<path d="${d}" fill="rgba(239, 68, 68, 0.45)" stroke="#DC2626" stroke-width="1.5" />`,
        )
        .join('\n');

      return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">\n${paths}\n</svg>`;
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      this.logger.error(`Error generating SVG tile: ${msg}`);
      return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"></svg>`;
    }
  }
}
