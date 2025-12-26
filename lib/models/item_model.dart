class ItemModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String type; // 'lost' or 'found'
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String userId;
  final String status;
  final String? verificationQuestion; // NEW FIELD

  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.type,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.userId,
    required this.status,
    this.verificationQuestion, // NEW FIELD
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'].toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      type: map['type'] ?? 'found',
      locationName: map['location_name'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      userId: map['user_id'] ?? '',
      status: map['status'] ?? 'active',
      verificationQuestion: map['verification_question'], // NEW FIELD
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'type': type,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'user_id': userId,
      'status': status,
      'verification_question': verificationQuestion, // NEW FIELD
    };
  }
}