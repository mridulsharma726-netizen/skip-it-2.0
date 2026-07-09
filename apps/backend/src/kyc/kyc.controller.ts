import { Controller, Post, Get, Body, Param, UseGuards, Req } from '@nestjs/common';
import { KycService } from './kyc.service';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';

@Controller('kyc')
@UseGuards(SupabaseAuthGuard)
export class KycController {
  constructor(private readonly kycService: KycService) {}

  @Post('submit')
  submit(
    @Req() req: any,
    @Body() body: { documentType: string; documentUrl: string; selfieUrl: string },
  ) {
    return this.kycService.submit(req.user.id, body.documentType, body.documentUrl, body.selfieUrl);
  }

  @Get('status')
  getStatus(@Req() req: any) {
    return this.kycService.getStatus(req.user.id);
  }

  // ─── ADMIN ENDPOINTS ──────────────────────────────────────
  @Get('pending')
  getPending(@Req() req: any) {
    return this.kycService.getPending(req.user.id);
  }

  @Post('approve/:userId')
  approve(@Req() req: any, @Param('userId') userId: string) {
    return this.kycService.approve(req.user.id, userId);
  }

  @Post('reject/:userId')
  reject(@Req() req: any, @Param('userId') userId: string, @Body('reason') reason: string) {
    return this.kycService.reject(req.user.id, userId, reason);
  }
}
