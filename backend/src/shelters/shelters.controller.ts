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
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { SheltersService, CreateShelterDto } from './shelters.service';
import { Shelter } from './entities/shelter.entity';

@ApiTags('Shelters')
@Controller('shelters')
export class SheltersController {
  constructor(private readonly sheltersService: SheltersService) {}

  @Post()
  @ApiOperation({ summary: 'Register a new evacuation shelter (SSOT)' })
  async createShelter(@Body() dto: CreateShelterDto): Promise<Shelter> {
    return this.sheltersService.createShelter(dto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all shelters' })
  async getAllShelters(): Promise<Shelter[]> {
    return this.sheltersService.getAllShelters();
  }

  @Get('nearby')
  @ApiOperation({ summary: 'Find nearby shelters within radius' })
  async findNearbyShelters(
    @Query('latitude', ParseFloatPipe) latitude: number,
    @Query('longitude', ParseFloatPipe) longitude: number,
    @Query('radiusInKm', new ParseIntPipe({ optional: true })) radiusInKm?: number,
  ): Promise<Shelter[]> {
    return this.sheltersService.findNearbyShelters(latitude, longitude, radiusInKm);
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
