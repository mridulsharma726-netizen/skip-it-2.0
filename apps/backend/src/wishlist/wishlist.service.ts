import { Injectable, BadRequestException } from '@nestjs/common';
import { SupabaseService } from '../common/supabase/supabase.service';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class WishlistService {
  constructor(private readonly supabaseService: SupabaseService) {}

  private get client() {
    return this.supabaseService.client;
  }

  private getFallbackFilePath() {
    return path.join(process.cwd(), 'wishlists_mock.json');
  }

  private readFallback(): Record<string, string[]> {
    try {
      const filePath = this.getFallbackFilePath();
      if (!fs.existsSync(filePath)) {
        return {};
      }
      return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (e) {
      return {};
    }
  }

  private writeFallback(data: Record<string, string[]>) {
    try {
      fs.writeFileSync(this.getFallbackFilePath(), JSON.stringify(data, null, 2), 'utf8');
    } catch (e) {
      // Ignore write errors
    }
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
      const isMissingTable = 
        err.message?.includes('wishlists') || 
        err.message?.includes('relation') || 
        err.message?.includes('schema cache') ||
        String(err).includes('wishlists');

      if (isMissingTable) {
        const fallbacks = this.readFallback();
        const listingIds = fallbacks[userId] || [];
        if (listingIds.length === 0) return [];
        
        // Fetch listings from Supabase that match these IDs
        const { data: listings, error: listingsError } = await this.client
          .from('listings')
          .select('*, owner:profiles(*)')
          .in('id', listingIds);

        if (listingsError) {
          throw new BadRequestException(`Failed to fetch fallback wishlist: ${listingsError.message}`);
        }
        return listings || [];
      }
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
      const isMissingTable = 
        err.message?.includes('wishlists') || 
        err.message?.includes('relation') || 
        err.message?.includes('schema cache') ||
        String(err).includes('wishlists');

      if (isMissingTable) {
        const fallbacks = this.readFallback();
        if (!fallbacks[userId]) {
          fallbacks[userId] = [];
        }
        if (!fallbacks[userId].includes(listingId)) {
          fallbacks[userId].push(listingId);
          this.writeFallback(fallbacks);
        }
        return { success: true, data: { user_id: userId, listing_id: listingId } };
      }
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
      const isMissingTable = 
        err.message?.includes('wishlists') || 
        err.message?.includes('relation') || 
        err.message?.includes('schema cache') ||
        String(err).includes('wishlists');

      if (isMissingTable) {
        const fallbacks = this.readFallback();
        if (fallbacks[userId]) {
          fallbacks[userId] = fallbacks[userId].filter(id => id !== listingId);
          this.writeFallback(fallbacks);
        }
        return { success: true };
      }
      throw new BadRequestException(`Failed to remove from wishlist: ${err.message}`);
    }
  }
}

