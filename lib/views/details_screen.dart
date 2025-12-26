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
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // FIXED: Function to open location in external map application
  Future<void> _openInExternalMap() async {
    // Correct URL format for Google Maps
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

  @override
  Widget build(BuildContext context) {
    final bool isMine = widget.item.userId == _service.currentUser?.id;
    final bool isLost = widget.item.type == 'lost';
    final bool hasLocation =
        widget.item.latitude != null && widget.item.longitude != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Item Details")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              InteractiveViewer(
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: 300,
                  child: Image.network(
                    widget.item.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Type Badge
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

                    // Status
                    Text(
                      "Status: ${widget.item.status.toUpperCase()}",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const Divider(height: 40),

                    // Description Section
                    const Text(
                      "Description",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.item.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // NEW: Location & Map Section
                    if (hasLocation) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Location Spotted",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openInExternalMap,
                            icon: const Icon(Icons.directions),
                            label: const Text("Open Maps"),
                          ),
                        ],
                      ),
                      if (widget.item.locationName != null)
                        Text(
                          widget.item.locationName!,
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
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
                            initialCenter: LatLng(
                              widget.item.latitude!,
                              widget.item.longitude!,
                            ),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png', // Humanitarian style (often more reliable)
                              subdomains: const ['a', 'b', 'c'],
                              userAgentPackageName: 'lost_and_found_project',
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
                    ],

                    const SizedBox(height: 40),

                    // Action Buttons
                    if (isMine) ...[
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
                          label: const Text("Mark as Resolved"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
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
      ),
    );
  }
}
