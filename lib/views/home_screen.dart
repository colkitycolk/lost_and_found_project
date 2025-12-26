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
  
  // Track the current filter status
  String _selectedStatus = 'active'; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Refetched data based on the selectedStatus
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final items = await _service.getItems(status: _selectedStatus);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading items: $e")),
        );
      }
    }
  }

  Future<void> _confirmDelete(ItemModel item) async {
    final bool? proceed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Report?"),
        content: const Text("This will permanently remove this item."),
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
        _loadData(); 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted successfully")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Lost & Found'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Toggle Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterChip('active', 'Current Feed', Icons.rss_feed),
                const SizedBox(width: 12),
                _buildFilterChip('resolved', 'Success Stories', Icons.stars),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? _buildEmptyState()
                      : _buildItemGrid(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/report');
          if (result == true) _loadData();
        },
        label: const Text("Report"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String status, String label, IconData icon) {
    final bool isSelected = _selectedStatus == status;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.blue),
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      onSelected: (bool selected) {
        if (selected && _selectedStatus != status) {
          setState(() => _selectedStatus = status);
          _loadData();
        }
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView( // ListView makes RefreshIndicator work even when empty
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "No $_selectedStatus items found.",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildItemGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final bool isMine = item.userId == _service.currentUser?.id;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => DetailsScreen(item: item)),
                        );
                        if (result == true) _loadData();
                      },
                      child: Image.network(
                        item.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => 
                          const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Status Badge (Top Left)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.type == 'lost' ? Colors.redAccent : Colors.greenAccent[700],
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    item.type.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Delete Button (Top Right)
              if (isMine)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.delete_outline, color: Colors.white, size: 16),
                    ),
                    onPressed: () => _confirmDelete(item),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}