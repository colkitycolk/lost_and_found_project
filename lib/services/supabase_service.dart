import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import 'package:geolocator/geolocator.dart';

class SupabaseService {
  // Always use the global instance to keep the session active
  SupabaseClient get _client => Supabase.instance.client;

  // Getter for current user
  User? get currentUser => _client.auth.currentUser;

  // --- FETCH DATA ---
  Future<List<ItemModel>> getItems({String status = 'active'}) async {
    try {
      final response = await _client
          .from('items')
          .select()
          .eq('status', status)
          .order('created_at', ascending: false);

      return (response as List).map((item) => ItemModel.fromMap(item)).toList();
    } catch (e) {
      print("Fetch Error: $e");
      rethrow;
    }
  }

  // --- UPLOAD & REPORT ---
  // FIXED: Added verificationQuestion to the parameters
  Future<void> addItem({
    required String title,
    required String description,
    required File imageFile,
    required String type,
    String? locationName,
    double? lat,
    double? lng,
    String? verificationQuestion, // NEW PARAMETER
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    try {
      // 1. Storage Upload
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${user.id}/$fileName';

      await _client.storage.from('item-images').upload(path, imageFile);
      final imageUrl = _client.storage.from('item-images').getPublicUrl(path);

      // 2. Database Insert
      await _client.from('items').insert({
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'user_id': user.id,
        'type': type,
        'location_name': locationName,
        'latitude': lat,
        'longitude': lng,
        'status': 'active',
        'verification_question': verificationQuestion, // SAVING TO DB
      });
    } catch (e) {
      print("Add Item Error: $e");
      rethrow;
    }
  }

  // --- DELETE ITEM ---
  Future<void> deleteItem(ItemModel item) async {
    try {
      // Extract storage path: userId/filename.jpg
      final uri = Uri.parse(item.imageUrl);
      final pathSegments = uri.pathSegments;

      // Safety check for URL parsing
      if (pathSegments.length >= 2) {
        final storagePath =
            "${pathSegments[pathSegments.length - 2]}/${pathSegments.last}";
        await _client.storage.from('item-images').remove([storagePath]);
      }

      await _client.from('items').delete().eq('id', item.id);
    } catch (e) {
      print("Delete Error: $e");
      rethrow;
    }
  }

  Future<void> updateItemStatus(String itemId, String newStatus) async {
    await _client.from('items').update({'status': newStatus}).eq('id', itemId);
  }

  // --- MATCHING ALGORITHM ---
  Future<List<ItemModel>> findMatches(
    String title,
    String currentType,
    String? location,
  ) async {
    String searchType = (currentType == 'lost') ? 'found' : 'lost';

    // Take the first word of the title for a broader search
    String keyword = title.split(' ')[0];

    var query = _client
        .from('items')
        .select()
        .eq('type', searchType)
        .eq('status', 'active') // Only match against active items
        .ilike('title', '%$keyword%')
        .neq('user_id', _client.auth.currentUser?.id ?? '');

    if (location != null && location.isNotEmpty) {
      query = query.ilike('location_name', '%$location%');
    }

    final response = await query;
    return (response as List).map((item) => ItemModel.fromMap(item)).toList();
  }

  // --- LOCATION SERVICES ---
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  // --- USER STATS ---
  Future<Map<String, int>> getUserStats() async {
    final userId = currentUser?.id;
    if (userId == null) return {'active': 0, 'resolved': 0};

    final response = await _client
        .from('items')
        .select('status')
        .eq('user_id', userId);

    final items = response as List;
    int active = items.where((i) => i['status'] == 'active').length;
    int resolved = items.where((i) => i['status'] == 'resolved').length;

    return {'active': active, 'resolved': resolved};
  }

  // --- SIGN OUT ---
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // --- FETCH MY ITEMS ---
  Future<List<ItemModel>> getMyItems() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('items')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((item) => ItemModel.fromMap(item)).toList();
  }

  // --- AUTH ---
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }
}
