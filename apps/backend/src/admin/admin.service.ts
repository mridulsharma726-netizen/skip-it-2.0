import { Injectable, Logger, BadRequestException, NotFoundException } from '@nestjs/common';
import { SupabaseService } from '../common/supabase/supabase.service';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  /**
   * Log an administrative action to the audit_log table.
   */
  private async logAction(
    adminId: string,
    action: string,
    entityType: string,
    entityId: string,
    oldData?: any,
    newData?: any,
  ) {
    try {
      await this.supabaseService.client.from('audit_log').insert({
        actor_id: adminId,
        action,
        entity_type: entityType,
        entity_id: entityId,
        old_data: oldData,
        new_data: newData,
      });
    } catch (err) {
      this.logger.error(`Failed to write to audit log: ${err.message}`);
    }
  }

  /**
   * Get all metrics for the Admin Dashboard.
   */
  async getStats() {
    const supabase = this.supabaseService.client;

    // Fetch all users
    const { data: users, error: usersErr } = await supabase
      .from('profiles')
      .select('id, is_banned, kyc_status, role');
    if (usersErr) throw new BadRequestException(`Failed to get user stats: ${usersErr.message}`);

    // Fetch all listings
    const { data: listings, error: listingsErr } = await supabase
      .from('listings')
      .select('id, category, is_available');
    if (listingsErr) throw new BadRequestException(`Failed to get listing stats: ${listingsErr.message}`);

    // Fetch all bookings
    const { data: bookings, error: bookingsErr } = await supabase
      .from('bookings')
      .select('id, total_price, deposit_paid, status');
    if (bookingsErr) throw new BadRequestException(`Failed to get booking stats: ${bookingsErr.message}`);

    // Fetch all reports
    const { data: reports, error: reportsErr } = await supabase
      .from('reports')
      .select('id, status');
    if (reportsErr) throw new BadRequestException(`Failed to get report stats: ${reportsErr.message}`);

    // Users summary
    const totalUsers = users.length;
    const bannedUsers = users.filter((u) => u.is_banned).length;
    const pendingKYC = users.filter((u) => u.kyc_status === 'pending').length;
    const adminCount = users.filter((u) => u.role === 'admin').length;

    // Listings summary
    const totalListings = listings.length;
    const activeListings = listings.filter((l) => l.is_available).length;
    
    // Category distribution
    const categoriesMap: Record<string, number> = {};
    listings.forEach((l) => {
      categoriesMap[l.category] = (categoriesMap[l.category] || 0) + 1;
    });

    // Bookings and financial summaries
    const totalBookings = bookings.length;
    const bookingStatusMap: Record<string, number> = {};
    let totalRevenue = 0;
    let escrowHoldings = 0;

    bookings.forEach((b) => {
      bookingStatusMap[b.status] = (bookingStatusMap[b.status] || 0) + 1;
      
      const price = Number(b.total_price) || 0;
      const deposit = Number(b.deposit_paid) || 0;

      // Include paid, active, return_pending, completed, and disputed in revenue
      if (['paid', 'active', 'return_pending', 'completed', 'disputed'].includes(b.status)) {
        totalRevenue += price;
      }

      // Escrow holdings: payments currently in platform custody
      if (['paid', 'active', 'return_pending', 'disputed'].includes(b.status)) {
        escrowHoldings += price + deposit;
      }
    });

    const openDisputes = bookings.filter((b) => b.status === 'disputed').length;

    return {
      users: {
        total: totalUsers,
        banned: bannedUsers,
        pendingKYC,
        admins: adminCount,
      },
      listings: {
        total: totalListings,
        active: activeListings,
        inactive: totalListings - activeListings,
        categories: categoriesMap,
      },
      bookings: {
        total: totalBookings,
        statuses: bookingStatusMap,
        disputed: openDisputes,
      },
      finance: {
        totalRevenueProcessed: totalRevenue,
        escrowHoldings,
        currency: 'INR',
      },
      reports: {
        total: reports.length,
        open: reports.filter((r) => r.status === 'open').length,
      }
    };
  }

  async getPendingKYC() {
    const { data, error } = await this.supabaseService.client
      .from('profiles')
      .select('*')
      .eq('kyc_status', 'pending');

    if (error) throw new BadRequestException(`Failed to get pending KYC: ${error.message}`);
    
    if (data && data.length > 0) {
      for (const profile of data) {
        if (profile.kyc_document_url) {
          profile.kyc_document_url = await this.generateSignedUrl(profile.kyc_document_url);
        }
        if (profile.kyc_selfie_url) {
          profile.kyc_selfie_url = await this.generateSignedUrl(profile.kyc_selfie_url);
        }
      }
    }

    return data || [];
  }

  /**
   * Approve a user's KYC submission.
   */
  async approveKYC(adminId: string, profileId: string) {
    const supabase = this.supabaseService.client;

    const { data: profile, error: fetchError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', profileId)
      .single();

    if (fetchError || !profile) {
      throw new NotFoundException(`User profile with ID ${profileId} not found`);
    }

    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        kyc_status: 'approved',
        is_verified: true,
        kyc_reviewed_at: new Date().toISOString(),
        trust_score: 95, // Elevated trust score on verification!
      })
      .eq('id', profileId);

    if (updateError) throw new BadRequestException(`Approve KYC failed: ${updateError.message}`);

    await this.logAction(
      adminId,
      'admin.kyc_approve',
      'profile',
      profileId,
      { kyc_status: profile.kyc_status, is_verified: profile.is_verified },
      { kyc_status: 'approved', is_verified: true, trust_score: 95 },
    );

    return { message: 'KYC verified and approved successfully.' };
  }

  /**
   * Reject a user's KYC submission with reviewer notes.
   */
  async rejectKYC(adminId: string, profileId: string, notes: string) {
    const supabase = this.supabaseService.client;

    if (!notes) throw new BadRequestException('Reviewer notes are required when rejecting KYC');

    const { data: profile, error: fetchError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', profileId)
      .single();

    if (fetchError || !profile) {
      throw new NotFoundException(`User profile with ID ${profileId} not found`);
    }

    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        kyc_status: 'rejected',
        is_verified: false,
        kyc_reviewed_at: new Date().toISOString(),
        kyc_reviewer_notes: notes,
      })
      .eq('id', profileId);

    if (updateError) throw new BadRequestException(`Reject KYC failed: ${updateError.message}`);

    await this.logAction(
      adminId,
      'admin.kyc_reject',
      'profile',
      profileId,
      { kyc_status: profile.kyc_status, kyc_reviewer_notes: profile.kyc_reviewer_notes },
      { kyc_status: 'rejected', kyc_reviewer_notes: notes },
    );

    return { message: 'KYC submission rejected.' };
  }

  /**
   * Get all user profiles (with filters/search).
   */
  async getUsers(search?: string) {
    const supabase = this.supabaseService.client;
    let query = supabase.from('profiles').select('*');

    if (search) {
      query = query.or(`full_name.ilike.%${search}%,phone.ilike.%${search}%`);
    }

    const { data, error } = await query.order('created_at', { ascending: false, nullsFirst: false });
    if (error) throw new BadRequestException(`Failed to fetch users: ${error.message}`);
    return data || [];
  }

  /**
   * Toggle a user's ban state (banned <-> unbanned).
   */
  async toggleBan(adminId: string, profileId: string) {
    const supabase = this.supabaseService.client;

    if (adminId === profileId) {
      throw new BadRequestException('Banning yourself is not permitted');
    }

    const { data: profile, error: fetchError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', profileId)
      .single();

    if (fetchError || !profile) {
      throw new NotFoundException(`User with ID ${profileId} not found`);
    }

    const newBanState = !profile.is_banned;

    const { error: updateError } = await supabase
      .from('profiles')
      .update({ is_banned: newBanState })
      .eq('id', profileId);

    if (updateError) throw new BadRequestException(`Toggle ban failed: ${updateError.message}`);

    await this.logAction(
      adminId,
      newBanState ? 'admin.user_ban' : 'admin.user_unban',
      'profile',
      profileId,
      { is_banned: profile.is_banned },
      { is_banned: newBanState },
    );

    return {
      message: `User has been ${newBanState ? 'banned and suspended' : 'reinstated'} successfully.`,
      is_banned: newBanState,
    };
  }

  /**
   * Get all listings for moderation.
   */
  async getListings() {
    const { data, error } = await this.supabaseService.client
      .from('listings')
      .select('*, profiles:owner_id(id, full_name, avatar_url)')
      .order('created_at', { ascending: false });

    if (error) throw new BadRequestException(`Failed to fetch listings: ${error.message}`);
    return data || [];
  }

  /**
   * Toggle a listing's visibility (available <-> hidden).
   */
  async toggleListingVisibility(adminId: string, listingId: string) {
    const supabase = this.supabaseService.client;

    const { data: listing, error: fetchError } = await supabase
      .from('listings')
      .select('*')
      .eq('id', listingId)
      .single();

    if (fetchError || !listing) {
      throw new NotFoundException(`Listing with ID ${listingId} not found`);
    }

    const newAvailableState = !listing.is_available;

    const { error: updateError } = await supabase
      .from('listings')
      .update({ is_available: newAvailableState })
      .eq('id', listingId);

    if (updateError) throw new BadRequestException(`Toggle listing visibility failed: ${updateError.message}`);

    await this.logAction(
      adminId,
      newAvailableState ? 'admin.listing_activate' : 'admin.listing_deactivate',
      'listing',
      listingId,
      { is_available: listing.is_available },
      { is_available: newAvailableState },
    );

    return {
      message: `Listing is now ${newAvailableState ? 'visible' : 'hidden'}.`,
      is_available: newAvailableState,
    };
  }

  /**
   * Get disputed bookings and reports.
   */
  async getDisputes() {
    const supabase = this.supabaseService.client;

    // Fetch disputed bookings
    const { data: bookings, error: bookingsErr } = await supabase
      .from('bookings')
      .select('*, renter:renter_id(id, full_name), listing:listing_id(id, title, owner_id, profiles:owner_id(id, full_name))')
      .eq('status', 'disputed');

    if (bookingsErr) throw new BadRequestException(`Failed to fetch disputed bookings: ${bookingsErr.message}`);

    // Fetch reports
    const { data: reports, error: reportsErr } = await supabase
      .from('reports')
      .select('*, reporter:reporter_id(id, full_name), reported_user:reported_user_id(id, full_name), listing:listing_id(id, title), booking:booking_id(id, status)')
      .order('created_at', { ascending: false });

    if (reportsErr) throw new BadRequestException(`Failed to fetch reports: ${reportsErr.message}`);

    return {
      disputedBookings: bookings || [],
      userReports: reports || [],
    };
  }

  /**
   * Resolve a dispute on a booking by completing or cancelling.
   */
  async resolveDispute(adminId: string, bookingId: string, resolution: 'release' | 'refund') {
    const supabase = this.supabaseService.client;

    const { data: booking, error: fetchError } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .single();

    if (fetchError || !booking) {
      throw new NotFoundException(`Booking with ID ${bookingId} not found`);
    }

    if (booking.status !== 'disputed') {
      throw new BadRequestException(`Booking is in status '${booking.status}' and cannot be resolved as a dispute`);
    }

    const targetStatus = resolution === 'release' ? 'completed' : 'cancelled';

    const { error: updateError } = await supabase
      .from('bookings')
      .update({ status: targetStatus })
      .eq('id', bookingId);

    if (updateError) throw new BadRequestException(`Dispute resolution failed: ${updateError.message}`);

    // Log dispute resolution action
    await this.logAction(
      adminId,
      resolution === 'release' ? 'admin.dispute_release_escrow' : 'admin.dispute_refund_renter',
      'booking',
      bookingId,
      { status: booking.status },
      { status: targetStatus },
    );

    return {
      message: `Dispute resolved successfully: funds have been ${resolution === 'release' ? 'released to the owner' : 'returned to the renter'}.`,
      status: targetStatus,
    };
  }

  private async generateSignedUrl(pathOrUrl: string): Promise<string> {
    if (!pathOrUrl) return '';
    // If it starts with http, it is either an external URL or mock URL
    // (We do not sign non-Supabase storage objects like mock URLs)
    if (pathOrUrl.startsWith('http') && !pathOrUrl.includes('/kyc-documents/')) {
      return pathOrUrl;
    }

    // Extract path: if it's already a path, use it. If it contains /kyc-documents/, extract from there.
    let path = pathOrUrl;
    const marker = '/kyc-documents/';
    const index = pathOrUrl.indexOf(marker);
    if (index !== -1) {
      path = pathOrUrl.substring(index + marker.length);
      // Strip query params if any
      const qIndex = path.indexOf('?');
      if (qIndex !== -1) {
        path = path.substring(0, qIndex);
      }
      path = decodeURIComponent(path);
    }

    const { data, error } = await this.supabaseService.client.storage
      .from('kyc-documents')
      .createSignedUrl(path, 600); // 10 minutes expiry

    if (error || !data) {
      this.logger.warn(`Failed to generate signed URL for path ${path}: ${error?.message}`);
      return pathOrUrl; // fallback
    }

    return data.signedUrl;
  }
}
