import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isVerified = false; // Tracks if user passed the challenge

  // Function to handle status change (Owner Only)
  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await _service.updateItemStatus(widget.item.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item marked as $newStatus")),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // FIXED: Corrected the string interpolation for Google Maps
  Future<void> _openInExternalMap() async {
    final String googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=${widget.item.latitude},${widget.item.longitude}";
    final Uri uri = Uri.parse(googleMapsUrl);

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

  // NEW: Logic to handle the verification question
  void _handleClaimProcess() {
    // If no verification question exists, go straight to contact
    if (widget.item.verificationQuestion == null || widget.item.verificationQuestion!.isEmpty) {
      setState(() => _isVerified = true);
      return;
    }

    final answerController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ownership Challenge"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("To protect the owner, please answer the finder's question:"),
            const SizedBox(height: 12),
            Text(
              widget.item.verificationQuestion!,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              // Simulation: In a real app, this would notify the owner
              setState(() => _isVerified = true);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Verification sent! You can now contact the finder.")),
              );
            },
            child: const Text("Submit Answer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMine = widget.item.userId == _service.currentUser?.id;
    final bool isLost = widget.item.type == 'lost';
    final bool hasLocation = widget.item.latitude != null && widget.item.longitude != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Item Details")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section with Zoom capability
              InteractiveViewer(
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: 300,
                  child: Image.network(widget.item.imageUrl, fit: BoxFit.contain),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Title & Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.title,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Chip(
                          label: Text(widget.item.type.toUpperCase()),
                          backgroundColor: isLost ? Colors.red[100] : Colors.green[100],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Status: ${widget.item.status.toUpperCase()}",
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                    ),

                    const Divider(height: 40),

                    // Description
                    const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(widget.item.description, style: const TextStyle(fontSize: 16, color: Colors.black87)),

                    const SizedBox(height: 25),

                    // Location Section
                    if (hasLocation) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Last Spotted At", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: _openInExternalMap,
                            icon: const Icon(Icons.directions),
                            label: const Text("Open Maps"),
                          ),
                        ],
                      ),
                      if (widget.item.locationName != null)
                        Text(widget.item.locationName!, style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 12),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(widget.item.latitude!, widget.item.longitude!),
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(widget.item.latitude!, widget.item.longitude!),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 100), // Space for bottom button
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Persistent Bottom Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: Builder(builder: (context) {
            // 1. If the item is already resolved, show a "Closed" indicator for everyone
            if (widget.item.status.toLowerCase() == 'resolved') {
              return Container(
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      "THIS CASE IS RESOLVED",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              );
            }

            // 2. If it's MY item and NOT resolved yet
            if (isMine) {
              return ElevatedButton.icon(
                onPressed: _isUpdating ? null : () => _updateStatus('resolved'),
                icon: const Icon(Icons.check_circle),
                label: const Text("Mark as Resolved"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }

            // 3. If it's SOMEONE ELSE'S item and NOT resolved yet
            return ElevatedButton.icon(
              onPressed: _handleClaimProcess,
              icon: Icon(_isVerified ? Icons.chat : Icons.lock_outline),
              label: Text(_isVerified 
                  ? "Contact Owner" 
                  : (isLost ? "I Found This" : "This is mine")),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isVerified ? Colors.orange : Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }),
        ),
      ),
    );
  }
}
