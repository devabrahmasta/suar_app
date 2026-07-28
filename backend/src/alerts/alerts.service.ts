import { Injectable, Logger, OnModuleInit, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Interval } from '@nestjs/schedule';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { ConfigService } from '@nestjs/config';
import { EarthquakeAlert } from './entities/earthquake-alert.entity';
import { UserDevice } from '../users/entities/user-device.entity';
import { FirebaseService } from '../firebase/firebase.service';
import * as GeoJSON from 'geojson';
import * as crypto from 'crypto';

interface BmkgGempa {
  Tanggal: string;
  Jam: string;
  DateTime: string;
  Coordinates: string;
  Magnitude: string;
  Kedalaman: string;
  Wilayah: string;
  Potensi: string;
  Dirasakan?: string;
}

interface BmkgEarthquakeResponse {
  Infogempa?: {
    gempa?: BmkgGempa;
  };
}

export interface Slab2Data {
  slabDepth: number | null;
  slabUnc: number | null;
}

export type TectonicRegion =
  | 'shallow_crustal'
  | 'subduction_interface'
  | 'subduction_intraslab';

export interface HazardResult {
  deviceId: string;
  pga: number;
  mmi: number;
}

@Injectable()
export class AlertsService implements OnModuleInit {
  private readonly logger = new Logger(AlertsService.name);
  private isPolling = false;

  constructor(
    @InjectRepository(EarthquakeAlert)
    private readonly alertRepository: Repository<EarthquakeAlert>,
    @InjectRepository(UserDevice)
    private readonly deviceRepository: Repository<UserDevice>,
    private readonly firebaseService: FirebaseService,
    @Optional() private readonly eventEmitter?: EventEmitter2,
    @Optional() private readonly configService?: ConfigService,
  ) {}

  onModuleInit() {
    this.logger.log(
      'AlertsService has been initialized. Polling starts automatically.',
    );
  }

  @Interval(30000) // Poll every 30 seconds
  async handleCron() {
    await this.pollBmkg();
  }

  async pollBmkg(): Promise<void> {
    if (this.isPolling) {
      this.logger.debug('Polling is already in progress, skipping this run.');
      return;
    }

    this.isPolling = true;
    try {
      // Keep OpenQuake microservice awake in the background
      void this.pingMicroservice();

      this.logger.log('Starting polling BMKG EWS API...');
      const response = await fetch(
        'https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json',
      );

      if (!response.ok) {
        throw new Error(`BMKG API returned status code: ${response.status}`);
      }

      const data = (await response.json()) as BmkgEarthquakeResponse;
      if (!data || !data.Infogempa || !data.Infogempa.gempa) {
        this.logger.warn('Received invalid data format from BMKG API');
        return;
      }

      await this.processEarthquake(data.Infogempa.gempa, false);
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      this.logger.error(`Error polling BMKG EWS API: ${errorMessage}`);
    } finally {
      this.isPolling = false;
    }
  }

  async simulateAlert(dto: {
    magnitude: number;
    depth: string;
    latitude: number;
    longitude: number;
    potensi: string;
    wilayah: string;
  }): Promise<any> {
    const simulatedGempa: BmkgGempa = {
      Tanggal: new Date().toLocaleDateString('id-ID'),
      Jam: new Date().toLocaleTimeString('id-ID'),
      DateTime: new Date().toISOString(),
      Coordinates: `${dto.latitude},${dto.longitude}`,
      Magnitude: dto.magnitude.toString(),
      Kedalaman: dto.depth,
      Wilayah: dto.wilayah,
      Potensi: dto.potensi,
    };

    return this.processEarthquake(simulatedGempa, true);
  }

  private async pingMicroservice(): Promise<void> {
    const baseUrl =
      this.configService?.get<string>('OPENQUAKE_SERVICE_URL') ||
      process.env.OPENQUAKE_MICROSERVICE_URL ||
      process.env.OPENQUAKE_SERVICE_URL ||
      'http://localhost:8000';
    try {
      const res = await fetch(`${baseUrl}/health`, {
        signal: AbortSignal.timeout(5000),
      });
      if (res.ok) {
        this.logger.debug('OpenQuake microservice health ping successful');
      }
    } catch (err) {
      // Ignore ping failure silently in background
    }
  }

