import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/widgets/skipit_widgets.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';
import 'package:skipit/features/listings/data/listings_repository.dart';
import 'package:skipit/features/listings/data/listings_provider.dart';
import 'package:skipit/features/profile/data/profile_provider.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _depositController = TextEditingController();
  
  String _selectedCategory = 'Electronics';
  String _selectedCondition = 'Good';
  bool _isLoading = false;
  String _loadingMessage = 'Creating Listing...';

  final List<String> _categories = ['Electronics', 'Camera', 'Sports', 'Tools', 'Furniture', 'Other'];
  final List<String> _conditions = ['Like New', 'Good', 'Fair'];
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _submit() async {
    final profileAsync = ref.read(profileProvider);
    
    // Hard gate KYC verification check
    final isKycApproved = profileAsync.maybeWhen(
      data: (profile) => profile.kycStatus == 'approved',
      orElse: () => false,
    );

    if (!isKycApproved) {
      _showKycDialog();
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Uploading images...';
      });

      try {
        final userId = ref.read(authProvider).user?.id ?? 'anonymous';
        final List<String> uploadedUrls = [];

        // Upload images one by one to real storage bucket
        for (int i = 0; i < _selectedImages.length; i++) {
          setState(() {
            _loadingMessage = 'Uploading image ${i + 1} of ${_selectedImages.length}...';
          });
          final file = _selectedImages[i];
          final url = await ref.read(listingsRepositoryProvider).uploadImage(
                file.path,
                'listing-images',
                userId,
              );
          uploadedUrls.add(url);
        }

        setState(() {
          _loadingMessage = 'Creating listing in database...';
        });

        final listing = await ref.read(listingsRepositoryProvider).createListing(
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              pricePerDay: double.parse(_priceController.text),
              depositAmount: double.parse(_depositController.text),
              category: _selectedCategory,
              images: uploadedUrls,
            );

        ref.read(listingsProvider.notifier).addListing(listing);
        
        // Trigger profile refresh to update total listings count
        ref.read(profileProvider.notifier).refreshProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing created successfully!', style: TextStyle(color: AppColors.white)),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e', style: const TextStyle(color: AppColors.white)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showKycDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verification Required',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'To ensure safety in our community, you must verify your identity (KYC) before listing products for rent. It takes less than 2 minutes!',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              context.push('/kyc');
            },
            child: const Text('Verify Now', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        limit: 5 - _selectedImages.length,
      );
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles);
          if (_selectedImages.length > 5) {
            _selectedImages.removeRange(5, _selectedImages.length);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e', style: const TextStyle(color: AppColors.white)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('List an Item', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KYC Warning Banner
                  profileAsync.when(
                    data: (profile) {
                      if (profile.kycStatus != 'approved') {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.primary),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Your identity verification is pending. Please complete KYC verification before listing items.',
                                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => context.push('/kyc'),
                                child: const Text('Verify', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // Image Upload Section
                  const Text('Photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Add up to 5 photos of your item.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2, style: BorderStyle.solid),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, color: AppColors.primary),
                                SizedBox(height: 8),
                                Text('Upload', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        ..._selectedImages.map((file) => Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(image: FileImage(File(file.path)), fit: BoxFit.cover),
                              ),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel, color: AppColors.white),
                                  onPressed: () {
                                    setState(() => _selectedImages.remove(file));
                                  },
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Product Details Section
                  const Text('Product Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  SkipItTextField(
                    controller: _titleController,
                    label: 'Title',
                    hint: 'e.g. Sony A7III Camera',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  SkipItTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Tell us about the condition, accessories...',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  // Category and Condition
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCategory,
                                  dropdownColor: AppColors.surface,
                                  isExpanded: true,
                                  style: const TextStyle(color: AppColors.textPrimary),
                                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  onChanged: (v) => setState(() => _selectedCategory = v!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Condition', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCondition,
                                  dropdownColor: AppColors.surface,
                                  isExpanded: true,
                                  style: const TextStyle(color: AppColors.textPrimary),
                                  items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  onChanged: (v) => setState(() => _selectedCondition = v!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Pricing Section
                  const Text('Pricing (per day)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SkipItTextField(
                          controller: _priceController,
                          label: 'Price (₹)',
                          hint: '500',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SkipItTextField(
                          controller: _depositController,
                          label: 'Deposit (₹)',
                          hint: '2000',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Deposit is fully refunded upon safe return.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  
                  const SizedBox(height: 40),
                  SkipItButton(
                    label: 'Create Listing',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Full Screen Loading Blur
          if (_isLoading)
            Container(
              color: AppColors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 24),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
