import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'registration.dart';
import 'customerloginscreen.dart';
import 'specificdoctorpage.dart';
import 'homepage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }
  
  // Set up logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // This will output to console during development
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Booking Doctor App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: ThemeMode.light,
      home: const SplashScreen(), // Changed to SplashScreen
      routes: {
        '/registration': (context) => const RegistrationScreen(),
        '/login': (context) => const CustomerLoginScreen(),
        '/specific_doctor': (context) => const SpecificDoctorPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Fade animation for the main content
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Scale animation for the logo
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    // Start the animation
    _animationController.forward();

    // Navigate to home page after delay
    Timer(const Duration(seconds: 3), () {
      _navigateToHome();
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomePageWithSearch(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade50,
                    Colors.white,
                  ],
                ),
              ),
            ),
            
            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated logo
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(60),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // App name
                    Text(
                      'Doctor Booking',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    
                    // Subtitle
                    Text(
                      'Find and book your doctor easily',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Loading indicator at bottom
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePageWithSearch extends StatefulWidget {
  const HomePageWithSearch({super.key});

  @override
  State<HomePageWithSearch> createState() => _HomePageWithSearchState();
}

class _HomePageWithSearchState extends State<HomePageWithSearch> {
  final TextEditingController _searchController = TextEditingController();
  final _logger = Logger('HomePageWithSearch');
  String _searchQuery = '';
  
  // Reference to the doctors collection
  final CollectionReference _doctorsCollection = 
      FirebaseFirestore.instance.collection('doctors');
      
  // Logger for debugging
  final _firebaseLogger = Logger('FirebaseData');
  
  // Stream for fetching doctors data
  Stream<QuerySnapshot>? _doctorsStream;

  @override
  void initState() {
    super.initState();
    // Initialize the stream to fetch all doctors
    _doctorsStream = _doctorsCollection.snapshots();
    
    // Log collection structure for debugging
    _fetchAndLogDoctorDataStructure();
  }
  
  // Function to examine the structure of the first document in the collection
  Future<void> _fetchAndLogDoctorDataStructure() async {
    try {
      final QuerySnapshot snapshot = await _doctorsCollection.limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        _firebaseLogger.info('Document ID: ${doc.id}');
        _firebaseLogger.info('Document data: ${doc.data()}');
        
        // Get all field names to see the actual structure
        final data = doc.data() as Map<String, dynamic>;
        _firebaseLogger.info('Field names: ${data.keys.toList()}');
      } else {
        _firebaseLogger.info('No documents found in doctors collection');
      }
    } catch (e) {
      _firebaseLogger.severe('Error fetching doctor data structure: $e');
    }
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      // When search query changes, we update the UI but the filtering
      // will be done in the StreamBuilder
      _logger.info('Searching for: $_searchQuery');
    });
  }

  void _navigateToSpecificDoctor(String doctorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecificDoctorPage(doctorId: doctorId),
      ),
    );
  }

  void _showDoctorsInLocation(String location) {
    setState(() {
      _searchQuery = location.toLowerCase();
      _searchController.text = location;
      _logger.info('Showing doctors in: $location');
    });
  }

  // Helper method to get image URL - same logic as SpecificDoctorPage
  String _getDoctorImageUrl(Map<String, dynamic> data) {
    if (data['imageUrls'] != null) {
      if (data['imageUrls'] is List) {
        List<dynamic> urls = data['imageUrls'];
        if (urls.isNotEmpty) {
          return urls[0].toString();
        }
      } else if (data['imageUrls'] is String) {
        return data['imageUrls'];
      }
    }
    return ''; // Return empty string if no image
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Your Doctor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // Search Bar with real-time search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search doctor, speciality or location',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _handleSearch('');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: _handleSearch,
              onSubmitted: _handleSearch,
            ),
            const SizedBox(height: 20),

            // Login and Sign Up Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text('Login'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/registration');
                  },
                  child: const Text('Sign Up'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Available Doctors from Firebase with images
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Doctors',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_searchQuery.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      _handleSearch('');
                    },
                    child: const Text('Clear Search'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            
            StreamBuilder<QuerySnapshot>(
              stream: _doctorsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error fetching doctors: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter doctors based on search query if there is one
                final doctors = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) {
                    return true; // Show all doctors when no search query
                  }
                  
                  // Get doctor data
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // Check if specialty or location contains the search query
                  final specialty = _getStringValue(data, ['specialty', 'specialization', 'profession', 'speciality', 'field']).toLowerCase();
                  final location = _getStringValue(data, ['location', 'city', 'area', 'address']).toLowerCase();
                  final name = _getStringValue(data, ['name', 'fullName', 'doctorName', 'firstName']).toLowerCase();
                  
                  return specialty.contains(_searchQuery) || 
                         location.contains(_searchQuery) ||
                         name.contains(_searchQuery);
                }).toList();

                if (doctors.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _searchQuery.isNotEmpty 
                          ? 'No doctors found matching "$_searchQuery"'
                          : 'No doctors found matching your search criteria.',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctorData = doctors[index].data() as Map<String, dynamic>;
                    final doctorId = doctors[index].id;
                    
                    // Get doctor information with improved robustness
                    final name = _getStringValue(doctorData, [
                      'name', 
                      'fullName', 
                      'doctorName', 
                      'firstName',
                      'doctor_name'
                    ]);
                    
                    final specialty = _getStringValue(doctorData, [
                      'specialty', 
                      'specialization', 
                      'speciality',
                      'profession',
                      'doctor_specialty',
                      'field'
                    ]);
                    
                    final location = _getStringValue(doctorData, [
                      'location', 
                      'city', 
                      'area', 
                      'address',
                      'doctor_location'
                    ]);
                    
                    // Get image URL
                    final imageUrl = _getDoctorImageUrl(doctorData);
                    
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[300],
                            image: imageUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: imageUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(specialty),
                            Text(
                              location,
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => _navigateToSpecificDoctor(doctorId),
                        trailing: const Icon(Icons.arrow_forward_ios),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // Popular Locations with click functionality
            const Text(
              'Popular Locations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('doctors')
                  .get().asStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text('Loading locations...');
                }

                // Extract unique locations from doctors' data
                final Set<String> locations = {};
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final location = _getStringValue(data, [
                    'location', 
                    'city', 
                    'area', 
                    'address',
                    'doctor_location'
                  ]);
                  if (location.isNotEmpty && location != 'Location not specified') {
                    locations.add(location);
                  }
                }

                if (locations.isEmpty) {
                  return const Text('No locations available');
                }

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: locations.length,
                    itemBuilder: (context, index) {
                      final location = locations.elementAt(index);
                      return Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _showDoctorsInLocation(location),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, 
                                  color: Colors.blue, 
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to get string value from map with multiple possible keys
  String _getStringValue(Map<String, dynamic> data, List<String> possibleKeys) {
    for (String key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null && data[key].toString().isNotEmpty) {
        return data[key].toString();
      }
    }
    
    // If we're looking for specialty, return a more appropriate default
    if (possibleKeys.contains('specialty') || possibleKeys.contains('profession')) {
      return 'General Practitioner';
    }
    
    // Default value
    return possibleKeys.first == 'name' ? 'Unknown Doctor' : 
           possibleKeys.first == 'location' ? 'Location not specified' : 
           'Not specified';
  }
}