  private async lookupSlab2(
    latitude: number,
    longitude: number,
  ): Promise<Slab2Data> {
    try {
      const result = await this.deviceRepository.query(
        `SELECT
           (SELECT ST_Value(rast, ST_SetSRID(ST_Point($1, $2), 4326)) FROM slab2_depth_raster
            WHERE ST_Intersects(rast, ST_SetSRID(ST_Point($1, $2), 4326))) AS slab_depth,
           (SELECT ST_Value(rast, ST_SetSRID(ST_Point($1, $2), 4326)) FROM slab2_unc_raster
            WHERE ST_Intersects(rast, ST_SetSRID(ST_Point($1, $2), 4326))) AS slab_unc`,
        [longitude, latitude], // PENTING: ST_Point(lon, lat)
      );

      const row = result?.[0];
      return {
        slabDepth:
          row?.slab_depth !== undefined && row?.slab_depth !== null
            ? Number(row.slab_depth)
            : null,
        slabUnc:
          row?.slab_unc !== undefined && row?.slab_unc !== null
            ? Number(row.slab_unc)
            : null,
      };
    } catch (error) {
      this.logger.error(
        'Gagal lookup Slab2, fallback ke heuristik kedalaman statis:',
        error,
      );
      return { slabDepth: null, slabUnc: null };
    }
  }

  private classifyTectonicRegion(
    eqDepth: number,
    slab2: Slab2Data,
  ): { region: TectonicRegion; method: 'slab2' | 'static_fallback' } {
    // Metode utama: pakai geometri Slab2 riil kalau datanya tersedia
    if (slab2.slabDepth !== null && slab2.slabUnc !== null) {
      const buffer = slab2.slabUnc; // buffer dinamis dari slabUnc
      const dSlab = Math.abs(slab2.slabDepth); // Handle raster negative values
      const diff = eqDepth - dSlab;

      if (diff < -buffer) {
        return { region: 'shallow_crustal', method: 'slab2' };
      } else if (Math.abs(diff) <= buffer) {
        return { region: 'subduction_interface', method: 'slab2' };
      } else {
        return { region: 'subduction_intraslab', method: 'slab2' };
      }
    }

    // [working assumption] Fallback kedalaman statis nasional
    this.logger.warn(
      `Slab2 tidak ditemukan di episenter, pakai fallback statis untuk depth=${eqDepth}km`,
    );
    if (eqDepth < 30)
      return { region: 'shallow_crustal', method: 'static_fallback' };
    if (eqDepth <= 60)
      return { region: 'subduction_interface', method: 'static_fallback' };
    return { region: 'subduction_intraslab', method: 'static_fallback' };
  }

