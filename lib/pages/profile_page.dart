import 'package:driver_cabbieo/screens/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';



class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final String driverId = FirebaseAuth.instance.currentUser!.uid;
  final DatabaseReference driversRef = FirebaseDatabase.instance.ref().child("drivers");

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController carModelController = TextEditingController();
  final TextEditingController carNumberController = TextEditingController();
  final TextEditingController carColorController = TextEditingController();

  String? profilePhotoUrl;
  bool isLoading = true;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    fetchDriverData();
  }

  void fetchDriverData() async {
    final snapshot = await driversRef.child(driverId).get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      nameController.text = data['name'] ?? '';
      phoneController.text = data['phone'] ?? '';
      emailController.text = data['email'] ?? '';
      carModelController.text = data['car_details']['carModel'] ?? '';
      carNumberController.text = data['car_details']['carNumber'] ?? '';
      carColorController.text = data['car_details']['carColor'] ?? '';
      profilePhotoUrl = data['photo'];
    }
    setState(() => isLoading = false);
  }

  Future<void> updateProfile() async {
    try {
      setState(() => isLoading = true);

      await driversRef.child(driverId).update({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'car_details': {
          'carModel': carModelController.text.trim(),
          'carNumber': carNumberController.text.trim(),
          'carColor': carColorController.text.trim(),
        }
      });

      setState(() {
        isEditing = false;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  void logoutUser() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Driver Profile",style: TextStyle(color: Colors.white),),
        centerTitle: true,
        backgroundColor: Colors.amber,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit,color: Colors.white,),
            onPressed: () {
              if (isEditing) {
                updateProfile();
              } else {
                setState(() => isEditing = true);
              }
            },
          ),
          
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: profilePhotoUrl != null
                        ? NetworkImage(profilePhotoUrl!)
                        : const AssetImage('assets/avatar.png') as ImageProvider,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField("Name", nameController),
                  _buildTextField("Phone", phoneController),
                  _buildTextField("Email", emailController),
                  const Divider(height: 30),
                  _buildTextField("Car Model", carModelController),
                  _buildTextField("Car Number", carNumberController),
                  _buildTextField("Car Color", carColorController),

                  SizedBox(height: 200),
                  buildAttractiveButton(
  text: "Log out",
  onPressed: () {
     logoutUser();
  },
),

                ],
              ),
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        enabled: isEditing,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelStyle: const TextStyle(color: Colors.indigo),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.indigo),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget buildAttractiveButton({
  required String text,
  required VoidCallback onPressed,
}) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      backgroundColor: Colors.amber,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Colors.indigo.withOpacity(0.4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  );
}

}
