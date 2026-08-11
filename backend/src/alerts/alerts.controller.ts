import { Controller, Post, Get, Body, Query, Param, Res, Header } from '@nestjs/common';
import { AlertsService } from './alerts.service';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiParam } from '@nestjs/swagger';
import type { Response as ExpressResponse } from 'express';

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

  @Get('tsunami-check')
  @ApiOperation({
    summary: 'Realtime PostGIS spatial check if a location is in the Tsunami Red Zone (Java & Bali)',
  })
  @ApiQuery({ name: 'latitude', type: Number, example: -7.02 })
  @ApiQuery({ name: 'longitude', type: Number, example: 110.32 })
  @ApiResponse({
    status: 200,
    description: 'Returns boolean isRedZone and hazardLevel.',
  })
  async checkTsunami(
    @Query('latitude') latitude: string,
    @Query('longitude') longitude: string,
  ) {
    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);
    return this.alertsService.checkTsunamiHazard(lat, lng);
  }

  @Get('tsunami-tile/:z/:x/:y.svg')
  @ApiOperation({
    summary: 'Get SVG overlay tile for Tsunami Red Zone visualization',
  })
  @ApiParam({ name: 'z', type: Number, example: 14 })
  @ApiParam({ name: 'x', type: Number, example: 13210 })
  @ApiParam({ name: 'y', type: Number, example: 8412 })
  @Header('Cache-Control', 'public, max-age=86400')
  async getTsunamiSvgTile(
    @Param('z') z: string,
    @Param('x') x: string,
    @Param('y') y: string,
    @Res() res: ExpressResponse,
  ) {
    const svg = await this.alertsService.getTsunamiSvgTile(
      parseInt(z, 10),
      parseInt(x, 10),
      parseInt(y, 10),
    );
    res.setHeader('Content-Type', 'image/svg+xml');
    return res.send(svg);
  }

  @Get('tsunami-tile/:z/:x/:y.pbf')
  @ApiOperation({
    summary: 'Get Mapbox Vector Tile (MVT) for Tsunami Red Zone',
  })
  @ApiParam({ name: 'z', type: Number, example: 14 })
  @ApiParam({ name: 'x', type: Number, example: 13210 })
  @ApiParam({ name: 'y', type: Number, example: 8412 })
  @Header('Cache-Control', 'public, max-age=86400')
  async getTsunamiMvtTile(
    @Param('z') z: string,
    @Param('x') x: string,
    @Param('y') y: string,
    @Res() res: ExpressResponse,
  ) {
    const pbf = await this.alertsService.getTsunamiMvtTile(
      parseInt(z, 10),
      parseInt(x, 10),
      parseInt(y, 10),
    );
    res.setHeader('Content-Type', 'application/x-protobuf');
    return res.send(pbf);
  }
}


