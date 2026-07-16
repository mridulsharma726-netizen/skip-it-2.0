import { Injectable, Logger, BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { SupabaseService } from '../common/supabase/supabase.service';
import { CreateReviewDto } from './dto/create-review.dto';

@Injectable()
export class ReviewsService {
  private readonly logger = new Logger(ReviewsService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  /**
   * Submit a review for a completed booking.
   */
  async create(userId: string, dto: CreateReviewDto) {
    const supabase = this.supabaseService.client;

    // 1. Fetch booking details
    const { data: booking, error: fetchErr } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', dto.bookingId)
      .single();

    if (fetchErr || !booking) {
      throw new NotFoundException(`Booking with ID ${dto.bookingId} not found`);
    }

    // 2. Only allow review when status is completed
    if (booking.status !== 'completed') {
      throw new BadRequestException(
        `Reviews can only be submitted for completed rentals. Current booking status is: ${booking.status}`
      );
    }

    // 3. Authenticate involvement
    const isRenter = booking.renter_id === userId;
    const isOwner = booking.owner_id === userId;

    if (!isRenter && !isOwner) {
      throw new ForbiddenException('You must be a participant in this booking to write a review');
    }

    // Determine target recipient (reviewee)
    const revieweeId = isRenter ? booking.owner_id : booking.renter_id;

    // 4. Ensure no duplicate reviews from the same reviewer for this booking
    const { data: existingReview, error: checkErr } = await supabase
      .from('reviews')
      .select('id')
      .eq('booking_id', dto.bookingId)
      .eq('reviewer_id', userId)
      .maybeSingle();

    if (existingReview) {
      throw new BadRequestException('You have already submitted a review for this rental booking');
    }

    // 5. Insert review into database
    const { data: review, error: insertErr } = await supabase
      .from('reviews')
      .insert({
        booking_id: dto.bookingId,
        reviewer_id: userId,
        reviewee_id: revieweeId,
        listing_id: booking.listing_id,
        rating: dto.rating,
        comment: dto.comment || null,
      })
      .select()
      .single();

    if (insertErr) {
      this.logger.error(`Failed to submit review: ${insertErr.message}`);
      throw new BadRequestException(`Failed to create review: ${insertErr.message}`);
    }

    // Fallback: Recalculate average rating & review count for reviewee manually
    // (In case the DB triggers aren't loaded or active yet)
    try {
      const { data: reviews } = await supabase
        .from('reviews')
        .select('rating')
        .eq('reviewee_id', revieweeId);

      if (reviews && reviews.length > 0) {
        const total = reviews.length;
        const avg = reviews.reduce((sum, r) => sum + r.rating, 0) / total;
        const roundedAvg = Math.round(avg * 10) / 10;

        await supabase
          .from('profiles')
          .update({
            rating: roundedAvg,
            total_reviews: total,
          })
          .eq('id', revieweeId);
      }
    } catch (err) {
      this.logger.warn(`Manual rating recalculation failed: ${err.message}`);
    }

    return review;
  }

  /**
   * Fetch all reviews received by a user.
   */
  async findByUser(userId: string) {
    const { data, error } = await this.supabaseService.client
      .from('reviews')
      .select('*, reviewer:reviewer_id(id, full_name, avatar_url), listing:listing_id(id, title)')
      .eq('reviewee_id', userId)
      .order('created_at', { ascending: false });

    if (error) {
      throw new BadRequestException(`Failed to fetch reviews: ${error.message}`);
    }

    return data || [];
  }
}
