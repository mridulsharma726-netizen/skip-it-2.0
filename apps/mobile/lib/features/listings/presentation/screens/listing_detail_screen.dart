import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/widgets/skipit_widgets.dart';
import 'package:skipit/features/bookings/data/bookings_repository.dart';
import 'package:skipit/features/bookings/data/bookings_provider.dart';
import 'package:skipit/features/bookings/domain/models/booking.dart';
import 'package:skipit/features/listings/domain/models/listing.dart';
import 'package:skipit/features/chat/presentation/screens/chat_screen.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final Listing listing;

  const ListingDetailScreen({super.key, required this.listing});

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  DateTimeRange? _selectedDateRange;
  bool _isBooking = false;
  int _currentImageIndex = 0;

  Future<void> _selectDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  double get _calculateTotalPrice {
    if (_selectedDateRange == null) return 0;
    final days = _selectedDateRange!.duration.inDays + 1;
    return (days * widget.listing.pricePerDay) + widget.listing.depositAmount;
  }

  Future<void> _confirmBooking([void Function(void Function())? setModalState]) async {
    if (_selectedDateRange == null) return;

    if (setModalState != null) {
      setModalState(() => _isBooking = true);
    }
    setState(() => _isBooking = true);
    try {
      final booking = await ref.read(bookingsRepositoryProvider).createBooking(
            listingId: widget.listing.id,
            startDate: _selectedDateRange!.start,
            endDate: _selectedDateRange!.end,
            totalPrice: _calculateTotalPrice,
            depositPaid: widget.listing.depositAmount,
          );

      ref.read(renterBookingsProvider.notifier).refresh();

      if (mounted) {
        Navigator.pop(context); // Close dates modal
        _showPaymentCheckoutSheet(context, booking); // Show payment sheet immediately!
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: const TextStyle(color: AppColors.white)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (setModalState != null) {
        setModalState(() => _isBooking = false);
      }
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showPaymentCheckoutSheet(BuildContext context, Booking booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'RAZORPAY SECURE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.security, color: AppColors.success, size: 20),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Rent: ${widget.listing.title}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Period: ${DateFormat('MMM d').format(booking.startDate)} - ${DateFormat('MMM d').format(booking.endDate)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.background),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Price', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                  Text('₹${booking.totalPrice.toInt()}', style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '(Includes ₹${booking.depositPaid.toInt()} refundable deposit)',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  children: [
                    Icon(Icons.credit_card, color: AppColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Razorpay Simulation Gateway', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Direct Sandbox payment processed securely.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SkipItButton(
                label: 'Pay via Razorpay',
                onPressed: () {
                  Navigator.pop(context);
                  final paymentId = 'pay_rzp_${DateTime.now().millisecondsSinceEpoch}';
                  
                  // Show processing dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppColors.primary),
                              SizedBox(height: 24),
                              Text('Processing payment with Razorpay...', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  Future.delayed(const Duration(seconds: 2), () async {
                    try {
                      await ref.read(bookingsRepositoryProvider).payBooking(booking.id, paymentId);
                      ref.read(renterBookingsProvider.notifier).refresh();
                      
                      if (context.mounted) {
                        Navigator.pop(context); // Close processing dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment processed successfully via Razorpay!', style: TextStyle(color: AppColors.white)),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        // Redirect to bookings list
                        context.go('/bookings');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Close processing dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to complete payment: $e', style: const TextStyle(color: AppColors.white)),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  });
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.listing.images.isNotEmpty
                      ? PageView.builder(
                          itemCount: widget.listing.images.length,
                          onPageChanged: (index) => setState(() => _currentImageIndex = index),
                          itemBuilder: (context, index) {
                            return Image.network(widget.listing.images[index], fit: BoxFit.cover);
                          },
                        )
                      : Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.image_outlined, size: 80, color: AppColors.textSecondary),
                        ),
                  // Gradient Overlay for AppBar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Image Counter Indicator
                  if (widget.listing.images.length > 1)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1} / ${widget.listing.images.length}',
                          style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: AppColors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: AppColors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.favorite_border, color: AppColors.white),
                    onPressed: () {},
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: AppColors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.share, color: AppColors.white),
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Basic Info
                  Text(widget.listing.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text('${widget.listing.owner?.rating?.toString() ?? '5.0'} (12 reviews)', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                      const SizedBox(width: 16),
                      const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 4),
                      Text(widget.listing.locationName ?? 'Nearby', style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.surface),
                  const SizedBox(height: 24),
                  
                  // Owner Profile Section
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          image: widget.listing.owner?.avatarUrl != null
                              ? DecorationImage(image: NetworkImage(widget.listing.owner!.avatarUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: widget.listing.owner?.avatarUrl == null
                            ? const Icon(Icons.person, color: AppColors.textSecondary, size: 30)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Listed by ${widget.listing.owner?.fullName ?? 'Renter'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            const Text('Joined 2026 \u2022 Super Renter', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified, color: AppColors.primary, size: 32),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 28),
                        onPressed: () {
                          final myUserId = ref.read(authProvider).user?.id;
                          if (widget.listing.ownerId == myUserId) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('You cannot chat with yourself!', style: TextStyle(color: AppColors.white)),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                otherUserId: widget.listing.ownerId,
                                otherUserName: widget.listing.owner?.fullName ?? 'Owner',
                                otherUserAvatar: widget.listing.owner?.avatarUrl,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.surface),
                  const SizedBox(height: 24),

                  // Description
                  const Text('Description', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Text(
                    widget.listing.description,
                    style: TextStyle(fontSize: 16, color: AppColors.textPrimary.withValues(alpha: 0.8), height: 1.6),
                  ),
                  const SizedBox(height: 32),

                  // Map Placeholder
                  const Text('Location', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.surface),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 48, color: AppColors.textSecondary),
                          SizedBox(height: 8),
                          Text('Exact location provided after booking', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 140), // Spacing for bottom sheet
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.surface)),
          boxShadow: [
            BoxShadow(color: AppColors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Price per day', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '₹${widget.listing.pricePerDay.toInt()}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: SkipItButton(
                label: 'Rent Now',
                onPressed: () => _showBookingModal(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
              const Text('Select Dates', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  await _selectDates();
                  setModalState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppColors.primary),
                      const SizedBox(width: 16),
                      Text(
                        _selectedDateRange == null
                            ? 'Select rental period'
                            : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 16),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit, size: 20, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.surface),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Price', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(
                    '₹${_calculateTotalPrice.toInt()}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '(Includes ₹${widget.listing.depositAmount.toInt()} refundable deposit)',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              SkipItButton(
                label: 'Confirm Rental Request',
                isLoading: _isBooking,
                onPressed: () {
                  if (_selectedDateRange == null) {
                    _selectDates().then((_) => setModalState(() {}));
                  } else {
                    _confirmBooking(setModalState);
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
}
