import { Test, TestingModule } from '@nestjs/testing';
import { KycService } from './kyc.service';
import { SupabaseService } from '../common/supabase/supabase.service';
import { ConfigService } from '@nestjs/config';
import { BadRequestException } from '@nestjs/common';

describe('KycService (Security and Gating Tests)', () => {
  let service: KycService;
  let supabaseClientMock: any;
  let configServiceMock: any;

  beforeEach(async () => {
    supabaseClientMock = {
      from: jest.fn(),
      storage: {
        from: jest.fn(),
      },
    };

    configServiceMock = {
      get: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        KycService,
        {
          provide: SupabaseService,
          useValue: { client: supabaseClientMock },
        },
        {
          provide: ConfigService,
          useValue: configServiceMock,
        },
      ],
    }).compile();

    service = module.get<KycService>(KycService);
  });

  describe('submit()', () => {
    const mockUserId = 'user_123';
    const mockDocType = 'pan';
    const mockDocUrl = 'user_123/doc_uuid.jpg';
    const mockSelfieUrl = 'user_123/selfie_uuid.jpg';

    it('should set status to pending by default (KYC_AUTO_APPROVE is false/unset)', async () => {
      configServiceMock.get.mockReturnValue('false');

      const selectMock = jest.fn().mockReturnThis();
      const eqMock = jest.fn().mockReturnThis();
      const singleMock = jest.fn().mockResolvedValue({ data: { kyc_status: 'none' }, error: null });
      const updateMock = jest.fn().mockReturnThis();

      supabaseClientMock.from.mockImplementation((table: string) => {
        if (table === 'profiles') {
          return {
            select: selectMock,
            update: updateMock,
            eq: eqMock,
            single: singleMock,
          };
        }
        if (table === 'notifications') {
          return {
            insert: jest.fn().mockResolvedValue({ error: null }),
          };
        }
      });

      const result = await service.submit(mockUserId, mockDocType, mockDocUrl, mockSelfieUrl);

      expect(result.kyc_status).toBe('pending');
      expect(result.message).toContain('pending review');

      expect(supabaseClientMock.from).toHaveBeenCalledWith('profiles');
      expect(selectMock).toHaveBeenCalledWith('kyc_status');
      expect(updateMock).toHaveBeenCalledWith({
        kyc_status: 'pending',
        kyc_document_type: 'pan',
        kyc_document_url: mockDocUrl,
        kyc_selfie_url: mockSelfieUrl,
        updated_at: expect.any(String),
      });
    });

    it('should set status to approved and set verification fields when KYC_AUTO_APPROVE is true', async () => {
      configServiceMock.get.mockReturnValue('true');

      const selectMock = jest.fn().mockReturnThis();
      const eqMock = jest.fn().mockReturnThis();
      const singleMock = jest.fn().mockResolvedValue({ data: { kyc_status: 'none' }, error: null });
      const updateMock = jest.fn().mockReturnThis();

      supabaseClientMock.from.mockImplementation((table: string) => {
        if (table === 'profiles') {
          return {
            select: selectMock,
            update: updateMock,
            eq: eqMock,
            single: singleMock,
          };
        }
        if (table === 'notifications') {
          return {
            insert: jest.fn().mockResolvedValue({ error: null }),
          };
        }
      });

      const result = await service.submit(mockUserId, mockDocType, mockDocUrl, mockSelfieUrl);

      expect(result.kyc_status).toBe('approved');
      expect(result.message).toContain('approved instantly');

      expect(updateMock).toHaveBeenCalledWith({
        kyc_status: 'approved',
        is_verified: true,
        trust_score: 80,
        kyc_document_type: 'pan',
        kyc_document_url: mockDocUrl,
        kyc_selfie_url: mockSelfieUrl,
        updated_at: expect.any(String),
      });
    });

    it('should prevent submission if KYC is already approved', async () => {
      const selectMock = jest.fn().mockReturnThis();
      const eqMock = jest.fn().mockReturnThis();
      const singleMock = jest.fn().mockResolvedValue({ data: { kyc_status: 'approved' }, error: null });

      supabaseClientMock.from.mockImplementation((table: string) => {
        if (table === 'profiles') {
          return {
            select: selectMock,
            eq: eqMock,
            single: singleMock,
          };
        }
      });

      const result = await service.submit(mockUserId, mockDocType, mockDocUrl, mockSelfieUrl);
      expect(result.kyc_status).toBe('approved');
      expect(result.message).toContain('already approved');
    });

    it('should prevent submission if KYC is already pending', async () => {
      const selectMock = jest.fn().mockReturnThis();
      const eqMock = jest.fn().mockReturnThis();
      const singleMock = jest.fn().mockResolvedValue({ data: { kyc_status: 'pending' }, error: null });

      supabaseClientMock.from.mockImplementation((table: string) => {
        if (table === 'profiles') {
          return {
            select: selectMock,
            eq: eqMock,
            single: singleMock,
          };
        }
      });

      const result = await service.submit(mockUserId, mockDocType, mockDocUrl, mockSelfieUrl);
      expect(result.kyc_status).toBe('pending');
      expect(result.message).toContain('pending review');
    });
  });

  describe('getStatus() and read-time signed URLs', () => {
    it('should sign the kyc_document_url and kyc_selfie_url at read time', async () => {
      const mockProfile = {
        kyc_status: 'pending',
        kyc_document_type: 'pan',
        kyc_reviewed_at: null,
        kyc_reviewer_notes: null,
        kyc_document_url: 'user_123/doc.jpg',
        kyc_selfie_url: 'user_123/selfie.jpg',
      };

      supabaseClientMock.from.mockReturnValue({
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({ data: mockProfile, error: null }),
      });

      const mockStorageBucket = {
        createSignedUrl: jest.fn()
          .mockImplementation((path: string) => Promise.resolve({ data: { signedUrl: `https://signed.url/${path}` }, error: null })),
      };

      supabaseClientMock.storage.from.mockReturnValue(mockStorageBucket);

      const result = await service.getStatus('user_123');

      expect(result.kyc_document_url).toBe('https://signed.url/user_123/doc.jpg');
      expect(result.kyc_selfie_url).toBe('https://signed.url/user_123/selfie.jpg');
      expect(supabaseClientMock.storage.from).toHaveBeenCalledWith('kyc-documents');
      expect(mockStorageBucket.createSignedUrl).toHaveBeenCalledWith('user_123/doc.jpg', 600);
      expect(mockStorageBucket.createSignedUrl).toHaveBeenCalledWith('user_123/selfie.jpg', 600);
    });

    it('should return mock external URLs as-is without signing', async () => {
      const mockProfile = {
        kyc_status: 'approved',
        kyc_document_type: 'passport',
        kyc_document_url: 'https://example.com/mock-doc.pdf',
        kyc_selfie_url: '',
      };

      supabaseClientMock.from.mockReturnValue({
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({ data: mockProfile, error: null }),
      });

      const result = await service.getStatus('user_123');

      expect(result.kyc_document_url).toBe('https://example.com/mock-doc.pdf');
      expect(supabaseClientMock.storage.from).not.toHaveBeenCalled();
    });
  });
});
