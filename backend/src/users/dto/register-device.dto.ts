import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RegisterDeviceDto {
  @ApiProperty({
    description: 'Unique identifier of the physical mobile device',
    example: 'device-uuid-1234-xyz',
  })
  deviceId: string;

  @ApiProperty({
    description: 'Firebase Cloud Messaging (FCM) token for targeted emergency alerts',
    example: 'fcm-token-sample-abc-123',
  })
  fcmToken: string;

  @ApiPropertyOptional({
    description: 'Dwelling/home building type (e.g., Rumah, Apartemen, Ruko)',
    example: 'Rumah',
  })
  homeType?: string;

  @ApiPropertyOptional({
    description: 'Latitude coordinate of home/primary location',
    example: -7.7956,
  })
  homeLatitude?: number;

  @ApiPropertyOptional({
    description: 'Longitude coordinate of home/primary location',
    example: 110.3695,
  })
  homeLongitude?: number;
}
