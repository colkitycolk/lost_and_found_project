import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../services/supabase_service.dart';

class DetailsScreen extends StatefulWidget {
  final ItemModel item;

  const DetailsScreen({super.key, required this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _service = SupabaseService();
  bool _isUpdating = false;

  // Function to handle status change
  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await _service.updateItemStatus(widget.item.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Item marked as $newStatus")));
        Navigator.pop(context, true); // Return true to trigger refresh on Home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error updating status: $e")));
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMine = widget.item.userId == _service.currentUser?.id;
    final bool isLost = widget.item.type == 'lost';

    return Scaffold(
      appBar: AppBar(title: const Text("Item Details")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with Zoom capability
            InteractiveViewer(
              child: Container(
                // Wrap the image in a Container
                color: Colors.black, // Set the background color here
                width: double.infinity,
                height: 300,
                child: Image.network(
                  widget.item.imageUrl,
                  fit: BoxFit.contain, // This ensures the image doesn't stretch
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Title and Type Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(widget.item.type.toUpperCase()),
                        backgroundColor: isLost
                            ? Colors.red[100]
                            : Colors.green[100],
                        labelStyle: TextStyle(
                          color: isLost ? Colors.red[900] : Colors.green[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Status Indicator
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Status: ${widget.item.status.toUpperCase()}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 40),

                  const Text(
                    "Description",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.item.description,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),

                  const SizedBox(height: 40),

                  // Action Buttons
                  if (isMine) ...[
                    // OWNER ACTIONS
                    const Text(
                      "Owner Controls",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isUpdating
                            ? null
                            : () => _updateStatus('resolved'),
                        icon: const Icon(Icons.check_circle),
                        label: const Text("Mark as Resolved / Returned"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ] else ...[
                    // FINDER/CLAIMER ACTIONS
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // For now, just a snackbar - future: Open Chat
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Contacting owner..."),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(
                          isLost ? "I Found This" : "This belongs to me",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
