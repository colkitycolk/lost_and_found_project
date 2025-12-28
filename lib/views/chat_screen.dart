import 'dart:async'; // Required for Timer
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/item_model.dart';

class ChatScreen extends StatefulWidget {
  final String itemId;
  final String receiverId;
  final String itemTitle;

  const ChatScreen({
    super.key,
    required this.itemId,
    required this.receiverId,
    required this.itemTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _service = SupabaseService();
  final _scrollController = ScrollController();

  // Polling Variables
  Timer? _pollingTimer;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingMessages = true;

  bool _isBlocked = false;
  bool _iAmTheBlocker = false;
  ItemModel? _item;
  bool _isOwner = false;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startPolling(); // Start the auto-refresh loop
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // CRITICAL: Stop the timer when leaving
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Loads static data (item details, block status) once
  Future<void> _loadInitialData() async {
    await _checkBlockStatus();
    final item = await _service.getItemById(widget.itemId);
    if (mounted && item != null) {
      setState(() {
        _item = item;
        _isOwner = item.userId == _service.currentUser?.id;
      });
    }
  }

  /// Starts a timer that fetches new messages every 3 seconds
  void _startPolling() {
    _fetchMessages(); // First fetch immediately
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchMessages();
    });
  }

  /// Replaces the StreamBuilder logic with a standard Future fetch
  Future<void> _fetchMessages() async {
    try {
      // Note: Make sure you added the getChatMessages method to your service
      final msgs = await _service.getChatMessages(widget.itemId, widget.receiverId);
      
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoadingMessages = false;
        });
      }
    } catch (e) {
      debugPrint("Polling Error: $e");
    }
  }

  Future<void> _checkBlockStatus() async {
    final myId = _service.currentUser?.id;
    if (myId == null) return;
    final blocked = await _service.isUserBlocked(widget.receiverId);

    final response = await _service.instance
        .from('blocks')
        .select()
        .eq('blocker_id', myId)
        .eq('blocked_id', widget.receiverId);

    if (mounted) {
      setState(() {
        _isBlocked = blocked;
        _iAmTheBlocker = (response as List).isNotEmpty;
      });
    }
  }

  // --- ACTIONS ---

  void _confirmResolve() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verify & Resolve?"),
        content: const Text("This will mark the item as found/returned."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: _isResolving ? null : () => _handleResolve(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Confirm & Notify", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResolve() async {
    setState(() => _isResolving = true);
    try {
      await _service.sendMessage(
        widget.itemId,
        widget.receiverId,
        "✅ ITEM VERIFIED: The finder has confirmed your claim. The item is now officially marked as resolved.",
      );
      await _service.updateItemStatus(widget.itemId, 'resolved');

      if (mounted) {
        Navigator.pop(context);
        _loadInitialData();
        _fetchMessages(); // Refresh immediately after resolution
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final myId = _service.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.itemTitle, style: const TextStyle(fontSize: 16)),
            Text(
              _item?.status == 'resolved' ? "Resolved" : "Active Chat",
              style: TextStyle(
                fontSize: 12,
                color: _item?.status == 'resolved' ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          if (_isOwner && _item?.status == 'active')
            IconButton(
              onPressed: _confirmResolve,
              icon: const Icon(Icons.verified, color: Colors.green),
            ),
          PopupMenuButton<String>(
            onSelected: (val) { if (val == 'block') _confirmBlockUser(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'block', child: Text("Block User", style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_item?.status == 'resolved')
            Container(
              width: double.infinity,
              color: Colors.green[50],
              padding: const EdgeInsets.all(8),
              child: const Text("✅ Item resolved. Chat active for coordination.",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontSize: 12)),
            ),
          
          // REPLACED StreamBuilder with standard ListView
          Expanded(
            child: _isLoadingMessages 
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty 
                ? const Center(child: Text("No messages yet."))
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true, 
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final String? rawDate = msg['created_at'];
                      final time = rawDate != null ? DateTime.parse(rawDate).toLocal() : DateTime.now();
                      return _buildBubble(msg['text'], msg['sender_id'] == myId, time);
                    },
                  ),
          ),
          _buildBottomArea(),
        ],
      ),
    );
  }

  Widget _buildBottomArea() {
    return SafeArea(top: false, child: _isBlocked ? _buildBlockedUI() : _buildInputUI());
  }

  Widget _buildBlockedUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.grey[100],
      child: Column(
        children: [
          Text(_iAmTheBlocker ? "You blocked this user" : "Conversation Unavailable"),
          if (_iAmTheBlocker)
            TextButton(
              onPressed: () async {
                await _service.unblockUser(widget.receiverId);
                _checkBlockStatus();
              },
              child: const Text("Unblock"),
            ),
        ],
      ),
    );
  }

  Widget _buildInputUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
            ),
          ),
          IconButton(
            onPressed: () async {
              if (_msgController.text.trim().isNotEmpty) {
                final text = _msgController.text.trim();
                _msgController.clear();
                await _service.sendMessage(widget.itemId, widget.receiverId, text);
                _fetchMessages(); // Refresh immediately after sending
              }
            },
            icon: const Icon(Icons.send, color: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(String text, bool isMe, DateTime time) {
    bool isSystemMessage = text.contains("✅ ITEM VERIFIED");
    return Align(
      alignment: isSystemMessage ? Alignment.center : (isMe ? Alignment.centerRight : Alignment.centerLeft),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSystemMessage ? Colors.green[100] : (isMe ? Colors.blueAccent : Colors.grey[300]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black, fontWeight: isSystemMessage ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(height: 2),
            Text(DateFormat('HH:mm').format(time), style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : Colors.black54)),
          ],
        ),
      ),
    );
  }

  void _confirmBlockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Block User?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _service.blockUser(widget.receiverId);
              Navigator.pop(context);
              _checkBlockStatus();
            },
            child: const Text("Block", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}