import { Injectable, Logger, BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseService } from '../common/supabase/supabase.service';
import { CreateBookingDto } from './dto/create-booking.dto';

/**
 * Booking State Machine:
 * 
 *   requested → approved → paid → active → return_pending → completed
 *       ↓          ↓        ↓       ↓           ↓
 *   cancelled  cancelled  cancelled disputed  disputed
 * 
 * Valid transitions:
 *   requested  → approved (by owner)
 *   requested  → cancelled (by renter or owner)
 *   approved   → paid (by system after payment verification)
 *   approved   → cancelled (by renter or owner)
 *   paid       → active (by renter via OTP verification)
 *   paid       → cancelled (by renter — refund triggered)
 *   active     → return_pending (by renter)
 *   active     → disputed (by either party)
 *   return_pending → completed (by owner)
 *   return_pending → disputed (by either party)
 */

@Injectable()
export class BookingsService {
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly configService: ConfigService,
  ) {}

  // ─── HELPERS ───────────────────────────────────────────────

  private generateOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  private async getBookingOrFail(bookingId: string) {
    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .select('*, listing:listings(owner_id, title)')
      .eq('id', bookingId)
      .single();

    if (error || !data) {
      throw new NotFoundException(`Booking ${bookingId} not found`);
    }
    return data;
  }

  private async auditLog(actorId: string, action: string, entityType: string, entityId: string, oldData?: any, newData?: any) {
    try {
      await this.supabaseService.client.from('audit_log').insert({
        actor_id: actorId,
        action,
        entity_type: entityType,
        entity_id: entityId,
        old_data: oldData ? JSON.parse(JSON.stringify(oldData)) : null,
        new_data: newData ? JSON.parse(JSON.stringify(newData)) : null,
      });
    } catch (e) {
      this.logger.warn(`Audit log failed for ${action}: ${e.message}`);
    }
  }

  private async createNotification(userId: string, type: string, title: string, body: string, data?: any) {
    try {
      await this.supabaseService.client.from('notifications').insert({
        user_id: userId,
        type,
        title,
        body,
        data: data || {},
      });
    } catch (e) {
      this.logger.warn(`Notification creation failed: ${e.message}`);
    }
  }

  // ─── CREATE BOOKING ────────────────────────────────────────

  async create(renterId: string, dto: CreateBookingDto) {
    // 1. Validate listing exists and is available
    const { data: listing, error: listingError } = await this.supabaseService.client
      .from('listings')
      .select('id, owner_id, title, is_available, price_per_day, deposit_amount')
      .eq('id', dto.listingId)
      .single();

    if (listingError || !listing) {
      throw new NotFoundException('Listing not found');
    }

    if (!listing.is_available) {
      throw new BadRequestException('This listing is not available for rent');
    }

    // 2. Cannot book your own listing
    if (listing.owner_id === renterId) {
      throw new BadRequestException('You cannot book your own listing');
    }

    // 3. Validate dates (Normalized to midnight to avoid timezone/clock-skew issues!)
    const startDate = new Date(dto.startDate);
    startDate.setHours(0, 0, 0, 0);
    const endDate = new Date(dto.endDate);
    endDate.setHours(0, 0, 0, 0);
    const now = new Date();
    now.setHours(0, 0, 0, 0);

    if (startDate < now) {
      throw new BadRequestException('Start date cannot be in the past');
    }
    if (endDate <= startDate) {
      throw new BadRequestException('End date must be after start date');
    }

    // 4. Server-side price calculation (don't trust client-submitted totals)
    const days = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    const calculatedTotal = (days * listing.price_per_day) + listing.deposit_amount;

    // 5. Insert booking — the DB trigger will enforce no overlap
    const { data: booking, error: insertError } = await this.supabaseService.client
      .from('bookings')
      .insert({
        listing_id: dto.listingId,
        renter_id: renterId,
        owner_id: listing.owner_id,
        start_date: dto.startDate,
        end_date: dto.endDate,
        total_price: calculatedTotal,
        deposit_paid: listing.deposit_amount,
        status: 'requested',
      })
      .select()
      .single();

    if (insertError) {
      if (insertError.message.includes('overlap')) {
        throw new BadRequestException('These dates are already booked. Please choose different dates.');
      }
      this.logger.error(`Failed to create booking: ${insertError.message}`);
      throw new BadRequestException(insertError.message);
    }

    // 6. Create Razorpay Order with smart fallback!
    let paymentOrderId = `order_mock_${Date.now()}`;
    const keyId = this.configService.get<string>('RAZORPAY_KEY_ID');
    const keySecret = this.configService.get<string>('RAZORPAY_KEY_SECRET');

    if (keyId && keyId !== 'your_razorpay_key_id' && keySecret && keySecret !== 'your_razorpay_key_secret') {
      try {
        const Razorpay = require('razorpay');
        const razorpay = new Razorpay({
          key_id: keyId,
          key_secret: keySecret,
        });

        const order = await razorpay.orders.create({
          amount: Math.round(calculatedTotal * 100), // in paise
          currency: 'INR',
          receipt: booking.id,
        });

        paymentOrderId = order.id;
      } catch (err) {
        this.logger.warn(`Razorpay Order creation failed: ${err.message}. Falling back to sandbox simulation.`);
      }
    }

    // 7. Update booking with the payment_order_id
    const { data: finalBooking, error: updateError } = await this.supabaseService.client
      .from('bookings')
      .update({ payment_order_id: paymentOrderId })
      .eq('id', booking.id)
      .select()
      .single();

    if (updateError) {
      throw new BadRequestException(updateError.message);
    }

    // 8. Notify the owner
    await this.createNotification(
      listing.owner_id,
      'booking_request',
      'New Booking Request',
      `Someone wants to rent your "${listing.title}" from ${dto.startDate} to ${dto.endDate}`,
      { booking_id: finalBooking.id, listing_id: dto.listingId },
    );

    await this.auditLog(renterId, 'booking.created', 'booking', finalBooking.id, null, { status: 'approved', payment_order_id: paymentOrderId });

    return finalBooking;
  }

  // ─── OWNER: APPROVE ────────────────────────────────────────

  async approve(bookingId: string, ownerId: string) {
    const booking = await this.getBookingOrFail(bookingId);

    if (booking.listing?.owner_id !== ownerId) {
      throw new ForbiddenException('Only the listing owner can approve bookings');
    }
    if (booking.status !== 'requested') {
      throw new BadRequestException(`Cannot approve a booking with status "${booking.status}"`);
    }

    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .update({ status: 'approved', approved_at: new Date().toISOString() })
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw new BadRequestException(error.message);

    await this.createNotification(
      booking.renter_id,
      'booking_approved',
      'Booking Approved!',
      `Your booking for "${booking.listing?.title}" has been approved. Please proceed to payment.`,
      { booking_id: bookingId },
    );

    await this.auditLog(ownerId, 'booking.approved', 'booking', bookingId, { status: 'requested' }, { status: 'approved' });

    return data;
  }

  // ─── OWNER: REJECT ─────────────────────────────────────────

  async reject(bookingId: string, ownerId: string, reason: string) {
    const booking = await this.getBookingOrFail(bookingId);

    if (booking.listing?.owner_id !== ownerId) {
      throw new ForbiddenException('Only the listing owner can reject bookings');
    }
    if (booking.status !== 'requested') {
      throw new BadRequestException(`Cannot reject a booking with status "${booking.status}"`);
    }

    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .update({
        status: 'cancelled',
        cancelled_by: ownerId,
        cancellation_reason: reason,
        cancelled_at: new Date().toISOString(),
      })
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw new BadRequestException(error.message);

    await this.createNotification(
      booking.renter_id,
      'booking_rejected',
      'Booking Rejected',
      `Your booking for "${booking.listing?.title}" was not approved. Reason: ${reason}`,
      { booking_id: bookingId },
    );

    await this.auditLog(ownerId, 'booking.rejected', 'booking', bookingId, { status: 'requested' }, { status: 'cancelled', reason });

    return data;
  }

  // ─── SYSTEM: MARK PAID (after Razorpay verification) ───────

  async markPaid(bookingId: string, paymentOrderId: string, paymentId: string, paymentSignature: string, userId: string) {
    const booking = await this.getBookingOrFail(bookingId);

    if (booking.renter_id !== userId) {
      throw new ForbiddenException('You are not authorized to pay for this booking');
    }

    if (booking.status !== 'approved') {
      throw new BadRequestException(`Cannot mark as paid — booking status is "${booking.status}"`);
    }

    const allowMock = this.configService.get<string>('ALLOW_MOCK_PAYMENTS') === 'true';

    if (paymentSignature.startsWith('mock_') || paymentSignature === 'mock_signature') {
      if (!allowMock) {
        throw new BadRequestException('Mock payments are disabled in this environment.');
      }
      // Allowed: bypass verification
    } else {
      // Unconditional cryptographic check
      const keySecret = this.configService.get<string>('RAZORPAY_KEY_SECRET');
      if (!keySecret || keySecret === 'your_razorpay_key_secret') {
        throw new BadRequestException('Razorpay is not configured on the backend.');
      }
      try {
        const crypto = require('crypto');
        const hmac = crypto.createHmac('sha256', keySecret);
        hmac.update(`${paymentOrderId}|${paymentId}`);
        const generatedSignature = hmac.digest('hex');

        if (generatedSignature !== paymentSignature) {
          throw new BadRequestException('Invalid Razorpay signature. Security check failed!');
        }
      } catch (err) {
        if (err instanceof BadRequestException) {
          throw err;
        }
        throw new BadRequestException(`Signature validation error: ${err.message}`);
      }
    }

    // Generate OTP for handover
    const otp = this.generateOtp();
    const otpExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours

    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .update({
        status: 'paid',
        paid_at: new Date().toISOString(),
        payment_order_id: paymentOrderId,
        payment_id: paymentId,
        payment_signature: paymentSignature,
        otp_code: otp,
        otp_expires_at: otpExpiresAt.toISOString(),
        otp_attempts: 0,
      })
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw new BadRequestException(error.message);

    // Notify renter with OTP
    await this.createNotification(
      booking.renter_id,
      'payment_success',
      'Payment Successful',
      `Your payment is confirmed. Your handover OTP is: ${otp}. Share this with the owner when you pick up the item.`,
      { booking_id: bookingId, otp },
    );

    // Notify owner
    await this.createNotification(
      booking.listing?.owner_id,
      'payment_received',
      'Payment Received',
      `Payment for "${booking.listing?.title}" has been received. The renter will share an OTP when picking up.`,
      { booking_id: bookingId },
    );

    await this.auditLog('system', 'booking.paid', 'booking', bookingId, { status: 'approved' }, { status: 'paid' });

    return data;
  }

  // ─── ACTIVATE VIA OTP ──────────────────────────────────────

  async activate(bookingId: string, userId: string, otp: string) {
    const booking = await this.getBookingOrFail(bookingId);

    if (booking.status !== 'paid') {
      throw new BadRequestException(`Cannot activate — booking status is "${booking.status}"`);
    }

    // Only owner verifies the OTP (renter tells them the code)
    if (booking.listing?.owner_id !== userId) {
      throw new ForbiddenException('Only the listing owner can verify the handover OTP');
    }

    // Check expiry
    if (new Date() > new Date(booking.otp_expires_at)) {
      throw new BadRequestException('OTP has expired. Please contact support.');
    }

    // Check attempts
    if (booking.otp_attempts >= 5) {
      throw new BadRequestException('Too many OTP attempts. Booking is locked. Please contact support.');
    }

    // Verify OTP
    if (booking.otp_code !== otp) {
      await this.supabaseService.client
        .from('bookings')
        .update({ otp_attempts: booking.otp_attempts + 1 })
        .eq('id', bookingId);
      throw new BadRequestException(`Invalid OTP. ${4 - booking.otp_attempts} attempts remaining.`);
    }

    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .update({
        status: 'active',
        activated_at: new Date().toISOString(),
        otp_code: null, // Clear OTP after successful verification
      })
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw new BadRequestException(error.message);

    await this.createNotification(
      booking.renter_id,
      'booking_active',
      'Rental Started!',
      `Your rental of "${booking.listing?.title}" is now active. Enjoy!`,
      { booking_id: bookingId },
    );

    await this.auditLog(userId, 'booking.activated', 'booking', bookingId, { status: 'paid' }, { status: 'active' });

    return data;
  }

  // ─── RENTER: REQUEST RETURN ────────────────────────────────

  async requestReturn(bookingId: string, renterId: string, evidenceUrls?: string[]) {
    const booking = await this.getBookingOrFail(bookingId);

    if (booking.renter_id !== renterId) {
      throw new ForbiddenException('Only the renter can request a return');
    }
    if (booking.status !== 'active') {
      throw new BadRequestException(`Cannot request return — booking status is "${booking.status}"`);
    }

    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .update({
        status: 'return_pending',
        return_evidence_urls: evidenceUrls || [],
      })
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw new BadRequestException(error.message);

    await this.createNotification(
      booking.listing?.owner_id,
      'return_requested',
      'Return Requested',
      `The renter wants to return "${booking.listing?.title}". Please inspect and confirm.`,
      { booking_id: bookingId },
    );

    await this.auditLog(renterId, 'booking.return_requested', 'booking', bookingId, { status: 'active' }, { status: 'return_pending' });

    return data;
  }

  // ─── OWNER: COMPLETE RETURN ────────────────────────────────

  async completeReturn(bookingId: string, ownerId: string, damageClaim?: string, damageDeduction?: number) {
    const booking = await this.getBookingOrFail(bookingId);

    if (booking.listing?.owner_id !== ownerId) {
      throw new ForbiddenException('Only the listing owner can complete the return');
    }
    if (booking.status !== 'return_pending') {
      throw new BadRequestException(`Cannot complete return — booking status is "${booking.status}"`);
    }

    const refundAmount = booking.deposit_paid - (damageDeduction || 0);

    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        damage_claim: damageClaim || null,
        damage_deduction: damageDeduction || 0,
      })
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw new BadRequestException(error.message);

    await this.createNotification(
      booking.renter_id,
      'booking_completed',
      'Rental Completed',
      `Your rental of "${booking.listing?.title}" is complete. ${refundAmount > 0 ? `₹${refundAmount} deposit refund is being processed.` : ''}`,
      { booking_id: bookingId, refund_amount: refundAmount },
    );

    await this.auditLog(ownerId, 'booking.completed', 'booking', bookingId,
      { status: 'return_pending' },
      { status: 'completed', damage_deduction: damageDeduction || 0 },
    );

    // TODO: Trigger Razorpay refund of (deposit - damageDeduction)

    return data;
  }

  // ─── CANCEL ────────────────────────────────────────────────

  async cancel(bookingId: string, userId: string, reason: string) {
    const booking = await this.getBookingOrFail(bookingId);

    const isRenter = booking.renter_id === userId;
    const isOwner = booking.listing?.owner_id === userId;

    if (!isRenter && !isOwner) {
      throw new ForbiddenException('You are not part of this booking');
    }

    const cancellableStatuses = ['requested', 'approved', 'paid'];
    if (!cancellableStatuses.includes(booking.status)) {
      throw new BadRequestException(`Cannot cancel a booking with status "${booking.status}". Use the dispute system instead.`);
    }

    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .update({
        status: 'cancelled',
        cancelled_by: userId,
        cancellation_reason: reason,
        cancelled_at: new Date().toISOString(),
      })
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw new BadRequestException(error.message);

    // Notify the other party
    const notifyUserId = isRenter ? booking.listing?.owner_id : booking.renter_id;
    await this.createNotification(
      notifyUserId,
      'booking_cancelled',
      'Booking Cancelled',
      `A booking for "${booking.listing?.title}" has been cancelled. Reason: ${reason}`,
      { booking_id: bookingId },
    );

    await this.auditLog(userId, 'booking.cancelled', 'booking', bookingId, { status: booking.status }, { status: 'cancelled', reason });

    // TODO: If status was 'paid', trigger Razorpay refund

    return data;
  }

  // ─── DISPUTE ───────────────────────────────────────────────

  async dispute(bookingId: string, userId: string, reason: string, evidenceUrls?: string[]) {
    const booking = await this.getBookingOrFail(bookingId);

    const isRenter = booking.renter_id === userId;
    const isOwner = booking.listing?.owner_id === userId;

    if (!isRenter && !isOwner) {
      throw new ForbiddenException('You are not part of this booking');
    }

    const disputableStatuses = ['active', 'return_pending'];
    if (!disputableStatuses.includes(booking.status)) {
      throw new BadRequestException(`Cannot dispute a booking with status "${booking.status}"`);
    }

    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .update({ status: 'disputed' })
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw new BadRequestException(error.message);

    // Create a report record
    await this.supabaseService.client.from('reports').insert({
      reporter_id: userId,
      booking_id: bookingId,
      listing_id: booking.listing_id,
      reason,
      description: `Dispute raised. Evidence: ${(evidenceUrls || []).join(', ')}`,
      status: 'open',
    });

    await this.auditLog(userId, 'booking.disputed', 'booking', bookingId, { status: booking.status }, { status: 'disputed', reason });

    return data;
  }

  // ─── QUERIES ───────────────────────────────────────────────

  async findByRenter(renterId: string) {
    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .select('*, listing:listings(id, title, images, price_per_day, category)')
      .eq('renter_id', renterId)
      .order('created_at', { ascending: false });

    if (error) {
      this.logger.error(`Failed to fetch bookings for renter ${renterId}: ${error.message}`);
      throw new BadRequestException(error.message);
    }

    return data;
  }

  async findByOwner(ownerId: string) {
    const { data, error } = await this.supabaseService.client
      .from('bookings')
      .select('*, listing:listings(id, title, images, price_per_day, category), renter:profiles!renter_id(full_name, avatar_url, rating, is_verified)')
      .eq('owner_id', ownerId)
      .order('created_at', { ascending: false });

    if (error) {
      this.logger.error(`Failed to fetch bookings for owner ${ownerId}: ${error.message}`);
      throw new BadRequestException(error.message);
    }

    return data;
  }

  async findOne(bookingId: string, userId: string) {
    const booking = await this.getBookingOrFail(bookingId);

    if (booking.renter_id !== userId && booking.listing?.owner_id !== userId) {
      throw new ForbiddenException('You do not have access to this booking');
    }

    return booking;
  }

  async findOnePlain(bookingId: string) {
    return this.getBookingOrFail(bookingId);
  }
}
