import { Injectable, Logger, Optional } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ConfigService } from '@nestjs/config';

export interface SystemHealthReport {
  status: 'ok' | 'degraded' | 'error';
  timestamp: string;
  uptimeSeconds: number;
  environment: string;
  database: {
    status: 'connected' | 'disconnected';
    latencyMs?: number;
  };
  memory: {
    heapUsedMb: number;
    heapTotalMb: number;
    rssMb: number;
  };
  openquakeMicroservice: {
    status: 'online' | 'offline' | 'unreachable';
    url: string;
  };
}

@Injectable()
export class AppService {
  private readonly logger = new Logger(AppService.name);

  constructor(
    @Optional() private readonly dataSource?: DataSource,
    @Optional() private readonly configService?: ConfigService,
  ) {}

  getHello() {
    return {
      name: 'SUAR Monorepo Cloud Backend EWS API',
      version: '1.0.0',
      description:
        'Sistem Ubiquitous Adaptif Respons (SUAR) - Early Warning System & Seismic Hazard Mitigation Backend',
      docs: '/api/docs',
      health: '/health',
      timestamp: new Date().toISOString(),
    };
  }

  async pingOpenQuakeMicroservice(): Promise<{
    status: 'online' | 'offline' | 'unreachable';
    url: string;
    latencyMs?: number;
    details?: any;
  }> {
    const baseUrl =
      this.configService?.get<string>('OPENQUAKE_SERVICE_URL') ||
      process.env.OPENQUAKE_MICROSERVICE_URL ||
      process.env.OPENQUAKE_SERVICE_URL ||
      'http://localhost:8000';
    const targetUrl = `${baseUrl}/health`;

    const startTime = Date.now();
    try {
      const response = await fetch(targetUrl, {
        signal: AbortSignal.timeout(5000), // 5s timeout
      });
      const latencyMs = Date.now() - startTime;

      if (response.ok) {
        let details: any = null;
        try {
          details = await response.json();
        } catch {
          // ignore parse error
        }
        return {
          status: 'online',
          url: targetUrl,
          latencyMs,
          details,
        };
      }
      return { status: 'offline', url: targetUrl, latencyMs };
    } catch (error) {
      return { status: 'unreachable', url: targetUrl };
    }
  }

  async getHealthReport(): Promise<SystemHealthReport> {
    const startTime = Date.now();
    let dbStatus: 'connected' | 'disconnected' = 'disconnected';
    let dbLatencyMs: number | undefined = undefined;

    if (this.dataSource && this.dataSource.isInitialized) {
      try {
        await this.dataSource.query('SELECT 1');
        dbStatus = 'connected';
        dbLatencyMs = Date.now() - startTime;
      } catch (error) {
        dbStatus = 'disconnected';
      }
    }

    const microserviceRes = await this.pingOpenQuakeMicroservice();
    const memory = process.memoryUsage();

    const isSystemOk =
      dbStatus === 'connected' && microserviceRes.status === 'online';

    return {
      status: isSystemOk ? 'ok' : 'degraded',
      timestamp: new Date().toISOString(),
      uptimeSeconds: Math.floor(process.uptime()),
      environment: process.env.NODE_ENV || 'development',
      database: {
        status: dbStatus,
        latencyMs: dbLatencyMs,
      },
      memory: {
        heapUsedMb: Number((memory.heapUsed / (1024 * 1024)).toFixed(2)),
        heapTotalMb: Number((memory.heapTotal / (1024 * 1024)).toFixed(2)),
        rssMb: Number((memory.rss / (1024 * 1024)).toFixed(2)),
      },
      openquakeMicroservice: {
        status: microserviceRes.status,
        url: microserviceRes.url,
      },
    };
  }
}
