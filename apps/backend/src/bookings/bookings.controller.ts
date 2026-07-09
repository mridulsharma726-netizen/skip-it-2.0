import { Controller, Post, Get, Patch, Body, Param, UseGuards, Req, ForbiddenException, NotFoundException } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import {
  RejectBookingDto,
  ActivateBookingDto,
  ReturnBookingDto,
  CompleteReturnDto,
  CancelBookingDto,
  DisputeBookingDto,
} from './dto/booking-actions.dto';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';

@Controller('bookings')
@UseGuards(SupabaseAuthGuard)
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  // ─── CREATE ────────────────────────────────────────────────
  @Post()
  create(@Req() req: any, @Body() dto: CreateBookingDto) {
    return this.bookingsService.create(req.user.id, dto);
  }

  // ─── OWNER ACTIONS ─────────────────────────────────────────
  @Patch(':id/approve')
  approve(@Req() req: any, @Param('id') id: string) {
    return this.bookingsService.approve(id, req.user.id);
  }

  @Patch(':id/reject')
  reject(@Req() req: any, @Param('id') id: string, @Body() dto: RejectBookingDto) {
    return this.bookingsService.reject(id, req.user.id, dto.reason);
  }

  @Patch(':id/activate')
  activate(@Req() req: any, @Param('id') id: string, @Body() body: any) {
    const otp = body.otp || body.otpCode;
    return this.bookingsService.activate(id, req.user.id, otp);
  }

  @Patch(':id/complete')
  completeReturnOld(@Req() req: any, @Param('id') id: string, @Body() dto: CompleteReturnDto) {
    return this.bookingsService.completeReturn(id, req.user.id, dto.damageClaim, dto.damageDeduction);
  }

  @Patch(':id/return-complete')
  completeReturn(@Req() req: any, @Param('id') id: string, @Body() body: any) {
    const damageClaim = body.damageClaim || null;
    const damageDeduction = body.damageDeduction !== undefined ? Number(body.damageDeduction) : 0;
    return this.bookingsService.completeReturn(id, req.user.id, damageClaim, damageDeduction);
  }

  // ─── RENTER ACTIONS ────────────────────────────────────────
  @Patch(':id/return')
  requestReturnOld(@Req() req: any, @Param('id') id: string, @Body() dto: ReturnBookingDto) {
    return this.bookingsService.requestReturn(id, req.user.id, dto.evidenceUrls);
  }

  @Patch(':id/return-request')
  requestReturn(@Req() req: any, @Param('id') id: string, @Body() body: any) {
    return this.bookingsService.requestReturn(id, req.user.id, body.evidenceUrls);
  }

  // ─── PAYMENT SIMULATION (Mobile Custom Checkout) ──────────
  @Patch(':id/pay')
  async pay(@Req() req: any, @Param('id') id: string, @Body() body: any) {
    const booking = await this.bookingsService.findOnePlain(id);
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    if (booking.renter_id !== req.user.id) {
      throw new ForbiddenException('You are not authorized to pay for this booking');
    }

    const paymentId = body.paymentId || `pay_mock_${Date.now()}`;
    const orderId = body.orderId || body.paymentOrderId || 'mock_order_id';
    const signature = body.signature || body.paymentSignature || 'mock_signature';

    return this.bookingsService.markPaid(id, orderId, paymentId, signature, req.user.id);
  }

  // ─── SHARED ACTIONS ────────────────────────────────────────
  @Patch(':id/cancel')
  cancel(@Req() req: any, @Param('id') id: string, @Body() dto: CancelBookingDto) {
    return this.bookingsService.cancel(id, req.user.id, dto.reason);
  }

  @Patch(':id/dispute')
  dispute(@Req() req: any, @Param('id') id: string, @Body() dto: DisputeBookingDto) {
    return this.bookingsService.dispute(id, req.user.id, dto.reason, dto.evidenceUrls);
  }

  // ─── QUERIES ───────────────────────────────────────────────
  @Get('my-bookings')
  findMyBookings(@Req() req: any) {
    return this.bookingsService.findByRenter(req.user.id);
  }

  @Get('owner-bookings')
  findOwnerBookings(@Req() req: any) {
    return this.bookingsService.findByOwner(req.user.id);
  }

  @Get('renter')
  findRenterBookings(@Req() req: any) {
    return this.bookingsService.findByRenter(req.user.id);
  }

  @Get('owner')
  findOwnerBookingsMobile(@Req() req: any) {
    return this.bookingsService.findByOwner(req.user.id);
  }

  @Get(':id')
  findOne(@Req() req: any, @Param('id') id: string) {
    return this.bookingsService.findOne(id, req.user.id);
  }
}

