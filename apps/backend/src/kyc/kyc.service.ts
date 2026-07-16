import { Injectable, Logger, BadRequestException, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseService } from '../common/supabase/supabase.service';

@Injectable()
export class KycService {
  private readonly logger = new Logger(KycService.name);

  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly configService: ConfigService,
  ) {}

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
      return { message: 'Your KYC submission is currently pending review.', kyc_status: 'pending' };
    }

    let normalizedType = (documentType || '').toLowerCase().trim().replace(/\s+/g, '_');
    if (normalizedType === 'aadhaar_card') {
      normalizedType = 'aadhaar';
    }

    const validDocTypes = ['aadhaar', 'pan', 'driving_license', 'passport', 'voter_id'];
    if (!validDocTypes.includes(normalizedType)) {
      throw new BadRequestException(`Invalid document type: ${documentType}. Allowed: ${validDocTypes.join(', ')}`);
    }

    const autoApprove = this.configService.get<string>('KYC_AUTO_APPROVE') === 'true';

    const updatePayload: any = {
      kyc_status: autoApprove ? 'approved' : 'pending',
      kyc_document_type: normalizedType,
      kyc_document_url: documentUrl,
      kyc_selfie_url: selfieUrl || null,
      updated_at: new Date().toISOString(),
    };

    if (autoApprove) {
      updatePayload.is_verified = true;
      updatePayload.trust_score = 80;
    }

    const { data, error } = await supabase
      .from('profiles')
      .update(updatePayload)
      .eq('id', userId)
      .select()
      .single();

    if (error) {
      this.logger.error(`KYC submission failed: ${error.message}`);
      throw new BadRequestException('Failed to submit KYC documents');
    }

    // Create confirmation notification
    try {
      if (autoApprove) {
        await supabase.from('notifications').insert({
          user_id: userId,
          type: 'kyc_approved',
          title: 'KYC Approved! ✅',
          body: 'Your identity has been verified in sandbox mode. You can now list products on SkipIt.',
          data: {},
        });
      } else {
        await supabase.from('notifications').insert({
          user_id: userId,
          type: 'kyc_submitted',
          title: 'KYC Submitted 📄',
          body: 'Your KYC documents have been submitted and are pending review.',
          data: {},
        });
      }
    } catch {
      // Non-blocking
    }

    if (autoApprove) {
      this.logger.log(`KYC auto-approved in sandbox for user ${userId} — document type: ${documentType}`);
      return { message: 'KYC documents verified and approved instantly in sandbox!', kyc_status: 'approved' };
    } else {
      this.logger.log(`KYC submitted for user ${userId} and is pending review — document type: ${documentType}`);
      return { message: 'KYC documents submitted successfully and are pending review.', kyc_status: 'pending' };
    }
  }

  async getStatus(userId: string) {
    const { data, error } = await this.supabaseService.client
      .from('profiles')
      .select('kyc_status, kyc_document_type, kyc_reviewed_at, kyc_reviewer_notes, kyc_document_url, kyc_selfie_url')
      .eq('id', userId)
      .single();

    if (error) {
      throw new BadRequestException('Failed to fetch KYC status');
    }

    if (data) {
      if (data.kyc_document_url) {
        data.kyc_document_url = await this.generateSignedUrl(data.kyc_document_url);
      }
      if (data.kyc_selfie_url) {
        data.kyc_selfie_url = await this.generateSignedUrl(data.kyc_selfie_url);
      }
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

    return data;
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
