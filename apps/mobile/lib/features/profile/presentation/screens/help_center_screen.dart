import 'package:flutter/material.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/widgets/skipit_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skipit/core/config/app_config.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<Map<String, dynamic>> _faqs = [
    {
      'question': 'How do I list an item for rent?',
      'answer': 'Tap on the "List Item" (+) icon in the main navigation. Fill in details like title, description, category, and daily rental price. Ensure you upload clear, high-quality images and specify the security deposit before submitting.',
      'category': 'Listings',
    },
    {
      'question': 'How does the security deposit work?',
      'answer': 'To protect owners, renters pay a refundable security deposit at checkout. Once the item is returned safely and the owner confirms its condition, the entire deposit is instantly refunded back to the renter\'s payment method.',
      'category': 'Payments',
    },
    {
      'question': 'What if the renter damages my item?',
      'answer': 'When confirming the return, you can declare damage claims and specify a deduction fee from the security deposit. If both parties agree, the deduction goes to the owner, and the rest is refunded. If disputed, our support team steps in to review evidence.',
      'category': 'Trust',
    },
    {
      'question': 'How is handover verified?',
      'answer': ' Handover is verified using a secure 6-digit OTP code. When the renter picks up the item, they will see a code on their screen. The owner must enter this code on their app to activate the rental booking.',
      'category': 'Renting',
    },
    {
      'question': 'Can I cancel a booking?',
      'answer': 'Yes, bookings can be cancelled at any time before handover. If cancelled, a full refund (including the daily rent and security deposit) is instantly credited back to the renter.',
      'category': 'Renting',
    },
    {
      'question': 'What forms of payment do you accept?',
      'answer': 'We support major payment gateways including Credit/Debit cards, Net Banking, UPI (GPay, PhonePe, Paytm), and popular mobile wallets through our secure checkout terminal.',
      'category': 'Payments',
    }
  ];

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _faqs.where((faq) {
      final matchesSearch = faq['question'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['answer'].toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || faq['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help Center', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // Header Search Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search topics, questions...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Categories chips list
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: ['All', 'Listings', 'Renting', 'Payments', 'Trust'].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // FAQs Expandable list
          Expanded(
            child: filteredFaqs.isEmpty
                ? _buildNoResults()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filteredFaqs.length,
                    itemBuilder: (context, index) {
                      final faq = filteredFaqs[index];
                      return _buildFaqItem(faq);
                    },
                  ),
          ),

          // Footer Contact Support Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Still need help?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text('Reach out to our support channels and we will respond instantly.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildContactButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'Live Chat',
                        onTap: () async {
                          final Uri url = Uri.parse('https://wa.me/${AppConfig.supportPhoneNumber.replaceAll('+', '')}');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not launch WhatsApp support chat for ${AppConfig.supportPhoneNumber}', style: const TextStyle(color: AppColors.white)), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildContactButton(
                        icon: Icons.phone_in_talk_outlined,
                        label: 'Call Us',
                        onTap: () async {
                          final Uri url = Uri.parse('tel:${AppConfig.supportPhoneNumber}');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not launch dialer for ${AppConfig.supportPhoneNumber}', style: const TextStyle(color: AppColors.white)), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFaqItem(Map<String, dynamic> faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            faq['question'],
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                faq['answer'],
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No results found', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Try modifying your query or category filters.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
