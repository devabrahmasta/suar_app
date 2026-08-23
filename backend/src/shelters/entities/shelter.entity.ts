import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';
import * as GeoJSON from 'geojson';

export enum ShelterType {
  TPS = 'TPS',
  TPA = 'TPA',
}

@Entity('shelters')
export class Shelter {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ nullable: true })
  name: string;

  @Column({
    type: 'varchar',
    length: 10,
    default: 'TPS',
  })
  @Index('idx_shelters_type')
  type: ShelterType;

  @Column({
    type: 'geometry',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  @Index({ spatial: true })
  location: GeoJSON.Point;

  @Column({ nullable: true, default: 0 })
  capacity: number;

  @Column({ name: 'current_evacuees', default: 0 })
  currentEvacuees: number;

  @Column({ default: 'active' })
  status: string;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  source: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
