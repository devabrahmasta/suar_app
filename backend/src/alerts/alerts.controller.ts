import { Controller, Post } from '@nestjs/common';
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
}
