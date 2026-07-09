import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skipit/features/listings/domain/models/listing.dart';
import 'wishlist_repository.dart';

class WishlistNotifier extends AsyncNotifier<List<Listing>> {
  @override
  Future<List<Listing>> build() async {
    return ref.read(wishlistRepositoryProvider).getWishlist();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(wishlistRepositoryProvider).getWishlist();
    });
  }

  Future<void> toggleWishlist(Listing listing) async {
    final currentList = state.value ?? [];
    final isSaved = currentList.any((item) => item.id == listing.id);

    // Optimistically update the UI state
    final updatedList = List<Listing>.from(currentList);
    if (isSaved) {
      updatedList.removeWhere((item) => item.id == listing.id);
    } else {
      updatedList.add(listing);
    }
    state = AsyncValue.data(updatedList);

    try {
      if (isSaved) {
        await ref.read(wishlistRepositoryProvider).removeFromWishlist(listing.id);
      } else {
        await ref.read(wishlistRepositoryProvider).addToWishlist(listing.id);
      }
    } catch (e) {
      // Rollback on failure
      state = AsyncValue.data(currentList);
    }
  }
}

final wishlistProvider = AsyncNotifierProvider<WishlistNotifier, List<Listing>>(
  WishlistNotifier.new,
);
