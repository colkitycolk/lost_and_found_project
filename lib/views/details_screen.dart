import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/item_model.dart';
import '../services/supabase_service.dart';
import 'chat_screen.dart';

class DetailsScreen extends StatefulWidget {
  final ItemModel item;

  const DetailsScreen({super.key, required this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _service = SupabaseService();
  bool _isUpdating = false;
  bool _isVerified = false;

  /// Handles the actual database update
  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await _service.updateItemStatus(widget.item.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Item is now $newStatus")));
        Navigator.pop(context, true); // Refresh previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// Confirmation dialog before toggling status
  Future<void> _confirmStatusChange(String newStatus) async {
    final bool isResolving = newStatus == 'resolved';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isResolving ? "Mark as Resolved?" : "Re-activate Item?"),
        content: Text(
          isResolving
              ? "This will hide the item from the main feed. Ensure the item has been returned/found."
              : "This will make the item visible to all users again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Confirm",
              style: TextStyle(
                color: isResolving ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) _updateStatus(newStatus);
  }

  void _shareItem() {
    final String text =
        "Check out this ${widget.item.type} item: ${widget.item.title}\n\n"
        "Description: ${widget.item.description}\n"
        "Posted on Lost&Found App";
    Share.share(text, subject: widget.item.title);
  }

  Future<void> _openInExternalMap() async {
    // FIXED: Standard Google Maps Query format
    final String url =
        "https://www.google.com/maps/search/?api=1&query=${widget.item.latitude},${widget.item.longitude}";
    final Uri uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open maps application")),
        );
      }
    }
  }

  void _handleClaimProcess() {
    if (_isVerified) {
      _navigateToChat();
      return;
    }
    if (widget.item.verificationQuestion == null ||
        widget.item.verificationQuestion!.trim().isEmpty) {
      setState(() => _isVerified = true);
      _navigateToChat();
      return;
    }
    _showVerificationDialog();
  }

  void _showVerificationDialog() {
    final answerController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Ownership Challenge"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Answer the finder's question to chat:",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              widget.item.verificationQuestion!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(
                hintText: "Your answer...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _isVerified = true);
              Navigator.pop(context);
              _navigateToChat();
            },
            child: const Text("Verify & Chat"),
          ),
        ],
      ),
    );
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          itemId: widget.item.id,
          receiverId: widget.item.userId,
          itemTitle: widget.item.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMine = widget.item.userId == _service.currentUser?.id;
    final bool isLost = widget.item.type == 'lost';
    final bool hasLocation =
        widget.item.latitude != null && widget.item.longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Item Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareItem,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: widget.item.id,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: Image.network(
                    widget.item.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          widget.item.type.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                        backgroundColor: isLost
                            ? Colors.redAccent
                            : Colors.green,
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text(
                    "Description",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 25),
                  if (hasLocation) ...[
                    const Text(
                      "Last Spotted At",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            widget.item.latitude!,
                            widget.item.longitude!,
                          ),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  widget.item.latitude!,
                                  widget.item.longitude!,
                                ),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: TextButton.icon(
                        onPressed: _openInExternalMap,
                        icon: const Icon(Icons.map),
                        label: const Text("Open Google Maps"),
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(child: _buildBottomAction(isMine, isLost)),
      ),
    );
  }

  Widget _buildBottomAction(bool isMine, bool isLost) {
    final String status = widget.item.status.toLowerCase();

    if (status == 'resolved') {
      return isMine
          ? _buildOwnerButton(
              label: "Re-activate Item",
              color: Colors.orange,
              statusToSet: "active",
              icon: Icons.refresh,
            )
          : _buildClosedBadge();
    }

    if (isMine) {
      return _buildOwnerButton(
        label: "Mark as Resolved",
        color: Colors.green,
        statusToSet: "resolved",
        icon: Icons.check_circle,
      );
    }
    return _buildClaimButton(isLost);
  }

  Widget _buildClosedBadge() {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified, color: Colors.green),
          SizedBox(width: 8),
          Text(
            "THIS CASE IS RESOLVED",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerButton({
    required String label,
    required Color color,
    required String statusToSet,
    required IconData icon,
  }) {
    return ElevatedButton.icon(
      onPressed: _isUpdating ? null : () => _confirmStatusChange(statusToSet),
      icon: _isUpdating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildClaimButton(bool isLost) {
    return ElevatedButton.icon(
      onPressed: _handleClaimProcess,
      icon: Icon(_isVerified ? Icons.chat : Icons.lock_outline),
      label: Text(
        _isVerified
            ? "Chat with Owner"
            : (isLost ? "I Found This" : "This is mine"),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isVerified ? Colors.blueAccent : Colors.indigo,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
