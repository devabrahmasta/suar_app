/* eslint-disable @typescript-eslint/unbound-method */
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TsunamiService } from './tsunami.service';
import { TsunamiHazardPolygon } from '../alerts/entities/tsunami-hazard.entity';

describe('TsunamiService', () => {
  let service: TsunamiService;
  let repository: Repository<TsunamiHazardPolygon>;

  const mockTsunamiRepository = {
    query: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TsunamiService,
        {
          provide: getRepositoryToken(TsunamiHazardPolygon),
          useValue: mockTsunamiRepository,
        },
      ],
    }).compile();

    service = module.get<TsunamiService>(TsunamiService);
    repository = module.get<Repository<TsunamiHazardPolygon>>(
      getRepositoryToken(TsunamiHazardPolygon),
    );
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('checkTsunamiHazard', () => {
    it('should return isRedZone true when point is inside hazard polygon', async () => {
      mockTsunamiRepository.query.mockResolvedValueOnce([{ is_red_zone: true }]);

      const result = await service.checkTsunamiHazard(-8.02, 110.33);

      expect(repository.query).toHaveBeenCalledWith(
        expect.stringContaining('ST_Contains'),
        [110.33, -8.02], // Longitude first, then Latitude
      );
      expect(result.isRedZone).toBe(true);
      expect(result.hazardLevel).toBe('HIGH');
    });

    it('should return isRedZone false when point is outside hazard polygon', async () => {
      mockTsunamiRepository.query.mockResolvedValueOnce([{ is_red_zone: false }]);

      const result = await service.checkTsunamiHazard(-7.79, 110.36);

      expect(result.isRedZone).toBe(false);
      expect(result.hazardLevel).toBe('SAFE');
    });
  });

  describe('loadGeoJsonFile', () => {
    it('should load asset file or handle missing file gracefully', () => {
      const asset = service.loadGeoJsonFile();
      if (asset) {
        expect(asset.buffer).toBeDefined();
        expect(asset.etag).toBeDefined();
      } else {
        expect(asset).toBeNull();
      }
    });
  });
});
