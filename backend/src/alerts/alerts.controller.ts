import { Controller, Post } from '@nestjs/common';
import { AlertsService } from './alerts.service';

@Controller('alerts')
export class AlertsController {
  constructor(private readonly alertsService: AlertsService) {}

  @Post('trigger-poll')
  async triggerPoll() {
    await this.alertsService.pollBmkg();
    return { success: true, message: 'BMKG Poll triggered manually' };
  }
}
