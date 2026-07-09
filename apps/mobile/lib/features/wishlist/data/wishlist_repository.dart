import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skipit/core/config/app_config.dart';
import 'package:skipit/core/services/supabase_provider.dart';
import 'package:skipit/features/listings/domain/models/listing.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref);
});

class WishlistRepository {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'bypass-tunnel-reminder': 'true'},
  ));

  WishlistRepository(this._ref);

  Future<List<Listing>> getWishlist() async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.get(
        '/wishlist',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final List list = response.data;
      return list.map((item) => Listing.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to fetch wishlist: $e');
    }
  }

  Future<void> addToWishlist(String listingId) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      await _dio.post(
        '/wishlist/$listingId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      throw Exception('Failed to add to wishlist: $e');
    }
  }

  Future<void> removeFromWishlist(String listingId) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      await _dio.delete(
        '/wishlist/$listingId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      throw Exception('Failed to remove from wishlist: $e');
    }
  }
}
