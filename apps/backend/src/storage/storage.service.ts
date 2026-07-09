import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { SupabaseService } from '../common/supabase/supabase.service';
import { randomUUID } from 'crypto';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);

  private readonly ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
  private readonly MAX_SIZE = 5 * 1024 * 1024; // 5MB

  constructor(private readonly supabaseService: SupabaseService) {}

  async uploadFile(
    file: Express.Multer.File,
    bucket: string,
    folder: string,
  ): Promise<string> {
    // Programmatically ensure bucket exists
    await this.ensureBucketExists(bucket);

    // Validate file type
    let mimeType = file.mimetype;
    if (mimeType === 'application/octet-stream' && file.originalname) {
      const ext = file.originalname.split('.').pop()?.toLowerCase();
      if (ext === 'png') {
        mimeType = 'image/png';
      } else if (ext === 'webp') {
        mimeType = 'image/webp';
      } else if (['jpg', 'jpeg'].includes(ext || '')) {
        mimeType = 'image/jpeg';
      }
    }

    if (!this.ALLOWED_TYPES.includes(mimeType)) {
      throw new BadRequestException(
        `Invalid file type: ${mimeType}. Allowed: ${this.ALLOWED_TYPES.join(', ')}`,
      );
    }

    // Validate file size
    if (file.size > this.MAX_SIZE) {
      throw new BadRequestException(
        `File too large: ${(file.size / 1024 / 1024).toFixed(1)}MB. Max: 5MB`,
      );
    }

    // Generate unique filename
    const ext = file.originalname.split('.').pop() || 'jpg';
    const filename = `${folder}/${randomUUID()}.${ext}`;

    const { error } = await this.supabaseService.client.storage
      .from(bucket)
      .upload(filename, file.buffer, {
        contentType: mimeType,
        upsert: false,
      });

    if (error) {
      this.logger.error(`File upload failed: ${error.message}`);
      throw new BadRequestException(`Upload failed: ${error.message}`);
    }

    // Get the public URL
    const { data } = this.supabaseService.client.storage
      .from(bucket)
      .getPublicUrl(filename);

    return data.publicUrl;
  }

  private async ensureBucketExists(bucket: string) {
    try {
      const { data, error } = await this.supabaseService.client.storage.getBucket(bucket);
      if (error || !data) {
        this.logger.log(`Bucket '${bucket}' not found. Programmatically provisioning it...`);
        const { error: createError } = await this.supabaseService.client.storage.createBucket(bucket, {
          public: true,
          fileSizeLimit: this.MAX_SIZE,
        });
        if (createError) {
          this.logger.error(`Failed to programmatically provision bucket '${bucket}': ${createError.message}`);
        } else {
          this.logger.log(`Bucket '${bucket}' programmatically provisioned successfully!`);
        }
      }
    } catch (e) {
      this.logger.warn(`Non-blocking error checking/provisioning bucket '${bucket}': ${e.message}`);
    }
  }

  async deleteFile(bucket: string, path: string): Promise<void> {
    const { error } = await this.supabaseService.client.storage
      .from(bucket)
      .remove([path]);

    if (error) {
      this.logger.warn(`File deletion failed: ${error.message}`);
    }
  }
}
