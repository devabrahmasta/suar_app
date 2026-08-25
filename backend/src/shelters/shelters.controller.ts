import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  ParseFloatPipe,
  ParseIntPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { SheltersService } from './shelters.service';
import { Shelter, ShelterType } from './entities/shelter.entity';
import { CreateShelterDto } from './dto/create-shelter.dto';

@ApiTags('Shelters')
@Controller('shelters')
export class SheltersController {
  constructor(private readonly sheltersService: SheltersService) {}

  @Post()
  @ApiOperation({ summary: 'Register a new evacuation shelter (SSOT)' })
  async createShelter(@Body() dto: CreateShelterDto): Promise<Shelter> {
    return this.sheltersService.createShelter(dto);
  }

  @Post('seed')
  @ApiOperation({ summary: 'Seed 19 official Bantul evacuation points (TPS/TPA)' })
  async seedShelters() {
    return this.sheltersService.seedBantulShelters();
  }

  @Get()
  @ApiOperation({ summary: 'Get all shelters with optional type filter (TPS, TPA, or ALL)' })
  @ApiQuery({ name: 'type', enum: ['TPS', 'TPA', 'ALL'], required: false })
  async getAllShelters(@Query('type') type?: ShelterType | 'ALL'): Promise<Shelter[]> {
    return this.sheltersService.getAllShelters(type);
  }

  @Get('nearby')
  @ApiOperation({ summary: 'Find nearby shelters within radius with optional TPS, TPA, or ALL type filter' })
  @ApiQuery({ name: 'latitude', type: Number, example: -7.97 })
  @ApiQuery({ name: 'longitude', type: Number, example: 110.28 })
  @ApiQuery({ name: 'radiusInKm', type: Number, required: false, example: 15 })
  @ApiQuery({ name: 'type', enum: ['TPS', 'TPA', 'ALL'], required: false })
  async findNearbyShelters(
    @Query('latitude', ParseFloatPipe) latitude: number,
    @Query('longitude', ParseFloatPipe) longitude: number,
    @Query('radiusInKm', new ParseIntPipe({ optional: true })) radiusInKm?: number,
    @Query('type') type?: ShelterType | 'ALL',
  ): Promise<Shelter[]> {
    return this.sheltersService.findNearbyShelters(latitude, longitude, radiusInKm, type);
  }

  @Patch(':id/evacuees')
  @ApiOperation({ summary: 'Update evacuee count for a shelter in real-time' })
  async updateEvacuees(
    @Param('id') id: string,
    @Body('count', ParseIntPipe) count: number,
  ): Promise<Shelter> {
    return this.sheltersService.updateEvacueeCount(id, count);
  }
}
