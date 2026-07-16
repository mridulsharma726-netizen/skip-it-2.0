import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skipit/core/config/app_config.dart';
import 'package:skipit/core/services/supabase_provider.dart';
import 'package:skipit/features/bookings/domain/models/booking.dart';

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return BookingsRepository(ref);
});

class BookingsRepository {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'bypass-tunnel-reminder': 'true'},
  ));

  BookingsRepository(this._ref);

  Future<List<Booking>> getRenterBookings() async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.get(
        '/bookings/renter',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final List list = response.data;
      return list.map((item) => Booking.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to fetch renter bookings: $e');
    }
  }

  Future<List<Booking>> getOwnerBookings() async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.get(
        '/bookings/owner',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final List list = response.data;
      return list.map((item) => Booking.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to fetch owner bookings: $e');
    }
  }

  Future<Booking> createBooking({
    required String listingId,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
    required double depositPaid,
  }) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.post(
        '/bookings',
        data: {
          'listingId': listingId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'totalPrice': totalPrice,
          'depositPaid': depositPaid,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return Booking.fromJson(response.data);
    } catch (e) {
      throw Exception(_handleDioError(e, 'Failed to create booking'));
    }
  }

  Future<Booking> approveBooking(String id) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.patch(
        '/bookings/$id/approve',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return Booking.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to approve booking: $e');
    }
  }

  Future<Booking> rejectBooking(String id, [String reason = 'Owner rejected request']) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.patch(
        '/bookings/$id/reject',
        data: {
          'reason': reason,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return Booking.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to reject booking: $e');
    }
  }

  Future<Booking> payBooking(String id, String paymentId, String orderId, String signature) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.patch(
        '/bookings/$id/pay',
        data: {
          'paymentId': paymentId,
          'orderId': orderId,
          'signature': signature,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return Booking.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to process payment: $e');
    }
  }

  Future<Booking> activateBooking(String id, String otpCode) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.patch(
        '/bookings/$id/activate',
        data: {
          'otpCode': otpCode,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return Booking.fromJson(response.data);
    } catch (e) {
      throw Exception(_handleDioError(e, 'Failed to activate booking'));
    }
  }

  Future<Booking> requestReturn(String id, List<String> evidenceUrls, String? damageClaim) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.patch(
        '/bookings/$id/return-request',
        data: {
          'evidenceUrls': evidenceUrls,
          if (damageClaim != null) 'damageClaim': damageClaim,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return Booking.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to submit return request: $e');
    }
  }

  Future<Booking> completeReturn(String id, double damageDeduction) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.patch(
        '/bookings/$id/return-complete',
        data: {
          'damageDeduction': damageDeduction,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return Booking.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to complete return: $e');
    }
  }

  Future<Booking> cancelBooking(String id, String reason) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.patch(
        '/bookings/$id/cancel',
        data: {
          'reason': reason,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return Booking.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }

  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      await _dio.post(
        '/reviews',
        data: {
          'bookingId': bookingId,
          'rating': rating,
          'comment': comment,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      throw Exception(_handleDioError(e, 'Failed to submit review'));
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
