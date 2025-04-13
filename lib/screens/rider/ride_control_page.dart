import 'dart:async';
import 'dart:ui';

import 'package:driver_cabbieo/global/global_var.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RideControlPage extends StatefulWidget {
  final String rideId;
  final LatLng pickupLocation;
  final LatLng destination;
  final Position driverLocation;
  final String riderPhone;
  final String riderName;
  final VoidCallback onRideCompleted;

  const RideControlPage({
    Key? key,
    required this.rideId,
    required this.pickupLocation,
    required this.destination,
    required this.driverLocation,
    required this.riderPhone,
    required this.riderName,
    required this.onRideCompleted,
  }) : super(key: key);

  @override
  State<RideControlPage> createState() => _RideControlPageState();
}

class _RideControlPageState extends State<RideControlPage> {
  late DatabaseReference _activeRidesRef;
  LatLng? _currentDriverLocation;
  bool _rideStarted = false;
  bool _rideCompleted = false;
  bool _isArrivedAtPickup = false;
  double? _distanceToPickup;
  Timer? _locationTimer;
  Timer? _distanceCheckTimer;
  BitmapDescriptor? _carIcon;
  List<LatLng> _routePoints = [];
  final Completer<GoogleMapController> _mapController = Completer();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _activeRidesRef = FirebaseDatabase.instance.ref("active_rides/${widget.rideId}");
    _currentDriverLocation = LatLng(
      widget.driverLocation.latitude,
      widget.driverLocation.longitude,
    );
    _loadCarIcon();
    _startLocationUpdates();
    _checkDistanceToPickup();
    _getRoute();
  }

  Future<void> _loadCarIcon() async {
    final Uint8List markerIcon = await getBytesFromAsset('assets/logo/car.png', 80);
    setState(() {
      _carIcon = BitmapDescriptor.fromBytes(markerIcon);
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    final data = await rootBundle.load(path);
    final codec = await instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _getCurrentLocation();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      
      setState(() {
        _currentDriverLocation = LatLng(position.latitude, position.longitude);
      });
      
      FirebaseDatabase.instance
          .ref("drivers_status/${FirebaseAuth.instance.currentUser!.uid}")
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': ServerValue.timestamp,
      });

      if (_mapController.isCompleted) {
        final controller = await _mapController.future;
        controller.animateCamera(
          CameraUpdate.newLatLng(_currentDriverLocation!),
        );
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> _getRoute() async {
    if (_currentDriverLocation == null) return;
    
    try {
      final apiKey = googleMapKey; // Replace with your API key
      final origin = "${_currentDriverLocation!.latitude},${_currentDriverLocation!.longitude}";
      final destination = "${widget.destination.latitude},${widget.destination.longitude}";
      final waypoints = "${widget.pickupLocation.latitude},${widget.pickupLocation.longitude}";
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&'
        'destination=$destination&'
        'waypoints=$waypoints&'
        'key=$apiKey',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final points = data['routes'][0]['overview_polyline']['points'];
        setState(() {
          _routePoints = _decodePoly(points);
        });
      }
    } catch (e) {
      debugPrint("Error getting route: $e");
    }
  }

  List<LatLng> _decodePoly(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  void _checkDistanceToPickup() {
    _distanceCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_currentDriverLocation == null) return;
      
      try {
        double distance = await Geolocator.distanceBetween(
          _currentDriverLocation!.latitude,
          _currentDriverLocation!.longitude,
          widget.pickupLocation.latitude,
          widget.pickupLocation.longitude,
        );
        
        setState(() {
          _distanceToPickup = distance;
          if (distance < 50 && !_isArrivedAtPickup) {
            _isArrivedAtPickup = true;
            _updateRideStatus('driver_arrived');
          }
        });
      } catch (e) {
        debugPrint("Error calculating distance: $e");
      }
    });
  }

  Future<void> _updateRideStatus(String status) async {
    try {
      await _activeRidesRef.update({
        'status': status,
        if (status == 'completed') 'completed_at': ServerValue.timestamp,
      });
    } catch (e) {
      
      if (mounted) {
        
        
      }
    }
  }

  Future<void> _startRide() async {
    setState(() => _isLoading = true);
    try {
      await _updateRideStatus('in_progress');
      setState(() {
        _rideStarted = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRide() async {
    setState(() => _isLoading = true);
    try {
      await _updateRideStatus('completed');
      widget.onRideCompleted();
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _callRider() async {
    final url = 'tel:${widget.riderPhone}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch phone call")),
        );
      }
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _distanceCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ride with ${widget.riderName}"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.pickupLocation,
              zoom: 15,
            ),
            markers: {
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
              if (_currentDriverLocation != null && _carIcon != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: _currentDriverLocation!,
                  icon: _carIcon!,
                  anchor: const Offset(0.5, 0.5),
                  rotation: _getMarkerRotation(),
                ),
            },
            polylines: {
              if (_routePoints.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: _routePoints,
                  color: Colors.blue,
                  width: 4,
                ),
            },
            onMapCreated: (controller) {
              _mapController.complete(controller);
            },
          ),
          Positioned(
  bottom: 0,
  left: 0,
  right: 0,
  child: Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          offset: Offset(0, -2),
          blurRadius: 10,
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getStatusMessage(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_distanceToPickup != null && !_isArrivedAtPickup)
          Text(
            "${(_distanceToPickup! / 1000).toStringAsFixed(1)} km to pickup",
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _callRider,
              icon: const Icon(Icons.phone),
              label: const Text("Call"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            if (_isArrivedAtPickup && !_rideStarted)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _startRide,
                icon: const Icon(Icons.play_arrow),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Start Ride"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            if (_rideStarted && !_rideCompleted)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _completeRide,
                icon: const Icon(Icons.check),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Complete Ride"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
          ],
        ),
      ],
    ),
  ),
),

        ],
      ),
    );
  }

  double _getMarkerRotation() {
    if (_routePoints.length < 2 || _currentDriverLocation == null) return 0;
    
    // Find the closest point on the route
    int closestIndex = 0;
    double closestDistance = double.maxFinite;
    for (int i = 0; i < _routePoints.length; i++) {
      final distance = Geolocator.distanceBetween(
        _currentDriverLocation!.latitude,
        _currentDriverLocation!.longitude,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }
    
    // Get the next point to determine direction
    if (closestIndex < _routePoints.length - 1) {
      final nextPoint = _routePoints[closestIndex + 1];
      final bearing = Geolocator.bearingBetween(
        _currentDriverLocation!.latitude,
        _currentDriverLocation!.longitude,
        nextPoint.latitude,
        nextPoint.longitude,
      );
      return bearing;
    }
    return 0;
  }

  String _getStatusMessage() {
    if (_rideCompleted) return "Ride Completed";
    if (_rideStarted) return "Ride in Progress - Take passenger to destination";
    if (_isArrivedAtPickup) return "Arrived at Pickup - Start Ride when passenger is ready";
    return "Heading to Pickup Location";
  }
}