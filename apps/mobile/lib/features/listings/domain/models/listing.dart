class Listing {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final double pricePerDay;
  final double depositAmount;
  final String category;
  final List<String> images;
  final double? locationLat;
  final double? locationLng;
  final String? locationName;
  final bool isAvailable;
  final DateTime createdAt;
  final ListingOwner? owner;

  Listing({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.pricePerDay,
    required this.depositAmount,
    required this.category,
    required this.images,
    this.locationLat,
    this.locationLng,
    this.locationName,
    required this.isAvailable,
    required this.createdAt,
    this.owner,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'],
      ownerId: json['owner_id'],
      title: json['title'],
      description: json['description'],
      pricePerDay: (json['price_per_day'] as num).toDouble(),
      depositAmount: (json['deposit_amount'] as num).toDouble(),
      category: json['category'],
      images: List<String>.from(json['images'] ?? []),
      locationLat: json['location_lat']?.toDouble(),
      locationLng: json['location_lng']?.toDouble(),
      locationName: json['location_name'],
      isAvailable: json['is_available'],
      createdAt: DateTime.parse(json['created_at']),
      owner: json['owner'] != null ? ListingOwner.fromJson(json['owner']) : null,
    );
  }
}

class ListingOwner {
  final String? fullName;
  final String? avatarUrl;
  final double? rating;

  ListingOwner({this.fullName, this.avatarUrl, this.rating});

  factory ListingOwner.fromJson(Map<String, dynamic> json) {
    return ListingOwner(
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      rating: json['rating']?.toDouble(),
    );
  }
}
