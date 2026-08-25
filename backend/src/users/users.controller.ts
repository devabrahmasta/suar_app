import { Controller, Post, Body } from '@nestjs/common';
import { UsersService } from './users.service';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { UpdateLocationDto } from './dto/update-location.dto';

@ApiTags('devices')
@Controller()
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post(['devices/register', 'users/register-device'])
  @ApiOperation({
    summary: 'Register or update user device FCM token and home location',
  })
  @ApiResponse({ status: 201, description: 'Device registered successfully.' })
  async registerDevice(@Body() dto: RegisterDeviceDto) {
    return this.usersService.registerDevice(
      dto.deviceId,
      dto.fcmToken,
      dto.homeType,
      dto.homeLatitude,
      dto.homeLongitude,
    );
  }

  @Post(['devices/location', 'users/update-location'])
  @ApiOperation({ summary: 'Update real-time active geolocation of user device and red zone status' })
  @ApiResponse({ status: 201, description: 'Location updated successfully.' })
  @ApiResponse({ status: 404, description: 'Device not found.' })
  async updateLocation(@Body() dto: UpdateLocationDto) {
    return this.usersService.updateLocation(
      dto.deviceId,
      dto.latitude,
      dto.longitude,
      dto.isRedZone,
    );
  }
}
