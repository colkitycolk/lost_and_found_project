class ItemModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String type;
  final String userId;
  final String status;
  final String? locationName; // New
  final double? latitude;    // New
  final double? longitude;   // New

  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.type,
    required this.userId,
    required this.status,
    this.locationName,
    this.latitude,
    this.longitude,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'].toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      type: map['type'] ?? 'found',
      userId: map['user_id'] ?? '',
      status: map['status'] ?? 'active',
      locationName: map['location_name'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }
}