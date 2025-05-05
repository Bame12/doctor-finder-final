import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'specificdoctorpage.dart';
import 'homepage.dart';
import 'myaccountpage.dart';

class FavoritesPage extends StatefulWidget {
  final bool showAppointmentSuccess;
  
  const FavoritesPage({
    super.key, 
    this.showAppointmentSuccess = false,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final int _selectedIndex = 1; // Favorites is selected by default
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _favoriteDoctors = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _userAppointments = [];
  final Map<String, Timer> _appointmentTimers = {};
  final Map<String, String> _timeRemaining = {};

  @override
  void initState() {
    super.initState();
    _fetchFavoriteDoctors();
    _fetchUserAppointments(); // Fetch appointments when the page initializes
    
    // Show the appointment success message if requested
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showAppointmentSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _fetchFavoriteDoctors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user ID
      final User? user = _auth.currentUser;
      if (user != null) {
        // Get user's favorite doctors from Firestore
        final QuerySnapshot favoritesSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .get();

        List<Map<String, dynamic>> doctors = [];
        
        // For each favorite reference, fetch the doctor data
        for (var doc in favoritesSnapshot.docs) {
          final String doctorId = doc.id;
          final DocumentSnapshot doctorDoc = 
              await _firestore.collection('doctors').doc(doctorId).get();
          
          if (doctorDoc.exists) {
            final doctorData = doctorDoc.data() as Map<String, dynamic>;
            doctors.add({
              'id': doctorId,
              'name': _getStringValue(doctorData, ['name', 'fullName', 'doctorName', 'firstName', 'doctor_name']) ?? 'Unknown Doctor',
              'specialty': _getStringValue(doctorData, ['specialty', 'specialization', 'speciality', 'profession', 'doctor_specialty', 'field']) ?? 'General Practitioner',
              'rating': doctorData['rating'] ?? 5.0,
              'distance': doctorData['distance'] ?? 1.2,
              'description': doctorData['description'] ?? 'No description available',
              'isFavorite': true,
            });
          }
        }

        setState(() {
          _favoriteDoctors = doctors;
          _isLoading = false;
        });
      } else {
        // No user logged in, set empty list
        setState(() {
          _favoriteDoctors = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching favorite doctors: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to get string value from map with multiple possible keys
  String? _getStringValue(Map<String, dynamic> data, List<String> possibleKeys) {
    for (String key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null && data[key].toString().isNotEmpty) {
        return data[key].toString();
      }
    }
    return null;
  }

  Future<void> _fetchUserAppointments() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        // Get user's appointments from Firestore
        final QuerySnapshot appointmentsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('appointments')
            .orderBy('date', descending: false)
            .get();
            
        List<Map<String, dynamic>> appointments = [];
          
        for (var doc in appointmentsSnapshot.docs) {
          final appointmentData = doc.data() as Map<String, dynamic>;
          final String doctorId = appointmentData['doctorId'] ?? '';
          
          // Get doctor info if available
          String doctorName = 'Unknown Doctor';
          String specialty = 'General Practitioner';
          if (doctorId.isNotEmpty) {
            final doctorDoc = await _firestore.collection('doctors').doc(doctorId).get();
            if (doctorDoc.exists) {
              final doctorData = doctorDoc.data() as Map<String, dynamic>;
              doctorName = _getStringValue(doctorData, ['name', 'fullName', 'doctorName', 'firstName', 'doctor_name']) ?? 'Unknown Doctor';
              specialty = _getStringValue(doctorData, ['specialty', 'specialization', 'speciality', 'profession', 'doctor_specialty', 'field']) ?? 'General Practitioner';
            }
          }
          
          // Convert Firestore timestamp to DateTime if it exists
          DateTime? appointmentDate;
          if (appointmentData['date'] is Timestamp) {
            appointmentDate = (appointmentData['date'] as Timestamp).toDate();
          } else if (appointmentData['date'] is String) {
            // Handle case where date is stored as a string (e.g., "Mon, Aug 17")
            final String dateStr = appointmentData['date'];
            
            
            // Parse date string - this is simplified, you may need a more robust parser
            try {
              final now = DateTime.now();
              final dateParts = dateStr.split(', ');
              if (dateParts.length == 2) {
                final monthStr = dateParts[1].split(' ')[0];
                final dayStr = dateParts[1].split(' ')[1];
                
                // Convert month string to number
                final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                final monthIndex = months.indexOf(monthStr);
                
                if (monthIndex >= 0) {
                  final day = int.tryParse(dayStr) ?? 1;
                  appointmentDate = DateTime(now.year, monthIndex + 1, day);
                  
                  // If the date is in the past, assume it's for next year
                  if (appointmentDate.isBefore(now) && !appointmentData['fromTime'].contains('completed')) {
                    appointmentDate = DateTime(now.year + 1, monthIndex + 1, day);
                  }
                }
              }
            } catch (e) {
              print('Error parsing date string: $e');
              appointmentDate = DateTime.now();
            }
          } else {
            appointmentDate = DateTime.now();
          }
          
          // Format date for display
          final formattedDate = appointmentDate != null 
              ? '${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}'
              : 'No date specified';
          
          // Create appointment object
          final appointment = {
            'id': doc.id,
            'doctorId': doctorId,
            'doctorName': doctorName,
            'specialty': specialty,
            'date': appointmentDate ?? DateTime.now(),
            'formattedDate': formattedDate,
            'time': appointmentData['fromTime'] ?? 'No time specified',
            'reason': appointmentData['message'] ?? 'General checkup',
            'status': appointmentData['status'] ?? 'Scheduled',
          };
          
          appointments.add(appointment);
          
          // Start countdown timer for upcoming appointments
          if (appointmentDate != null && 
              appointment['status'] == 'Scheduled' && 
              appointmentDate.isAfter(DateTime.now())) {
            _startCountdownTimer(doc.id, appointmentDate);
          }
        }
        
        setState(() {
          _userAppointments = appointments;
        });
      }
    } catch (e) {
      print('Error fetching appointments: $e');
    }
  }

  void _startCountdownTimer(String appointmentId, DateTime appointmentDate) {
    // Cancel existing timer if any
    _appointmentTimers[appointmentId]?.cancel();
    
    // Start a new timer that updates every second
    _appointmentTimers[appointmentId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final difference = appointmentDate.difference(now);
      
      // If appointment time has passed, cancel timer
      if (difference.isNegative) {
        timer.cancel();
        setState(() {
          _timeRemaining[appointmentId] = 'Appointment time reached';
        });
        return;
      }
      
      // Format the remaining time
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;
      
      String remainingTime = '';
      if (days > 0) {
        remainingTime = '$days day${days > 1 ? 's' : ''}, ';
      }
      remainingTime += '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
      setState(() {
        _timeRemaining[appointmentId] = remainingTime;
      });
    });
  }

  @override
  void dispose() {
    // Clean up all timers when the widget is disposed
    _appointmentTimers.forEach((_, timer) => timer.cancel());
    _appointmentTimers.clear();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // No need to navigate if already on the page
    
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else if (index == 1) {
      // Already on favorites page
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MyAccountPage()),
      );
    }
  }

  Future<void> _removeFavorite(String doctorId) async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        // Remove from Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .doc(doctorId)
            .delete();
            
        // Remove from local list
        setState(() {
          _favoriteDoctors.removeWhere((doctor) => doctor['id'] == doctorId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor removed from favorites'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error removing favorite doctor: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove doctor from favorites'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showAppointments() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Refresh appointments before showing the dialog
      await _fetchUserAppointments();
      _showAppointmentsDialog(_userAppointments);
    } catch (e) {
      print('Error preparing appointments dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load appointments'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _cancelAppointment(String appointmentId) async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        // Update appointment status to 'Cancelled' in Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('appointments')
            .doc(appointmentId)
            .update({'status': 'Cancelled'});
        
        // Refresh the appointments list
        await _fetchUserAppointments();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment cancelled successfully'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error cancelling appointment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel appointment'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAppointmentsDialog(List<Map<String, dynamic>> appointments) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Your Appointments'),
          content: appointments.isEmpty
              ? const Text('No appointments scheduled yet.')
              : SizedBox(
                  width: double.maxFinite,
                  height: 400, // Set a fixed height to allow scrolling
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final appointment = appointments[index];
                      final bool isCompletedOrCancelled = 
                          appointment['status'] == 'Completed' || 
                          appointment['status'] == 'Cancelled';
                      
                      Color statusColor;
                      if (appointment['status'] == 'Completed') {
                        statusColor = Colors.green;
                      } else if (appointment['status'] == 'Cancelled') {
                        statusColor = Colors.red;
                      } else {
                        statusColor = Colors.blue;
                      }
                      
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    appointment['doctorName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      appointment['status'],
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                appointment['specialty'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    appointment['formattedDate'],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.access_time, size: 14, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    appointment['time'],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Reason: ${appointment['reason']}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              
                              // Add countdown timer display
                              if (!isCompletedOrCancelled && _timeRemaining.containsKey(appointment['id'])) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.timer, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Time remaining: ${_timeRemaining[appointment['id']]}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              
                              if (!isCompletedOrCancelled) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Close the dialog
                                    _cancelAppointment(appointment['id']);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Cancel Appointment'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Favorites',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAppointments,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('View Appointments'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _favoriteDoctors.isEmpty
                      ? const Center(
                          child: Text(
                            'No favorite doctors yet.\nAdd doctors to your favorites from the home page.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _favoriteDoctors.length,
                          itemBuilder: (context, index) {
                            final doctor = _favoriteDoctors[index];
                            return _buildDoctorCard(doctor);
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favourites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'My Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpecificDoctorPage(doctorId: doctor['id']),
          ),
        );
        
        // If appointment was booked successfully, refresh the appointments list
        if (result == true) {
          _fetchUserAppointments();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.person, color: Colors.grey[400], size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        doctor['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                Icons.star,
                                size: 14,
                                color: index < (doctor['rating'] as num).floor()
                                    ? Colors.amber
                                    : Colors.grey[300],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.favorite,
                              size: 18,
                              color: Colors.pink,
                            ),
                            onPressed: () {
                              _removeFavorite(doctor['id']);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        doctor['specialty'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                      Icon(Icons.star, size: 12, color: Colors.grey[600]),
                      Text(
                        ' ${doctor['rating']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                      Text(
                        '${doctor['distance']} km away',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor['description'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Divider(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}