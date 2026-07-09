import { Test, TestingModule } from '@nestjs/testing';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { SupabaseService } from '../common/supabase/supabase.service';
import { ConfigService } from '@nestjs/config';
import { ForbiddenException, BadRequestException, NotFoundException } from '@nestjs/common';

describe('Bookings Payment Security Tests', () => {
  let controller: BookingsController;
  let service: BookingsService;

  let allowMockPaymentsValue = 'false';
  let mockBooking = {
    id: 'booking_123',
    renter_id: 'user_renter_A',
    owner_id: 'user_owner_B',
    status: 'approved',
    listing: {
      owner_id: 'user_owner_B',
      title: 'Test Skip Bin',
    }
  };

  const mockSupabaseService = {
    client: {
      from: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      eq: jest.fn().mockReturnThis(),
      single: jest.fn().mockImplementation(() => {
        return Promise.resolve({ data: mockBooking, error: null });
      }),
      update: jest.fn().mockReturnThis(),
      insert: jest.fn().mockReturnThis(),
    },
  };

  const mockConfigService = {
    get: jest.fn().mockImplementation((key: string) => {
      if (key === 'ALLOW_MOCK_PAYMENTS') return allowMockPaymentsValue;
      if (key === 'RAZORPAY_KEY_ID') return 'your_razorpay_key_id';
      if (key === 'RAZORPAY_KEY_SECRET') return 'your_razorpay_key_secret';
      return null;
    }),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      controllers: [BookingsController],
      providers: [
        BookingsService,
        {
          provide: SupabaseService,
          useValue: mockSupabaseService,
        },
        {
          provide: ConfigService,
          useValue: mockConfigService,
        },
      ],
    }).compile();

    controller = module.get<BookingsController>(BookingsController);
    service = module.get<BookingsService>(BookingsService);
  });

  describe('ISSUE 1: Booking Pay Request Ownership Verification', () => {
    it('should REJECT payment request with 403 Forbidden if requesting user is NOT the renter', async () => {
      const mockReq = {
        user: { id: 'user_attacker_C' } // User C trying to pay User A's booking
      };

      await expect(
        controller.pay(mockReq, 'booking_123', {
          paymentId: 'pay_123',
          paymentOrderId: 'order_123',
          paymentSignature: 'mock_sig_123',
        })
      ).rejects.toThrow(ForbiddenException);

      console.log('Ownership Verification Success: Rejected request for unauthorized user (403 Forbidden)');
    });

    it('should ALLOW payment request if requesting user is the renter', async () => {
      const mockReq = {
        user: { id: 'user_renter_A' } // User A pays for User A's booking
      };

      // Temporarily allow mock payments so it goes through
      allowMockPaymentsValue = 'true';

      const result = await controller.pay(mockReq, 'booking_123', {
        paymentId: 'pay_123',
        paymentOrderId: 'order_123',
        paymentSignature: 'mock_sig_123',
      });

      expect(result).toBeDefined();
      console.log('Ownership Verification Success: Allowed request for authorized renter');
    });
  });

  describe('ISSUE 1: ALLOW_MOCK_PAYMENTS Gating', () => {
    it('should REJECT mock payment signatures with 400 Bad Request when ALLOW_MOCK_PAYMENTS is false/unset', async () => {
      allowMockPaymentsValue = 'false';

      const mockReq = {
        user: { id: 'user_renter_A' }
      };

      await expect(
        controller.pay(mockReq, 'booking_123', {
          paymentId: 'pay_123',
          paymentOrderId: 'order_123',
          paymentSignature: 'mock_signature_123',
        })
      ).rejects.toThrow(new BadRequestException('Mock payments are disabled in this environment.'));

      console.log('ALLOW_MOCK_PAYMENTS=false Gating Success: Mock signature rejected');
    });

    it('should UNCONDITIONALLY run cryptographic signature check when ALLOW_MOCK_PAYMENTS is false', async () => {
      allowMockPaymentsValue = 'false';
      mockConfigService.get = jest.fn().mockImplementation((key: string) => {
        if (key === 'ALLOW_MOCK_PAYMENTS') return 'false';
        if (key === 'RAZORPAY_KEY_ID') return 'real_key';
        if (key === 'RAZORPAY_KEY_SECRET') return 'real_secret'; // Active secret
        return null;
      });

      const mockReq = {
        user: { id: 'user_renter_A' }
      };

      // Using a real signature that doesn't match the HMAC check
      await expect(
        controller.pay(mockReq, 'booking_123', {
          paymentId: 'pay_123',
          paymentOrderId: 'order_123',
          paymentSignature: 'invalid_cryptographic_signature',
        })
      ).rejects.toThrow(new BadRequestException('Invalid Razorpay signature. Security check failed!'));

      console.log('Signature Check Verification Success: Invalid real signature rejected');
    });
  });
});
