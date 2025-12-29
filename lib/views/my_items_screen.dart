import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/item_model.dart';
import '../models/match_model.dart';
import '../utils/dialog_helper.dart';
import 'details_screen.dart';

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  final _service = SupabaseService();
  late Future<List<ItemModel>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  void _refreshItems() {
    setState(() {
      _itemsFuture = _service.getMyItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Reported Items"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshItems,
          ),
        ],
      ),
      body: FutureBuilder<List<ItemModel>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshItems(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) => _ItemCard(
                item: items[index],
                onDelete: () async {
                  final confirmed = await DialogHelper.showDeleteDialog(context);
                  if (confirmed) {
                    await _service.deleteItem(items[index]);
                    _refreshItems();
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text("No reports found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Items you report will appear here.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ItemCard extends StatefulWidget {
  final ItemModel item;
  final VoidCallback onDelete;

  const _ItemCard({required this.item, required this.onDelete});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _showMatches = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: _buildThumbnail(),
            title: Text(widget.item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("Status: ${widget.item.status.toUpperCase()}", 
                style: TextStyle(
                  color: widget.item.status == 'active' ? Colors.green[700] : Colors.orange[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              onPressed: widget.onDelete,
            ),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => DetailsScreen(item: widget.item))),
          ),
          const Divider(height: 0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey[50],
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => DetailsScreen(item: widget.item))),
                  child: const Text("Full Details"),
                ),
                const Spacer(),
                // THE MATCHES BUTTON
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showMatches = !_showMatches),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showMatches ? Colors.indigo : Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  icon: Icon(_showMatches ? Icons.expand_less : Icons.auto_awesome, size: 18),
                  label: Text(_showMatches ? "Hide Matches" : "View Matches"),
                ),
              ],
            ),
          ),
          if (_showMatches) _MatchSection(itemId: widget.item.id),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
        image: widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty
            ? DecorationImage(image: NetworkImage(widget.item.imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: widget.item.imageUrl == null || widget.item.imageUrl!.isEmpty
          ? const Icon(Icons.image, color: Colors.grey)
          : null,
    );
  }
}

class _MatchSection extends StatelessWidget {
  final String itemId;
  const _MatchSection({required this.itemId});

  Color _getScoreColor(double score) {
    if (score >= 0.85) return Colors.green; // Excellent match
    if (score >= 0.75) return Colors.orange; // Good match
    return Colors.blueGrey; // Average/Fair match
  }

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();

    return FutureBuilder<List<MatchModel>>(
      future: service.getMatchesForItem(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator());
        }

        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text("No AI matches found yet...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }

        return Container(
          decoration: BoxDecoration(color: Colors.blue[50]?.withOpacity(0.3), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
          child: Column(
            children: matches.map((match) {
              final percentage = (match.similarityScore * 100).toStringAsFixed(1);
              final scoreColor = _getScoreColor(match.similarityScore);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: scoreColor.withOpacity(0.2),
                  child: Icon(Icons.check_circle, color: scoreColor, size: 20),
                ),
                title: Text(match.matchedItem.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("Similarity Score: $percentage%"),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: scoreColor, borderRadius: BorderRadius.circular(12)),
                  child: Text("$percentage%", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => DetailsScreen(item: match.matchedItem))),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}