import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import 'package:geolocator/geolocator.dart';

class SupabaseService {
  // Always use the global instance to keep the session active
  SupabaseClient get _client => Supabase.instance.client;

  // Getter for current user
  User? get currentUser => _client.auth.currentUser;

  SupabaseClient get instance => _client;

  // --- FETCH DATA ---
  Future<List<ItemModel>> getItems({String status = 'active'}) async {
    try {
      final response = await _client
          .from('items')
          .select('*, profiles(full_name)') // FIX: Joins profiles table
          .eq('status', status)
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
    required String type,
    File? imageFile,
    String? locationName,
    double? lat,
    double? lng,
    String? verificationQuestion,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    try {
      String? imageUrl;

      if (imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = '${user.id}/$fileName';

        await _client.storage.from('item-images').upload(path, imageFile);
        imageUrl = _client.storage.from('item-images').getPublicUrl(path);
      }

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
        'verification_question': verificationQuestion,
      });
    } catch (e) {
      print("Add Item Error: $e");
      rethrow;
    }
  }

  // --- DELETE ITEM ---
  Future<void> deleteItem(ItemModel item) async {
    try {
      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
        final uri = Uri.parse(item.imageUrl!);
        final pathSegments = uri.pathSegments;

        if (pathSegments.length >= 2) {
          final storagePath =
              "${pathSegments[pathSegments.length - 2]}/${pathSegments.last}";
          await _client.storage.from('item-images').remove([storagePath]);
        }
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
    String keyword = title.split(' ')[0];

    var query = _client
        .from('items')
        .select('*, profiles(full_name)') // FIX: Joins profiles table
        .eq('type', searchType)
        .eq('status', 'active')
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
        .select('*, profiles(full_name)') // FIX: Joins profiles table
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((item) => ItemModel.fromMap(item)).toList();
  }

  // Stream for real-time messages
  Stream<List<Map<String, dynamic>>> getChatStream(
    String itemId,
    String otherUserId,
  ) {
    final myId = _client.auth.currentUser!.id;

    // We let the database handle the heavy lifting.
    // This stream only listens for messages belonging to this specific item.
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('item_id', itemId)
        .order('created_at', ascending: false)
        .map((data) {
          // Now we only filter for the two participants
          return data.where((msg) {
            final s = msg['sender_id'];
            final r = msg['receiver_id'];
            return (s == myId && r == otherUserId) ||
                (s == otherUserId && r == myId);
          }).toList();
        });
  }

  Future<List<Map<String, dynamic>>> getChatMessages(
    String itemId,
    String otherUserId,
  ) async {
    final myId = _client.auth.currentUser!.id;

    final response = await _client
        .from('messages')
        .select()
        .eq('item_id', itemId)
        .or(
          'and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)',
        )
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Send a message
  Future<void> sendMessage(
    String itemId,
    String receiverId,
    String text,
  ) async {
    await _client.from('messages').insert({
      'item_id': itemId,
      'receiver_id': receiverId,
      'sender_id': _client.auth.currentUser!.id,
      'text': text,
    });
  }

  Future<List<Map<String, dynamic>>> getMyConversations() async {
    final userId = _client.auth.currentUser!.id;

    final response = await _client
        .from('messages')
        .select('*, items(title, image_url)')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    final Map<String, Map<String, dynamic>> latestChats = {};

    for (var msg in data) {
      final String otherId = msg['sender_id'] == userId
          ? msg['receiver_id']
          : msg['sender_id'];
      final String chatKey = "${msg['item_id']}_$otherId";

      if (!latestChats.containsKey(chatKey)) {
        latestChats[chatKey] = msg;
      }
    }
    return latestChats.values.toList();
  }

  // --- FETCH ITEM BY ID ---
  Future<ItemModel?> getItemById(String id) async {
    final data = await _client
        .from('items')
        .select('*, profiles(full_name)') // FIX: Joins profiles table
        .eq('id', id)
        .single();
    return ItemModel.fromMap(data);
  }

  // --- BLOCKING LOGIC ---
  Future<void> blockUser(String targetUserId) async {
    final myId = currentUser?.id;
    if (myId == null) return;

    await _client.from('blocks').insert({
      'blocker_id': myId,
      'blocked_id': targetUserId,
    });
  }

  Future<bool> isUserBlocked(String otherUserId) async {
    final myId = currentUser?.id;
    if (myId == null) return false;

    final response = await _client
        .from('blocks')
        .select()
        .or(
          'and(blocker_id.eq.$myId,blocked_id.eq.$otherUserId),and(blocker_id.eq.$otherUserId,blocked_id.eq.$myId)',
        );

    return (response as List).isNotEmpty;
  }

  // --- VERIFY CLAIMANT ---
  Future<void> verifyClaimant(String itemId, String claimantId) async {
    await _client.from('items').update({'status': 'resolved'}).eq('id', itemId);

    await sendMessage(
      itemId,
      claimantId,
      "✅ The finder has verified your claim! This item is now resolved.",
    );
  }

  Future<void> unblockUser(String targetUserId) async {
    final myId = currentUser?.id;
    if (myId == null) return;

    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', myId)
        .eq('blocked_id', targetUserId);
  }

  // --- AUTH ---
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(
    String email,
    String password,
    String name,
  ) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name}, // Passes name for the trigger
    );
  }
}
