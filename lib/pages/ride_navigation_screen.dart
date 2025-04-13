import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideNavigationScreen extends StatefulWidget {
  final String rideId;
  final LatLng pickupLocation;
  final LatLng destination;
  final Position driverLocation;
  final VoidCallback onRideCompleted;

  const RideNavigationScreen({
    required this.rideId,
    required this.pickupLocation,
    required this.destination,
    required this.driverLocation,
    required this.onRideCompleted,
  });

  @override
  State<RideNavigationScreen> createState() => _RideNavigationScreenState();
}
class _RideNavigationScreenState extends State<RideNavigationScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  void _setupMap() {
    _markers.addAll({
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: widget.destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(
          widget.driverLocation.latitude,
          widget.driverLocation.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    });

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(widget.driverLocation.latitude, widget.driverLocation.longitude),
          widget.pickupLocation,
          widget.destination,
        ],
        color: Colors.blue,
        width: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigation"),
        actions: [
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Complete Ride"),
                  content: const Text("Are you sure you want to complete this ride?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onRideCompleted();
                        Navigator.pop(context);
                      },
                      child: const Text("Complete"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.pickupLocation,
          zoom: 14,
        ),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
    );
  }
}