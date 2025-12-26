import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
//import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../models/item_model.dart';
import 'details_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _service = SupabaseService();

  String _itemType = 'found';
  File? _selectedImage;
  bool _isUploading = false;

  // NEW: Coordinates state
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // NEW: Get current GPS coordinates
  Future<void> _getCurrentLocation() async {
    setState(() => _isUploading = true);
    try {
      final position = await _service.getCurrentPosition();
      if (position != null) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _locationController.text = "GPS Coordinates Attached";
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location captured successfully!")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not get location. Check permissions.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMatchDialog(List<ItemModel> matches) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(child: Text("${matches.length} Matches Found!")),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: matches.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final match = matches[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(match.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                ),
                title: Text(match.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(match.locationName ?? "Unknown Location", maxLines: 1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DetailsScreen(item: match)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context, true); 
            },
            child: const Text("None of these are mine"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_titleController.text.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title and an image')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. ADD ITEM TO DB (Includes Location String + GPS)
      await _service.addItem(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageFile: _selectedImage!,
        type: _itemType,
        locationName: _locationController.text.trim(),
        lat: _lat, // GPS Latitude
        lng: _lng, // GPS Longitude
      );

      // 2. RUN MATCHING
      final matches = await _service.findMatches(
        _titleController.text.trim(),
        _itemType,
        _locationController.text.trim(),
      );

      if (mounted) {
        if (matches.isNotEmpty) {
          _showMatchDialog(matches);
        } else {
          Navigator.pop(context, true); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reported successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'found', label: Text('I Found'), icon: Icon(Icons.check_circle_outline)),
                  ButtonSegment(value: 'lost', label: Text('I Lost'), icon: Icon(Icons.help_outline)),
                ],
                selected: {_itemType},
                onSelectionChanged: (newSelection) => setState(() => _itemType = newSelection.first),
              ),
            ),
            const SizedBox(height: 25),

            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 50, color: Colors.blueAccent),
                          SizedBox(height: 10),
                          Text('Add Item Photo', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 25),

            _buildLabel("Item Title"),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'e.g., iPhone 13', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),

            _buildLabel("Location"),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Cafeteria',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // NEW: GPS Toggle Button
                IconButton.filledTonal(
                  onPressed: _isUploading ? null : _getCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  tooltip: "Get Current GPS",
                ),
              ],
            ),
            const SizedBox(height: 15),

            _buildLabel("Additional Details"),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Identifying marks...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Post Report & Search', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}