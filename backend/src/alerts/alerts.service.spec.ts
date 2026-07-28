/* eslint-disable @typescript-eslint/unbound-method */
/* eslint-disable @typescript-eslint/no-unsafe-return */
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AlertsService } from './alerts.service';
import { EarthquakeAlert } from './entities/earthquake-alert.entity';
import { UserDevice } from '../users/entities/user-device.entity';
import { FirebaseService } from '../firebase/firebase.service';

describe('AlertsService', () => {
  let service: AlertsService;
  let alertRepository: Repository<EarthquakeAlert>;
  let deviceRepository: Repository<UserDevice>;
  let firebaseService: FirebaseService;

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
    query: jest.fn().mockResolvedValue([{ slab_depth: 35.0, slab_unc: 15.0 }]),
  };

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
        {
          provide: FirebaseService,
          useValue: {
            sendPushNotification: jest.fn().mockResolvedValue(undefined),
          },
        },
      ],
    }).compile();

    service = module.get<AlertsService>(AlertsService);
    alertRepository = module.get<Repository<EarthquakeAlert>>(
      getRepositoryToken(EarthquakeAlert),
    );
    deviceRepository = module.get<Repository<UserDevice>>(
      getRepositoryToken(UserDevice),
    );
    firebaseService = module.get<FirebaseService>(FirebaseService);

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

      global.fetch = jest.fn().mockImplementation((url: string) => {
        if (url.includes('health')) {
          return Promise.resolve({ ok: true });
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve(mockJson),
        });
      });

      mockAlertRepository.findOne.mockResolvedValue({ id: 'existing-alert' });

      await service.pollBmkg();

      expect(global.fetch).toHaveBeenCalled();
      expect(alertRepository.findOne).toHaveBeenCalled();
      expect(alertRepository.create).not.toHaveBeenCalled();
    });

    it('should process OpenQuake hazard calculation and send FCM for devices with MMI >= V', async () => {
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
          },
        },
      };

      const mockDevices = [
        {
          deviceId: 'device-1',
          fcmToken: 'token-1',
          lastLocation: { coordinates: [110.36, -7.79] },
          vs30: 270.0,
        },
        {
          deviceId: 'device-2',
          fcmToken: 'token-2',
          lastLocation: { coordinates: [112.0, -8.0] },
          vs30: 400.0,
        },
      ];

      global.fetch = jest.fn().mockImplementation((url: string) => {
        if (url.includes('health')) {
          return Promise.resolve({ ok: true });
        }
        if (url.includes('calculate-hazard')) {
          return Promise.resolve({
            ok: true,
            json: () =>
              Promise.resolve([
                { deviceId: 'device-1', pga: 0.25, mmi: 6.5 }, // MMI >= V
                { deviceId: 'device-2', pga: 0.02, mmi: 3.5 }, // MMI < V
              ]),
          });
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve(mockJson),
        });
      });

      mockAlertRepository.findOne.mockResolvedValue(null);
      mockAlertRepository.create.mockImplementation((dto) => dto);
      mockAlertRepository.save.mockImplementation((dto) =>
        Promise.resolve({ id: 'new-id', ...dto }),
      );
      mockQueryBuilder.getMany.mockResolvedValue(mockDevices);

      await service.pollBmkg();

      expect(alertRepository.save).toHaveBeenCalled();
      expect(firebaseService.sendPushNotification).toHaveBeenCalledWith(
        ['token-1'], // Only device-1 (MMI >= 5) receives FCM notification
        expect.stringContaining('PERINGATAN TSUNAMI'),
        expect.stringContaining('Gempa M 6.6'),
        expect.objectContaining({ type: 'EARTHQUAKE_ALERT' }),
      );
    });

    it('should fallback to Phase 2 dynamic radius if OpenQuake microservice fails', async () => {
      const mockJson = {
        Infogempa: {
          gempa: {
            Tanggal: '05 Jul 2026',
            Jam: '10:00:00 WIB',
            DateTime: '2026-07-05T03:00:00+00:00',
            Coordinates: '-7.79,110.36',
            Magnitude: '6.0',
            Kedalaman: '15 km',
            Wilayah: 'Yogyakarta',
            Potensi: 'Tidak berpotensi tsunami',
          },
        },
      };

      const mockDevices = [
        {
          deviceId: 'device-fallback',
          fcmToken: 'token-fallback',
          lastLocation: { coordinates: [110.36, -7.79] },
          vs30: 270.0,
        },
      ];

      global.fetch = jest.fn().mockImplementation((url: string) => {
        if (url.includes('calculate-hazard')) {
          return Promise.resolve({
            ok: false,
            status: 500,
          });
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve(mockJson),
        });
      });

      mockAlertRepository.findOne.mockResolvedValue(null);
      mockAlertRepository.create.mockImplementation((dto) => dto);
      mockAlertRepository.save.mockImplementation((dto) =>
        Promise.resolve({ id: 'new-id', ...dto }),
      );
      mockQueryBuilder.getMany.mockResolvedValue(mockDevices);

      await service.pollBmkg();

      expect(firebaseService.sendPushNotification).toHaveBeenCalledWith(
        ['token-fallback'],
        expect.stringContaining('PERINGATAN GEMPA BUMI'),
        expect.stringContaining('Gempa M 6 Mw'),
        expect.objectContaining({ type: 'EARTHQUAKE_ALERT' }),
      );
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

      global.fetch = jest.fn().mockImplementation((url: string) => {
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve(mockJson),
        });
      });

      mockAlertRepository.findOne.mockResolvedValue(null);
      mockAlertRepository.create.mockImplementation((dto) => dto);

      await service.pollBmkg();

      expect(alertRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          magnitude: 4.2,
          isBroadcasted: false,
        }),
      );
      expect(deviceRepository.createQueryBuilder).not.toHaveBeenCalled();
    });

    it('should handle invalid or missing data from BMKG API gracefully', async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ Infogempa: {} }),
      });

      await service.pollBmkg();

      expect(alertRepository.findOne).not.toHaveBeenCalled();
      expect(alertRepository.create).not.toHaveBeenCalled();
    });

    it('should handle network error during fetch without throwing unhandled exception', async () => {
      global.fetch = jest
        .fn()
        .mockRejectedValue(new Error('Network connection timeout'));

      await expect(service.pollBmkg()).resolves.not.toThrow();
      expect(alertRepository.findOne).not.toHaveBeenCalled();
    });

    it('should handle HTTP error status from BMKG API gracefully', async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: false,
        status: 503,
      });

      await expect(service.pollBmkg()).resolves.not.toThrow();
      expect(alertRepository.findOne).not.toHaveBeenCalled();
    });
  });
});
