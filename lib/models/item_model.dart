class ItemModel {
  final String id;
  final String title;
  final String description;
  final String? imageUrl; // CHANGED: Made nullable
  final String type; // 'lost' or 'found'
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String userId;
  final String status;
  final String? verificationQuestion;

  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl, // CHANGED: No longer required
    required this.type,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.userId,
    required this.status,
    this.verificationQuestion,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'].toString(),
      title: map['title'] ?? 'Untitled',
      description: map['description'] ?? '',
      // If image_url is null in DB, it becomes null in our app
      imageUrl: map['image_url'], 
      type: map['type'] ?? 'found',
      locationName: map['location_name'],
      // Safe conversion for numeric types
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      userId: map['user_id'] ?? '',
      status: map['status'] ?? 'active',
      verificationQuestion: map['verification_question'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Added ID for completeness
      'title': title,
      'description': description,
      'image_url': imageUrl, 
      'type': type,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'user_id': userId,
      'status': status,
      'verification_question': verificationQuestion,
    };
  }
}