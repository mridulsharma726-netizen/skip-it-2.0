import {
  Controller,
  Post,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  Query,
  Req,
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
    @Req() req: any,
  ) {
    if (!file) {
      throw new BadRequestException('No file provided');
    }

    const allowedBuckets = ['listing-images', 'kyc-documents', 'avatars'];
    if (!allowedBuckets.includes(bucket)) {
      throw new BadRequestException(`Invalid bucket: ${bucket}. Allowed: ${allowedBuckets.join(', ')}`);
    }

    const targetFolder = req.user.id;

    const url = await this.storageService.uploadFile(file, bucket, targetFolder);

    // Note: For 'kyc-documents' bucket, url contains the raw storage path (e.g. "userId/uuid.jpg")
    // rather than a public URL, since it is a private bucket. The upload folder is derived on the
    // server side using the authenticated user's ID (req.user.id) for all buckets, ignoring the
    // client's query parameter for security. We keep the property name as 'url' for client-side
    // compatibility.
    return { url };
  }
}
