import { ApiProperty } from '@nestjs/swagger';

export class VerifyLocationDto {
  @ApiProperty({
    description: 'Latitude coordinate of the user location',
    example: -8.02,
  })
  latitude: number;

  @ApiProperty({
    description: 'Longitude coordinate of the user location',
    example: 110.33,
  })
  longitude: number;
}
