import {
  Injectable,
  NotFoundException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2, OnEvent } from '@nestjs/event-emitter';
import { Shelter, ShelterType } from './entities/shelter.entity';
import { CreateShelterDto } from './dto/create-shelter.dto';
import * as GeoJSON from 'geojson';
import * as bantulShelters from './data/titik_evakuasi_bantul_fixed.json';

export { CreateShelterDto };

@Injectable()
export class SheltersService implements OnModuleInit {
  private readonly logger = new Logger(SheltersService.name);

  constructor(
    @InjectRepository(Shelter)
    private readonly shelterRepository: Repository<Shelter>,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async onModuleInit() {
    await this.seedBantulShelters();
  }

  async seedBantulShelters(): Promise<{ seeded: number; total: number }> {
    try {
      const count = await this.shelterRepository.count();
      if (count >= bantulShelters.length) {
        this.logger.log(
          `Shelters table already initialized (${count} records). Skipping auto-seed.`,
        );
        return { seeded: 0, total: count };
      }

      this.logger.log(
        `Seeding ${bantulShelters.length} Bantul evacuation points (TPS/TPA)...`,
      );

      let seededCount = 0;
      for (const item of bantulShelters as Array<{
        id: string;
        type: ShelterType;
        latitude: number;
        longitude: number;
        status?: string;
      }>) {
        // Check duplicate by location point
        const existing = await this.shelterRepository
          .createQueryBuilder('shelter')
          .where(
            `ST_DWithin(
              shelter.location::geography,
              ST_SetSRID(ST_Point(:lon, :lat), 4326)::geography,
              50
            )`,
            { lon: item.longitude, lat: item.latitude },
          )
          .getOne();

        if (!existing) {
          await this.createShelter({
            name: `Titik Evakuasi ${item.type} (${item.id.toUpperCase()})`,
            latitude: item.latitude,
            longitude: item.longitude,
            type: item.type,
            status: item.status || 'active',
            capacity: item.type === 'TPA' ? 500 : 150,
            source: 'digitized_bpbd_peta_2010',
            notes: `Data evakuasi resmi BPBD Bantul (${item.type})`,
          });
          seededCount++;
        }
      }

      const totalAfter = await this.shelterRepository.count();
      this.logger.log(
        `Seeding complete. Seeded: ${seededCount}, Total Shelters: ${totalAfter}`,
      );
      return { seeded: seededCount, total: totalAfter };
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      this.logger.error(`Failed to seed Bantul shelters: ${msg}`);
      return { seeded: 0, total: 0 };
    }
  }

  async createShelter(dto: CreateShelterDto): Promise<Shelter> {
    const location: GeoJSON.Point = {
      type: 'Point',
      coordinates: [dto.longitude, dto.latitude],
    };

    const shelterType: ShelterType = dto.type || 'TPS';
    const fallbackName = `Titik Evakuasi ${shelterType} (${dto.latitude.toFixed(4)}, ${dto.longitude.toFixed(4)})`;

    const shelter = this.shelterRepository.create({
      name: dto.name || fallbackName,
      type: shelterType,
      location,
      capacity: dto.capacity ?? 0,
      currentEvacuees: 0,
      status: dto.status || 'active',
      notes: dto.notes,
      source: dto.source || 'digitized_bpbd_peta_2010',
    });

    const saved = await this.shelterRepository.save(shelter);
    this.eventEmitter.emit('shelter.created', {
      shelterId: saved.id,
      name: saved.name,
      type: saved.type,
    });
    return saved;
  }

  async getAllShelters(type?: ShelterType): Promise<Shelter[]> {
    const query = this.shelterRepository.createQueryBuilder('shelter');
    if (type) {
      query.where('shelter.type = :type', { type });
    }
    return query.orderBy('shelter.createdAt', 'DESC').getMany();
  }

  async findNearbyShelters(
    latitude: number,
    longitude: number,
    radiusInKm = 50,
    type?: ShelterType,
  ): Promise<Shelter[]> {
    const radiusInMeters = radiusInKm * 1000;
    const query = this.shelterRepository
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
      );

    if (type) {
      query.andWhere('shelter.type = :type', { type });
    }

    return query.getMany();
  }

  async updateEvacueeCount(id: string, count: number): Promise<Shelter> {
    const shelter = await this.shelterRepository.findOne({ where: { id } });
    if (!shelter) {
      throw new NotFoundException(`Shelter with ID ${id} not found`);
    }

    shelter.currentEvacuees = Math.max(0, count);
    const updated = await this.shelterRepository.save(shelter);

    this.logger.log(
      `Shelter ${updated.name || updated.id} evacuees updated to ${updated.currentEvacuees}/${updated.capacity}`,
    );
    this.eventEmitter.emit('shelter.updated', {
      shelterId: updated.id,
      name: updated.name,
      type: updated.type,
      currentEvacuees: updated.currentEvacuees,
      capacity: updated.capacity,
    });

    return updated;
  }

  @OnEvent('earthquake.alertCreated')
  handleEarthquakeAlert(event: {
    alertId: string;
    magnitude: number;
    wilayah: string;
  }) {
    this.logger.log(
      `[SSOT Event Listener] SheltersService received earthquake alert event: M ${event.magnitude} - ${event.wilayah}. Syncing shelter status...`,
    );
  }
}
