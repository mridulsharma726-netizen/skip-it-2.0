import 'package:skipit/features/listings/domain/models/listing.dart';

class Booking {
  final String id;
  final String renterId;
  final String ownerId;
  final String listingId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final double depositPaid;
  final String status; // 'requested', 'approved', 'paid', 'active', 'return_pending', 'completed', 'cancelled', 'disputed'
  final String? otpCode;
  final DateTime? otpExpiresAt;
  final List<String> returnEvidenceUrls;
  final String? damageClaim;
  final double damageDeduction;
  final String? paymentId;
  final Listing? listing;
  final List<dynamic>? reviews;

  Booking({
    required this.id,
    required this.renterId,
    required this.ownerId,
    required this.listingId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.depositPaid,
    required this.status,
    this.otpCode,
    this.otpExpiresAt,
    required this.returnEvidenceUrls,
    this.damageClaim,
    required this.damageDeduction,
    this.paymentId,
    this.listing,
    this.reviews,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      renterId: json['renter_id'],
      ownerId: json['owner_id'] ?? '',
      listingId: json['listing_id'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      totalPrice: (json['total_price'] as num).toDouble(),
      depositPaid: (json['deposit_paid'] as num).toDouble(),
      status: json['status'] ?? 'requested',
      otpCode: json['otp_code'],
      otpExpiresAt: json['otp_expires_at'] != null ? DateTime.parse(json['otp_expires_at']) : null,
      returnEvidenceUrls: List<String>.from(json['return_evidence_urls'] ?? []),
      damageClaim: json['damage_claim'],
      damageDeduction: (json['damage_deduction'] as num?)?.toDouble() ?? 0.0,
      paymentId: json['payment_id'],
      listing: json['listing'] != null ? Listing.fromJson(json['listing']) : null,
      reviews: json['reviews'] as List<dynamic>?,
    );
  }

  bool hasReviewBy(String reviewerId) {
    if (reviews == null) return false;
    return reviews!.any((r) => r['reviewer_id'] == reviewerId);
  }
}
