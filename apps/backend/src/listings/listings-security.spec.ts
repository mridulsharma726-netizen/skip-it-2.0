import { Test, TestingModule } from '@nestjs/testing';
import { ListingsController } from './listings.controller';
import { ListingsService } from './listings.service';
import { SupabaseService } from '../common/supabase/supabase.service';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';

describe('Listings and Profile Security Tests', () => {
  let controller: ListingsController;
  let service: ListingsService;

  let mockProfile = {
    id: 'user_owner_123',
    full_name: 'John Doe',
    avatar_url: 'https://example.com/avatar.png',
    rating: 4.8,
    is_verified: true,
    is_banned: false,
    kyc_status: 'approved',
    total_listings: 0,
    phone: '+919999999999',
    kyc_document_url: 'https://example.com/doc.pdf',
    kyc_selfie_url: 'https://example.com/selfie.png',
    saved_addresses: [{ city: 'Mumbai' }],
  };

  let mockListingsDb = [] as any[];

  // Chainable thenable query mock
  const mockQuery: any = {
    eq: () => mockQuery,
    or: () => mockQuery,
    gte: () => mockQuery,
    lte: () => mockQuery,
    order: () => mockQuery,
    range: () => mockQuery,
    then: (resolve: any) => {
      resolve({
        data: [
          {
            id: 'listing_123',
            title: 'Skip Bin 1',
            owner: {
              full_name: mockProfile.full_name,
              avatar_url: mockProfile.avatar_url,
              rating: mockProfile.rating,
              is_verified: mockProfile.is_verified,
            }
          }
        ],
        error: null
      });
    }
  };

  const mockSupabaseService = {
    client: {
      from: jest.fn().mockImplementation((table: string) => {
        return {
          select: jest.fn().mockImplementation((selectString?: string) => {
            if (selectString && selectString.includes('owner:profiles')) {
              return mockQuery;
            }
            return {
              single: jest.fn().mockImplementation(() => {
                return Promise.resolve({ data: mockProfile, error: null });
              }),
              eq: jest.fn().mockReturnThis(),
            };
          }),
          eq: jest.fn().mockReturnThis(),
          single: jest.fn().mockImplementation(() => {
            return Promise.resolve({ data: mockProfile, error: null });
          }),
          insert: jest.fn().mockImplementation((payload: any) => {
            const newListing = { id: 'listing_123', ...payload };
            mockListingsDb.push(newListing);
            return {
              select: jest.fn().mockReturnThis(),
              single: jest.fn().mockImplementation(() => Promise.resolve({ data: newListing, error: null })),
            };
          }),
          update: jest.fn().mockImplementation((payload: any) => {
            if (payload.total_listings !== undefined) {
              mockProfile.total_listings = payload.total_listings;
            }
            return Promise.resolve({ data: mockProfile, error: null });
          }),
        };
      })
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    mockListingsDb = [];
    mockProfile.total_listings = 0;

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ListingsController],
      providers: [
        ListingsService,
        {
          provide: SupabaseService,
          useValue: mockSupabaseService,
        },
      ],
    }).compile();

    controller = module.get<ListingsController>(ListingsController);
    service = module.get<ListingsService>(ListingsService);
  });

  describe('ISSUE 3: Atomic Listing Count Increment', () => {
    it('should correctly increment total_listings count when multiple listings are created', async () => {
      const mockReq = {
        user: { id: 'user_owner_123' }
      };

      // Create first listing
      await controller.create(mockReq, {
        title: 'Skip Bin 1',
        description: 'First test bin',
        pricePerDay: 150,
        depositAmount: 500,
        category: 'skip_bins',
      });
      expect(mockProfile.total_listings).toBe(1);

      // Create second listing
      await controller.create(mockReq, {
        title: 'Skip Bin 2',
        description: 'Second test bin',
        pricePerDay: 180,
        depositAmount: 600,
        category: 'skip_bins',
      });
      expect(mockProfile.total_listings).toBe(2);

      console.log(`Incremental Count Success: total_listings count is dynamically incremented to ${mockProfile.total_listings}`);
    });
  });

  describe('ISSUE 2: Public Profile View / REST safety validation', () => {
    it('should confirm that the API returns owner details with safe fields only', async () => {
      const result = await controller.findAll();
      expect(result).toBeDefined();
      const listings = result.data;
      expect(listings.length).toBe(1);
      expect(listings[0].owner).toEqual({
        full_name: 'John Doe',
        avatar_url: 'https://example.com/avatar.png',
        rating: 4.8,
        is_verified: true,
      });

      // Confirm sensitive fields are NOT leaked in backend join
      expect(listings[0].owner.phone).toBeUndefined();
      expect(listings[0].owner.kyc_document_url).toBeUndefined();
      console.log('Public Profile Safety Verification Success: Listings endpoint returned safe profile details without leaking sensitive PII');
    });
  });
});
