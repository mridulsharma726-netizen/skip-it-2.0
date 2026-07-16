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

  describe('findAll() search split query execution', () => {
    it('should run separate title and description queries and escape LIKE wildcards', async () => {
      const ilikeMock = jest.fn().mockImplementation(() => Promise.resolve({ data: [], error: null }));
      const eqMock = jest.fn().mockReturnThis();
      const gteMock = jest.fn().mockReturnThis();
      const lteMock = jest.fn().mockReturnThis();

      const selectMock = jest.fn().mockReturnValue({
        eq: eqMock,
        gte: gteMock,
        lte: lteMock,
        ilike: ilikeMock,
      });

      supabaseClientMock.from.mockReturnValue({
        select: selectMock,
      });

      const searchInput = '50% off_now';
      await service.findAll({ search: searchInput });

      expect(supabaseClientMock.from).toHaveBeenCalledWith('listings');
      
      // Should query both columns in parallel
      expect(ilikeMock).toHaveBeenCalledTimes(2);
      
      // Wildcard percentage (%) and underscore (_) are escaped as \% and \_
      expect(ilikeMock).toHaveBeenNthCalledWith(1, 'title', '%50\\% off\\_now%');
      expect(ilikeMock).toHaveBeenNthCalledWith(2, 'description', '%50\\% off\\_now%');
    });
  });
});
