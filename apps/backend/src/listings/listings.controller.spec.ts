import { Test, TestingModule } from '@nestjs/testing';
import { ListingsController } from './listings.controller';
import { ListingsService } from './listings.service';
import { SupabaseService } from '../common/supabase/supabase.service';

describe('ListingsController', () => {
  let controller: ListingsController;

  const mockListingsService = {};
  const mockSupabaseService = {
    client: {
      auth: {
        getUser: jest.fn(),
      },
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ListingsController],
      providers: [
        {
          provide: ListingsService,
          useValue: mockListingsService,
        },
        {
          provide: SupabaseService,
          useValue: mockSupabaseService,
        },
      ],
    }).compile();

    controller = module.get<ListingsController>(ListingsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
