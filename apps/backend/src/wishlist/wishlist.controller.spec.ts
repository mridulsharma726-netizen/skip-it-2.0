import { Test, TestingModule } from '@nestjs/testing';
import { WishlistController } from './wishlist.controller';
import { WishlistService } from './wishlist.service';
import { SupabaseService } from '../common/supabase/supabase.service';

describe('WishlistController', () => {
  let controller: WishlistController;

  const mockWishlistService = {};
  const mockSupabaseService = {
    client: {
      auth: {
        getUser: jest.fn(),
      },
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [WishlistController],
      providers: [
        {
          provide: WishlistService,
          useValue: mockWishlistService,
        },
        {
          provide: SupabaseService,
          useValue: mockSupabaseService,
        },
      ],
    }).compile();

    controller = module.get<WishlistController>(WishlistController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
