import { Test, TestingModule } from '@nestjs/testing';
import { WishlistService } from './wishlist.service';
import { SupabaseService } from '../common/supabase/supabase.service';

describe('WishlistService', () => {
  let service: WishlistService;

  const mockSupabaseService = {
    client: {
      from: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WishlistService,
        {
          provide: SupabaseService,
          useValue: mockSupabaseService,
        },
      ],
    }).compile();

    service = module.get<WishlistService>(WishlistService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
