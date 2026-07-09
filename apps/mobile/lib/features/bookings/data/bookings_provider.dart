import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skipit/features/bookings/domain/models/booking.dart';
import 'bookings_repository.dart';

// Renter bookings list provider
class RenterBookingsNotifier extends AsyncNotifier<List<Booking>> {
  @override
  Future<List<Booking>> build() async {
    return ref.read(bookingsRepositoryProvider).getRenterBookings();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(bookingsRepositoryProvider).getRenterBookings();
    });
  }
}

final renterBookingsProvider = AsyncNotifierProvider<RenterBookingsNotifier, List<Booking>>(
  RenterBookingsNotifier.new,
);

// Owner bookings list provider
class OwnerBookingsNotifier extends AsyncNotifier<List<Booking>> {
  @override
  Future<List<Booking>> build() async {
    return ref.read(bookingsRepositoryProvider).getOwnerBookings();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(bookingsRepositoryProvider).getOwnerBookings();
    });
  }
}

final ownerBookingsProvider = AsyncNotifierProvider<OwnerBookingsNotifier, List<Booking>>(
  OwnerBookingsNotifier.new,
);
