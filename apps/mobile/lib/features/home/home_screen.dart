import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/services/location_service.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';
import 'package:skipit/features/listings/data/listings_provider.dart';
import 'package:skipit/features/listings/presentation/widgets/listing_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _cityAddress = 'Detecting Location...';
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectUserLocation();
    });
  }

  Future<void> _detectUserLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final address = await LocationService.getAddressFromLatLng(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
            _cityAddress = address ?? 'Unknown Location';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cityAddress = 'Mumbai, Maharashtra'; // Fallback default
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cityAddress = 'Mumbai, Maharashtra';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _detectUserLocation();
    await ref.read(listingsProvider.notifier).fetchListings();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final listingsAsync = ref.watch(listingsProvider);
    final user = authState.user;

    final categories = ['All', 'Electronics', 'Camera', 'Sports', 'Tools', 'Furniture', 'Other'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _detectUserLocation,
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _cityAddress,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                _isLocating
                                    ? const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      )
                                    : const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hey, ${user?.userMetadata?['full_name']?.split(' ')[0] ?? 'Renter'} \u{1F44B}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (user?.userMetadata?['full_name'] as String?)?.substring(0, 1).toUpperCase() ?? 'S',
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () => context.push('/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surface),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Search for anything...', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.tune, color: AppColors.primary, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Categories
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 8),
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == 0;
                        return GestureDetector(
                          onTap: () {
                            if (index == 0) {
                              context.push('/search');
                            } else {
                              context.push('/search', extra: categories[index]);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                categories[index],
                                style: TextStyle(
                                  color: isSelected ? AppColors.white : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Section Title
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trending Near You',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'See all',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),

              // Listings Section
              listingsAsync.when(
                data: (listings) => listings.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              const Text('No listings yet', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => ListingCard(
                              listing: listings[index],
                              userLat: _latitude,
                              userLng: _longitude,
                            ),
                            childCount: listings.length,
                          ),
                        ),
                      ),
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
                error: (err, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: ElevatedButton(
          onPressed: () => context.push('/add-listing'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: AppColors.primary, width: 2),
            ),
            elevation: 8,
            shadowColor: AppColors.black.withValues(alpha: 0.5),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 24),
              SizedBox(width: 8),
              Text('List an Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
