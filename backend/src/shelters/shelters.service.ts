import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2, OnEvent } from '@nestjs/event-emitter';
import { Shelter } from './entities/shelter.entity';
import * as GeoJSON from 'geojson';

export interface CreateShelterDto {
  name: string;
  latitude: number;
  longitude: number;
  capacity: number;
  notes?: string;
}

@Injectable()
export class SheltersService {
  private readonly logger = new Logger(SheltersService.name);

  constructor(
    @InjectRepository(Shelter)
    private readonly shelterRepository: Repository<Shelter>,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async createShelter(dto: CreateShelterDto): Promise<Shelter> {
    const location: GeoJSON.Point = {
      type: 'Point',
      coordinates: [dto.longitude, dto.latitude],
    };

    const shelter = this.shelterRepository.create({
      name: dto.name,
      location,
      capacity: dto.capacity,
      currentEvacuees: 0,
      status: 'active',
      notes: dto.notes,
    });

    const saved = await this.shelterRepository.save(shelter);
    this.eventEmitter.emit('shelter.created', { shelterId: saved.id, name: saved.name });
    return saved;
  }

  async getAllShelters(): Promise<Shelter[]> {
    return this.shelterRepository.find({
      order: { createdAt: 'DESC' },
    });
  }

  async findNearbyShelters(
    latitude: number,
    longitude: number,
    radiusInKm = 50,
  ): Promise<Shelter[]> {
    const radiusInMeters = radiusInKm * 1000;
    return this.shelterRepository
      .createQueryBuilder('shelter')
      .where('shelter.status = :status', { status: 'active' })
      .andWhere(
        `ST_DWithin(
          shelter.location::geography,
          ST_SetSRID(ST_Point(:lon, :lat), 4326)::geography,
          :radius
        )`,
        {
          lon: longitude,
          lat: latitude,
          radius: radiusInMeters,
        },
      )
      .getMany();
  }

  async updateEvacueeCount(id: string, count: number): Promise<Shelter> {
    const shelter = await this.shelterRepository.findOne({ where: { id } });
    if (!shelter) {
      throw new NotFoundException(`Shelter with ID ${id} not found`);
    }

    shelter.currentEvacuees = Math.max(0, count);
    const updated = await this.shelterRepository.save(shelter);

    this.logger.log(`Shelter ${updated.name} evacuees updated to ${updated.currentEvacuees}/${updated.capacity}`);
    this.eventEmitter.emit('shelter.updated', {
      shelterId: updated.id,
      name: updated.name,
      currentEvacuees: updated.currentEvacuees,
      capacity: updated.capacity,
    });

    return updated;
  }

  @OnEvent('earthquake.alertCreated')
  handleEarthquakeAlert(event: { alertId: string; magnitude: number; wilayah: string }) {
    this.logger.log(
      `[SSOT Event Listener] SheltersService received earthquake alert event: M ${event.magnitude} - ${event.wilayah}. Syncing shelter status...`,
    );
  }
}
