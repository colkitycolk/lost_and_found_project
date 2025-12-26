import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/item_model.dart';
import 'details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = SupabaseService();
  bool _isLoading = true;
  List<ItemModel> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _service.getItems();
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // NEW: Delete Confirmation Dialog
  Future<void> _confirmDelete(ItemModel item) async {
    final bool? proceed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Report?"),
        content: const Text("This will permanently remove this item from the feed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      try {
        await _service.deleteItem(item);
        _loadData(); // Refresh list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted successfully")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost & Found Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Sign out and go back to login
              // await _service.signOut(); 
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final bool isMine = item.userId == _service.currentUser?.id;

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (c) => DetailsScreen(item: item)),
                                ),
                                child: Image.network(
                                  item.imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        // DELETE BUTTON (Only shows if it's your post)
                        if (isMine)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                                onPressed: () => _confirmDelete(item),
                              ),
                            ),
                          ),
                        // TYPE BADGE
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.type == 'lost' ? Colors.red : Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.type.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/report'),
        child: const Icon(Icons.add),
      ),
    );
  }
}