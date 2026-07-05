import { Controller, Post, Body } from '@nestjs/common';
import { UsersService } from './users.service';
import { ApiTags, ApiOperation, ApiBody, ApiResponse } from '@nestjs/swagger';

@ApiTags('users')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post('register-device')
  @ApiOperation({
    summary: 'Register or update user device token and home location',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        deviceId: {
          type: 'string',
          example: 'device-uuid-1234',
          description: 'Unique ID of the physical device',
        },
        fcmToken: {
          type: 'string',
          example: 'fcm-token-xyz',
          description: 'Firebase Cloud Messaging token for push alerts',
        },
        homeType: {
          type: 'string',
          example: 'Rumah',
          description: 'Type of dwelling (Rumah/Apartemen/etc.)',
          nullable: true,
        },
        homeLatitude: {
          type: 'number',
          example: -7.7956,
          description: 'Latitude coordinate of home location',
          nullable: true,
        },
        homeLongitude: {
          type: 'number',
          example: 110.3695,
          description: 'Longitude coordinate of home location',
          nullable: true,
        },
      },
      required: ['deviceId', 'fcmToken'],
    },
  })
  @ApiResponse({ status: 201, description: 'Device registered successfully.' })
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
  @ApiOperation({ summary: 'Update last active geolocation of user device' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        deviceId: {
          type: 'string',
          example: 'device-uuid-1234',
          description: 'Unique ID of the registered device',
        },
        latitude: {
          type: 'number',
          example: -7.7956,
          description: 'Current latitude coordinate',
        },
        longitude: {
          type: 'number',
          example: 110.3695,
          description: 'Current longitude coordinate',
        },
      },
      required: ['deviceId', 'latitude', 'longitude'],
    },
  })
  @ApiResponse({ status: 201, description: 'Location updated successfully.' })
  @ApiResponse({ status: 404, description: 'Device not found.' })
  async updateLocation(
    @Body('deviceId') deviceId: string,
    @Body('latitude') latitude: number,
    @Body('longitude') longitude: number,
  ) {
    return this.usersService.updateLocation(deviceId, latitude, longitude);
  }
}
