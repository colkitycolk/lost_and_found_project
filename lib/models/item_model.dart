class ItemModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String type;
  final String userId;
  final String status; // <--- Add this

  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.type,
    required this.userId,
    required this.status, // <--- Add this
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'].toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      type: map['type'] ?? 'found',
      userId: map['user_id'] ?? '',
      status: map['status'] ?? 'active', // <--- Add this
    );
  }
}