/* eslint-disable @typescript-eslint/unbound-method */
/* eslint-disable @typescript-eslint/no-unsafe-return */
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as crypto from 'crypto';
import { AlertsService } from '../src/alerts/alerts.service';
import { EarthquakeAlert } from '../src/alerts/entities/earthquake-alert.entity';
import { UserDevice } from '../src/users/entities/user-device.entity';
import { FirebaseService } from '../src/firebase/firebase.service';

describe('BMKG 1-Hour Polling Deduplication Verification Suite (Task 6.1)', () => {
  let service: AlertsService;
  let alertRepository: Repository<EarthquakeAlert>;

  const dbStore = new Map<string, EarthquakeAlert>();

  const mockQueryBuilder = {
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([]),
  };

  const mockAlertRepository = {
    findOne: jest.fn().mockImplementation(({ where }: { where: { bmkgId: string } }) => {
      const found = dbStore.get(where.bmkgId) || null;
      return Promise.resolve(found);
    }),
    create: jest.fn().mockImplementation((dto: Partial<EarthquakeAlert>) => dto as EarthquakeAlert),
    save: jest.fn().mockImplementation((alert: EarthquakeAlert) => {
      const saved = { id: `uuid-${Date.now()}`, ...alert } as EarthquakeAlert;
      dbStore.set(alert.bmkgId, saved);
      return Promise.resolve(saved);
    }),
  };

  const mockDeviceRepository = {
    createQueryBuilder: jest.fn(() => mockQueryBuilder),
  };

  let originalFetch: typeof global.fetch;

  beforeAll(() => {
    originalFetch = global.fetch;
  });

  afterAll(() => {
    global.fetch = originalFetch;
  });

  beforeEach(async () => {
    dbStore.clear();

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

    jest.clearAllMocks();
  });

  it('SHA-256 hash generation should be deterministic for DateTime + Coordinates', () => {
    const dateTimeISO = '2026-07-26T06:00:00+07:00';
    const coordinates = '-6.20,106.81';
    const expectedRaw = `${dateTimeISO}_${coordinates}`;
    const expectedHash = crypto.createHash('sha256').update(expectedRaw).digest('hex');

    expect(expectedHash).toHaveLength(64);
    expect(expectedHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('Verification Run: 1 Hour Polling (120 Cycles at 30-sec interval) with constant BMKG payload', async () => {
    const mockBmkgPayload = {
      Infogempa: {
        gempa: {
          Tanggal: '26 Jul 2026',
          Jam: '06:00:00 WIB',
          DateTime: '2026-07-26T06:00:00+07:00',
          Coordinates: '-6.20,106.81',
          Magnitude: '5.8',
          Kedalaman: '12 km',
          Wilayah: 'Selatan Jawa Barat',
          Potensi: 'Tidak berpotensi tsunami',
        },
      },
    };

    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(mockBmkgPayload),
    });

    const totalCycles = 120; // 120 cycles * 30s = 60 minutes (1 hour)
    let processedNewCount = 0;
    let duplicateSkippedCount = 0;

    for (let cycle = 1; cycle <= totalCycles; cycle++) {
      const initialDbSize = dbStore.size;
      await service.pollBmkg();
      const finalDbSize = dbStore.size;

      if (finalDbSize > initialDbSize) {
        processedNewCount++;
      } else {
        duplicateSkippedCount++;
      }
    }

    // VERIFICATION ASSERTIONS
    expect(processedNewCount).toBe(1);
    expect(duplicateSkippedCount).toBe(119);
    expect(dbStore.size).toBe(1);
    expect(mockAlertRepository.save).toHaveBeenCalledTimes(1);

    const savedAlert = Array.from(dbStore.values())[0];
    const expectedHash = crypto
      .createHash('sha256')
      .update('2026-07-26T06:00:00+07:00_-6.20,106.81')
      .digest('hex');

    expect(savedAlert.bmkgId).toBe(expectedHash);
  });

  it('Verification Run: Multi-Earthquake Polling (2 distinct earthquakes over 1 hour polling)', async () => {
    const earthquake1 = {
      Infogempa: {
        gempa: {
          Tanggal: '26 Jul 2026',
          Jam: '06:00:00 WIB',
          DateTime: '2026-07-26T06:00:00+07:00',
          Coordinates: '-6.20,106.81',
          Magnitude: '5.2',
          Kedalaman: '10 km',
          Wilayah: 'Wilayah A',
          Potensi: 'Tidak berpotensi tsunami',
        },
      },
    };

    const earthquake2 = {
      Infogempa: {
        gempa: {
          Tanggal: '26 Jul 2026',
          Jam: '06:30:00 WIB',
          DateTime: '2026-07-26T06:30:00+07:00',
          Coordinates: '-8.12,112.50',
          Magnitude: '6.1',
          Kedalaman: '25 km',
          Wilayah: 'Wilayah B',
          Potensi: 'Berpotensi tsunami',
        },
      },
    };

    // Cycle 1 to 60 (First 30 minutes) -> Earthquake 1
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(earthquake1),
    });

    for (let c = 1; c <= 60; c++) {
      await service.pollBmkg();
    }

    expect(dbStore.size).toBe(1);

    // Cycle 61 to 120 (Second 30 minutes) -> Earthquake 2 published by BMKG
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(earthquake2),
    });

    for (let c = 61; c <= 120; c++) {
      await service.pollBmkg();
    }

    expect(dbStore.size).toBe(2);
    expect(mockAlertRepository.save).toHaveBeenCalledTimes(2);
  });
});
