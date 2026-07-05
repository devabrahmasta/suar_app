import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AlertsService } from './alerts.service';
import { EarthquakeAlert } from './entities/earthquake-alert.entity';
import { UserDevice } from '../users/entities/user-device.entity';

describe('AlertsService', () => {
  let service: AlertsService;
  let alertRepository: Repository<EarthquakeAlert>;
  let deviceRepository: Repository<UserDevice>;

  const mockQueryBuilder = {
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([]),
  };

  const mockAlertRepository = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockDeviceRepository = {
    createQueryBuilder: jest.fn(() => mockQueryBuilder),
  };

  // Mock global fetch
  let originalFetch: typeof global.fetch;

  beforeAll(() => {
    originalFetch = global.fetch;
  });

  afterAll(() => {
    global.fetch = originalFetch;
  });

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AlertsService,
        {
          provide: getRepositoryToken(EarthquakeAlert),
          useValue: mockAlertRepository,
        },
        {
          provide: getRepositoryToken(UserDevice),
          useValue: mockDeviceRepository,
        },
      ],
    }).compile();

    service = module.get<AlertsService>(AlertsService);
    alertRepository = module.get<Repository<EarthquakeAlert>>(getRepositoryToken(EarthquakeAlert));
    deviceRepository = module.get<Repository<UserDevice>>(getRepositoryToken(UserDevice));

    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('pollBmkg', () => {
    it('should skip if earthquake alert already exists (duplicate check)', async () => {
      const mockJson = {
        Infogempa: {
          gempa: {
            Tanggal: '05 Jul 2026',
            Jam: '10:00:00 WIB',
            DateTime: '2026-07-05T03:00:00+00:00',
            Coordinates: '-7.79,110.36',
            Magnitude: '5.5',
            Kedalaman: '20 km',
            Wilayah: 'Yogyakarta',
            Potensi: 'Tidak berpotensi tsunami',
          },
        },
      };

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockJson),
      });

      mockAlertRepository.findOne.mockResolvedValue({ id: 'existing-alert' });

      await service.pollBmkg();

      expect(global.fetch).toHaveBeenCalled();
      expect(alertRepository.findOne).toHaveBeenCalled();
      expect(alertRepository.create).not.toHaveBeenCalled();
    });

    it('should process, save, and trigger EWS broadcast if alert passes threshold', async () => {
      const mockJson = {
        Infogempa: {
          gempa: {
            Tanggal: '05 Jul 2026',
            Jam: '10:00:00 WIB',
            DateTime: '2026-07-05T03:00:00+00:00',
            Coordinates: '-7.79,110.36',
            Magnitude: '6.6',
            Kedalaman: '15 km',
            Wilayah: 'Selatan Jawa',
            Potensi: 'Berpotensi tsunami',
            Dirasakan: 'III MMI Jogja',
          },
        },
      };

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockJson),
      });

      mockAlertRepository.findOne.mockResolvedValue(null);
      mockAlertRepository.create.mockImplementation((dto) => dto);
      mockAlertRepository.save.mockImplementation((dto) => Promise.resolve({ id: 'new-id', ...dto }));

      const mockDevices = [
        { deviceId: 'device-1', fcmToken: 'token-1' },
        { deviceId: 'device-2', fcmToken: 'token-2' },
      ];
      mockQueryBuilder.getMany.mockResolvedValue(mockDevices);

      await service.pollBmkg();

      expect(global.fetch).toHaveBeenCalled();
      expect(alertRepository.findOne).toHaveBeenCalled();
      expect(alertRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          magnitude: 6.6,
          isBroadcasted: true,
          potensi: 'Berpotensi tsunami',
        })
      );
      expect(alertRepository.save).toHaveBeenCalled();
      expect(deviceRepository.createQueryBuilder).toHaveBeenCalled();
      expect(mockQueryBuilder.getMany).toHaveBeenCalled();
    });

    it('should save but NOT broadcast if below threshold (Magnitude < 5.0)', async () => {
      const mockJson = {
        Infogempa: {
          gempa: {
            Tanggal: '05 Jul 2026',
            Jam: '10:00:00 WIB',
            DateTime: '2026-07-05T03:00:00+00:00',
            Coordinates: '-7.79,110.36',
            Magnitude: '4.2',
            Kedalaman: '10 km',
            Wilayah: 'Jogja kecil',
            Potensi: 'Tidak berpotensi',
          },
        },
      };

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockJson),
      });

      mockAlertRepository.findOne.mockResolvedValue(null);
      mockAlertRepository.create.mockImplementation((dto) => dto);

      await service.pollBmkg();

      expect(alertRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          magnitude: 4.2,
          isBroadcasted: false,
        })
      );
      expect(deviceRepository.createQueryBuilder).not.toHaveBeenCalled();
    });
  });
});
