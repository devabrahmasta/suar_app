/* eslint-disable @typescript-eslint/unbound-method */
/* eslint-disable @typescript-eslint/no-unsafe-return */
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsersService } from './users.service';
import { UserDevice } from './entities/user-device.entity';
import { NotFoundException } from '@nestjs/common';

describe('UsersService', () => {
  let service: UsersService;
  let repository: Repository<UserDevice>;

  const mockUserDeviceRepository = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(UserDevice),
          useValue: mockUserDeviceRepository,
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    repository = module.get<Repository<UserDevice>>(
      getRepositoryToken(UserDevice),
    );
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('registerDevice', () => {
    it('should create a new device if not found', async () => {
      mockUserDeviceRepository.findOne.mockResolvedValue(null);
      mockUserDeviceRepository.create.mockImplementation((dto) => dto);
      mockUserDeviceRepository.save.mockImplementation((dto) =>
        Promise.resolve({ id: 'uuid', ...dto }),
      );

      const result = await service.registerDevice(
        'device-1',
        'fcm-token',
        'Home',
        -7.79,
        110.36,
      );

      expect(repository.findOne).toHaveBeenCalledWith({
        where: { deviceId: 'device-1' },
      });
      expect(repository.create).toHaveBeenCalled();
      expect(repository.save).toHaveBeenCalled();
      expect(result).toHaveProperty('id', 'uuid');
      expect(result.fcmToken).toBe('fcm-token');
      expect(result.homeLocation).toEqual({
        type: 'Point',
        coordinates: [110.36, -7.79],
      });
    });

    it('should update existing device if found', async () => {
      const existingDevice = { deviceId: 'device-1', fcmToken: 'old-token' };
      mockUserDeviceRepository.findOne.mockResolvedValue(existingDevice);
      mockUserDeviceRepository.save.mockImplementation((device) =>
        Promise.resolve(device),
      );

      const result = await service.registerDevice(
        'device-1',
        'new-token',
        'Apartment',
      );

      expect(repository.findOne).toHaveBeenCalledWith({
        where: { deviceId: 'device-1' },
      });
      expect(repository.save).toHaveBeenCalledWith(
        expect.objectContaining({
          deviceId: 'device-1',
          fcmToken: 'new-token',
          homeType: 'Apartment',
        }),
      );
      expect(result.fcmToken).toBe('new-token');
    });
  });

  describe('updateLocation', () => {
    it('should update last location of existing device', async () => {
      const existingDevice = { deviceId: 'device-1' };
      mockUserDeviceRepository.findOne.mockResolvedValue(existingDevice);
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
    });

    it('should throw NotFoundException if device is not found', async () => {
      mockUserDeviceRepository.findOne.mockResolvedValue(null);

      await expect(
        service.updateLocation('device-invalid', -7.79, 110.36),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
