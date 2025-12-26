import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _service = SupabaseService();

  // NEW: Track if reporting a Lost or Found item
  String _itemType = 'found';
  File? _selectedImage;
  bool _isUploading = false;

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

  // NEW: Show matches in a professional dialog
  void _showMatchDialog(List<ItemModel> matches) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${matches.length} Potential Matches Found!"),
        content: SizedBox(
          width: double.maxFinite,
          // Using a ListView inside the dialog for multiple candidates
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: matches.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final match = matches[index];
              return ListTile(
                leading: Image.network(
                  match.imageUrl,
                  width: 50,
                  fit: BoxFit.cover,
                ),
                title: Text(match.title),
                subtitle: Text(
                  match.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailsScreen(item: match),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go Home
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
      // 1. Add the item to the database
      await _service.addItem(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageFile: _selectedImage!,
        type: _itemType, // New parameter
      );

      // 2. RUN THE ALGORITHM: Check for matches
      final matches = await _service.findMatches(
        _titleController.text.trim(),
        _itemType,
      );

      if (mounted) {
        if (matches.isNotEmpty) {
          _showMatchDialog(matches);
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Reported successfully! No immediate matches found.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // NEW: Segmented Control to choose Lost vs Found
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'found',
                  label: Text('I Found'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment(
                  value: 'lost',
                  label: Text('I Lost'),
                  icon: Icon(Icons.help_outline),
                ),
              ],
              selected: {_itemType},
              onSelectionChanged: (newSelection) {
                setState(() => _itemType = newSelection.first);
              },
            ),
            const SizedBox(height: 20),

            // Image Preview Area
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                          Text('Tap to add photo'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Item Title',
                hintText: 'e.g., iPhone 13, Car Keys',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Where was it lost/found?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit & Run Matching',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
