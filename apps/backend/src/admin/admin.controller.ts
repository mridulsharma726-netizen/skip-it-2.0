import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { AdminGuard } from '../auth/guards/admin.guard';
import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(SupabaseAuthGuard, AdminGuard)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('stats')
  async getStats() {
    return this.adminService.getStats();
  }

  @Get('kyc')
  async getPendingKYC() {
    return this.adminService.getPendingKYC();
  }

  @Post('kyc/:id/approve')
  async approveKYC(@Req() req: any, @Param('id') profileId: string) {
    const adminId = req.user.id;
    return this.adminService.approveKYC(adminId, profileId);
  }

  @Post('kyc/:id/reject')
  async rejectKYC(
    @Req() req: any,
    @Param('id') profileId: string,
    @Body('notes') notes: string,
  ) {
    const adminId = req.user.id;
    return this.adminService.rejectKYC(adminId, profileId, notes);
  }

  @Get('users')
  async getUsers(@Query('search') search?: string) {
    return this.adminService.getUsers(search);
  }

  @Post('users/:id/ban')
  async toggleBan(@Req() req: any, @Param('id') profileId: string) {
    const adminId = req.user.id;
    return this.adminService.toggleBan(adminId, profileId);
  }

  @Get('listings')
  async getListings() {
    return this.adminService.getListings();
  }

  @Post('listings/:id/toggle-visibility')
  async toggleListingVisibility(@Req() req: any, @Param('id') listingId: string) {
    const adminId = req.user.id;
    return this.adminService.toggleListingVisibility(adminId, listingId);
  }

  @Get('disputes')
  async getDisputes() {
    return this.adminService.getDisputes();
  }

  @Post('disputes/:bookingId/resolve')
  async resolveDispute(
    @Req() req: any,
    @Param('bookingId') bookingId: string,
    @Body('resolution') resolution: 'release' | 'refund',
  ) {
    const adminId = req.user.id;
    return this.adminService.resolveDispute(adminId, bookingId, resolution);
  }
}
