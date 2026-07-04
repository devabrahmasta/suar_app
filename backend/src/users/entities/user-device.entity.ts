import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';
import * as GeoJSON from 'geojson';

@Entity('user_devices')
export class UserDevice {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'device_id', unique: true })
  deviceId: string;

  @Column({ name: 'fcm_token', nullable: true })
  fcmToken: string;

  @Column({
    type: 'geometry',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  @Index({ spatial: true })
  homeLocation: GeoJSON.Point;

  @Column({
    type: 'geometry',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  @Index({ spatial: true })
  lastLocation: GeoJSON.Point;

  @Column({ name: 'home_type', nullable: true })
  homeType: string;

  @Column({ name: 'last_active', default: () => 'CURRENT_TIMESTAMP' })
  lastActive: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
