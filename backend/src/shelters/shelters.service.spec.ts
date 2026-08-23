/* eslint-disable @typescript-eslint/unbound-method */
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { SheltersService } from './shelters.service';
import { Shelter } from './entities/shelter.entity';
import { CreateShelterDto } from './dto/create-shelter.dto';

describe('SheltersService (SSOT & Real-time Event Verification)', () => {
  let service: SheltersService;
  let shelterRepository: Repository<Shelter>;
  let eventEmitter: EventEmitter2;

  const mockQueryBuilder = {
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([]),
    getOne: jest.fn().mockResolvedValue(null),
  };

  const mockShelterRepository = {
    create: jest.fn(),
    save: jest.fn(),
    find: jest.fn(),
    findOne: jest.fn(),
    count: jest.fn().mockResolvedValue(19),
    createQueryBuilder: jest.fn(() => mockQueryBuilder),
  };

  const mockEventEmitter = {
    emit: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SheltersService,
        {
          provide: getRepositoryToken(Shelter),
          useValue: mockShelterRepository,
        },
        {
          provide: EventEmitter2,
          useValue: mockEventEmitter,
        },
      ],
    }).compile();

    service = module.get<SheltersService>(SheltersService);
    shelterRepository = module.get<Repository<Shelter>>(getRepositoryToken(Shelter));
    eventEmitter = module.get<EventEmitter2>(EventEmitter2);

    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createShelter', () => {
    it('should save shelter with type TPS/TPA into canonical DB store and emit shelter.created event', async () => {
      const dto: CreateShelterDto = {
        name: 'Gedung Olahraga Kota',
        type: 'TPA',
        latitude: -6.2,
        longitude: 106.81,
        capacity: 500,
        notes: 'Area aman evakuasi tsunami',
      };

      const mockSaved = {
        id: 'shelter-uuid-123',
        ...dto,
        currentEvacuees: 0,
        status: 'active',
      };
      mockShelterRepository.create.mockReturnValue(mockSaved);
      mockShelterRepository.save.mockResolvedValue(mockSaved);

      const result = await service.createShelter(dto);

      expect(shelterRepository.create).toHaveBeenCalled();
      expect(shelterRepository.save).toHaveBeenCalled();
      expect(eventEmitter.emit).toHaveBeenCalledWith('shelter.created', {
        shelterId: 'shelter-uuid-123',
        name: 'Gedung Olahraga Kota',
        type: 'TPA',
      });
      expect(result.id).toBe('shelter-uuid-123');
    });

    it('should generate fallback name if name is omitted', async () => {
      const dto: CreateShelterDto = {
        type: 'TPS',
        latitude: -7.97,
        longitude: 110.28,
      };

      const mockSaved = {
        id: 'shelter-uuid-456',
        name: 'Titik Evakuasi TPS (-7.9700, 110.2800)',
        type: 'TPS',
        capacity: 0,
        currentEvacuees: 0,
        status: 'active',
      };

      mockShelterRepository.create.mockReturnValue(mockSaved);
      mockShelterRepository.save.mockResolvedValue(mockSaved);

      const result = await service.createShelter(dto);

      expect(shelterRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'TPS',
          name: 'Titik Evakuasi TPS (-7.9700, 110.2800)',
        }),
      );
      expect(result.name).toBe('Titik Evakuasi TPS (-7.9700, 110.2800)');
    });
  });

  describe('updateEvacueeCount', () => {
    it('should update evacuees count in DB and emit shelter.updated event for SSOT sync', async () => {
      const existing = {
        id: 'shelter-uuid-123',
        name: 'Gedung Olahraga Kota',
        type: 'TPA',
        capacity: 500,
        currentEvacuees: 10,
      };

      mockShelterRepository.findOne.mockResolvedValue(existing);
      mockShelterRepository.save.mockImplementation((s) => Promise.resolve(s));

      const updated = await service.updateEvacueeCount('shelter-uuid-123', 150);

      expect(shelterRepository.findOne).toHaveBeenCalledWith({ where: { id: 'shelter-uuid-123' } });
      expect(shelterRepository.save).toHaveBeenCalled();
      expect(updated.currentEvacuees).toBe(150);
      expect(eventEmitter.emit).toHaveBeenCalledWith('shelter.updated', {
        shelterId: 'shelter-uuid-123',
        name: 'Gedung Olahraga Kota',
        type: 'TPA',
        currentEvacuees: 150,
        capacity: 500,
      });
    });
  });

  describe('handleEarthquakeAlert Event Listener', () => {
    it('should receive earthquake.alertCreated event and trigger synchronization log', () => {
      const spy = jest.spyOn(service['logger'], 'log');
      service.handleEarthquakeAlert({
        alertId: 'alert-1',
        magnitude: 6.5,
        wilayah: 'Selatan Jawa',
      });
      expect(spy).toHaveBeenCalledWith(
        expect.stringContaining('[SSOT Event Listener] SheltersService received earthquake alert event'),
      );
    });
  });
});
