import { Controller, Post, Get, Body } from '@nestjs/common';
import { AlertsService } from './alerts.service';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { CalculateImpactDto } from './dto/calculate-impact.dto';

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
      depth: string | number;
      latitude: number;
      longitude: number;
      potensi: string;
      wilayah: string;
    },
  ) {
    return this.alertsService.simulateAlert({
      ...body,
      depth: String(body.depth ?? '15'),
    });
  }

  @Post('calculate-impact')
  @ApiOperation({
    summary: 'Calculate user impact distance and estimated MMI intensity for Jawa-Bali region',
  })
  @ApiResponse({
    status: 200,
    description:
      'Returns distance in KM, estimated MMI, shaking level, and tsunami status.',
  })
  async calculateImpact(@Body() dto: CalculateImpactDto) {
    return this.alertsService.calculateUserImpact(
      dto.latitude,
      dto.longitude,
      dto.earthquakeId,
    );
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


