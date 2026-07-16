import { Test, TestingModule } from '@nestjs/testing';
import { StorageController } from './storage.controller';
import { StorageService } from './storage.service';
import { SupabaseService } from '../common/supabase/supabase.service';
import { BadRequestException } from '@nestjs/common';

describe('StorageController (Upload Folder Gating Tests)', () => {
  let controller: StorageController;
  let serviceMock: any;

  beforeEach(async () => {
    serviceMock = {
      uploadFile: jest.fn().mockResolvedValue('https://supabase.co/file.jpg'),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [StorageController],
      providers: [
        {
          provide: StorageService,
          useValue: serviceMock,
        },
        {
          provide: SupabaseService,
          useValue: { client: {} },
        },
      ],
    }).compile();

    controller = module.get<StorageController>(StorageController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('upload() folder derivation security', () => {
    const mockFile: any = {
      buffer: Buffer.from('test'),
      originalname: 'test.png',
      mimetype: 'image/png',
      size: 100,
    };
    
    const mockReq = {
      user: {
        id: 'user_authenticated_123',
      },
    };

    it('should derive folder from request user ID and ignore client folder query param for kyc-documents', async () => {
      const clientProvidedFolder = 'some_malicious_user_456';
      
      const result = await controller.upload(
        mockFile,
        'kyc-documents',
        clientProvidedFolder,
        mockReq,
      );

      expect(result).toEqual({ url: 'https://supabase.co/file.jpg' });
      
      // Verify that uploadFile was called with the requester's ID, completely ignoring client parameter
      expect(serviceMock.uploadFile).toHaveBeenCalledWith(
        mockFile,
        'kyc-documents',
        'user_authenticated_123',
      );
    });

    it('should derive folder from request user ID and ignore client folder query param for listing-images', async () => {
      const clientProvidedFolder = 'unowned_listing_id_999';
      
      const result = await controller.upload(
        mockFile,
        'listing-images',
        clientProvidedFolder,
        mockReq,
      );

      expect(result).toEqual({ url: 'https://supabase.co/file.jpg' });
      
      // Verify that uploadFile was called with the requester's ID
      expect(serviceMock.uploadFile).toHaveBeenCalledWith(
        mockFile,
        'listing-images',
        'user_authenticated_123',
      );
    });

    it('should derive folder from request user ID and ignore client folder query param for avatars', async () => {
      const clientProvidedFolder = 'another_user_id';
      
      const result = await controller.upload(
        mockFile,
        'avatars',
        clientProvidedFolder,
        mockReq,
      );

      expect(result).toEqual({ url: 'https://supabase.co/file.jpg' });
      
      expect(serviceMock.uploadFile).toHaveBeenCalledWith(
        mockFile,
        'avatars',
        'user_authenticated_123',
      );
    });

    it('should reject with BadRequestException if no file is provided', async () => {
      await expect(
        controller.upload(null as any, 'avatars', 'folder', mockReq),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject with BadRequestException for invalid buckets', async () => {
      await expect(
        controller.upload(mockFile, 'invalid-bucket', 'folder', mockReq),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
