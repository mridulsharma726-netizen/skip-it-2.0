import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:skipit/core/config/app_config.dart';
import 'package:skipit/core/services/supabase_provider.dart';
import 'package:skipit/features/listings/domain/models/listing.dart';


final listingsRepositoryProvider = Provider<ListingsRepository>((ref) {
  return ListingsRepository(ref);
});

class ListingsRepository {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'bypass-tunnel-reminder': 'true'},
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  ListingsRepository(this._ref);

  /// Fetches all listings directly from Supabase (bypasses unreliable NestJS tunnel for reads).
  Future<List<Listing>> getListings({String? search, String? category}) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      var query = supabase
          .from('listings')
          .select('*, owner:profiles!listings_owner_id_fkey(full_name, avatar_url, rating, trust_score, total_reviews, created_at, is_verified)')
          .eq('is_available', true);

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.eq('category', category);
      }

      if (search != null && search.isNotEmpty) {
        // Search in title and description
        query = query.or('title.ilike.%$search%,description.ilike.%$search%');
      }

      final response = await query.order('created_at', ascending: false).limit(50);
      return (response as List).map((item) => Listing.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to fetch listings: $e');
    }
  }

  Future<Listing> createListing({
    required String title,
    required String description,
    required double pricePerDay,
    required double depositAmount,
    required String category,
    List<String>? images,
  }) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.post(
        '/listings',
        data: {
          'title': title,
          'description': description,
          'pricePerDay': pricePerDay,
          'depositAmount': depositAmount,
          'category': category,
          'images': images ?? [],
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return Listing.fromJson(response.data);
    } catch (e) {
      throw Exception(_handleDioError(e, 'Failed to create listing'));
    }
  }

  /// Uploads an image via NestJS Backend (bypasses RLS by using service_role key on backend).
  Future<String> uploadImage(String filePath, String bucket, String folder) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final ext = filePath.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (ext == 'png') {
        mimeType = 'image/png';
      } else if (ext == 'webp') {
        mimeType = 'image/webp';
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split(RegExp(r'[/\\]')).last,
          contentType: MediaType.parse(mimeType),
        ),
      });

      final response = await _dio.post(
        '/storage/upload',
        queryParameters: {
          'bucket': bucket,
          'folder': folder,
        },
        data: formData,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return response.data['url'] as String;
    } catch (e) {
      throw Exception(_handleDioError(e, 'Failed to upload image'));
    }
  }
}

String _handleDioError(dynamic e, String defaultMessage) {
  if (e is DioException) {
    final responseData = e.response?.data;
    if (responseData is Map && responseData.containsKey('message')) {
      final msg = responseData['message'];
      if (msg is List) {
        return msg.join(', ');
      }
      return msg.toString();
    }
  }
  return '$defaultMessage: $e';
}

