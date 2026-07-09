class UserProfile {
  final String id;
  final String fullName;
  final String? phone;
  final String? bio;
  final String? location;
  final String role;
  final String kycStatus;
  final String? kycDocumentType;
  final String? kycDocumentUrl;
  final int trustScore;
  final bool isVerified;
  final bool isBanned;
  final int totalRentals;
  final int totalListings;
  final double rating;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.fullName,
    this.phone,
    this.bio,
    this.location,
    required this.role,
    required this.kycStatus,
    this.kycDocumentType,
    this.kycDocumentUrl,
    required this.trustScore,
    required this.isVerified,
    required this.isBanned,
    required this.totalRentals,
    required this.totalListings,
    required this.rating,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      phone: json['phone'],
      bio: json['bio'],
      location: json['location'],
      role: json['role'] ?? 'user',
      kycStatus: json['kyc_status'] ?? 'none',
      kycDocumentType: json['kyc_document_type'],
      kycDocumentUrl: json['kyc_document_url'],
      trustScore: json['trust_score'] ?? 50,
      isVerified: json['is_verified'] ?? false,
      isBanned: json['is_banned'] ?? false,
      totalRentals: json['total_rentals'] ?? 0,
      totalListings: json['total_listings'] ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      avatarUrl: json['avatar_url'],
    );
  }
}
