import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';
import '../models/item_model.dart';
import 'details_screen.dart';
import 'location_picker_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _questionController = TextEditingController();
  final _service = SupabaseService();

  String _itemType = 'found'; // Default to found
  File? _selectedImage;
  bool _isUploading = false;
  bool _useVerification = false;

  double? _lat;
  double? _lng;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _pickLocationOnMap() async {
    final position = await _service.getCurrentPosition();
    final startLatLng = position != null 
        ? LatLng(position.latitude, position.longitude)
        : const LatLng(0, 0);

    if (!mounted) return;

    final LatLng? picked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(initialPosition: startLatLng),
      ),
    );

    if (picked != null) {
      setState(() {
        _lat = picked.latitude;
        _lng = picked.longitude;
        _locationController.text = "Map Pin Selected";
      });
    }
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
      // Logic: Only send verificationQuestion if the item is 'found'
      final String? finalQuestion = (_itemType == 'found' && _useVerification) 
          ? _questionController.text.trim() 
          : null;

      await _service.addItem(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageFile: _selectedImage!,
        type: _itemType,
        locationName: _locationController.text.trim(),
        lat: _lat,
        lng: _lng,
        verificationQuestion: finalQuestion,
      );

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

  void _showMatchDialog(List<ItemModel> matches) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Possible Matches Found!"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: matches.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final match = matches[index];
              return ListTile(
                leading: Image.network(match.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                title: Text(match.title),
                subtitle: Text(match.locationName ?? ""),
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
            child: const Text("Continue Anyway"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Item')),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _itemType = newSelection.first;
                      // Logic: If user switches to 'lost', disable verification toggle
                      if (_itemType == 'lost') {
                        _useVerification = false;
                        _questionController.clear();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 25),

              // Image Picker UI
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_selectedImage!, fit: BoxFit.cover))
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 40, color: Colors.blue),
                            Text("Add Photo"),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel("Item Title"),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "What did you find/lose?"),
              ),
              const SizedBox(height: 15),

              _buildLabel("Location"),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Describe or pick on map',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _pickLocationOnMap,
                    icon: const Icon(Icons.map),
                    tooltip: "Pick on Map",
                  ),
                ],
              ),
              const SizedBox(height: 15),

              _buildLabel("Additional Details"),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Color, brand, etc."),
              ),
              
              // CONDITIONAL SECURITY SECTION
              if (_itemType == 'found') ...[
                const SizedBox(height: 20),
                const Divider(),
                _buildLabel("Security Verification"),
                SwitchListTile(
                  title: const Text("Ask a Question"),
                  subtitle: const Text("Require claimants to prove ownership"),
                  value: _useVerification,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _useVerification = val),
                ),
                if (_useVerification)
                  TextField(
                    controller: _questionController,
                    decoration: const InputDecoration(
                      labelText: "Verification Question",
                      hintText: "e.g., What color is the phone case?",
                      border: OutlineInputBorder(),
                    ),
                  ),
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isUploading 
                      ? const CircularProgressIndicator() 
                      : const Text("Submit Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}