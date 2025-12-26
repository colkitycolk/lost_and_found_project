import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialPosition;

  const LocationPickerScreen({super.key, required this.initialPosition});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _pickedPosition;

  @override
  void initState() {
    super.initState();
    _pickedPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () => Navigator.pop(context, _pickedPosition),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: widget.initialPosition,
          initialZoom: 16,
          onTap: (tapPosition, point) {
            setState(() => _pickedPosition = point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'lost_and_found_project',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _pickedPosition,
                width: 50,
                height: 50,
                child: const Icon(Icons.location_on, color: Colors.red, size: 45),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, _pickedPosition),
        label: const Text("Confirm Location"),
        icon: const Icon(Icons.location_searching),
      ),
    );
  }
}