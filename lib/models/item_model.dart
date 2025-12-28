class ItemModel {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String type;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String userId;
  final String? userName; // NEW: To store the finder's name
  final String status;
  final String? verificationQuestion;

  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.type,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.userId,
    this.userName, // NEW
    required this.status,
    this.verificationQuestion,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    // Check if profile data was joined in the query
    final profile = map['profiles'] as Map<String, dynamic>?;

    return ItemModel(
      id: map['id'].toString(),
      title: map['title'] ?? 'Untitled',
      description: map['description'] ?? '',
      imageUrl: map['image_url'],
      type: map['type'] ?? 'found',
      locationName: map['location_name'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      userId: map['user_id'] ?? '',
      userName: profile?['full_name'] ?? 'Unknown', // NEW: Extract joined name
      status: map['status'] ?? 'active',
      verificationQuestion: map['verification_question'],
    );
  }
}