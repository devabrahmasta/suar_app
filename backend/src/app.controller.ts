import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';

@ApiTags('system')
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  @ApiOperation({ summary: 'API Root Banner & System Overview' })
  getHello() {
    return this.appService.getHello();
  }

  @Get(['health', 'system/health'])
  @ApiOperation({
    summary:
      'System Health Diagnostic Report (Uptime, PostGIS DB connection, Memory, Microservice status)',
  })
  @ApiResponse({
    status: 200,
    description: 'System health report retrieved successfully.',
  })
  async getHealth() {
    return this.appService.getHealthReport();
  }

  @Get('system/ping-microservice')
  @ApiOperation({
    summary:
      'Direct HTTP keep-alive ping to Python OpenQuake FastAPI Microservice',
  })
  @ApiResponse({
    status: 200,
    description: 'Returns connection status and latency of microservice.',
  })
  async pingMicroservice() {
    return this.appService.pingOpenQuakeMicroservice();
  }
}
