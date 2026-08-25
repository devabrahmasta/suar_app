import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('SUAR App Full E2E Test Suite', () => {
  let app: INestApplication;
  let simulatedAlertId = '';
  let shelterId = '';
  let geoJsonEtag = '';

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  }, 30000);

  afterAll(async () => {
    if (app) {
      await app.close();
    }
  });

  // MODUL 1: Diagnostik & Health Check System
  describe('Modul 1: System Diagnostics', () => {
    it('TC-SYS-01: Health Check REST API (GET /health)', async () => {
      const res = await request(app.getHttpServer()).get('/health').expect(200);

      expect(res.body).toBeDefined();
      expect(res.body.status).toBeDefined();
    });

    it('TC-SYS-02: OpenQuake Microservice Keep-Alive Ping (GET /system/ping-microservice)', async () => {
      const res = await request(app.getHttpServer())
        .get('/system/ping-microservice')
        .expect(200);

      expect(res.body).toBeDefined();
      expect(res.body.status).toBeDefined();
    });
  });

  // MODUL 2: Device Onboarding & Spasial Soil Amplification (Vs30)
  describe('Modul 2: Device Onboarding & Spasial Vs30', () => {
    it('TC-DEV-01: Registrasi Perangkat & FCM Token (POST /devices/register)', async () => {
      const payload = {
        deviceId: 'device-testing-jogja-001',
        fcmToken: 'sample_fcm_token_jogja_12345',
        homeType: 'Apartemen',
        homeLatitude: -7.7956,
        homeLongitude: 110.3695,
      };

      const res = await request(app.getHttpServer())
        .post('/devices/register')
        .send(payload)
        .expect(201);

      expect(res.body).toBeDefined();
      expect(res.body.deviceId).toBe(payload.deviceId);
    });

    it('TC-DEV-02: Tracking Lokasi Aktif & Spasial Vs30 Lookup (POST /devices/location)', async () => {
      const payload = {
        deviceId: 'device-testing-jogja-001',
        latitude: -8.0225,
        longitude: 110.3346,
        isRedZone: true,
      };

      const res = await request(app.getHttpServer())
        .post('/devices/location')
        .send(payload)
        .expect(201);

      expect(res.body).toBeDefined();
      expect(res.body.deviceId).toBe(payload.deviceId);
    });
  });

  // MODUL 3: Tsunami Red Zone GeoJSON & Tile Engine
  describe('Modul 3: Tsunami Red Zone & Tile Engine', () => {
    it('TC-TSU-01a: Stream GeoJSON Zona Merah Tsunami Jawa-Bali (GET /tsunami/geojson/jawa-bali)', async () => {
      const res = await request(app.getHttpServer())
        .get('/tsunami/geojson/jawa-bali')
        .expect(200);

      if (res.headers['etag']) {
        geoJsonEtag = res.headers['etag'];
      }
      expect(res.body).toBeDefined();
    });

    it('TC-TSU-01b: GeoJSON ETag Cache Validation (304 Not Modified)', async () => {
      if (!geoJsonEtag) return;

      await request(app.getHttpServer())
        .get('/tsunami/geojson/jawa-bali')
        .set('If-None-Match', geoJsonEtag)
        .expect(304);
    });

    it('TC-TSU-02: Server-side Point-in-Polygon Location Verification (POST /tsunami/verify-location)', async () => {
      const payload = {
        latitude: -8.0225,
        longitude: 110.3346,
      };

      const res = await request(app.getHttpServer())
        .post('/tsunami/verify-location')
        .send(payload)
        .expect(201);

      expect(res.body).toBeDefined();
      expect(typeof res.body.isRedZone).toBe('boolean');
    });

    it('TC-TSU-03: Tile Server SVG Overlay Rendering (GET /tsunami/tile/14/13210/8412.svg)', async () => {
      const res = await request(app.getHttpServer())
        .get('/tsunami/tile/14/13210/8412.svg')
        .expect(200);

      expect(res.headers['content-type']).toContain('image/svg+xml');
    });
  });

  // MODUL 4: BMKG EWS Polling, Simulasi & Notifikasi Push Broadcast
  describe('Modul 4: BMKG EWS & Simulation', () => {
    it('TC-ALT-01: Manual Polling Trigger BMKG API (POST /alerts/trigger-poll)', async () => {
      const res = await request(app.getHttpServer())
        .post('/alerts/trigger-poll')
        .expect(201);

      expect(res.body).toBeDefined();
    });

    it('TC-ALT-02: Simulasi Gempa Bumi & Kalkulasi OpenQuake MMI (POST /alerts/simulate)', async () => {
      const payload = {
        magnitude: 6.8,
        depth: '15',
        latitude: -7.97,
        longitude: 110.36,
        wilayah: 'Yogyakarta (Simulasi Test)',
        potensi: 'Tidak berpotensi tsunami',
      };

      const res = await request(app.getHttpServer())
        .post('/alerts/simulate')
        .send(payload)
        .expect(201);

      expect(res.body).toBeDefined();
      simulatedAlertId = res.body.alertId || res.body.id || '';
    });

    it('TC-ALT-03: Simulasi Megathrust Tsunami Red Zone Alert (POST /alerts/simulate)', async () => {
      const payload = {
        magnitude: 7.5,
        depth: '10',
        latitude: -8.12,
        longitude: 110.36,
        wilayah: 'Pesisir Selatan Jawa (Simulasi Megathrust)',
        potensi: 'Berpotensi tsunami',
      };

      const res = await request(app.getHttpServer())
        .post('/alerts/simulate')
        .send(payload)
        .expect(201);

      expect(res.body).toBeDefined();
    });
  });

  // MODUL 5: Kalkulasi Dampak Spesifik Pengguna (Personal Impact)
  describe('Modul 5: Personal Impact Assessment', () => {
    it('TC-IMP-01: Kalkulasi Dampak Personal Pengguna (POST /alerts/calculate-impact)', async () => {
      const payload = {
        latitude: -7.7956,
        longitude: 110.3695,
        earthquakeId: simulatedAlertId || undefined,
      };

      const res = await request(app.getHttpServer())
        .post('/alerts/calculate-impact')
        .send(payload)
        .expect(200);

      expect(res.body).toBeDefined();
      expect(res.body.distanceKm).toBeDefined();
    });
  });

  // MODUL 6: Shelter Routing & Evacuee Capacity Management
  describe('Modul 6: Shelter Routing & Capacity Management', () => {
    it('TC-SHL-01: Seed 19 Titik Evakuasi Resmi BPBD Bantul (POST /shelters/seed)', async () => {
      const res = await request(app.getHttpServer())
        .post('/shelters/seed')
        .expect(201);

      expect(res.body).toBeDefined();
    });

    it('TC-SHL-02: Query All Shelters dengan Filter type=ALL (GET /shelters?type=ALL)', async () => {
      const res = await request(app.getHttpServer())
        .get('/shelters?type=ALL')
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      if (res.body.length > 0) {
        shelterId = res.body[0].id;
      }
    });

    it('TC-SHL-03: Kueri Spasial Nearby Shelter Search (GET /shelters/nearby)', async () => {
      const res = await request(app.getHttpServer())
        .get('/shelters/nearby?latitude=-7.97&longitude=110.28&radiusInKm=15&type=TPS')
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
    });

    it('TC-SHL-04: Update Jumlah Pengungsi Real-Time (PATCH /shelters/:id/evacuees)', async () => {
      if (!shelterId) return;

      const res = await request(app.getHttpServer())
        .patch(`/shelters/${shelterId}/evacuees`)
        .send({ count: 120 })
        .expect(200);

      expect(res.body).toBeDefined();
    });
  });
});
