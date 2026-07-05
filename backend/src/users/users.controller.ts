import { Controller, Post, Body } from '@nestjs/common';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post('register-device')
  async registerDevice(
    @Body('deviceId') deviceId: string,
    @Body('fcmToken') fcmToken: string,
    @Body('homeType') homeType?: string,
    @Body('homeLatitude') homeLatitude?: number,
    @Body('homeLongitude') homeLongitude?: number,
  ) {
    return this.usersService.registerDevice(
      deviceId,
      fcmToken,
      homeType,
      homeLatitude,
      homeLongitude,
    );
  }

  @Post('update-location')
  async updateLocation(
    @Body('deviceId') deviceId: string,
    @Body('latitude') latitude: number,
    @Body('longitude') longitude: number,
  ) {
    return this.usersService.updateLocation(deviceId, latitude, longitude);
  }
}
