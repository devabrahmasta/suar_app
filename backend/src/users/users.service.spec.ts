/* eslint-disable @typescript-eslint/unbound-method */
/* eslint-disable @typescript-eslint/no-unsafe-return */
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsersService } from './users.service';
import { UserDevice } from './entities/user-device.entity';
import { NotFoundException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';

describe('UsersService', () => {
  let service: UsersService;
  let repository: Repository<UserDevice>;
  let eventEmitter: EventEmitter2;

  const mockUserDeviceRepository = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
    query: jest.fn(),
  };

  const mockEventEmitter = {
    emit: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(UserDevice),
          useValue: mockUserDeviceRepository,
        },
        {
          provide: EventEmitter2,
          useValue: mockEventEmitter,
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    repository = module.get<Repository<UserDevice>>(
      getRepositoryToken(UserDevice),
    );
    eventEmitter = module.get<EventEmitter2>(EventEmitter2);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('lookupVs30', () => {
    it('should return soil vs30 value from raster query if found', async () => {
      mockUserDeviceRepository.query.mockResolvedValueOnce([{ vs30: 450.5 }]);

      const vs30 = await service.lookupVs30(-7.79, 110.36);

      expect(repository.query).toHaveBeenCalledWith(
        expect.stringContaining('vs30_soil_raster'),
        [110.36, -7.79], // Longitude first, then Latitude
      );
      expect(vs30).toBe(450.5);
    });

    it('should return default 270.0 (SNI tanah SD) if raster query returns empty or fails', async () => {
      mockUserDeviceRepository.query.mockRejectedValueOnce(
        new Error('Raster table not found'),
      );

      const vs30 = await service.lookupVs30(-7.79, 110.36);

      expect(vs30).toBe(270.0);
    });
  });

  describe('registerDevice', () => {
    it('should create a new device and lookup vs30 if home coordinates provided', async () => {
      mockUserDeviceRepository.findOne.mockResolvedValue(null);
      mockUserDeviceRepository.query.mockResolvedValueOnce([{ vs30: 320.0 }]);
      mockUserDeviceRepository.create.mockImplementation((dto) => dto);
      mockUserDeviceRepository.save.mockImplementation((dto) =>
        Promise.resolve({ id: 'uuid-1', ...dto }),
      );

      const result = await service.registerDevice(
        'device-1',
        'fcm-token-1',
        'Home',
        -7.79,
        110.36,
      );

      expect(repository.findOne).toHaveBeenCalledWith({
        where: { deviceId: 'device-1' },
      });
      expect(repository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          deviceId: 'device-1',
          fcmToken: 'fcm-token-1',
          homeType: 'Home',
          vs30: 320.0,
          homeLocation: {
            type: 'Point',
            coordinates: [110.36, -7.79],
          },
        }),
      );
      expect(result).toHaveProperty('id', 'uuid-1');
      expect(result.vs30).toBe(320.0);
    });

    it('should update existing device token and home location', async () => {
      const existingDevice = {
        deviceId: 'device-1',
        fcmToken: 'old-token',
        vs30: 270.0,
      };
      mockUserDeviceRepository.findOne.mockResolvedValue(existingDevice);
      mockUserDeviceRepository.query.mockResolvedValueOnce([{ vs30: 500.0 }]);
      mockUserDeviceRepository.save.mockImplementation((device) =>
        Promise.resolve(device),
      );

      const result = await service.registerDevice(
        'device-1',
        'new-token',
        'Apartment',
        -6.2,
        106.81,
      );

      expect(repository.save).toHaveBeenCalledWith(
        expect.objectContaining({
          deviceId: 'device-1',
          fcmToken: 'new-token',
          homeType: 'Apartment',
          vs30: 500.0,
        }),
      );
      expect(result.fcmToken).toBe('new-token');
      expect(result.vs30).toBe(500.0);
    });
  });

  describe('updateLocation', () => {
    it('should update last location & vs30 of existing device and emit event', async () => {
      const existingDevice = { deviceId: 'device-1', vs30: 270.0 };
      mockUserDeviceRepository.findOne.mockResolvedValue(existingDevice);
      mockUserDeviceRepository.query.mockResolvedValueOnce([{ vs30: 380.0 }]);
      mockUserDeviceRepository.save.mockImplementation((device) =>
        Promise.resolve(device),
      );

      const result = await service.updateLocation('device-1', -7.79, 110.36);

      expect(repository.findOne).toHaveBeenCalledWith({
        where: { deviceId: 'device-1' },
      });
      expect(repository.save).toHaveBeenCalled();
      expect(result.lastLocation).toEqual({
        type: 'Point',
        coordinates: [110.36, -7.79],
      });
      expect(result.vs30).toBe(380.0);
      expect(eventEmitter.emit).toHaveBeenCalledWith(
        'user.locationUpdated',
        expect.objectContaining({
          deviceId: 'device-1',
          latitude: -7.79,
          longitude: 110.36,
          vs30: 380.0,
        }),
      );
    });

    it('should throw NotFoundException if device is not found', async () => {
      mockUserDeviceRepository.findOne.mockResolvedValue(null);

      await expect(
        service.updateLocation('device-invalid', -7.79, 110.36),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
