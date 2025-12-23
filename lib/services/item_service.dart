import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ItemService {
  final _supabase = Supabase.instance.client;

  Future<void> uploadItem({
    required File imageFile,
    required String description,
    required String type, 
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw 'Authentication required';

    // 1. Upload Image to 'item-images' bucket
    final fileExt = imageFile.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = '${user.id}/$fileName';

    await _supabase.storage.from('item-images').upload(path, imageFile);

    // 2. Get Public URL
    final imageUrl = _supabase.storage.from('item-images').getPublicUrl(path);

    // 3. Insert into Database
    await _supabase.from('items').insert({
      'user_id': user.id,
      'title': type == 'lost' ? 'Lost Item' : 'Found Item',
      'description': description,
      'image_url': imageUrl,
      'type': type,
    });
  }
}