import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ShelterType } from '../entities/shelter.entity';

export { ShelterType };

export class CreateShelterDto {
  @ApiPropertyOptional({
    description: 'Name or title of the shelter/evacuation point',
    example: 'Posko Evakuasi Parangtritis',
  })
  name?: string;

  @ApiProperty({
    description: 'Latitude coordinate of the shelter',
    example: -7.968502,
  })
  latitude: number;

  @ApiProperty({
    description: 'Longitude coordinate of the shelter',
    example: 110.255611,
  })
  longitude: number;

  @ApiProperty({
    description:
      'Type of evacuation point: TPS (Tempat Pengungsian Sementara) or TPA (Tempat Pengungsian Akhir)',
    enum: ['TPS', 'TPA'],
    example: 'TPA',
  })
  type: ShelterType;

  @ApiPropertyOptional({
    description: 'Maximum capacity of evacuees',
    example: 500,
  })
  capacity?: number;

  @ApiPropertyOptional({
    description: 'Operational status of shelter (active, full, inactive)',
    example: 'active',
  })
  status?: string;

  @ApiPropertyOptional({
    description: 'Additional notes or facilities description',
    example: 'Akses mudah dari jalan utama, dekat fasilitas kesehatan',
  })
  notes?: string;

  @ApiPropertyOptional({
    description: 'Source or origin of shelter data',
    example: 'digitized_bpbd_peta_2010',
  })
  source?: string;
}
