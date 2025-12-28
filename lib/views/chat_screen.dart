import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../services/supabase_service.dart';

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
  
  bool _isBlocked = false;
  bool _iAmTheBlocker = false;

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    final myId = _service.currentUser?.id;
    if (myId == null) return;

    try {
      // Use the service's client instance to avoid "Undefined name Supabase"
      final response = await _service.instance
          .from('blocks')
          .select()
          .or('and(blocker_id.eq.$myId,blocked_id.eq.${widget.receiverId}),and(blocker_id.eq.${widget.receiverId},blocked_id.eq.$myId)');

      final List data = response as List;
      
      if (mounted) {
        setState(() {
          _isBlocked = data.isNotEmpty;
          if (_isBlocked) {
            _iAmTheBlocker = data.any((b) => b['blocker_id'] == myId);
          }
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _confirmBlockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Block User?"),
        content: const Text("You will no longer receive messages from this user."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _service.blockUser(widget.receiverId);
              Navigator.pop(context);
              _checkBlockStatus();
            },
            child: const Text("Block", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemTitle),
        actions: [
          if (!_isBlocked)
            IconButton(
              icon: const Icon(Icons.block, color: Colors.red),
              onPressed: _confirmBlockUser,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.getChatStream(widget.itemId, widget.receiverId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildBubble(msg['text'], msg['sender_id'] == _service.currentUser?.id);
                  },
                );
              },
            ),
          ),
          _buildBottomArea(),
        ],
      ),
    );
  }

  Widget _buildBottomArea() {
    return SafeArea(
      child: _isBlocked ? _buildBlockedUI() : _buildInputUI(),
    );
  }

  Widget _buildBlockedUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.grey[100],
      child: Column(
        children: [
          Text(
            _iAmTheBlocker ? "You blocked this user" : "This conversation is unavailable",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
      child: Row(
        children: [
          Expanded(child: TextField(controller: _msgController)),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_msgController.text.isNotEmpty) {
                _service.sendMessage(widget.itemId, widget.receiverId, _msgController.text);
                _msgController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black)),
      ),
    );
  }
}