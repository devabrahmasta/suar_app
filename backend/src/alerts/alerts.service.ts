import { Injectable, Logger, OnModuleInit, Optional, NotFoundException } from '@nestjs/common';
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

  // Official BMKG InaTEWS & Seismic Hazard EWS Static Thresholds
  public static readonly MIN_MAGNITUDE_EWS = 5.0;
  public static readonly MAX_DEPTH_EWS = 300.0;
  public static readonly TSUNAMI_MIN_MAGNITUDE = 6.5;
  public static readonly TSUNAMI_MAX_DEPTH = 100.0;

  getTsunamiReachRadius(magnitude: number): number {
    if (magnitude >= 8.0) return 1200; // km
    if (magnitude >= 7.0) return 700;  // km
    if (magnitude >= 6.5) return 400;  // km
    return 250; // km
  }

  constructor(
    @InjectRepository(EarthquakeAlert)
    private readonly alertRepository: Repository<EarthquakeAlert>,
    @InjectRepository(UserDevice)
    private readonly deviceRepository: Repository<UserDevice>,
    private readonly firebaseService: FirebaseService,
    @Optional() private readonly eventEmitter?: EventEmitter2,
    @Optional() private readonly configService?: ConfigService,
  ) { }

  async onModuleInit() {
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
        'https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json',
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
    // Filter by Jawa-Bali regional boundary & impact radius
    const isJawaBali = this.isJawaBaliRegion(latitude, longitude);
    const reachesJawaBali = isJawaBali || this.impactsJawaBali(latitude, longitude, magnitude);

    const passesThreshold =
      isSimulation ||
      (magnitude >= AlertsService.MIN_MAGNITUDE_EWS &&
        depth <= AlertsService.MAX_DEPTH_EWS &&
        reachesJawaBali);

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

      const isTsunamiPotential =
        !potensi.toLowerCase().includes('tidak berpotensi') &&
        (potensi.toLowerCase().includes('tsunami') ||
          (magnitude >= AlertsService.TSUNAMI_MIN_MAGNITUDE && depth <= AlertsService.TSUNAMI_MAX_DEPTH));

      const tsunamiReachRadius = this.getTsunamiReachRadius(magnitude);
      const searchRadiusKm = Math.max(500, tsunamiReachRadius);

      // 1. Coarse Bounding Box Filter (Search Radius based on max reach)
      const candidateDevices = await this.findDevicesInImpactZone(
        longitude,
        latitude,
        searchRadiusKm,
      );

      let microserviceProcessed = false;

      if (candidateDevices.length > 0) {
        // Build device distance map from epicenter
        const deviceDistanceMap = new Map<string, number>();
        candidateDevices.forEach((d) => {
          if (d.lastLocation && d.lastLocation.coordinates) {
            const dist = this.calculateHaversineDistance(
              latitude,
              longitude,
              d.lastLocation.coordinates[1],
              d.lastLocation.coordinates[0],
            );
            deviceDistanceMap.set(d.deviceId, dist);
          }
        });

        // 2. Separate Tsunami Red Zone Devices within Tsunami Reach Distance
        const tsunamiRedZoneDevices = isTsunamiPotential
          ? candidateDevices.filter((d) => {
              const dist = deviceDistanceMap.get(d.deviceId);
              return d.isRedZone && dist !== undefined && dist <= tsunamiReachRadius;
            })
          : [];

        const tsunamiDeviceIdSet = new Set(
          tsunamiRedZoneDevices.map((d) => d.deviceId),
        );

        // Prepare devices for OpenQuake shaking hazard
        const preparedDevices = candidateDevices
          .filter((d) => d.lastLocation && d.lastLocation.coordinates)
          .map((d) => ({
            deviceId: d.deviceId,
            latitude: d.lastLocation.coordinates[1],
            longitude: d.lastLocation.coordinates[0],
            vs30: d.vs30 ?? 270.0,
          }));

        if (preparedDevices.length > 0) {
          const slab2 = await this.lookupSlab2(latitude, longitude);
          const { region, method } = this.classifyTectonicRegion(depth, slab2);
          this.logger.log(`Tectonic region: ${region} (metode: ${method})`);

          const hazardResults = await this.calculateHazard(
            { magnitude, depth, latitude, longitude, region },
            preparedDevices,
          );

          if (hazardResults.length > 0) {
            const mmiMap = new Map<string, number>();
            hazardResults.forEach((h) => mmiMap.set(h.deviceId, h.mmi));

            // Shaking devices with MMI >= V (excluding tsunami red zone devices to prevent duplicate FCM)
            const shakingDevices = candidateDevices.filter((d) => {
              const mmi = mmiMap.get(d.deviceId);
              return (
                mmi !== undefined &&
                mmi >= 5.0 &&
                !tsunamiDeviceIdSet.has(d.deviceId)
              );
            });

            impactedCount = tsunamiRedZoneDevices.length + shakingDevices.length;
            radiusInKm = searchRadiusKm;
            microserviceProcessed = true;

            // Send Tsunami Evacuation Push Alerts to Coastal Red Zone Users within Tsunami Propagation Distance
            if (tsunamiRedZoneDevices.length > 0) {
              this.logger.warn(
                `Sending TSUNAMI_EVACUATION_ALERT to ${tsunamiRedZoneDevices.length} devices in coastal red zone within ${tsunamiReachRadius} km.`,
              );
              await this.sendFcmAlerts(
                tsunamiRedZoneDevices,
                magnitude,
                depth,
                wilayah,
                potensi,
                date,
                isSimulation,
                latitude,
                longitude,
                'TSUNAMI_EVACUATION_ALERT',
              );
            }

            // Send Shaking Push Alerts to users experiencing MMI >= V
            if (shakingDevices.length > 0) {
              this.logger.warn(
                `Sending EARTHQUAKE_ALERT to ${shakingDevices.length} devices with MMI >= V.`,
              );
              await this.sendFcmAlerts(
                shakingDevices,
                magnitude,
                depth,
                wilayah,
                potensi,
                date,
                isSimulation,
                latitude,
                longitude,
                'EARTHQUAKE_ALERT',
              );
            }
          }
        }
      }

      // Secondary Fail-Safe: Fallback to Dynamic Radius if Microservice down
      if (!microserviceProcessed) {
        radiusInKm = this.calculateDynamicRadius(magnitude, depth, potensi);
        const impactedDevices = await this.findDevicesInImpactZone(
          longitude,
          latitude,
          radiusInKm,
        );

        impactedCount = impactedDevices.length;

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
            isTsunamiPotential ? 'TSUNAMI_EVACUATION_ALERT' : 'EARTHQUAKE_ALERT',
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
    alertType: 'TSUNAMI_EVACUATION_ALERT' | 'EARTHQUAKE_ALERT' = 'EARTHQUAKE_ALERT',
  ): Promise<void> {
    const isTsunamiEvacuation = alertType === 'TSUNAMI_EVACUATION_ALERT';
    const statusTindakan = isTsunamiEvacuation ? 'EVAKUASI TSUNAMI' : 'BERLINDUNG';

    const prefix = isSimulation ? '[SIMULASI] ' : '';
    const title = isTsunamiEvacuation
      ? `🚨 ${prefix}PERINGATAN EVAKUASI TSUNAMI (SUAR)`
      : `⚠️ ${prefix}PERINGATAN GEMPA BUMI (SUAR)`;

    const body = isTsunamiEvacuation
      ? `${prefix}Peringatan Tsunami! Gempa M ${magnitude} Mw di ${wilayah}. Anda berada di Zona Merah Tsunami. Segera evakuasi ke TPS/TPA!`
      : `${prefix}Gempa M ${magnitude} Mw, Kedalaman ${depth} km. Wilayah: ${wilayah}. Status: BERLINDUNG.`;

    const tokens = devices
      .map((d) => d.fcmToken)
      .filter((t): t is string => Boolean(t));

    if (tokens.length === 0) return;

    const payloadData = {
      type: alertType,
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

  isJawaBaliRegion(latitude: number, longitude: number): boolean {
    const minLat = -9.20;
    const maxLat = -5.00;
    const minLon = 105.00;
    const maxLon = 116.00;
    return (
      latitude >= minLat &&
      latitude <= maxLat &&
      longitude >= minLon &&
      longitude <= maxLon
    );
  }

  impactsJawaBali(
    latitude: number,
    longitude: number,
    magnitude: number,
  ): boolean {
    const estimatedRadiusKm = magnitude >= 6.5 ? 400 : magnitude >= 5.5 ? 200 : 100;
    const minLat = -9.20;
    const maxLat = -5.00;
    const minLon = 105.00;
    const maxLon = 116.00;

    const closestLat = Math.max(minLat, Math.min(latitude, maxLat));
    const closestLon = Math.max(minLon, Math.min(longitude, maxLon));

    const distanceKm = this.calculateHaversineDistance(
      latitude,
      longitude,
      closestLat,
      closestLon,
    );

    return distanceKm <= estimatedRadiusKm;
  }

  async calculateUserImpact(
    latitude: number,
    longitude: number,
    earthquakeId: string,
  ) {
    let alert = await this.alertRepository.findOne({
      where: { id: earthquakeId },
    });

    if (!alert) {
      alert = await this.alertRepository.findOne({
        where: { bmkgId: earthquakeId },
      });
    }

    if (!alert) {
      throw new NotFoundException(
        `Earthquake alert with ID '${earthquakeId}' not found.`,
      );
    }

    const eqLon = alert.epicenter.coordinates[0];
    const eqLat = alert.epicenter.coordinates[1];

    const distanceKm = this.calculateHaversineDistance(
      latitude,
      longitude,
      eqLat,
      eqLon,
    );

    const magnitude = Number(alert.magnitude);
    const depthKm = parseInt(alert.depth.replace(/[^0-9]/g, ''), 10) || 10;
    const hypocentralDist = Math.sqrt(distanceKm * distanceKm + depthKm * depthKm);

    const pgaGal =
      (108.4 * Math.pow(10, 0.299 * magnitude)) /
      Math.pow(hypocentralDist + 25, 1.2);
    const mmi = Math.max(
      1,
      Math.min(12, Number((3.66 * Math.log10(pgaGal) - 1.66).toFixed(1))),
    );

    let shakingLevel = 'MINOR';
    if (mmi >= 7) shakingLevel = 'VERY_SEVERE';
    else if (mmi >= 5) shakingLevel = 'MODERATE';
    else if (mmi >= 3) shakingLevel = 'LIGHT';

    const isTsunamiPotential =
      !alert.potensi.toLowerCase().includes('tidak berpotensi') &&
      (alert.potensi.toLowerCase().includes('tsunami') || magnitude >= 6.5);

    const isUserInJawaBali = this.isJawaBaliRegion(latitude, longitude);

    return {
      earthquakeId: alert.id,
      bmkgId: alert.bmkgId,
      magnitude: alert.magnitude,
      depth: alert.depth,
      wilayah: alert.wilayah,
      potensi: alert.potensi,
      isTsunamiPotential,
      isUserInJawaBaliScope: isUserInJawaBali,
      epicenter: { latitude: eqLat, longitude: eqLon },
      userLocation: { latitude, longitude },
      distanceKm: Number(distanceKm.toFixed(2)),
      estimatedMmi: mmi,
      shakingLevel,
      alertTime: alert.alertTime,
    };
  }

  calculateHaversineDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const R = 6371; // Earth radius in KM
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
}

