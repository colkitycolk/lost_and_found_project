import 'package:flutter/material.dart';
import '../models/item_model.dart';

class DetailsScreen extends StatelessWidget {
  final ItemModel item;

  const DetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isLost = item.type == 'lost';

    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            InteractiveViewer(
              child: Container(
                width: double.infinity,
                height: 300,
                color: Colors.black12,
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.contain,
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
                        child: Text(item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      Chip(
                        label: Text(item.type.toUpperCase()),
                        backgroundColor: isLost ? Colors.red[100] : Colors.green[100],
                        labelStyle: TextStyle(color: isLost ? Colors.red[900] : Colors.green[900]),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(item.description, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Connecting to owner...')),
                        );
                      },
                      icon: const Icon(Icons.mail),
                      label: Text(isLost ? "I Found This!" : "This is Mine!"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}