import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TsunamiService } from './tsunami.service';
import { TsunamiController } from './tsunami.controller';
import { TsunamiHazardPolygon } from '../alerts/entities/tsunami-hazard.entity';

@Module({
  imports: [TypeOrmModule.forFeature([TsunamiHazardPolygon])],
  controllers: [TsunamiController],
  providers: [TsunamiService],
  exports: [TsunamiService],
})
export class TsunamiModule {}
