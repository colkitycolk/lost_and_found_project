import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import 'package:geolocator/geolocator.dart';

class SupabaseService {
  // Always use the global instance to keep the session active
  SupabaseClient get _client => Supabase.instance.client;

  // --- FETCH DATA ---
  Future<List<ItemModel>> getItems({String status = 'active'}) async {
    try {
      final response = await _client
          .from('items')
          .select()
          .eq('status', status) // Filter based on the passed status
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
    String? locationName,
    double? lat,
    double? lng,
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
      'location_name': locationName,
      'latitude': lat,
      'longitude': lng,
    });
  }

  // NEW: Getter for current user
  User? get currentUser => _client.auth.currentUser;

  // --- DELETE ITEM ---
  Future<void> deleteItem(ItemModel item) async {
    // 1. Extract the filename from the URL to delete from storage
    // The path is usually: userId/filename.jpg
    final uri = Uri.parse(item.imageUrl);
    final pathSegments = uri.pathSegments;
    // This takes the last two segments (userId and filename)
    final storagePath =
        "${pathSegments[pathSegments.length - 2]}/${pathSegments.last}";

    // 2. Delete from Storage
    await _client.storage.from('item-images').remove([storagePath]);

    // 3. Delete from Database
    await _client.from('items').delete().eq('id', item.id);
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
    String keyword = title.split(' ')[0];

    var query = _client
        .from('items')
        .select()
        .eq('type', searchType)
        .ilike('title', '%$keyword%')
        .neq('user_id', _client.auth.currentUser?.id ?? '');

    // If a location is provided, filter by it too!
    if (location != null && location.isNotEmpty) {
      query = query.ilike('location_name', '%$location%');
    }

    final response = await query;
    return (response as List).map((item) => ItemModel.fromMap(item)).toList();
  }

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    // 2. Handle permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    // 3. Get coordinates
    return await Geolocator.getCurrentPosition();
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
