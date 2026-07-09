import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Interval } from '@nestjs/schedule';
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

    let impactedCount = 0;
    let radiusInKm = 0;

    if (passesThreshold) {
      this.logger.warn(
        `[EWS TRIGGERED${isSimulation ? ' - SIMULATION' : ''}] New Earthquake Alert: M ${magnitude} Mw, Depth ${depth} km. Epicenter: ${wilayah}.`,
      );

      // Determine dynamic radius
      radiusInKm = this.calculateDynamicRadius(magnitude, depth, potensi);
      this.logger.log(
        `Calculated dynamic impact radius: ${radiusInKm} km based on magnitude and tsunami potential.`,
      );

      // Query impacted devices
      const impactedDevices = await this.findDevicesInImpactZone(
        longitude,
        latitude,
        radiusInKm,
      );

      impactedCount = impactedDevices.length;

      this.logger.warn(
        `Found ${impactedDevices.length} devices in the impact zone for ${isSimulation ? 'simulated' : 'real'} earthquake.`,
      );

      if (impactedDevices.length > 0) {
        const isTsunami =
          potensi.toLowerCase().includes('tsunami') || magnitude >= 6.5;
        const statusTindakan = isTsunami ? 'EVAKUASI' : 'BERLINDUNG';

        const prefix = isSimulation ? '[SIMULASI] ' : '';
        const title = isTsunami
          ? `🚨 ${prefix}PERINGATAN TSUNAMI (SUAR)`
          : `⚠️ ${prefix}PERINGATAN GEMPA BUMI (SUAR)`;
        const body = `${prefix}Gempa M ${magnitude} Mw, Kedalaman ${depth} km. Wilayah: ${wilayah}. Status: ${statusTindakan}.`;

        const tokens = impactedDevices.map((d) => d.fcmToken);

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

        // Kirim notifikasi nyata ke Firebase Admin SDK
        await this.firebaseService.sendPushNotification(
          tokens,
          title,
          body,
          payloadData,
        );
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
      potensi.toLowerCase().includes('tsunami') || magnitude >= 6.5;

    let baseRadius = 50;
    if (isTsunami) {
      baseRadius = 250;
    } else if (magnitude >= 6.0) {
      baseRadius = 150;
    } else if (magnitude >= 5.5) {
      baseRadius = 100;
    }

    // Koreksi kedalaman (Depth Attenuation Factor):
    // Semakin dalam pusat gempa, semakin kecil jangkauan rambat energi getaran di permukaan.
    if (depth >= 70) {
      return Math.round(baseRadius * 0.5); // Reduksi 50% untuk gempa dalam (>= 70 km)
    } else if (depth >= 30) {
      return Math.round(baseRadius * 0.75); // Reduksi 25% untuk gempa menengah (30 - 69 km)
    }
    return baseRadius; // Gempa dangkal (<30 km) memiliki radius dampak maksimal
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
