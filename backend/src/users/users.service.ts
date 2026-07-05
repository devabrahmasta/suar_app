import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserDevice } from './entities/user-device.entity';
import * as GeoJSON from 'geojson';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(UserDevice)
    private readonly userDeviceRepository: Repository<UserDevice>,
  ) {}

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
    if (homeLatitude !== undefined && homeLongitude !== undefined) {
      homeLocation = {
        type: 'Point',
        coordinates: [homeLongitude, homeLatitude],
      };
    }

    if (!device) {
      device = this.userDeviceRepository.create({
        deviceId,
        fcmToken,
        homeType,
        homeLocation,
        lastActive: new Date(),
      });
    } else {
      device.fcmToken = fcmToken;
      if (homeType) device.homeType = homeType;
      if (homeLocation) device.homeLocation = homeLocation;
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

    device.lastLocation = {
      type: 'Point',
      coordinates: [longitude, latitude],
    };
    device.lastActive = new Date();

    return this.userDeviceRepository.save(device);
  }
}
