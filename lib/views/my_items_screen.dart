import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/item_model.dart';
import '../utils/dialog_helper.dart';
import 'details_screen.dart';

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  final _service = SupabaseService();

  Future<void> _handleDelete(ItemModel item) async {
    final confirmed = await DialogHelper.showDeleteDialog(context);
    if (confirmed) {
      try {
        await _service.deleteItem(item);
        setState(() {}); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item deleted successfully")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Reports")),
      body: FutureBuilder<List<ItemModel>>(
        future: _service.getMyItems(), // Ensure this exists in SupabaseService
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text("You haven't reported any items yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(item.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                  ),
                  title: Text(item.title),
                  subtitle: Text("Status: ${item.status}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _handleDelete(item),
                  ),
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (c) => DetailsScreen(item: item))
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