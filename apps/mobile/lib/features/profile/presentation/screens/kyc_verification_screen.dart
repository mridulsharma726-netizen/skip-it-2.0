import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/widgets/skipit_widgets.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';
import 'package:skipit/features/listings/data/listings_repository.dart';
import 'package:skipit/features/profile/data/profile_repository.dart';
import 'package:skipit/features/profile/data/profile_provider.dart';

class KYCVerificationScreen extends ConsumerStatefulWidget {
  const KYCVerificationScreen({super.key});

  @override
  ConsumerState<KYCVerificationScreen> createState() => _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends ConsumerState<KYCVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _documentImage;
  bool _isLoading = false;
  String _selectedDocumentType = 'Aadhaar Card';
  String _loadingMessage = 'Submitting...';

  final List<String> _documentTypes = ['Aadhaar Card', 'Driving License', 'Passport', 'Voter ID'];

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _documentImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e', style: const TextStyle(color: AppColors.white)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _submitDocument() async {
    if (_documentImage == null) return;
    
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Uploading document image...';
    });
    
    try {
      final userId = ref.read(authProvider).user?.id ?? 'anonymous';
      
      // 1. Upload to Supabase Storage private KYC bucket
      final documentUrl = await ref.read(listingsRepositoryProvider).uploadImage(
            _documentImage!.path,
            'kyc-documents',
            userId,
          );

      setState(() {
        _loadingMessage = 'Submitting verification request...';
      });

      // 2. Submit document details to backend KYC API
      await ref.read(profileRepositoryProvider).submitKYC(
            documentType: _selectedDocumentType,
            documentUrl: documentUrl,
          );

      // 3. Refresh user profile to immediately show "pending" KYC status in UI
      ref.read(profileProvider.notifier).refreshProfile();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC Document submitted successfully! Verification usually takes 2-4 hours.', style: TextStyle(color: AppColors.white)),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e', style: const TextStyle(color: AppColors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trust & Verification', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(Icons.security, size: 64, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Become a Verified Renter',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Verified renters get 3x more bookings and access to premium rentals. Upload your ID to get the verification badge.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
                const SizedBox(height: 40),
                
                const Text('Document Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDocumentType,
                      dropdownColor: AppColors.surface,
                      isExpanded: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      items: _documentTypes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedDocumentType = v!),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                const Text('Upload Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2, style: BorderStyle.solid),
                      image: _documentImage != null
                          ? DecorationImage(image: FileImage(File(_documentImage!.path)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _documentImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary),
                              SizedBox(height: 12),
                              Text('Tap to upload image', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('JPG, PNG up to 5MB', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: AppColors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Icon(Icons.check_circle, color: AppColors.white, size: 48),
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 40),
                SkipItButton(
                  label: 'Submit for Verification',
                  isLoading: _isLoading,
                  onPressed: _documentImage == null ? null : _submitDocument,
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Your data is securely encrypted and never shared with third parties.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
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
