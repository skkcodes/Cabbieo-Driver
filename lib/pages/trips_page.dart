import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class TripPage extends StatefulWidget {
  const TripPage({Key? key}) : super(key: key);

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  final DatabaseReference activeRidesRef = FirebaseDatabase.instance.ref().child('active_rides');
  final String currentDriverId = FirebaseAuth.instance.currentUser!.uid;

  List<Map<dynamic, dynamic>> driverRides = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDriverRides();
  }

  void fetchDriverRides() async {
    try {
      final event = await activeRidesRef.orderByChild('driver_id').equalTo(currentDriverId).once();
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        setState(() {
          driverRides = data.entries
              .map((entry) => Map<String, dynamic>.from(entry.value))
              .toList()
              .reversed
              .toList(); // Most recent first
          isLoading = false;
        });
      } else {
        setState(() {
          driverRides = [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching rides: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget statusBadge(String status) {
    Color color;
    String text;
    if (status.toLowerCase() == 'completed') {
      color = Colors.green.shade100;
      text = 'Completed';
    } else {
      color = Colors.orange.shade100;
      text = 'In Progress';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
  backgroundColor: Colors.indigo,
  elevation: 0,
  centerTitle: true,
  title: const Text(
    'Your Ride History',
    style: TextStyle(color: Colors.white),
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.refresh, color: Colors.white),
      onPressed: () {
        setState(() {
          isLoading = true;
        });
        fetchDriverRides();
      },
    ),
  ],
),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : driverRides.isEmpty
              ? const Center(child: Text('No rides found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: driverRides.length,
                  itemBuilder: (context, index) {
                    final ride = driverRides[index];

                    final pickup = ride['source']?['address'] ?? 'N/A';
                    final drop = ride['destination']?['address'] ?? 'N/A';
                    final fare = ride['fare'] ?? 0;
                    final status = ride['status'] ?? 'in_progress';
                    final name = ride['rider_name']?.toString().isNotEmpty == true
                        ? ride['rider_name']
                        : 'Customer';
                    final timestamp = ride['completed_at'] ?? ride['created_at'];
                    final time = timestamp != null
                        ? DateFormat.yMMMd().add_jm().format(
                            DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp.toString())))
                        : '';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                statusBadge(status),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.my_location, color: Colors.indigo),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pickup,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, color: Colors.redAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    drop,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Fare: ₹$fare',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green),
                                ),
                                Text(
                                  time,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
