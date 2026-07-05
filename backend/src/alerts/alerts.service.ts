import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Interval } from '@nestjs/schedule';
import { EarthquakeAlert } from './entities/earthquake-alert.entity';
import { UserDevice } from '../users/entities/user-device.entity';
import * as GeoJSON from 'geojson';
import * as crypto from 'crypto';

@Injectable()
export class AlertsService implements OnModuleInit {
  private readonly logger = new Logger(AlertsService.name);
  private isPolling = false;

  constructor(
    @InjectRepository(EarthquakeAlert)
    private readonly alertRepository: Repository<EarthquakeAlert>,
    @InjectRepository(UserDevice)
    private readonly deviceRepository: Repository<UserDevice>,
  ) {}

  onModuleInit() {
    this.logger.log('AlertsService has been initialized. Polling starts automatically.');
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
      this.logger.log('Starting polling BMKG EWS API...');
      const response = await fetch('https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json');
      
      if (!response.ok) {
        throw new Error(`BMKG API returned status code: ${response.status}`);
      }

      const data = await response.json();
      if (!data || !data.Infogempa || !data.Infogempa.gempa) {
        this.logger.warn('Received invalid data format from BMKG API');
        return;
      }

      const rawGempa = data.Infogempa.gempa;
      
      // Generate unique hash using DateTime and Coordinates
      const bmkgId = this.generateUniqueBmkgId(rawGempa.DateTime, rawGempa.Coordinates);
      
      // Check for duplication
      const existingAlert = await this.alertRepository.findOne({ where: { bmkgId } });
      if (existingAlert) {
        this.logger.log(`Earthquake alert already processed (bmkgId: ${bmkgId.substring(0, 8)}). Skipping.`);
        return;
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
      const dirasakan = rawGempa.Dirasakan || 'Tidak dirasakan secara signifikan';

      const epicenter: GeoJSON.Point = {
        type: 'Point',
        coordinates: [longitude, latitude],
      };

      // Filter thresholds: Magnitude >= 5.0 and Depth < 100 km (tsunami danger limit)
      const passesThreshold = magnitude >= 5.0 && depth < 100;

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

      if (passesThreshold) {
        this.logger.warn(
          `[EWS TRIGGERED] New Earthquake Alert: M ${magnitude} Mw, Depth ${depth} km. Epicenter: ${wilayah}.`
        );
        
        // Determine dynamic radius
        const radiusInKm = this.calculateDynamicRadius(magnitude, potensi);
        this.logger.log(`Calculated dynamic impact radius: ${radiusInKm} km based on magnitude and tsunami potential.`);
        
        // Query impacted devices
        const impactedDevices = await this.findDevicesInImpactZone(longitude, latitude, radiusInKm);
        
        this.logger.warn(`Found ${impactedDevices.length} devices in the impact zone.`);
        
        // Broadcast simulation
        for (const device of impactedDevices) {
          const isTsunami = potensi.toLowerCase().includes('tsunami') || magnitude >= 6.5;
          const statusTindakan = isTsunami ? 'EVAKUASI' : 'BERLINDUNG';
          
          this.logger.warn(
            `[FCM BROADCAST] Sending Alert to Device ${device.deviceId} (Token: ${device.fcmToken}) - Action Status: ${statusTindakan} | MMI: ${dirasakan}`
          );
        }
      } else {
        this.logger.log(
          `[EWS IGNORED] Earthquake below threshold: M ${magnitude} Mw, Depth ${depth} km. Saved to logs.`
        );
      }

    } catch (error) {
      this.logger.error(`Error polling BMKG EWS API: ${error.message}`);
    } finally {
      this.isPolling = false;
    }
  }

  private generateUniqueBmkgId(dateTimeISO: string, coordinates: string): string {
    const rawString = `${dateTimeISO}_${coordinates}`;
    return crypto.createHash('sha256').update(rawString).digest('hex');
  }

  private calculateDynamicRadius(magnitude: number, potensi: string): number {
    const isTsunami = potensi.toLowerCase().includes('tsunami') || magnitude >= 6.5;
    if (isTsunami) {
      return 250; // Tsunami potential or large earthquakes impact up to 250 km radius (especially coastlines)
    }

    if (magnitude >= 6.0) return 150;
    if (magnitude >= 5.5) return 100;
    return 50; // For magnitude 5.0 - 5.4
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
}
