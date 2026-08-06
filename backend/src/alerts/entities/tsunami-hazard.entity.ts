import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

@Entity('tsunami_hazard_polygons')
export class TsunamiHazardPolygon {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'hazard_level', type: 'varchar', length: 50, default: 'HIGH' })
  hazardLevel: string;

  @Index('idx_tsunami_hazard_geom', { spatial: true })
  @Column({
    type: 'geometry',
    spatialFeatureType: 'Geometry',
    srid: 4326,
    nullable: true,
  })
  geom: string;
}
