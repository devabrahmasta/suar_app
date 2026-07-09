import { Controller, Post, Get } from '@nestjs/common';
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
