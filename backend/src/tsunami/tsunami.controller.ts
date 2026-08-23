import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  Param,
  Res,
  Header,
  Req,
  HttpStatus,
  NotFoundException,
} from '@nestjs/common';
import { TsunamiService } from './tsunami.service';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiParam } from '@nestjs/swagger';
import { VerifyLocationDto } from './dto/verify-location.dto';
import type { Request as ExpressRequest, Response as ExpressResponse } from 'express';

@ApiTags('tsunami')
@Controller('tsunami')
export class TsunamiController {
  constructor(private readonly tsunamiService: TsunamiService) {}

  @Get('geojson/jawa-bali')
  @ApiOperation({
    summary:
      'Stream / Download Tsunami Red Zone GeoJSON asset for Jawa-Bali with ETag caching',
  })
  @ApiResponse({
    status: 200,
    description: 'Returns the GeoJSON file buffer (~3MB uncompressed / ~300KB gzipped).',
  })
  @ApiResponse({
    status: 304,
    description: 'Not Modified (If-None-Match ETag matched client cache).',
  })
  getJawaBaliGeoJson(
    @Req() req: ExpressRequest,
    @Res() res: ExpressResponse,
  ) {
    const asset = this.tsunamiService.loadGeoJsonFile();
    if (!asset) {
      throw new NotFoundException(
        'Tsunami Red Zone GeoJSON asset file is not available on server.',
      );
    }

    const clientEtag = req.headers['if-none-match'];
    if (clientEtag && clientEtag === asset.etag) {
      return res.status(HttpStatus.NOT_MODIFIED).send();
    }

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('ETag', asset.etag);
    res.setHeader('Cache-Control', 'public, max-age=604800'); // 7 days cache
    return res.send(asset.buffer);
  }

  @Post('verify-location')
  @ApiOperation({
    summary:
      'Server-side fallback check if a user coordinate is in Tsunami Red Zone (PostGIS ST_Contains)',
  })
  @ApiResponse({
    status: 200,
    description: 'Returns boolean isRedZone and hazardLevel.',
  })
  async verifyLocation(@Body() dto: VerifyLocationDto) {
    return this.tsunamiService.checkTsunamiHazard(dto.latitude, dto.longitude);
  }

  @Get('check')
  @ApiOperation({
    summary:
      'GET endpoint query check if location is in Tsunami Red Zone',
  })
  @ApiQuery({ name: 'latitude', type: Number, example: -8.02 })
  @ApiQuery({ name: 'longitude', type: Number, example: 110.33 })
  async checkTsunamiQuery(
    @Query('latitude') latitude: string,
    @Query('longitude') longitude: string,
  ) {
    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);
    return this.tsunamiService.checkTsunamiHazard(lat, lng);
  }

  @Get('tile/:z/:x/:y.svg')
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
    const svg = await this.tsunamiService.getTsunamiSvgTile(
      parseInt(z, 10),
      parseInt(x, 10),
      parseInt(y, 10),
    );
    res.setHeader('Content-Type', 'image/svg+xml');
    return res.send(svg);
  }

  @Get('tile/:z/:x/:y.pbf')
  @ApiOperation({
    summary: 'Get Mapbox Vector Tile (MVT PBF) for Tsunami Red Zone',
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
    const pbf = await this.tsunamiService.getTsunamiMvtTile(
      parseInt(z, 10),
      parseInt(x, 10),
      parseInt(y, 10),
    );
    res.setHeader('Content-Type', 'application/x-protobuf');
    return res.send(pbf);
  }
}
