import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { AppService } from './app.service';

describe('AppController', () => {
  let appController: AppController;
  let appService: AppService;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        {
          provide: AppService,
          useValue: {
            getHello: jest.fn().mockReturnValue({
              name: 'SUAR Monorepo Cloud Backend EWS API',
              version: '1.0.0',
            }),
            getHealthReport: jest.fn().mockResolvedValue({
              status: 'ok',
              environment: 'test',
              database: { status: 'connected' },
            }),
            pingOpenQuakeMicroservice: jest.fn().mockResolvedValue({
              status: 'online',
              url: 'http://localhost:8000/health',
            }),
          },
        },
      ],
    }).compile();

    appController = app.get<AppController>(AppController);
    appService = app.get<AppService>(AppService);
  });

  describe('root & health', () => {
    it('should return system banner object', () => {
      const res = appController.getHello();
      expect(res).toHaveProperty('name', 'SUAR Monorepo Cloud Backend EWS API');
      expect(res).toHaveProperty('version', '1.0.0');
    });

    it('should return health report', async () => {
      const health = await appController.getHealth();
      expect(health).toHaveProperty('status', 'ok');
      expect(health.database).toHaveProperty('status', 'connected');
    });

    it('should ping openquake microservice', async () => {
      const ping = await appController.pingMicroservice();
      expect(ping).toHaveProperty('status', 'online');
    });
  });
});
