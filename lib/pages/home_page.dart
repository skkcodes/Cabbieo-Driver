import 'dart:async';

import 'package:driver_cabbieo/pages/earning_page.dart';
import 'package:driver_cabbieo/pages/trips_page.dart';
import 'package:driver_cabbieo/screens/rider/ride_control_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _mapController = Completer();
  Position? _currentPosition;
  bool _isOnline = false;
  bool _isOnTrip = false;
  String? _currentRideId;
  
  // Database references
  late DatabaseReference _statusRef;
  late DatabaseReference _rideRequestsRef;
  late DatabaseReference _activeRidesRef;
  StreamSubscription<DatabaseEvent>? _rideSubscription;
  final Set<String> _processedRequestIds = {};
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser!.uid;
    _statusRef = FirebaseDatabase.instance.ref("drivers_status/$userId");
    _rideRequestsRef = FirebaseDatabase.instance.ref("ride_requests");
    _activeRidesRef = FirebaseDatabase.instance.ref("active_rides");
    _initializeLocation();
    _checkActiveRides();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _locationTimer?.cancel();
    if (_isOnline && !_isOnTrip) {
      _statusRef.remove();
    }
    super.dispose();
  }

  Future<void> _checkActiveRides() async {
    try {
      final snapshot = await _activeRidesRef
          .orderByChild("driver_id")
          .equalTo(FirebaseAuth.instance.currentUser!.uid)
          .once();

      if (snapshot.snapshot.value != null && mounted) {
        final activeRide = (snapshot.snapshot.value as Map).values.first;
        if (activeRide['status'] != 'completed') {
          _startRideNavigation(
            activeRide['id'],
            LatLng(
              activeRide['source']['latitude'],
              activeRide['source']['longitude'],
            ),
            LatLng(
              activeRide['destination']['latitude'],
              activeRide['destination']['longitude'],
            ),
            riderPhone: activeRide['rider_phone'] ?? '',
            riderName: activeRide['rider_name'] ?? 'Passenger',
            isResume: true,
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking active rides: ${e.toString()}");
    }
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      await _getCurrentLocation();
      _startLocationUpdates();
    } catch (e) {
      debugPrint("Error getting location: ${e.toString()}");
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isOnline && mounted) {
        _getCurrentLocation();
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }

      if (_isOnline && mounted) {
        await _updateDriverLocation(position);
      }

      if (_mapController.isCompleted && mounted) {
        final GoogleMapController controller = await _mapController.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 16,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating location: ${e.toString()}");
    }
  }

  Future<void> _updateDriverLocation(Position position) async {
    try {
      await _statusRef.update({
        "latitude": position.latitude,
        "longitude": position.longitude,
        "lastUpdated": ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint("Error updating location in database");
    }
  }

  Future<void> _toggleOnlineStatus(bool isOnline) async {
    try {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }

      if (isOnline) {
        await _getCurrentLocation();
        if (_currentPosition == null) return;

        await _statusRef.set({
          "status": "online",
          "latitude": _currentPosition!.latitude,
          "longitude": _currentPosition!.longitude,
          "lastUpdated": ServerValue.timestamp,
          "driverId": FirebaseAuth.instance.currentUser!.uid,
        });

        _listenForRideRequests();
      } else {
        await _statusRef.remove();
        _rideSubscription?.cancel();
        _processedRequestIds.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOnline = false);
      }
      debugPrint("Error changing online status: ${e.toString()}");
    }
  }

  void _listenForRideRequests() {
    _rideSubscription?.cancel();
    _rideSubscription = _rideRequestsRef
        .orderByChild("status")
        .equalTo("pending")
        .onValue
        .listen((event) async {
      if (event.snapshot.value != null && mounted) {
        final Map<dynamic, dynamic> requests = event.snapshot.value as Map;
        final List<String> currentRequestIds = [];
        
        requests.forEach((rideId, requestData) async {
          currentRequestIds.add(rideId.toString());
          if (!_processedRequestIds.contains(rideId)) {
            if (await _shouldShowRequest(requestData)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showRideRequestNotification(rideId.toString(), requestData);
                  _processedRequestIds.add(rideId.toString());
                }
              });
            }
          }
        });

        _processedRequestIds.removeWhere((id) => !currentRequestIds.contains(id));
      }
    }, onError: (error) {
      debugPrint("Request error: ${error.toString()}");
    });
  }

  Future<bool> _shouldShowRequest(Map requestData) async {
    if (_currentPosition == null || !_isOnline || _isOnTrip) return false;
    
    try {
      final status = requestData['status'];
      if (status != 'pending') return false;
      
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        requestData['source']['latitude'],
        requestData['source']['longitude'],
      );
      
      return distance <= 5000; // 5km radius
    } catch (e) {
      return false;
    }
  }

  void _showRideRequestNotification(String rideId, dynamic requestData) {
  // Ensure we have all required data
  if (_currentPosition == null || 
      requestData['source'] == null || 
      requestData['source']['latitude'] == null || 
      requestData['source']['longitude'] == null ||
      requestData['destination'] == null ||
      requestData['destination']['address'] == null ||
      requestData['source']['address'] == null) {
    debugPrint("Missing required data for notification");
    return;
  }

  try {
    // Calculate distance
    final double distanceInKm = _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      requestData['source']['latitude'],
      requestData['source']['longitude'],
    );

    // Format the distance with 1 decimal place
    final String formattedDistance = distanceInKm.toStringAsFixed(1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("New Ride Request"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("From: ${requestData['source']['address']}"),
            Text("To: ${requestData['destination']['address']}"),
            const SizedBox(height: 10),
            Text("Distance: $formattedDistance km"),
            Text("Fare: ₹${requestData['fare']?.toStringAsFixed(2)}"),
            Text("Passenger: ${requestData['rider_name'] ?? 'Unknown'}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _respondToRideRequest(rideId, false),
            child: const Text("Reject"),
          ),
          ElevatedButton(
            onPressed: () => _respondToRideRequest(rideId, true),
            child: const Text("Accept"),
          ),
        ],
      ),
    );
  } catch (e) {
    debugPrint("Error calculating distance: $e");
    // You might want to show an error to the user here
  }
}


  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  Future<void> _respondToRideRequest(String rideId, bool accept) async {
    if (!mounted) return;
    Navigator.pop(context);

    try {
      if (accept) {
        final rideSnapshot = await _rideRequestsRef.child(rideId).get();
        final rideData = rideSnapshot.value as Map?;
        
        if (rideData == null || rideData['status'] != 'pending') return;

        if (_currentPosition == null) return;

        await _rideRequestsRef.child(rideId).update({
          'status': 'driver_accepted',
          'driver_id': FirebaseAuth.instance.currentUser!.uid,
          'driver_location': {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
          },
          'accepted_at': ServerValue.timestamp,
        });

        await _activeRidesRef.child(rideId).set({
          ...rideData,
          'status': 'driver_accepted',
          'driver_id': FirebaseAuth.instance.currentUser!.uid,
        });

        if (mounted) {
          _startRideNavigation(
            rideId,
            LatLng(
              (rideData['source'] as Map)['latitude'] as double,
              (rideData['source'] as Map)['longitude'] as double,
            ),
            LatLng(
              (rideData['destination'] as Map)['latitude'] as double,
              (rideData['destination'] as Map)['longitude'] as double,
            ),
            riderPhone: rideData['rider_phone'] ?? '',
            riderName: rideData['rider_name'] ?? 'Passenger',
          );
        }
      } else {
        await _rideRequestsRef.child(rideId).update({
          'status': 'cancelled',
          'rejected_by': FirebaseAuth.instance.currentUser!.uid,
        });
      }
    } catch (e) {
      debugPrint("Error responding to ride request: ${e.toString()}");
    }
  }

  void _startRideNavigation(
    String rideId, 
    LatLng pickupLocation, 
    LatLng destination, {
    required String riderPhone,
    required String riderName,
    bool isResume = false,
  }) {
    if (!mounted) return;
    
    setState(() {
      _isOnTrip = true;
      _currentRideId = rideId;
    });

    _statusRef.update({
      'status': 'on_trip',
      'current_ride_id': rideId,
    });

    if (!isResume) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideControlPage(
            rideId: rideId,
            pickupLocation: pickupLocation,
            destination: destination,
            driverLocation: _currentPosition!,
            riderPhone: riderPhone,
            riderName: riderName,
            onRideCompleted: () => _completeRide(rideId),
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isOnTrip = false;
            _currentRideId = null;
          });
          if (_isOnline) {
            _statusRef.update({'status': 'online'});
            _listenForRideRequests();
          }
        }
      });
    }
  }

 Future<void> _completeRide(String rideId) async {
  try {
    final rideSnapshot = await _activeRidesRef.child(rideId).once();
    if (rideSnapshot.snapshot.value == null) return;

    final rideData = rideSnapshot.snapshot.value as Map;
    final fare = rideData['fare'] ?? 0.0;

    // Show rating dialog first
    await _showRatingDialog(rideId, rideData['rider_id']);

    // Automatically mark ride as completed and process payment/earnings
    await _activeRidesRef.child(rideId).update({
      'status': 'completed',
      'completed_at': ServerValue.timestamp,
    });

    await _recordEarning(rideId, fare);
    await _recordTripHistory(rideId, rideData);

  } catch (e) {
    debugPrint("Error completing ride: ${e.toString()}");
  }
}

  Future<void> _showRatingDialog(String rideId, String riderId) async {
    int? rating;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rate Your Passenger"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("How was your experience with this passenger?"),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    rating != null && index < rating! ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                  onPressed: () {
                    setState(() {
                      rating = index + 1;
                    });
                  },
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Skip"),
          ),
          ElevatedButton(
            onPressed: () {
              if (rating != null) {
                Navigator.pop(context);
                _submitRating(rideId, riderId, rating!);
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating(String rideId, String riderId, int rating) async {
    try {
      await FirebaseDatabase.instance
          .ref('rider_ratings/$riderId/$rideId')
          .set({
        'rating': rating,
        'timestamp': ServerValue.timestamp,
        'driver_id': FirebaseAuth.instance.currentUser!.uid,
      });
    } catch (e) {
      debugPrint("Error submitting rating: ${e.toString()}");
    }
  }

  Future<void> _recordEarning(String rideId, double fare) async {
    try {
      await FirebaseDatabase.instance
          .ref('driver_earnings/${FirebaseAuth.instance.currentUser!.uid}')
          .push()
          .set({
        'amount': fare,
        'ride_id': rideId,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint("Error recording earning: ${e.toString()}");
    }
  }

  Future<void> _recordTripHistory(String rideId, Map rideData) async {
    try {
      await FirebaseDatabase.instance
          .ref('driver_trip_history/${FirebaseAuth.instance.currentUser!.uid}/$rideId')
          .set({
        'completed_at': ServerValue.timestamp,
        'fare': rideData['fare'],
        'rider_name': rideData['rider_name'],
        'pickup_address': rideData['source']['address'],
        'destination_address': rideData['destination']['address'],
      });
    } catch (e) {
      debugPrint("Error recording trip history: ${e.toString()}");
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Text(
              'Driver Menu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Earnings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EarningPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Trip History'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TripPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  drawer: _buildDrawer(),
  floatingActionButton: FloatingActionButton(
    onPressed: _getCurrentLocation,
    backgroundColor: Colors.deepOrange,
    child: const Icon(Icons.my_location, color: Colors.white),
  ),
  body: Stack(
    children: [
      // 🌍 Google Map Layer
      GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : const LatLng(0, 0),
          zoom: 15,
        ),
        myLocationEnabled: true,
        onMapCreated: (controller) {
          _mapController.complete(controller);
        },
      ),

      // 👋 Welcome Banner
      Positioned(
        top: 40,
        left: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "👋 Welcome to Cabbieo!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 14,
                    color: _isOnTrip
                        ? Colors.amber
                        : _isOnline
                            ? Colors.green
                            : Colors.redAccent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isOnTrip
                        ? "On Trip - Ride #${_currentRideId?.substring(0, 6)}..."
                        : _isOnline
                            ? "Online - Available for rides"
                            : "Offline - Not receiving rides",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isOnTrip
                          ? Colors.amber[800]
                          : _isOnline
                              ? Colors.green[800]
                              : Colors.red[800],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // 🔘 Go Online / Offline Button
      Positioned(
        bottom: 30,
        left: 20,
        right: 20,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (_isOnline ? Colors.red : Colors.green).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _toggleOnlineStatus(!_isOnline),
            icon: Icon(
              _isOnline ? Icons.toggle_off : Icons.toggle_on,
              color: Colors.white,
            ),
            label: Text(
              _isOnline ? "🚫 GO OFFLINE" : "✅ GO ONLINE",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              backgroundColor: _isOnline ? Colors.redAccent : Colors.green.shade600,
              elevation: 8,
            ),
          ),
        ),
      ),
    ],
  ),
);

  }
}