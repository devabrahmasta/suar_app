import { Controller, Post, Get, Body } from '@nestjs/common';
import { AlertsService } from './alerts.service';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';

@ApiTags('alerts')
@Controller('alerts')
export class AlertsController {
  constructor(private readonly alertsService: AlertsService) {}

  @Post('trigger-poll')
  @ApiOperation({
    summary: 'Manually trigger BMKG API polling for new earthquakes',
  })
  @ApiResponse({
    status: 201,
    description: 'BMKG Poll triggered successfully.',
  })
  async triggerPoll() {
    await this.alertsService.pollBmkg();
    return { success: true, message: 'BMKG Poll triggered manually' };
  }

  @Post('simulate')
  @ApiOperation({
    summary: 'Simulate a custom earthquake for EWS dynamic geofencing tests',
  })
  @ApiResponse({
    status: 201,
    description: 'Custom simulated earthquake processed successfully.',
  })
  async simulateAlert(
    @Body()
    body: {
      magnitude: number;
      depth: string;
      latitude: number;
      longitude: number;
      potensi: string;
      wilayah: string;
    },
  ) {
    return this.alertsService.simulateAlert(body);
  }

  @Get('latest')
  @ApiOperation({ summary: 'Get the latest processed earthquake alert' })
  @ApiResponse({
    status: 200,
    description: 'Latest alert retrieved successfully.',
  })
  async getLatestAlert() {
    return this.alertsService.getLatestAlert();
  }
}
