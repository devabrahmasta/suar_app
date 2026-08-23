import { ApiProperty } from '@nestjs/swagger';

export class CalculateImpactDto {
  @ApiProperty({
    description: 'Latitude of the client location',
    example: -6.2,
  })
  latitude: number;

  @ApiProperty({
    description: 'Longitude of the client location',
    example: 106.816,
  })
  longitude: number;

  @ApiProperty({
    description: 'ID of the earthquake alert record (UUID or BMKG ID)',
    example: '550e8400-e29b-41d4-a716-446655440000',
  })
  earthquakeId: string;
}
