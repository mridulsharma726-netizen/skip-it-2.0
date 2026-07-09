import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/widgets/skipit_widgets.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';
import 'package:skipit/features/profile/data/profile_provider.dart';
import 'package:skipit/features/profile/domain/models/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSaving = false;

  void _showEditProfileModal(UserProfile profile) {
    final nameController = TextEditingController(text: profile.fullName);
    final phoneController = TextEditingController(text: profile.phone ?? '');
    final bioController = TextEditingController(text: profile.bio ?? '');
    final locationController = TextEditingController(text: profile.location ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  SkipItTextField(
                    controller: nameController,
                    label: 'Full Name',
                    hint: 'e.g. John Doe',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  SkipItTextField(
                    controller: phoneController,
                    label: 'Phone Number',
                    hint: 'e.g. +91 98765 43210',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  SkipItTextField(
                    controller: locationController,
                    label: 'Location (City)',
                    hint: 'e.g. Mumbai, Maharashtra',
                  ),
                  const SizedBox(height: 16),
                  SkipItTextField(
                    controller: bioController,
                    label: 'Bio',
                    hint: 'Tell others about yourself...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  SkipItButton(
                    label: 'Save Changes',
                    isLoading: _isSaving,
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        setModalState(() => _isSaving = true);
                        try {
                          await ref.read(profileProvider.notifier).updateProfile(
                                fullName: nameController.text.trim(),
                                phone: phoneController.text.trim(),
                                bio: bioController.text.trim(),
                                location: locationController.text.trim(),
                              );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully!', style: TextStyle(color: AppColors.white)),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update: $e', style: const TextStyle(color: AppColors.white)),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } finally {
                          setModalState(() => _isSaving = false);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: profileAsync.when(
        data: (profile) {
          final fullName = profile.fullName;
          final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S';
          final verifiedKyc = profile.kycStatus == 'approved';

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => ref.read(profileProvider.notifier).refreshProfile(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Avatar & Name
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 4),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
                            ],
                            image: profile.avatarUrl != null
                                ? DecorationImage(image: NetworkImage(profile.avatarUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: profile.avatarUrl == null
                              ? Center(
                                  child: Text(initial, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showEditProfileModal(profile),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.surface, width: 2),
                              ),
                              child: const Icon(Icons.edit, size: 16, color: AppColors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      if (verifiedKyc) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: AppColors.primary, size: 24),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (profile.location != null && profile.location!.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(profile.location!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Trust Score Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield, color: AppColors.success, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Trust Score: ${profile.trustScore}',
                          style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Stats Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                Text('${profile.totalRentals}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                const Text('Rentals', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                Text('${profile.totalListings}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                const Text('Listings', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${profile.rating}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text('Rating', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Options List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        _buildOptionItem(
                          context,
                          icon: Icons.verified_user_outlined,
                          title: 'Trust & Verification',
                          subtitle: profile.kycStatus == 'approved'
                              ? 'Fully Verified'
                              : profile.kycStatus == 'pending'
                                  ? 'Verification Pending'
                                  : 'Upload KYC documents',
                          onTap: () => context.push('/kyc'),
                          iconColor: verifiedKyc ? AppColors.success : AppColors.textSecondary,
                        ),
                        _buildOptionItem(
                          context, 
                          icon: Icons.payment, 
                          title: 'Payment Methods', 
                          subtitle: 'Manage cards and payouts', 
                          onTap: () => context.push('/payment-methods'),
                        ),
                        _buildOptionItem(context, icon: Icons.favorite_border, title: 'Wishlist', subtitle: 'Your saved items', onTap: () => context.push('/wishlist')),
                        _buildOptionItem(
                          context, 
                          icon: Icons.chat_bubble_outline_rounded, 
                          title: 'Messages & Inbox', 
                          subtitle: 'Chat with rental listing owners', 
                          onTap: () => context.push('/inbox'),
                        ),
                        _buildOptionItem(context, icon: Icons.history, title: 'Rental History & Handovers', subtitle: 'Handovers, OTPs, Handoff Dashboard', onTap: () => context.push('/bookings')),
                        const SizedBox(height: 24),
                        const Text('Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        _buildOptionItem(context, icon: Icons.help_outline, title: 'Help Center', onTap: () => context.push('/help-center')),
                        _buildOptionItem(context, icon: Icons.shield_outlined, title: 'Safety Center', onTap: () => context.push('/safety-center')),
                        const SizedBox(height: 24),
                        _buildOptionItem(
                          context, 
                          icon: Icons.logout, 
                          title: 'Sign Out', 
                          titleColor: AppColors.error, 
                          iconColor: AppColors.error,
                          showArrow: false,
                          onTap: () {
                            ref.read(authProvider.notifier).signOut();
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('Error: $e', style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(profileProvider.notifier).refreshProfile(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem(BuildContext context, {required IconData icon, required String title, String? subtitle, required VoidCallback onTap, Color titleColor = AppColors.textPrimary, Color iconColor = AppColors.textSecondary, bool showArrow = true}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: titleColor)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            if (showArrow) const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
