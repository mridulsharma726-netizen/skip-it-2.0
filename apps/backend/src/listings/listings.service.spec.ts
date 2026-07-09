import { Test, TestingModule } from '@nestjs/testing';
import { ListingsService } from './listings.service';
import { SupabaseService } from '../common/supabase/supabase.service';

describe('ListingsService', () => {
  let service: ListingsService;

  const mockSupabaseService = {
    client: {
      from: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ListingsService,
        {
          provide: SupabaseService,
          useValue: mockSupabaseService,
        },
      ],
    }).compile();

    service = module.get<ListingsService>(ListingsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
