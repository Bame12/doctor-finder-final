import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:doctor_finder_flutter/screens/profile/my_account_screen.dart'; // ADDED THIS IMPORT

class DoctorDetailScreen extends StatefulWidget {
  final String doctorId;

  const DoctorDetailScreen({Key? key, required this.doctorId}) : super(key: key);

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  final int _selectedIndex = 0;

  String _doctorFirstName = '';
  String _doctorSurname = '';
  String _doctorServices = '';
  String _doctorDescription = '';
  String _doctorEmail = '';
  String _doctorPhone = '';
  double _doctorRating = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    if (widget.doctorId.isEmpty) return; // FIXED: removed null check

    try {
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .get();

      if (doctorDoc.exists && doctorDoc.data() != null) {
        Map<String, dynamic> data = doctorDoc.data() as Map<String, dynamic>;

        setState(() {
          _doctorFirstName = data['firstName'] ?? 'Doctor';
          _doctorSurname = data['surname'] ?? '';
          _doctorServices = data['services'] ?? 'No services listed';
          _doctorDescription = data['description'] ?? 'No description available';
          _doctorEmail = data['email'] ?? 'doctor@example.com';
          _doctorPhone = data['contacts'] ?? 'No phone number';
          _doctorRating = (data['rating'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      print('Error loading doctor data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BOOKING PAGE'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_doctorFirstName $_doctorSurname',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Services',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _doctorServices,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            _showBookingDialog(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today, size: 16),
                              SizedBox(width: 8),
                              Text('Book now'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // ... rest of the build method remains the same
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'My Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showBookingDialog(context);
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.calendar_today),
      ),
    );
  }

  void _showBookingDialog(BuildContext context) {
    // ... rest of dialog code ...
  }

  Future<void> _bookAppointment(BuildContext context, DateTime date, String fromTime, String toTime, String message) async {
    if (widget.doctorId.isEmpty || FirebaseAuth.instance.currentUser == null) { // FIXED: removed null check
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to book appointments')),
      );
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      String userName = 'User';
      String userEmail = FirebaseAuth.instance.currentUser!.email ?? 'Not provided';
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        userName = userData['name'] ?? 'User';
      }

      final appointmentData = {
        'doctorId': widget.doctorId,
        'doctorName': '$_doctorFirstName $_doctorSurname',
        'doctorEmail': _doctorEmail,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'userName': userName,
        'userEmail': userEmail,
        'date': date,
        'fromTime': fromTime,
        'toTime': toTime,
        'message': message,
        'status': 'Scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      };

      DocumentReference appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      // USING THE VARIABLE
      print('Appointment created with ID: ${appointmentRef.id}');

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked successfully!')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking appointment: $e')),
      );
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MyAccountScreen()),
      );
    }
  }
}