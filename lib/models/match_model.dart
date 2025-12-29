import 'item_model.dart';

class MatchModel {
  final String id;
  final double similarityScore;
  final ItemModel matchedItem; // The "other" item details

  MatchModel({
    required this.id,
    required this.similarityScore,
    required this.matchedItem,
  });

  factory MatchModel.fromMap(Map<String, dynamic> map, String currentUserId) {
    // Determine which side of the match is the 'other' person
    // If the lost_item belongs to us, we want to show the found_item, and vice versa.
    final bool isLostItemOurs = map['lost_item']['user_id'] == currentUserId;
    final itemData = isLostItemOurs ? map['found_item'] : map['lost_item'];

    return MatchModel(
      id: map['id'].toString(),
      similarityScore: (map['similarity_score'] as num).toDouble(),
      matchedItem: ItemModel.fromMap(itemData),
    );
  }
}