import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/widgets/skipit_widgets.dart';
import 'package:skipit/features/bookings/data/bookings_provider.dart';
import 'package:skipit/features/bookings/data/bookings_repository.dart';
import 'package:skipit/features/bookings/domain/models/booking.dart';
import 'package:skipit/features/listings/data/listings_repository.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;
  String _processingMessage = 'Processing...';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'requested':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'paid':
        return Colors.purple;
      case 'active':
        return AppColors.success;
      case 'return_pending':
        return Colors.teal;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return AppColors.error;
      case 'disputed':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _handleAction(Future<void> Function() action, String message) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = message;
    });

    try {
      await action();
      ref.read(renterBookingsProvider.notifier).refresh();
      ref.read(ownerBookingsProvider.notifier).refresh();
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
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Renters simulated payment bottom sheet
  void _showSimulatedPaymentSheet(Booking booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.payment, color: AppColors.primary, size: 28),
                SizedBox(width: 12),
                Text('Secure Checkout', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Rental: ${booking.listing?.title ?? 'Product'}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Duration: ${DateFormat('MMM d').format(booking.startDate)} - ${DateFormat('MMM d').format(booking.endDate)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.background),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount Due', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                Text('₹${booking.totalPrice.toInt()}', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '(Includes ₹${booking.depositPaid.toInt()} fully refundable deposit)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 32),
            // Sleek simulated card indicators
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
              child: const Row(
                children: [
                  Icon(Icons.credit_card, color: AppColors.primary),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Simulated Payment Card', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('No real banking balance is charged.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SkipItButton(
              label: 'Pay ₹${booking.totalPrice.toInt()} & Confirm',
              onPressed: () {
                Navigator.pop(context);
                final randomPaymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}';
                final mockOrderId = 'order_mock_${DateTime.now().millisecondsSinceEpoch}';
                const mockSignature = 'mock_signature';
                _handleAction(() async {
                  await ref.read(bookingsRepositoryProvider).payBooking(
                    booking.id,
                    randomPaymentId,
                    mockOrderId,
                    mockSignature,
                  );
                }, 'Processing secure payment...');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Owners Handover OTP entry sheet
  void _showHandoverOtpSheet(Booking booking) {
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Text('Verify Handover OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Please ask the Renter to display the 6-digit Handover OTP shown on their screen, and enter it below to activate the booking.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              SkipItTextField(
                controller: otpController,
                label: 'Enter 6-Digit Handover OTP',
                hint: '123456',
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.length != 6) ? 'Must be a 6-digit code' : null,
              ),
              const SizedBox(height: 32),
              SkipItButton(
                label: 'Activate Rental Now',
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    _handleAction(() async {
                      await ref.read(bookingsRepositoryProvider).activateBooking(booking.id, otpController.text.trim());
                    }, 'Verifying handover OTP...');
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Renters Return Request sheet (with image uploading)
  void _showReturnRequestSheet(Booking booking) {
    XFile? returnImage;
    final damageController = TextEditingController();
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Icon(Icons.assignment_return_outlined, color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Text('Initiate Return', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Please upload a picture of the product to prove it is being returned in good condition.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setModalState(() => returnImage = picked);
                  }
                },
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    image: returnImage != null
                        ? DecorationImage(image: FileImage(File(returnImage!.path)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: returnImage == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 36),
                            SizedBox(height: 8),
                            Text('Upload Product Condition Picture', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              SkipItTextField(
                controller: damageController,
                label: 'Damage Claims / Notes (Optional)',
                hint: 'e.g. Scratched during use, or returned cleanly.',
              ),
              const SizedBox(height: 32),
              SkipItButton(
                label: 'Submit Return Request',
                onPressed: returnImage == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        _handleAction(() async {
                          // Upload return evidence image first
                          final url = await ref.read(listingsRepositoryProvider).uploadImage(
                                returnImage!.path,
                                'listing-images',
                                booking.renterId,
                              );
                          await ref.read(bookingsRepositoryProvider).requestReturn(
                                booking.id,
                                [url],
                                damageController.text.trim().isEmpty ? null : damageController.text.trim(),
                              );
                        }, 'Uploading return evidence...');
                      },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Owners return complete verification sheet
  void _showReturnCompleteSheet(Booking booking) {
    final deductionController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.success, size: 28),
                  SizedBox(width: 12),
                  Text('Verify Return & Complete', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Please verify the item has been returned safely. If there are any damages, specify a deduction from the renter\'s security deposit.', style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              SkipItTextField(
                controller: deductionController,
                label: 'Damage Deduction Fee (₹)',
                hint: '0',
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              SkipItButton(
                label: 'Complete Return & Refund Deposit',
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    final deduction = double.parse(deductionController.text.trim());
                    _handleAction(() async {
                      await ref.read(bookingsRepositoryProvider).completeReturn(booking.id, deduction);
                    }, 'Processing return completion...');
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renterBookingsAsync = ref.watch(renterBookingsProvider);
    final ownerBookingsAsync = ref.watch(ownerBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rental History & Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'My Rentals (Renter)', icon: Icon(Icons.shopping_bag_outlined)),
            Tab(text: 'Received Requests (Owner)', icon: Icon(Icons.handshake_outlined)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // RENTERS TAB
              renterBookingsAsync.when(
                data: (bookings) => RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref.read(renterBookingsProvider.notifier).refresh(),
                  child: bookings.isEmpty
                      ? _buildEmptyState('No rentals requested yet', 'Browse trending products nearby to place an order!')
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: bookings.length,
                          itemBuilder: (context, index) => _buildBookingCard(bookings[index], isRenterView: true),
                        ),
                ),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Center(child: Text('Error loading rentals: $err', style: const TextStyle(color: AppColors.error))),
              ),

              // OWNERS TAB
              ownerBookingsAsync.when(
                data: (bookings) => RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref.read(ownerBookingsProvider.notifier).refresh(),
                  child: bookings.isEmpty
                      ? _buildEmptyState('No rental requests received', 'Ensure your listings are published and verify your KYC.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: bookings.length,
                          itemBuilder: (context, index) => _buildBookingCard(bookings[index], isRenterView: false),
                        ),
                ),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Center(child: Text('Error loading requests: $err', style: const TextStyle(color: AppColors.error))),
              ),
            ],
          ),

          if (_isProcessing)
            Container(
              color: AppColors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 24),
                    Text(
                      _processingMessage,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, {required bool isRenterView}) {
    final statusColor = _getStatusColor(booking.status);
    final days = booking.endDate.difference(booking.startDate).inDays + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.black.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of card (status & title)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.listing?.title ?? 'Product Rental',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.background, height: 1),
          // Details section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow(Icons.calendar_today, 'Dates', '${DateFormat('MMM d, yyyy').format(booking.startDate)} - ${DateFormat('MMM d, yyyy').format(booking.endDate)} ($days days)'),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.currency_rupee, 'Total Price', '₹${booking.totalPrice.toInt()} (Deposit Paid: ₹${booking.depositPaid.toInt()})'),
                
                // If renter view and OTP code is available in active states, show Renter OTP code!
                if (isRenterView && booking.status == 'paid' && booking.otpCode != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Handover OTP Code:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        Text(
                          booking.otpCode!,
                          style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons based on status & role
                const SizedBox(height: 20),
                if (isRenterView) ...[
                  // RENTER ACTIONS
                  if (booking.status == 'approved')
                    SkipItButton(
                      label: 'Pay Now & Checkout',
                      onPressed: () => _showSimulatedPaymentSheet(booking),
                    ),
                  if (booking.status == 'active')
                    SkipItButton(
                      label: 'Request Return & Upload Pics',
                      onPressed: () => _showReturnRequestSheet(booking),
                    ),
                  if (booking.status == 'requested')
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _handleAction(() async {
                        await ref.read(bookingsRepositoryProvider).cancelBooking(booking.id, 'Renter cancelled request');
                      }, 'Cancelling booking request...'),
                      child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  if (booking.status == 'completed' && !booking.hasReviewBy(ref.read(authProvider).user?.id ?? ''))
                    SkipItButton(
                      label: 'Write a Review',
                      onPressed: () => _showReviewDialog(booking),
                    ),
                ] else ...[
                  // OWNER ACTIONS
                  if (booking.status == 'requested') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), minimumSize: const Size(0, 48)),
                            onPressed: () => _handleAction(() async {
                              await ref.read(bookingsRepositoryProvider).rejectBooking(booking.id);
                            }, 'Rejecting request...'),
                            child: const Text('Reject', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), minimumSize: const Size(0, 48)),
                            onPressed: () => _handleAction(() async {
                              await ref.read(bookingsRepositoryProvider).approveBooking(booking.id);
                            }, 'Approving request...'),
                            child: const Text('Approve', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (booking.status == 'paid')
                    SkipItButton(
                      label: 'Verify Handover OTP',
                      onPressed: () => _showHandoverOtpSheet(booking),
                    ),
                  if (booking.status == 'return_pending')
                    SkipItButton(
                      label: 'Verify Return Condition & Complete',
                      onPressed: () => _showReturnCompleteSheet(booking),
                    ),
                  if (booking.status == 'completed' && !booking.hasReviewBy(ref.read(authProvider).user?.id ?? ''))
                    SkipItButton(
                      label: 'Write a Review',
                      onPressed: () => _showReviewDialog(booking),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  void _showReviewDialog(Booking booking) {
    int selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Submit Review', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was your experience with this rental transaction?', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starRating = index + 1;
                  return IconButton(
                    icon: Icon(
                      selectedRating >= starRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = starRating;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Share your feedback (condition, timing, communication...)',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  fillColor: AppColors.background,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
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
              onPressed: () => _handleAction(() async {
                Navigator.pop(context);
                await ref.read(bookingsRepositoryProvider).submitReview(
                  bookingId: booking.id,
                  rating: selectedRating,
                  comment: commentController.text.trim(),
                );
              }, 'Submitting review...'),
              child: const Text('Submit', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
