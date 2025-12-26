import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'chat_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();

    return Scaffold(
      appBar: AppBar(title: const Text("My Messages"), elevation: 0),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: service.getMyConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final chats = snapshot.data ?? [];
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("No messages yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final item = chat['items'];
              final String otherUserId = chat['sender_id'] == service.currentUser?.id 
                  ? chat['receiver_id'] 
                  : chat['sender_id'];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(item['image_url']),
                ),
                title: Text(item['title'] ?? "Item Chat", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(chat['text'], maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      itemId: chat['item_id'],
                      receiverId: otherUserId,
                      itemTitle: item['title'],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}