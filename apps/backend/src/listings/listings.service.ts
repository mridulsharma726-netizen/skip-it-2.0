import { Injectable, Logger, BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { SupabaseService } from '../common/supabase/supabase.service';
import { CreateListingDto } from './dto/create-listing.dto';

@Injectable()
export class ListingsService {
  private readonly logger = new Logger(ListingsService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  async create(userId: string, dto: CreateListingDto) {
    // 1. Fetch user auth information to check email/phone confirmation
    const { data: authUser, error: authUserErr } = await this.supabaseService.client.auth.admin.getUserById(userId);
    if (authUserErr || !authUser || !authUser.user) {
      throw new ForbiddenException('User authentication details not found');
    }

    const emailConfirmed = !!authUser.user.email_confirmed_at;
    const phoneConfirmed = !!authUser.user.phone_confirmed_at || !!authUser.user.phone;

    if (!emailConfirmed) {
      throw new ForbiddenException('Please verify your email address before listing products.');
    }

    // 2. Enforce real KYC, active status, and phone in profile
    const { data: profile, error: profileError } = await this.supabaseService.client
      .from('profiles')
      .select('is_banned, kyc_status, phone')
      .eq('id', userId)
      .single();

    if (profileError || !profile) {
      throw new NotFoundException('User profile not found');
    }

    if (profile.is_banned) {
      throw new ForbiddenException('Your account has been suspended');
    }

    if (!phoneConfirmed && !profile.phone) {
      throw new ForbiddenException('Please verify your phone number before listing products.');
    }

    if (profile.kyc_status !== 'approved') {
      throw new ForbiddenException(
        'KYC verification required before listing products. Please complete your identity verification and wait for admin approval first.',
      );
    }

    const { data, error } = await this.supabaseService.client
      .from('listings')
      .insert({
        owner_id: userId,
        title: dto.title,
        description: dto.description,
        price_per_day: dto.pricePerDay,
        deposit_amount: dto.depositAmount,
        category: dto.category,
        images: dto.images ?? [],
        condition: dto.condition || 'good',
        location_lat: dto.locationLat,
        location_lng: dto.locationLng,
        location_name: dto.locationName,
        is_available: false, // NEW listings require admin approval before becoming available in the catalog!
      })
      .select()
      .single();

    if (error) {
      this.logger.error(`Failed to create listing: ${error.message}`);
      throw new BadRequestException(error.message);
    }

    // Increment owner's listing count (non-critical)
    try {
      const { data: profile } = await this.supabaseService.client
        .from('profiles')
        .select('total_listings')
        .eq('id', userId)
        .single();
      const currentListings = profile?.total_listings || 0;

      await this.supabaseService.client
        .from('profiles')
        .update({ total_listings: currentListings + 1 })
        .eq('id', userId);
    } catch (err) {
      this.logger.warn(`Failed to increment listing count for ${userId}: ${err.message}`);
    }

    return data;
  }

  async findAll(options?: { category?: string; search?: string; minPrice?: number; maxPrice?: number; page?: number; limit?: number; sort?: string }) {
    if (options?.search) {
      // Escape SQL LIKE wildcards % and _
      const escapedSearch = options.search
        .replace(/\\/g, '\\\\')
        .replace(/%/g, '\\%')
        .replace(/_/g, '\\_');
      const pattern = `%${escapedSearch}%`;

      const buildBaseQuery = () => {
        let q = this.supabaseService.client
          .from('listings')
          .select('*, owner:profiles(full_name, avatar_url, rating, is_verified)')
          .eq('is_available', true);

        if (options?.category) {
          q = q.eq('category', options.category);
        }
        if (options?.minPrice !== undefined) {
          q = q.gte('price_per_day', options.minPrice);
        }
        if (options?.maxPrice !== undefined) {
          q = q.lte('price_per_day', options.maxPrice);
        }
        return q;
      };

      const [titleResult, descResult] = await Promise.all([
        buildBaseQuery().ilike('title', pattern),
        buildBaseQuery().ilike('description', pattern),
      ]);

      if (titleResult.error) {
        throw new BadRequestException(titleResult.error.message);
      }
      if (descResult.error) {
        throw new BadRequestException(descResult.error.message);
      }

      // Merge and deduplicate by listing ID
      const mergedListingsMap = new Map<string, any>();
      titleResult.data?.forEach((item) => mergedListingsMap.set(item.id, item));
      descResult.data?.forEach((item) => mergedListingsMap.set(item.id, item));
      const mergedListings = Array.from(mergedListingsMap.values());

      // Apply sorting in memory
      const sortField = options?.sort === 'price_asc' ? 'price_per_day' :
                         options?.sort === 'price_desc' ? 'price_per_day' :
                         'created_at';
      const ascending = options?.sort === 'price_asc';

      mergedListings.sort((a, b) => {
        const valA = a[sortField];
        const valB = b[sortField];

        if (sortField === 'created_at') {
          const timeA = new Date(valA).getTime();
          const timeB = new Date(valB).getTime();
          return ascending ? timeA - timeB : timeB - timeA;
        } else {
          const numA = Number(valA) || 0;
          const numB = Number(valB) || 0;
          return ascending ? numA - numB : numB - numA;
        }
      });

      // Apply pagination in memory
      const page = options?.page || 1;
      const limit = Math.min(options?.limit || 20, 50);
      const from = (page - 1) * limit;
      const paginatedListings = mergedListings.slice(from, from + limit);

      return {
        data: paginatedListings,
        page,
        limit,
        total: mergedListings.length,
      };
    }

    // Default path without search
    let query = this.supabaseService.client
      .from('listings')
      .select('*, owner:profiles(full_name, avatar_url, rating, is_verified)')
      .eq('is_available', true);

    if (options?.category) {
      query = query.eq('category', options.category);
    }
    if (options?.minPrice !== undefined) {
      query = query.gte('price_per_day', options.minPrice);
    }
    if (options?.maxPrice !== undefined) {
      query = query.lte('price_per_day', options.maxPrice);
    }

    // Sorting
    const sortField = options?.sort === 'price_asc' ? 'price_per_day' :
                       options?.sort === 'price_desc' ? 'price_per_day' :
                       'created_at';
    const ascending = options?.sort === 'price_asc';
    query = query.order(sortField, { ascending });

    // Pagination
    const page = options?.page || 1;
    const limit = Math.min(options?.limit || 20, 50);
    const from = (page - 1) * limit;
    query = query.range(from, from + limit - 1);

    const { data, error, count } = await query;

    if (error) {
      this.logger.error(`Failed to fetch listings: ${error.message}`);
      throw new BadRequestException(error.message);
    }

    return { data, page, limit, total: count };
  }

  async findOne(id: string) {
    const { data, error } = await this.supabaseService.client
      .from('listings')
      .select('*, owner:profiles(id, full_name, avatar_url, rating, is_verified, bio, trust_score, total_reviews, created_at)')
      .eq('id', id)
      .single();

    if (error || !data) {
      throw new NotFoundException(`Listing ${id} not found`);
    }

    // Increment view count (non-blocking)
    try {
      await this.supabaseService.client
        .from('listings')
        .update({ views_count: (data.views_count || 0) + 1 })
        .eq('id', id);
    } catch {
      // Non-critical
    }

    return data;
  }

  async update(id: string, userId: string, updates: Partial<CreateListingDto>) {
    // Verify ownership
    const { data: listing } = await this.supabaseService.client
      .from('listings')
      .select('owner_id')
      .eq('id', id)
      .single();

    if (!listing) {
      throw new NotFoundException(`Listing ${id} not found`);
    }
    if (listing.owner_id !== userId) {
      throw new ForbiddenException('You can only edit your own listings');
    }

    const updateData: any = {};
    if (updates.title) updateData.title = updates.title;
    if (updates.description) updateData.description = updates.description;
    if (updates.pricePerDay) updateData.price_per_day = updates.pricePerDay;
    if (updates.depositAmount) updateData.deposit_amount = updates.depositAmount;
    if (updates.category) updateData.category = updates.category;
    if (updates.images) updateData.images = updates.images;
    if (updates.condition) updateData.condition = updates.condition;
    if (updates.locationLat) updateData.location_lat = updates.locationLat;
    if (updates.locationLng) updateData.location_lng = updates.locationLng;
    if (updates.locationName) updateData.location_name = updates.locationName;

    const { data, error } = await this.supabaseService.client
      .from('listings')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      throw new BadRequestException(error.message);
    }

    return data;
  }

  async delete(id: string, userId: string) {
    // Verify ownership
    const { data: listing } = await this.supabaseService.client
      .from('listings')
      .select('owner_id')
      .eq('id', id)
      .single();

    if (!listing) {
      throw new NotFoundException(`Listing ${id} not found`);
    }
    if (listing.owner_id !== userId) {
      throw new ForbiddenException('You can only delete your own listings');
    }

    // Check for active bookings
    const { data: activeBookings } = await this.supabaseService.client
      .from('bookings')
      .select('id')
      .eq('listing_id', id)
      .in('status', ['requested', 'approved', 'paid', 'active'])
      .limit(1);

    if (activeBookings && activeBookings.length > 0) {
      throw new BadRequestException('Cannot delete a listing with active bookings');
    }

    const { error } = await this.supabaseService.client
      .from('listings')
      .delete()
      .eq('id', id);

    if (error) {
      throw new BadRequestException(error.message);
    }

    return { message: 'Listing deleted successfully' };
  }

  async findByOwner(ownerId: string) {
    const { data, error } = await this.supabaseService.client
      .from('listings')
      .select('*')
      .eq('owner_id', ownerId)
      .order('created_at', { ascending: false });

    if (error) {
      throw new BadRequestException(error.message);
    }

    return data;
  }
}
