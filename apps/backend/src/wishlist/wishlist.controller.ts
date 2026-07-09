import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { WishlistService } from './wishlist.service';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';

@Controller('wishlist')
@UseGuards(SupabaseAuthGuard)
export class WishlistController {
  constructor(private readonly wishlistService: WishlistService) {}

  @Get()
  async getWishlist(@Req() req: any) {
    return this.wishlistService.getWishlist(req.user.id);
  }

  @Post(':listingId')
  @HttpCode(HttpStatus.OK)
  async addToWishlist(@Req() req: any, @Param('listingId') listingId: string) {
    return this.wishlistService.addToWishlist(req.user.id, listingId);
  }

  @Delete(':listingId')
  @HttpCode(HttpStatus.OK)
  async removeFromWishlist(@Req() req: any, @Param('listingId') listingId: string) {
    return this.wishlistService.removeFromWishlist(req.user.id, listingId);
  }
}
