import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';

class SupabaseService {
  // Always use the global instance to keep the session active
  SupabaseClient get _client => Supabase.instance.client;

  // --- FETCH DATA ---
  Future<List<ItemModel>> getItems() async {
    try {
      final response = await _client
          .from('items')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List).map((item) => ItemModel.fromMap(item)).toList();
    } catch (e) {
      print("Fetch Error: $e");
      rethrow;
    }
  }

  // --- UPLOAD & REPORT ---
  Future<void> addItem({
    required String title,
    required String description,
    required File imageFile,
    required String type, 
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Fix: Using 'item-images' with the dash
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '${user.id}/$fileName';
    
    await _client.storage.from('item-images').upload(path, imageFile);
    final imageUrl = _client.storage.from('item-images').getPublicUrl(path);

    await _client.from('items').insert({
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'user_id': user.id,
      'type': type,
    });
  }

  // --- MATCHING ALGORITHM ---
  Future<List<ItemModel>> findMatches(String title, String currentType) async {
    String searchType = (currentType == 'lost') ? 'found' : 'lost';
    String keyword = title.split(' ')[0];
    
    final response = await _client
        .from('items')
        .select()
        .eq('type', searchType)
        .ilike('title', '%$keyword%')
        .neq('user_id', _client.auth.currentUser?.id ?? ''); 

    return (response as List).map((item) => ItemModel.fromMap(item)).toList();
  }

  // --- AUTH ---
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }
}