import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateLocationDto {
  @ApiProperty({
    description: 'Unique identifier of the registered device',
    example: 'device-uuid-1234-xyz',
  })
  deviceId: string;

  @ApiProperty({
    description: 'Current latitude coordinate of the device',
    example: -7.7956,
  })
  latitude: number;

  @ApiProperty({
    description: 'Current longitude coordinate of the device',
    example: 110.3695,
  })
  longitude: number;

  @ApiPropertyOptional({
    description: 'Optional boolean status evaluated locally by Flutter client indicating if user is in Tsunami Red Zone',
    example: true,
  })
  isRedZone?: boolean;
}
