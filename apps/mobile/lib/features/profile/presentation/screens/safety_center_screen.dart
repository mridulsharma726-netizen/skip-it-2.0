import 'package:flutter/material.dart';
import 'package:skipit/core/theme/app_colors.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Safety & Trust Center', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shield trust illustration banner
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.success,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Safety is Our Priority',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'SkipIt is built on community trust, secure checkouts, and rigorous verification guidelines.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Section: Core pillars
            const Text('Our 4 Pillars of Safety', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _buildPillarRow(
              icon: Icons.fingerprint,
              title: 'Verified Users only',
              subtitle: 'Every listing owner and renter completes secure government-issued KYC document verification before transacting.',
            ),
            _buildPillarRow(
              icon: Icons.payments_outlined,
              title: 'Secure Escrow Payments',
              subtitle: 'Rentals and security deposits are held in a secure escrow vault. Funds are only released when handover matches.',
            ),
            _buildPillarRow(
              icon: Icons.vpn_key_outlined,
              title: 'OTP Handover Codes',
              subtitle: 'No item changes hands without an active OTP validation check on the owner\'s smartphone device.',
            ),
            _buildPillarRow(
              icon: Icons.support_agent_outlined,
              title: '24/7 Dispute Support',
              subtitle: 'Damage claims are handled fairly by our local SkipIt mediation panel, backed by visual return photo evidence.',
            ),

            const SizedBox(height: 32),

            // Section: Checklists
            const Text('Smart Handover Checklist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            const Text('Follow these guidelines to ensure zero disputes:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            _buildChecklistItem('Verify current condition together at handover.'),
            _buildChecklistItem('Take clear pictures before starting and uploading them.'),
            _buildChecklistItem('Test powers, gears, cords, or screens in person.'),
            _buildChecklistItem('Confirm return times and location address clearly.'),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarRow({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
