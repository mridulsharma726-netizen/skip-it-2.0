import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/features/listings/data/listings_provider.dart';
import 'package:skipit/features/listings/presentation/widgets/listing_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialCategory;

  const SearchScreen({super.key, this.initialCategory});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Electronics', 'Camera', 'Sports', 'Tools', 'Furniture', 'Other'];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(listingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header & Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surface),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Search items...',
                                hintStyle: TextStyle(color: AppColors.textSecondary),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (value) => setState(() {}),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              child: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.tune, color: AppColors.white, size: 20),
                  ),
                ],
              ),
            ),

            // Categories
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.textPrimary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? AppColors.background : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Results List
            Expanded(
              child: listingsAsync.when(
                data: (listings) {
                  // Apply filters
                  var filtered = listings;
                  if (_selectedCategory != 'All') {
                    filtered = filtered.where((l) => l.category == _selectedCategory).toList();
                  }
                  if (_searchController.text.isNotEmpty) {
                    final query = _searchController.text.toLowerCase();
                    filtered = filtered.where((l) => l.title.toLowerCase().contains(query) || l.description.toLowerCase().contains(query)).toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('No results found', style: TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Try adjusting your search or filters.', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ListingCard(listing: filtered[index]),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
