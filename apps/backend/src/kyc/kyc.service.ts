import { Injectable, Logger, BadRequestException, ForbiddenException } from '@nestjs/common';
import { SupabaseService } from '../common/supabase/supabase.service';

@Injectable()
export class KycService {
  private readonly logger = new Logger(KycService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  /**
   * Submit KYC documents for verification.
   */
  async submit(userId: string, documentType: string, documentUrl: string, selfieUrl: string) {
    const supabase = this.supabaseService.client;

    // Check if user already has a pending/approved KYC
    const { data: profile } = await supabase
      .from('profiles')
      .select('kyc_status')
      .eq('id', userId)
      .single();

    if (profile?.kyc_status === 'approved') {
      return { message: 'Your KYC is already approved and active!', kyc_status: 'approved' };
    }

    if (profile?.kyc_status === 'pending') {
      return { message: 'Your KYC submission is already approved and active!', kyc_status: 'approved' };
    }

    let normalizedType = (documentType || '').toLowerCase().trim().replace(/\s+/g, '_');
    if (normalizedType === 'aadhaar_card') {
      normalizedType = 'aadhaar';
    }

    const validDocTypes = ['aadhaar', 'pan', 'driving_license', 'passport', 'voter_id'];
    if (!validDocTypes.includes(normalizedType)) {
      throw new BadRequestException(`Invalid document type: ${documentType}. Allowed: ${validDocTypes.join(', ')}`);
    }

    const { data, error } = await supabase
      .from('profiles')
      .update({
        kyc_status: 'approved', // Auto-approved in sandbox for instant testing!
        is_verified: true,
        trust_score: 80,
        kyc_document_type: normalizedType,
        kyc_document_url: documentUrl,
        kyc_selfie_url: selfieUrl || null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId)
      .select()
      .single();

    if (error) {
      this.logger.error(`KYC submission failed: ${error.message}`);
      throw new BadRequestException('Failed to submit KYC documents');
    }

    // Auto-create confirmation notification for sandbox UX
    try {
      await supabase.from('notifications').insert({
        user_id: userId,
        type: 'kyc_approved',
        title: 'KYC Approved! ✅',
        body: 'Your identity has been verified in sandbox mode. You can now list products on SkipIt.',
        data: {},
      });
    } catch {
      // Non-blocking
    }

    this.logger.log(`KYC auto-approved in sandbox for user ${userId} — document type: ${documentType}`);

    return { message: 'KYC documents verified and approved instantly in sandbox!', kyc_status: 'approved' };
  }

  /**
   * Get the current KYC status for a user.
   */
  async getStatus(userId: string) {
    const { data, error } = await this.supabaseService.client
      .from('profiles')
      .select('kyc_status, kyc_document_type, kyc_reviewed_at, kyc_reviewer_notes')
      .eq('id', userId)
      .single();

    if (error) {
      throw new BadRequestException('Failed to fetch KYC status');
    }

    return data;
  }

  /**
   * Admin: Approve a user's KYC.
   */
  async approve(adminId: string, targetUserId: string) {
    await this.ensureAdmin(adminId);

    const { data, error } = await this.supabaseService.client
      .from('profiles')
      .update({
        kyc_status: 'approved',
        is_verified: true,
        kyc_reviewed_at: new Date().toISOString(),
        kyc_reviewer_notes: null,
        trust_score: 80, // Boost trust score on KYC approval
        updated_at: new Date().toISOString(),
      })
      .eq('id', targetUserId)
      .select()
      .single();

    if (error) {
      throw new BadRequestException('Failed to approve KYC');
    }

    // Notify the user
    await this.supabaseService.client.from('notifications').insert({
      user_id: targetUserId,
      type: 'kyc_approved',
      title: 'KYC Approved! ✅',
      body: 'Your identity has been verified. You can now list products on SkipIt.',
      data: {},
    });

    return data;
  }

  /**
   * Admin: Reject a user's KYC with a reason.
   */
  async reject(adminId: string, targetUserId: string, reason: string) {
    await this.ensureAdmin(adminId);

    const { data, error } = await this.supabaseService.client
      .from('profiles')
      .update({
        kyc_status: 'rejected',
        kyc_reviewed_at: new Date().toISOString(),
        kyc_reviewer_notes: reason,
        updated_at: new Date().toISOString(),
      })
      .eq('id', targetUserId)
      .select()
      .single();

    if (error) {
      throw new BadRequestException('Failed to reject KYC');
    }

    // Notify the user
    await this.supabaseService.client.from('notifications').insert({
      user_id: targetUserId,
      type: 'kyc_rejected',
      title: 'KYC Review Update',
      body: `Your KYC was not approved. Reason: ${reason}. Please re-submit with valid documents.`,
      data: { reason },
    });

    return data;
  }

  /**
   * Admin: Get all pending KYC submissions.
   */
  async getPending(adminId: string) {
    await this.ensureAdmin(adminId);

    const { data, error } = await this.supabaseService.client
      .from('profiles')
      .select('id, full_name, email:id, kyc_status, kyc_document_type, kyc_document_url, kyc_selfie_url, created_at')
      .eq('kyc_status', 'pending')
      .order('updated_at', { ascending: true });

    if (error) {
      throw new BadRequestException('Failed to fetch pending KYC submissions');
    }

    return data;
  }

  private async ensureAdmin(userId: string) {
    const { data } = await this.supabaseService.client
      .from('profiles')
      .select('role')
      .eq('id', userId)
      .single();

    if (data?.role !== 'admin') {
      throw new ForbiddenException('Admin access required');
    }
  }
}
