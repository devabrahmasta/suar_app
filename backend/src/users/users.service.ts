import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { UserDevice } from './entities/user-device.entity';
import * as GeoJSON from 'geojson';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(UserDevice)
    private readonly userDeviceRepository: Repository<UserDevice>,
    @Optional() private readonly eventEmitter?: EventEmitter2,
  ) {}

  async lookupVs30(latitude: number, longitude: number): Promise<number> {
    const DEFAULT_VS30 = 270.0; // Fallback SNI 1726:2019 kelas tanah SD (sedang)

    try {
      // PENTING: ST_Point($1, $2) di PostGIS selalu (longitude, latitude)
      const result = await this.userDeviceRepository.query(
        `SELECT ST_Value(rast, ST_SetSRID(ST_Point($1, $2), 4326)) AS vs30
         FROM vs30_soil_raster
         WHERE ST_Intersects(rast, ST_SetSRID(ST_Point($1, $2), 4326))
         LIMIT 1`,
        [longitude, latitude],
      );

      const vs30 = result?.[0]?.vs30;
      return vs30 !== null && vs30 !== undefined && !isNaN(Number(vs30))
        ? Number(vs30)
        : DEFAULT_VS30;
    } catch (error) {
      console.error('Gagal lookup Vs30, pakai default:', error);
      return DEFAULT_VS30;
    }
  }

  async registerDevice(
    deviceId: string,
    fcmToken: string,
    homeType?: string,
    homeLatitude?: number,
    homeLongitude?: number,
  ): Promise<UserDevice> {
    let device = await this.userDeviceRepository.findOne({
      where: { deviceId },
    });

    let homeLocation: GeoJSON.Point | undefined = undefined;
    let vs30: number | undefined = undefined;
    if (homeLatitude !== undefined && homeLongitude !== undefined) {
      homeLocation = {
        type: 'Point',
        coordinates: [homeLongitude, homeLatitude],
      };
      vs30 = await this.lookupVs30(homeLatitude, homeLongitude);
    }

    if (!device) {
      device = this.userDeviceRepository.create({
        deviceId,
        fcmToken,
        homeType,
        homeLocation,
        vs30: vs30 ?? 270.0,
        lastActive: new Date(),
      });
    } else {
      device.fcmToken = fcmToken;
      if (homeType) device.homeType = homeType;
      if (homeLocation) {
        device.homeLocation = homeLocation;
        device.vs30 = vs30 ?? 270.0;
      }
      device.lastActive = new Date();
    }

    return this.userDeviceRepository.save(device);
  }

  async updateLocation(
    deviceId: string,
    latitude: number,
    longitude: number,
  ): Promise<UserDevice> {
    const device = await this.userDeviceRepository.findOne({
      where: { deviceId },
    });

    if (!device) {
      throw new NotFoundException(
        `Perangkat dengan ID ${deviceId} tidak ditemukan`,
      );
    }

    const vs30 = await this.lookupVs30(latitude, longitude);

    device.lastLocation = {
      type: 'Point',
      coordinates: [longitude, latitude],
    };
    device.vs30 = vs30;
    device.lastActive = new Date();

    const saved = await this.userDeviceRepository.save(device);

    if (this.eventEmitter) {
      this.eventEmitter.emit('user.locationUpdated', {
        deviceId: saved.deviceId,
        latitude,
        longitude,
        vs30,
        lastActive: saved.lastActive,
      });
    }

    return saved;
  }
}
