import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Shelter } from './entities/shelter.entity';
import { SheltersService } from './shelters.service';
import { SheltersController } from './shelters.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Shelter])],
  controllers: [SheltersController],
  providers: [SheltersService],
  exports: [SheltersService],
})
export class SheltersModule {}
