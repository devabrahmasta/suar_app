import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EarthquakeAlert } from './entities/earthquake-alert.entity';
import { UserDevice } from '../users/entities/user-device.entity';
import { TsunamiHazardPolygon } from './entities/tsunami-hazard.entity';
import { AlertsService } from './alerts.service';
import { AlertsController } from './alerts.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      EarthquakeAlert,
      UserDevice,
      TsunamiHazardPolygon,
    ]),
  ],
  controllers: [AlertsController],
  providers: [AlertsService],
  exports: [AlertsService],
})
export class AlertsModule {}

