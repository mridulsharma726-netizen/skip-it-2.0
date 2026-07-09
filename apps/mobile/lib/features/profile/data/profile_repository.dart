import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skipit/core/config/app_config.dart';
import 'package:skipit/core/services/supabase_provider.dart';
import 'package:skipit/features/profile/domain/models/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref);
});

class ProfileRepository {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'bypass-tunnel-reminder': 'true'},
  ));

  ProfileRepository(this._ref);

  Future<UserProfile> getProfile() async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.get(
        '/auth/profile',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return UserProfile.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
    String? bio,
    String? location,
  }) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.patch(
        '/auth/profile',
        data: {
          if (fullName != null) 'fullName': fullName,
          if (phone != null) 'phone': phone,
          if (bio != null) 'bio': bio,
          if (location != null) 'location': location,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return UserProfile.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<UserProfile> updateAvatar(String avatarUrl) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.post(
        '/auth/profile/avatar',
        data: {
          'avatarUrl': avatarUrl,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return UserProfile.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update avatar: $e');
    }
  }

  Future<void> submitKYC({
    required String documentType,
    required String documentUrl,
  }) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      await _dio.post(
        '/kyc/submit',
        data: {
          'documentType': documentType,
          'documentUrl': documentUrl,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      throw Exception('Failed to submit KYC: $e');
    }
  }
}
