import {
  Controller,
  Post,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  Query,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { StorageService } from './storage.service';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';

@Controller('storage')
@UseGuards(SupabaseAuthGuard)
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  /**
   * Upload a file to Supabase Storage.
   * Query params:
   *   bucket: 'listing-images' | 'kyc-documents' | 'avatars'
   *   folder: subfolder path (e.g., user ID)
   */
  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  async upload(
    @UploadedFile() file: Express.Multer.File,
    @Query('bucket') bucket: string,
    @Query('folder') folder: string,
  ) {
    if (!file) {
      throw new BadRequestException('No file provided');
    }

    const allowedBuckets = ['listing-images', 'kyc-documents', 'avatars'];
    if (!allowedBuckets.includes(bucket)) {
      throw new BadRequestException(`Invalid bucket: ${bucket}. Allowed: ${allowedBuckets.join(', ')}`);
    }

    const url = await this.storageService.uploadFile(file, bucket, folder || 'uploads');

    // Note: For 'kyc-documents' bucket, url contains the raw storage path (e.g. "userId/uuid.jpg")
    // rather than a public URL, since it is a private bucket. We keep the property name as 'url'
    // to maintain compatibility with the mobile client's existing JSON response parser.
    return { url };
  }
}
