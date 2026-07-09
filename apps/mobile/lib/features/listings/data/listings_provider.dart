import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skipit/features/listings/domain/models/listing.dart';
import 'package:skipit/features/listings/data/listings_repository.dart';

final listingsProvider = NotifierProvider<ListingsNotifier, AsyncValue<List<Listing>>>(
  ListingsNotifier.new,
);

class ListingsNotifier extends Notifier<AsyncValue<List<Listing>>> {
  @override
  AsyncValue<List<Listing>> build() {
    // Initial fetch
    fetchListings();
    return const AsyncValue.loading();
  }

  ListingsRepository get _repository => ref.read(listingsRepositoryProvider);

  Future<void> fetchListings() async {
    state = const AsyncValue.loading();
    try {
      final listings = await _repository.getListings();
      state = AsyncValue.data(listings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addListing(Listing listing) {
    state.whenData((current) {
      state = AsyncValue.data([listing, ...current]);
    });
  }
}
