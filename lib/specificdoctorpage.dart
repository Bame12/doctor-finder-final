import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class SpecificDoctorPage extends StatefulWidget {
  final String? doctorId;

  const SpecificDoctorPage({super.key, this.doctorId});

  @override
  State<SpecificDoctorPage> createState() => _SpecificDoctorPageState();
}

class _SpecificDoctorPageState extends State<SpecificDoctorPage> {
  int _selectedIndex = 0;
  bool _isFavorite = false;
  int _rating = 0;
  String _reviewText = '';

  // Updated doctor data fields to match Firebase database structure
  String _doctorFirstName = '';
  String _doctorSurname = '';
  String _doctorServices = '';
  String _doctorDescription = '';
  String _doctorEmail = '';
  
  // Working hours fields
  String _monFri = '';
  String _satSun = '';
  String _holidays = '';
  
  // Contact information
  String _doctorPhone = '';
  
  // Location information
  double _latitude = 0.0;
  double _longitude = 0.0;
  String _location = '';
  
  // Image URL
  String _imageUrl = '';
  
  double _doctorRating = 0.0;
  List<Map<String, dynamic>> _reviews = [];
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
    _checkIfFavorite();
  }

  Future<void> _loadDoctorData() async {
    if (widget.doctorId == null) return;
    
    try {
      DocumentSnapshot doctorDoc = await _firestore
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
          
          _monFri = data['monFri'] ?? 'Not available';
          _satSun = data['satSun'] ?? 'Not available';
          _holidays = data['holidays'] ?? 'Closed';
          
          _doctorPhone = data['contacts'] ?? 'No phone number';
          
          var latitudeData = data['latitude'];
          var longitudeData = data['longitude'];
          
          if (latitudeData is String) {
            _latitude = double.tryParse(latitudeData.replaceAll(',', '.')) ?? 0.0;
          } else if (latitudeData is num) {
            _latitude = latitudeData.toDouble();
          } else {
            _latitude = 0.0;
          }
          
          if (longitudeData is String) {
            _longitude = double.tryParse(longitudeData.replaceAll(',', '.')) ?? 0.0;
          } else if (longitudeData is num) {
            _longitude = longitudeData.toDouble();
          } else {
            _longitude = 0.0;
          }
          
          _location = data['location']?.toString() ?? '';
          
          if (data['imageUrls'] != null) {
            if (data['imageUrls'] is List) {
              List<dynamic> urls = data['imageUrls'];
              if (urls.isNotEmpty) {
                _imageUrl = urls[0].toString();
              }
            } else if (data['imageUrls'] is String) {
              _imageUrl = data['imageUrls'];
            }
          }
          
          _doctorRating = (data['rating'] ?? 0.0).toDouble();
        });

        await _loadReviews();
      }
    } catch (e) {
      print('Error loading doctor data: $e');
    }
  }

  Future<void> _loadReviews() async {
    if (widget.doctorId == null) return;
    
    try {
      QuerySnapshot reviewsSnapshot = await _firestore
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('reviews')
          .get();

      List<Map<String, dynamic>> reviews = [];
      
      for (var doc in reviewsSnapshot.docs) {
        reviews.add({
          'id': doc.id,
          'userName': doc['userName'] ?? 'Anonymous',
          'comment': doc['comment'] ?? '',
          'rating': doc['rating'] ?? 0,
          'date': doc['date'] ?? Timestamp.now(),
        });
      }

      setState(() {
        _reviews = reviews;
      });
    } catch (e) {
      print('Error loading reviews: $e');
    }
  }

  Future<void> _checkIfFavorite() async {
    if (widget.doctorId == null || _auth.currentUser == null) return;
    
    try {
      DocumentSnapshot favoriteDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('favorites')
          .doc(widget.doctorId)
          .get();

      setState(() {
        _isFavorite = favoriteDoc.exists;
      });
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _toggleFavorite() async {
    if (widget.doctorId == null || _auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to save favorites')),
      );
      return;
    }
    
    final userFavoritesRef = _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('favorites')
        .doc(widget.doctorId);
    
    try {
      if (_isFavorite) {
        await userFavoritesRef.delete();
      } else {
        await userFavoritesRef.set({
          'doctorId': widget.doctorId,
          'doctorName': '$_doctorFirstName $_doctorSurname',
          'addedAt': Timestamp.now(),
        });
      }

      setState(() {
        _isFavorite = !_isFavorite;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite 
              ? 'Added to favorites' 
              : 'Removed from favorites'),
        ),
      );
    } catch (e) {
      print('Error updating favorite status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update favorites')),
      );
    }
  }

  Future<void> _openGoogleMaps() async {
    if (_latitude == 0.0 || _longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }
    
    if (_latitude < -90 || _latitude > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid latitude coordinate (must be between -90 and 90)')),
      );
      return;
    }
    
    if (_longitude < -180 || _longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid longitude coordinate (must be between -180 and 180)')),
      );
      return;
    }
    
    final String formattedCoordinates = '${_latitude.toStringAsFixed(6)},${_longitude.toStringAsFixed(6)}';
    final url = 'https://www.google.com/maps/search/?api=1&query=$formattedCoordinates';
    
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps application')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening maps: ${e.toString()}')),
      );
    }
  }

  Future<void> _rateDoctor(int rating) async {
    if (widget.doctorId == null || _auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to rate')),
      );
      return;
    }
    
    setState(() {
      _rating = rating;
    });
    
    _showAddReviewDialog();
  }

  void _showAddReviewDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    color: index < _rating ? Colors.amber : Colors.grey[300],
                    size: 24,
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Write your review here...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _reviewText = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _submitReview();
                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitReview() async {
    if (widget.doctorId == null || _auth.currentUser == null) return;
    
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      String userName = 'Anonymous';
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        userName = userData['name'] ?? 'Anonymous';
      }
      
      await _firestore
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('reviews')
          .add({
            'userId': _auth.currentUser!.uid,
            'userName': userName,
            'rating': _rating,
            'comment': _reviewText,
            'date': Timestamp.now(),
          });
      
      QuerySnapshot reviewsSnapshot = await _firestore
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('reviews')
          .get();
      
      double totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        totalRating += (doc['rating'] ?? 0) as num;
      }
      
      double avgRating = reviewsSnapshot.docs.isEmpty 
          ? 0 
          : totalRating / reviewsSnapshot.docs.length;
      
      await _firestore
          .collection('doctors')
          .doc(widget.doctorId)
          .update({
            'rating': avgRating,
            'reviewCount': reviewsSnapshot.docs.length,
          });
      
      setState(() {
        _doctorRating = avgRating;
      });
      
      await _loadReviews();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your review!')),
      );
    } catch (e) {
      print('Error submitting review: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit review')),
      );
    }
  }

  // Flutter Email Implementation
  Future<void> _bookAppointmentWithEmail(
      BuildContext context, String date, String fromTime, String toTime, String message) async {
    if (widget.doctorId == null || _auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to book appointments')),
      );
      return;
    }
    
    try {
      // Get user information
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      String userName = 'User';
      String userEmail = _auth.currentUser!.email ?? 'Not provided';
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        userName = userData['name'] ?? 'User';
      }
      
      // Create appointment data
      final appointmentData = {
        'doctorId': widget.doctorId,
        'doctorName': '$_doctorFirstName $_doctorSurname',
        'doctorEmail': _doctorEmail,
        'userId': _auth.currentUser!.uid,
        'userName': userName,
        'userEmail': userEmail,
        'date': date,
        'fromTime': fromTime,
        'toTime': toTime,
        'message': message,
        'status': 'Scheduled',
        'createdAt': Timestamp.now(),
      };
      
      // Save appointment to Firebase
      DocumentReference appointmentRef = await _firestore
          .collection('appointments')
          .add(appointmentData);
      
      // Close the dialog first
      Navigator.of(context).pop();
      
      // Create email content
      final emailContent = '''Dear $_doctorFirstName $_doctorSurname,

You have a new appointment request:

Patient Information:
------------------
Name: $userName
Email: $userEmail

Appointment Details:
-------------------
Date: $date
Time: $fromTime - $toTime
Reason: $message

Appointment ID: ${appointmentRef.id}

Please confirm this appointment at your earliest convenience.

Thank you,
Health Appointment App''';

      // Create email
      final Email email = Email(
        body: emailContent,
        subject: 'New Appointment Request from $userName',
        recipients: [_doctorEmail],
        cc: [userEmail],
        isHTML: false,
      );

      // Show a beautiful dialog to prepare the email
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Send Appointment Email'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your appointment has been saved!'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Appointment Details:', 
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Date: $date'),
                        Text('Time: $fromTime - $toTime'),
                        Text('Doctor: $_doctorFirstName $_doctorSurname'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Click the button below to send the appointment email to the doctor.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FlutterEmailSender.send(email);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email sent successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not send email: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Send Email'),
              ),
            ],
          );
        },
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking appointment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title:
            const Text('BOOKING PAGE', style: TextStyle(color: Colors.black, fontSize: 14)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDoctorHeader(),
              const SizedBox(height: 20),
              _buildDoctorDescription(),
              const SizedBox(height: 20),
              _buildContactInformation(),
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
            icon: Icon(Icons.favorite_border),
            label: 'Favorites',
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
    DateTime selectedDate = DateTime.now();
    String fromTime = '09:00 AM'; 
    String toTime = '10:00 AM';
    String message = '';

    final List<String> timeSlots = [
      '08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM', 
      '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM', 
      '12:00 PM', '12:30 PM', '01:00 PM', '01:30 PM', 
      '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM', 
      '04:00 PM', '04:30 PM', '05:00 PM'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[200],
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Select date',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('EEE, MMM d').format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null && picked != selectedDate) {
                                      setState(() {
                                        selectedDate = picked;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Times:'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('From'),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: fromTime,
                                    isExpanded: true,
                                    items: timeSlots.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          fromTime = newValue;
                                          int fromIndex = timeSlots.indexOf(fromTime);
                                          int toIndex = timeSlots.indexOf(toTime);
                                          if (toIndex <= fromIndex) {
                                            if (fromIndex + 1 < timeSlots.length) {
                                              toTime = timeSlots[fromIndex + 1];
                                            }
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () {
                                    _showCustomTimePicker(context, 'From', fromTime, (selectedTime) {
                                      setState(() {
                                        fromTime = selectedTime;
                                      });
                                    });
                                  },
                                  child: const Icon(Icons.edit, color: Colors.blue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('To'),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: toTime,
                                    isExpanded: true,
                                    items: timeSlots.where((time) {
                                      int fromIndex = timeSlots.indexOf(fromTime);
                                      int timeIndex = timeSlots.indexOf(time);
                                      return timeIndex > fromIndex;
                                    }).map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          toTime = newValue;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () {
                                    _showCustomTimePicker(context, 'To', toTime, (selectedTime) {
                                      setState(() {
                                        toTime = selectedTime;
                                      });
                                    });
                                  },
                                  child: const Icon(Icons.edit, color: Colors.blue),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            const Text('Message'),
                            const SizedBox(height: 8),
                            Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextField(
                                onChanged: (value) {
                                  message = value;
                                },
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  String formattedDate = DateFormat('EEEE, MMM d, yyyy').format(selectedDate);
                                  _bookAppointmentWithEmail(context, formattedDate, fromTime, toTime, message);
                                },
                                child: const Text('Book Appointment'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomTimePicker(BuildContext context, String label, String currentTime, Function(String) onTimeSelected) {
    TextEditingController timeController = TextEditingController(text: currentTime);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select $label Time'),
          content: TextField(
            controller: timeController,
            decoration: const InputDecoration(
              hintText: 'e.g., 09:00 AM',
              labelText: 'Time',
            ),
            keyboardType: TextInputType.text,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                String selectedTime = timeController.text;
                if (_isValidTimeFormat(selectedTime)) {
                  onTimeSelected(selectedTime);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid time format. Please use HH:MM AM/PM')),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  bool _isValidTimeFormat(String time) {
    RegExp timeRegex = RegExp(r'^(0[1-9]|1[0-2]):[0-5][0-9] (AM|PM)$');
    return timeRegex.hasMatch(time);
  }

  Widget _buildDoctorHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
            image: _imageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(_imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _imageUrl.isEmpty
              ? Center(
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_doctorFirstName $_doctorSurname',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ],
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
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _showBookingDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.calendar_today, size: 16),
                        SizedBox(width: 8),
                        Text('Book now'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showReviewsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Doctor Reviews'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _reviews.isEmpty
                  ? [const Text('No reviews yet')]
                  : _reviews.map((review) {
                      return _buildReviewItem(
                        review['userName'],
                        review['comment'],
                        review['rating'],
                      );
                    }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rateDoctor(_rating > 0 ? _rating : 5);
              },
              child: const Text('Add Review'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewItem(String name, String comment, int rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(comment),
          Row(
            children: List.generate(
              rating,
              (index) => const Icon(Icons.star, color: Colors.amber, size: 16),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildDoctorDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _doctorDescription,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ...List.generate(5, (index) {
              return InkWell(
                onTap: () {
                  _rateDoctor(index + 1);
                },
                child: Icon(
                  Icons.star,
                  color: index < _doctorRating ? Colors.amber : Colors.grey[300],
                  size: 18,
                ),
              );
            }),
            const SizedBox(width: 8),
            Text(
              _doctorRating > 0 
                  ? _doctorRating.toStringAsFixed(1) 
                  : 'No ratings',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                _showReviewsDialog(context);
              },
              child: const Text(
                'See Reviews',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildContactInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _contactItem(
          Icons.email,
          _doctorEmail,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.access_time, color: Colors.black54),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monday-Friday: $_monFri'),
                Text('Saturday-Sunday: $_satSun'),
                Text('Holidays: $_holidays'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _contactItem(
          Icons.phone,
          _doctorPhone,
        ),
        const SizedBox(height: 12),
        (_location.isNotEmpty || (_latitude != 0.0 && _longitude != 0.0))
          ? InkWell(
              onTap: _openGoogleMaps,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _location.isNotEmpty 
                        ? _location + 
                          ((_latitude != 0.0 && _longitude != 0.0) 
                            ? '\n${_latitude.toStringAsFixed(6)}, ${_longitude.toStringAsFixed(6)}' 
                            : '')
                        : 'Coordinates: ${_latitude.toStringAsFixed(6)}, ${_longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            )
          : _contactItem(
              Icons.location_on,
              'Location not available',
              textColor: Colors.grey,
            ),
      ],
    );
  }

  Widget _contactItem(IconData icon, String text, {Color textColor = Colors.black}) {
    return Row(
      children: [
        Icon(icon, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: textColor),
        ),
      ],
    );
  }
}