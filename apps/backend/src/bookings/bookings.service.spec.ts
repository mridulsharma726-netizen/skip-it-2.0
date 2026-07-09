import { Test, TestingModule } from '@nestjs/testing';
import { BookingsService } from './bookings.service';
import { SupabaseService } from '../common/supabase/supabase.service';

describe('BookingsService', () => {
  let service: BookingsService;

  const mockSupabaseService = {
    client: {
      from: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        {
          provide: SupabaseService,
          useValue: mockSupabaseService,
        },
      ],
    }).compile();

    service = module.get<BookingsService>(BookingsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
