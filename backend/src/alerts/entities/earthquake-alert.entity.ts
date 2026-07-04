import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';
import * as GeoJSON from 'geojson';

@Entity('earthquake_alerts')
export class EarthquakeAlert {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'bmkg_id', unique: true, nullable: true })
  bmkgId: string;

  @Column({ type: 'decimal', precision: 3, scale: 1 })
  magnitude: number;

  @Column()
  depth: string;

  @Column()
  wilayah: string;

  @Column()
  potensi: string;

  @Column({
    type: 'geometry',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  @Index({ spatial: true })
  epicenter: GeoJSON.Point;

  @Column({ name: 'is_broadcasted', default: false })
  isBroadcasted: boolean;

  @Column({ name: 'alert_time' })
  alertTime: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
