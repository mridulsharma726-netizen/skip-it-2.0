import { Injectable, BadRequestException } from '@nestjs/common';
import { SupabaseService } from '../common/supabase/supabase.service';

@Injectable()
export class WishlistService {
  constructor(private readonly supabaseService: SupabaseService) {}

  private get client() {
    return this.supabaseService.client;
  }

  async getWishlist(userId: string) {
    try {
      const { data, error } = await this.client
        .from('wishlists')
        .select('*, listing:listings(*, owner:profiles(*))')
        .eq('user_id', userId);

      if (error) {
        throw error;
      }

      // Return the nested listing details
      return (data || []).map((item: any) => item.listing).filter(Boolean);
    } catch (err: any) {
      throw new BadRequestException(`Failed to fetch wishlist: ${err.message}`);
    }
  }

  async addToWishlist(userId: string, listingId: string) {
    try {
      const { data, error } = await this.client
        .from('wishlists')
        .upsert({ user_id: userId, listing_id: listingId }, { onConflict: 'user_id,listing_id' })
        .select();

      if (error) throw error;

      return { success: true, data };
    } catch (err: any) {
      throw new BadRequestException(`Failed to add to wishlist: ${err.message}`);
    }
  }

  async removeFromWishlist(userId: string, listingId: string) {
    try {
      const { data, error } = await this.client
        .from('wishlists')
        .delete()
        .eq('user_id', userId)
        .eq('listing_id', listingId)
        .select();

      if (error) throw error;

      return { success: true };
    } catch (err: any) {
      throw new BadRequestException(`Failed to remove from wishlist: ${err.message}`);
    }
  }
}
