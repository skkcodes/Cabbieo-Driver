import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class EarningPage extends StatefulWidget {
  const EarningPage({Key? key}) : super(key: key);

  @override
  State<EarningPage> createState() => _EarningPageState();
}

class _EarningPageState extends State<EarningPage> {
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();

  double _totalEarnings = 0.0;
  String _lastUpdated = '';
  List<Map<dynamic, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load total earnings
      final earningsSnap = await _dbRef.child('earnings/$userId').get();
      if (earningsSnap.exists) {
        final earningsData = earningsSnap.value as Map;
        _totalEarnings = (earningsData['total_earnings'] ?? 0).toDouble();
        final timestamp = earningsData['last_updated'];
        if (timestamp != null) {
          _lastUpdated = DateFormat.yMMMd().add_jm().format(
            DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp.toString())),
          );
        }
      }

      // Load and sort payments
      final paymentsSnap = await _dbRef.child('payments').get();
      if (paymentsSnap.exists) {
        final data = paymentsSnap.value as Map;
        final filtered = data.entries
            .where((entry) =>
                entry.value['driver_id'] == userId &&
                entry.value['amount'] != null)
            .map((entry) {
              final payment = entry.value as Map<dynamic, dynamic>;
              return {
                ...payment,
                'sort_timestamp': payment['timestamp'] != null 
                    ? int.parse(payment['timestamp'].toString())
                    : 0,
              };
            })
            .toList();

        // Sort in descending order (newest first)
        filtered.sort((a, b) => (b['sort_timestamp'] as int).compareTo(a['sort_timestamp'] as int));

        setState(() {
          _payments = filtered;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildEarningsCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.attach_money, size: 40, color: Colors.green),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total Earnings",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text("₹${_totalEarnings.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text("Last Updated", style: TextStyle(fontSize: 12)),
                Text(_lastUpdated, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    if (_payments.isEmpty) {
      return const Center(child: Text("No payment history found."));
    }

    return ListView.builder(
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        final timestamp = payment['timestamp'];
        final formattedTime = timestamp != null
            ? DateFormat.yMMMd().add_jm().format(
                DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp.toString())))
            : "Unknown";

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.payment_rounded, color: Colors.blueAccent),
            title: Text("₹${payment['amount'] ?? 0}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Rider: ${payment['rider_id']}"),
                Text("Date: $formattedTime"),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_car, size: 20),
                Text(payment['ride_id'] ?? "", style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,

        backgroundColor: Colors.green,
        title: const Text("My Earnings",style: TextStyle(color: Colors.white),),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,color: Colors.white,),
            onPressed: _loadData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildEarningsCard(),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Payment History",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: _buildPaymentHistory()),
                    ],
                  ),
                ),
    );
  }
}