import { Test, TestingModule } from '@nestjs/testing';
import { ListingsService } from './listings.service';
import { SupabaseService } from '../common/supabase/supabase.service';

describe('ListingsService', () => {
  let service: ListingsService;
  let supabaseClientMock: any;

  beforeEach(async () => {
    supabaseClientMock = {
      from: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ListingsService,
        {
          provide: SupabaseService,
          useValue: { client: supabaseClientMock },
        },
      ],
    }).compile();

    service = module.get<ListingsService>(ListingsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('findAll() search query execution', () => {
    it('should query title and description with an OR clause and escape LIKE wildcards', async () => {
      const queryMock: any = {
        eq: jest.fn().mockReturnThis(),
        gte: jest.fn().mockReturnThis(),
        lte: jest.fn().mockReturnThis(),
        or: jest.fn().mockImplementation(() => queryMock),
        order: jest.fn().mockReturnThis(),
        range: jest.fn().mockReturnThis(),
        then: jest.fn().mockImplementation((resolve) => {
          resolve({ data: [], error: null, count: 0 });
        }),
      };

      supabaseClientMock.from.mockReturnValue({
        select: jest.fn().mockReturnValue(queryMock),
      });

      const searchInput = '50% off_now';
      await service.findAll({ search: searchInput });

      expect(supabaseClientMock.from).toHaveBeenCalledWith('listings');
      expect(queryMock.or).toHaveBeenCalledWith('title.ilike.%50\\% off\\_now%,description.ilike.%50\\% off\\_now%');
    });

    it('should correctly handle listings matching search criteria', async () => {
      const mockData = [
        { id: '1', title: 'Skip Bin Small', description: 'Small skip bin', price_per_day: 50 },
        { id: '2', title: 'Camera Pro', description: 'Professional camera', price_per_day: 120 }
      ];

      const queryMock: any = {
        eq: jest.fn().mockReturnThis(),
        gte: jest.fn().mockReturnThis(),
        lte: jest.fn().mockReturnThis(),
        or: jest.fn().mockImplementation(() => queryMock),
        order: jest.fn().mockReturnThis(),
        range: jest.fn().mockReturnThis(),
        then: jest.fn().mockImplementation((resolve) => {
          resolve({ data: mockData, error: null, count: 2 });
        }),
      };

      supabaseClientMock.from.mockReturnValue({
        select: jest.fn().mockReturnValue(queryMock),
      });

      const result = await service.findAll({ search: 'bin' });
      expect(result.data).toHaveLength(2);
      expect(result.total).toBe(2);
    });
  });
});