  private async calculateHazard(
    earthquake: {
      magnitude: number;
      depth: number;
      latitude: number;
      longitude: number;
      region: TectonicRegion;
    },
    devices: {
      deviceId: string;
      latitude: number;
      longitude: number;
      vs30: number;
    }[],
  ): Promise<HazardResult[]> {
    const baseUrl =
      this.configService?.get<string>('OPENQUAKE_SERVICE_URL') ||
      process.env.OPENQUAKE_MICROSERVICE_URL ||
      process.env.OPENQUAKE_SERVICE_URL ||
      'http://localhost:8000';
    const apiKey =
      this.configService?.get<string>('OPENQUAKE_API_KEY') ||
      process.env.OPENQUAKE_API_KEY ||
      'suar_secret_key_123';
    const url = `${baseUrl}/calculate-hazard`;

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: JSON.stringify({ earthquake, devices }),
        signal: AbortSignal.timeout(15000), // 15 detik timeout
      });

      if (!response.ok) {
        throw new Error(`Microservice merespons status ${response.status}`);
      }

      return (await response.json()) as HazardResult[];
    } catch (error) {
      this.logger.error('Gagal memanggil OpenQuake microservice:', error);
      return []; // fail-safe: mengembalikan array kosong daripada crash
    }
  }

  private async processEarthquake(
    rawGempa: BmkgGempa,
    isSimulation = false,
  ): Promise<any> {
    // Generate unique hash using DateTime and Coordinates if not simulation
    const bmkgId = isSimulation
      ? `SIMULASI_${Date.now()}`
      : this.generateUniqueBmkgId(rawGempa.DateTime, rawGempa.Coordinates);

    // Check for duplication if not simulation
    if (!isSimulation) {
      const existingAlert = await this.alertRepository.findOne({
        where: { bmkgId },
      });
      if (existingAlert) {
        this.logger.log(
          `Earthquake alert already processed (bmkgId: ${bmkgId.substring(0, 8)}). Skipping.`,
        );
        return { success: true, message: 'Duplicate alert' };
      }
    }

    // Parse values
    const magnitude = parseFloat(rawGempa.Magnitude);
    const depth = parseInt(rawGempa.Kedalaman.replace(/[^0-9]/g, ''), 10);
    const [latStr, lonStr] = rawGempa.Coordinates.split(',');
    const latitude = parseFloat(latStr);
    const longitude = parseFloat(lonStr);
    const date = new Date(rawGempa.DateTime);
    const wilayah = rawGempa.Wilayah;
    const potensi = rawGempa.Potensi;

    const epicenter: GeoJSON.Point = {
      type: 'Point',
      coordinates: [longitude, latitude],
    };

    // Filter thresholds: Magnitude >= 5.0 and Depth < 100 km (tsunami danger limit)
    // For simulation, we always pass threshold check
    const passesThreshold = isSimulation || (magnitude >= 5.0 && depth < 100);

    const newAlert = this.alertRepository.create({
      bmkgId,
      magnitude,
      depth: `${depth} km`,
      wilayah,
      potensi,
      epicenter,
      isBroadcasted: passesThreshold,
      alertTime: date,
    });

    await this.alertRepository.save(newAlert);

    if (this.eventEmitter) {
      this.eventEmitter.emit('earthquake.alertCreated', {
        alertId: newAlert.id,
        magnitude: newAlert.magnitude,
        depth: newAlert.depth,
        wilayah: newAlert.wilayah,
        potensi: newAlert.potensi,
        isBroadcasted: newAlert.isBroadcasted,
      });
    }

    let impactedCount = 0;
    let radiusInKm = 0;

    if (passesThreshold) {
      this.logger.warn(
        `[EWS TRIGGERED${isSimulation ? ' - SIMULATION' : ''}] New Earthquake Alert: M ${magnitude} Mw, Depth ${depth} km. Epicenter: ${wilayah}.`,
      );

      // 1. Coarse Bounding Box Filter (500 KM radius)
      const candidateDevices = await this.findDevicesInImpactZone(
        longitude,
        latitude,
        500,
      );

      let microserviceProcessed = false;

      if (candidateDevices.length > 0) {
        // Prepare devices array with vs30 and location coordinates
        const preparedDevices = candidateDevices
          .filter((d) => d.lastLocation && d.lastLocation.coordinates)
          .map((d) => ({
            deviceId: d.deviceId,
            latitude: d.lastLocation.coordinates[1],
            longitude: d.lastLocation.coordinates[0],
            vs30: d.vs30 ?? 270.0,
          }));

        if (preparedDevices.length > 0) {
          // 2. Lookup Slab2 & Classify Tectonic Region
          const slab2 = await this.lookupSlab2(latitude, longitude);
          const { region, method } = this.classifyTectonicRegion(depth, slab2);
          this.logger.log(`Tectonic region: ${region} (metode: ${method})`);

          // 3. Compute PGA & MMI via OpenQuake microservice
          const hazardResults = await this.calculateHazard(
            { magnitude, depth, latitude, longitude, region },
            preparedDevices,
          );

          if (hazardResults.length > 0) {
            // Map deviceId -> mmi
            const mmiMap = new Map<string, number>();
            hazardResults.forEach((h) => mmiMap.set(h.deviceId, h.mmi));

            // 4. Filter devices with MMI >= 5.0 (Intensity V)
            const devicesToAlert = candidateDevices.filter((d) => {
              const mmi = mmiMap.get(d.deviceId);
              return mmi !== undefined && mmi >= 5.0;
            });

            impactedCount = devicesToAlert.length;
            radiusInKm = 500;
            microserviceProcessed = true;

            this.logger.warn(
              `OpenQuake hazard calculated for ${candidateDevices.length} devices. Impacted (MMI >= V): ${impactedCount}`,
            );

            if (devicesToAlert.length > 0) {
              await this.sendFcmAlerts(
                devicesToAlert,
                magnitude,
                depth,
                wilayah,
                potensi,
                date,
                isSimulation,
                latitude,
                longitude,
              );
            }
          }
        }
      }

      // Secondary Fail-Safe: Fallback to Phase 2 Dynamic Radius if Microservice failed/down or returned empty
      if (!microserviceProcessed) {
        radiusInKm = this.calculateDynamicRadius(magnitude, depth, potensi);
        this.logger.log(
          `Fallback dynamic impact radius: ${radiusInKm} km based on magnitude and tsunami potential.`,
        );

        const impactedDevices = await this.findDevicesInImpactZone(
          longitude,
          latitude,
          radiusInKm,
        );

        impactedCount = impactedDevices.length;
        this.logger.warn(
          `Fallback Phase 2: Found ${impactedCount} devices in impact zone.`,
        );

        if (impactedDevices.length > 0) {
          await this.sendFcmAlerts(
            impactedDevices,
            magnitude,
            depth,
            wilayah,
            potensi,
            date,
            isSimulation,
            latitude,
            longitude,
          );
        }
      }
    } else {
      this.logger.log(
        `[EWS IGNORED] Earthquake below threshold: M ${magnitude} Mw, Depth ${depth} km. Saved to logs.`,
      );
    }

    return {
      success: true,
      alertId: newAlert.id,
      impactedCount,
      radiusInKm,
    };
  }

  private async sendFcmAlerts(
    devices: UserDevice[],
    magnitude: number,
    depth: number,
    wilayah: string,
    potensi: string,
    date: Date,
    isSimulation: boolean,
    latitude: number,
    longitude: number,
  ): Promise<void> {
    const isTsunami =
      !potensi.toLowerCase().includes('tidak berpotensi') &&
      (potensi.toLowerCase().includes('tsunami') || magnitude >= 6.5);
    const statusTindakan = isTsunami ? 'EVAKUASI' : 'BERLINDUNG';

    const prefix = isSimulation ? '[SIMULASI] ' : '';
    const title = isTsunami
      ? `🚨 ${prefix}PERINGATAN TSUNAMI (SUAR)`
      : `⚠️ ${prefix}PERINGATAN GEMPA BUMI (SUAR)`;
    const body = `${prefix}Gempa M ${magnitude} Mw, Kedalaman ${depth} km. Wilayah: ${wilayah}. Status: ${statusTindakan}.`;

    const tokens = devices
      .map((d) => d.fcmToken)
      .filter((t): t is string => Boolean(t));

    if (tokens.length === 0) return;

    const payloadData = {
      type: 'EARTHQUAKE_ALERT',
      magnitude: magnitude.toString(),
      depth: `${depth} km`,
      wilayah: isSimulation ? `${wilayah} (Simulasi)` : wilayah,
      potensi,
      statusTindakan,
      coordinates: `${latitude},${longitude}`,
      dateTime: date.toISOString(),
      isSimulation: isSimulation ? 'true' : 'false',
    };

    await this.firebaseService.sendPushNotification(
      tokens,
      title,
      body,
      payloadData,
    );
  }

  private generateUniqueBmkgId(
    dateTimeISO: string,
    coordinates: string,
  ): string {
    const rawString = `${dateTimeISO}_${coordinates}`;
    return crypto.createHash('sha256').update(rawString).digest('hex');
  }

  private calculateDynamicRadius(
    magnitude: number,
    depth: number,
    potensi: string,
  ): number {
    const isTsunami =
      !potensi.toLowerCase().includes('tidak berpotensi') &&
      (potensi.toLowerCase().includes('tsunami') || magnitude >= 6.5);

    let baseRadius = 50;
    if (isTsunami) {
      baseRadius = 250;
    } else if (magnitude >= 6.0) {
      baseRadius = 150;
    } else if (magnitude >= 5.5) {
      baseRadius = 100;
    }

    if (depth >= 70) {
      return Math.round(baseRadius * 0.5);
    } else if (depth >= 30) {
      return Math.round(baseRadius * 0.75);
    }
    return baseRadius;
  }

  private async findDevicesInImpactZone(
    longitude: number,
    latitude: number,
    radiusInKm: number,
  ): Promise<UserDevice[]> {
    const radiusInMeters = radiusInKm * 1000;
    return this.deviceRepository
      .createQueryBuilder('device')
      .where('device.fcmToken IS NOT NULL')
      .andWhere(
        `ST_DWithin(
          device.lastLocation::geography,
          ST_SetSRID(ST_Point(:lon, :lat), 4326)::geography,
          :radius
        )`,
        {
          lon: longitude,
          lat: latitude,
          radius: radiusInMeters,
        },
      )
      .getMany();
  }

  async getLatestAlert(): Promise<EarthquakeAlert | null> {
    return this.alertRepository.findOne({
      where: {},
      order: { alertTime: 'DESC' },
    });
  }
}
