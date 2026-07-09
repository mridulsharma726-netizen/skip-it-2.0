import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:skipit/core/config/app_config.dart';
import 'package:skipit/core/services/supabase_provider.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';
import 'package:skipit/features/listings/domain/models/listing.dart';

final listingsRepositoryProvider = Provider<ListingsRepository>((ref) {
  return ListingsRepository(ref);
});

class ListingsRepository {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'bypass-tunnel-reminder': 'true'},
  ));

  ListingsRepository(this._ref);

  Future<List<Listing>> getListings() async {
    try {
      final response = await _dio.get('/listings');
      final data = response.data;
      final List list;
      if (data is Map) {
        list = data['data'] ?? [];
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }
      return list.map((item) => Listing.fromJson(item)).toList();
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
      throw Exception('Failed to create listing: $e');
    }
  }

  Future<String> uploadImage(String filePath, String bucket, String folder) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final extension = filePath.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
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
      throw Exception('Failed to upload image: $e');
    }
  }
}
