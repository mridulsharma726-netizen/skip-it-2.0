import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ListingsService } from './listings.service';
import { CreateListingDto } from './dto/create-listing.dto';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';

@Controller('listings')
export class ListingsController {
  constructor(private readonly listingsService: ListingsService) {}

  @Post()
  @UseGuards(SupabaseAuthGuard)
  create(@Req() req: any, @Body() createListingDto: CreateListingDto) {
    return this.listingsService.create(req.user.id, createListingDto);
  }

  @Get()
  findAll(
    @Query('category') category?: string,
    @Query('search') search?: string,
    @Query('minPrice') minPrice?: string,
    @Query('maxPrice') maxPrice?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('sort') sort?: string,
  ) {
    return this.listingsService.findAll({
      category,
      search,
      minPrice: minPrice ? parseFloat(minPrice) : undefined,
      maxPrice: maxPrice ? parseFloat(maxPrice) : undefined,
      page: page ? parseInt(page) : undefined,
      limit: limit ? parseInt(limit) : undefined,
      sort,
    });
  }

  @Get('my-listings')
  @UseGuards(SupabaseAuthGuard)
  findMyListings(@Req() req: any) {
    return this.listingsService.findByOwner(req.user.id);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.listingsService.findOne(id);
  }

  @Patch(':id')
  @UseGuards(SupabaseAuthGuard)
  update(@Req() req: any, @Param('id') id: string, @Body() dto: Partial<CreateListingDto>) {
    return this.listingsService.update(id, req.user.id, dto);
  }

  @Delete(':id')
  @UseGuards(SupabaseAuthGuard)
  delete(@Req() req: any, @Param('id') id: string) {
    return this.listingsService.delete(id, req.user.id);
  }
}
