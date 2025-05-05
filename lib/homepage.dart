import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'specificdoctorpage.dart';
import 'favoritespage.dart';
import 'myaccountpage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final int _selectedIndex = 0; // Home is selected by default
  final TextEditingController _searchController = TextEditingController();
  final _logger = Logger('HomePage');
  String _searchQuery = '';
  bool _showSearchResults = false;
  List<DocumentSnapshot> _searchResults = [];
  
  // Google Maps controller
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  LatLng _currentPosition = const LatLng(37.42796133580664, -122.085749655962); // Default position
  bool _isLoading = true;
  
  // Reference to the doctors collection
  final CollectionReference _doctorsCollection = 
      FirebaseFirestore.instance.collection('doctors');

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final permissionStatus = await Permission.location.request();
    
    if (permissionStatus.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        
        // Add marker for current location and center the map if controller exists
        _addMarker(
          _currentPosition, 
          'Your Location', 
          'Your current location',
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentPosition,
                zoom: 14.0,
              ),
            ),
          );
        }
        
        // Load nearby doctors
        _loadNearbyDoctors();
      } catch (e) {
        _logger.severe('Error getting location: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      _logger.warning('Location permission denied');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNearbyDoctors() async {
    try {
      final QuerySnapshot doctorsSnapshot = await _doctorsCollection.get();
      
      for (var doc in doctorsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if doctor has location data
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final double lat = (data['latitude'] as num).toDouble();
          final double lng = (data['longitude'] as num).toDouble();
          
          final doctorLocation = LatLng(lat, lng);
          final doctorName = _getStringValue(data, [
            'name', 'fullName', 'doctorName', 'firstName', 'doctor_name'
          ]);
          
          final specialty = _getStringValue(data, [
            'specialty', 'specialization', 'speciality', 'profession',
            'doctor_specialty', 'field'
          ]);
          
          _addMarker(
            doctorLocation,
            doctorName,
            '$doctorName - $specialty',
            BitmapDescriptor.defaultMarker,
            doc.id,
          );
        }
      }
    } catch (e) {
      _logger.severe('Error loading nearby doctors: $e');
    }
  }

  void _addMarker(LatLng position, String title, String snippet, 
      BitmapDescriptor icon, [String? doctorId]) {
    final marker = Marker(
      markerId: MarkerId(title),
      position: position,
      infoWindow: InfoWindow(
        title: title,
        snippet: snippet,
        onTap: doctorId != null ? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpecificDoctorPage(doctorId: doctorId),
            ),
          );
        } : null,
      ),
      icon: icon,
    );
    
    setState(() {
      _markers.add(marker);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Move camera to current position
    if (_currentPosition.latitude != 0 && _currentPosition.longitude != 0) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition,
            zoom: 14.0,
          ),
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // No need to navigate if already on the page
    
    if (index == 0) {
      // Already on home page
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FavoritesPage()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MyAccountPage()),
      );
    }
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _logger.info('Searching for: $_searchQuery');
    });
    
    // Search for the query
    if (_searchQuery.isNotEmpty) {
      _searchDoctors(_searchQuery);
    } else {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
    }
  }
  
  void _searchDoctors(String query) async {
    _logger.info('Performing search for: $query');
    
    // Show loading indicator
    setState(() {
      _showSearchResults = true;
      _searchResults = [];
    });
    
    try {
      // Search in doctors collection for name, specialty, or location
      final QuerySnapshot doctorsSnapshot = await _doctorsCollection.get();
      final List<DocumentSnapshot> matchingDocs = [];
      
      for (var doc in doctorsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final searchableFields = [
          _getStringValue(data, ['name', 'fullName', 'doctorName', 'firstName', 'doctor_name']),
          _getStringValue(data, ['specialty', 'specialization', 'speciality', 'profession', 'doctor_specialty', 'field']),
          _getStringValue(data, ['location', 'city', 'area', 'address', 'doctor_location']),
        ];
        
        // Check if any field contains the search query
        bool isMatch = searchableFields.any((field) => 
          field.toLowerCase().contains(query.toLowerCase())
        );
        
        if (isMatch) {
          matchingDocs.add(doc);
        }
      }
      
      setState(() {
        _searchResults = matchingDocs;
      });
      
      // If there are matches and they have location data, focus the map on the first result
      if (matchingDocs.isNotEmpty && _mapController != null) {
        for (var doc in matchingDocs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('latitude') && data.containsKey('longitude')) {
            final double lat = (data['latitude'] as num).toDouble();
            final double lng = (data['longitude'] as num).toDouble();
            
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 14.0,
                ),
              ),
            );
            break; // Only focus on the first match
          }
        }
      }
    } catch (e) {
      _logger.severe('Error searching doctors: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _searchByLocation(String location) {
    setState(() {
      _searchController.text = location;
      _searchQuery = location.toLowerCase();
      _handleSearch(location);
    });
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

  Widget _buildSearchResultItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = _getStringValue(data, [
      'name', 'fullName', 'doctorName', 'firstName', 'doctor_name'
    ]);
    final specialty = _getStringValue(data, [
      'specialty', 'specialization', 'speciality', 'profession', 'doctor_specialty', 'field'
    ]);
    final location = _getStringValue(data, [
      'location', 'city', 'area', 'address', 'doctor_location'
    ]);
    final imageUrl = _getDoctorImageUrl(data);
    
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
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
                size: 25,
                color: Colors.white,
              )
            : null,
      ),
      title: Text(name),
      subtitle: Text('$specialty • $location'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpecificDoctorPage(doctorId: doc.id),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar as requested
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 30.0, 16.0, 16.0), // Add padding at top to compensate for removed app bar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome! How may we be of service?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Search bar with enhanced functionality
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search doctor, specialty or location',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        // Clear search field
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _showSearchResults = false;
                          _searchResults = [];
                        });
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
                
                // Show search results if searching
                if (_showSearchResults)
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'Search Results (${_searchResults.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_searchResults.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text('No results found'),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              return _buildSearchResultItem(_searchResults[index]);
                            },
                          ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Google Maps section with improved error handling
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : GoogleMap(
                            onMapCreated: _onMapCreated,
                            initialCameraPosition: CameraPosition(
                              target: _currentPosition,
                              zoom: 14.0,
                            ),
                            markers: _markers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            mapToolbarEnabled: true,
                            compassEnabled: true,
                            zoomControlsEnabled: false, // Hide the zoom controls to save space
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
                const Text(
                  'Find Doctors Near You',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Popular Doctors',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                
                // Popular doctors list from Firebase with images
                SizedBox(
                  height: 120,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _doctorsCollection.limit(10).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No doctors available'));
                      }
                      
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data!.docs.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final doctorData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          final doctorId = snapshot.data!.docs[index].id;
                          
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
                          
                          // Get image URL using the same logic as SpecificDoctorPage
                          final imageUrl = _getDoctorImageUrl(doctorData);
                          
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SpecificDoctorPage(doctorId: doctorId),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 100,
                              child: Column(
                                children: [
                                  Container(
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
                                  const SizedBox(height: 8),
                                  Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    specialty,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.grey),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Locations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios,
                          color: Colors.grey, size: 16),
                      onPressed: () {
                        // You can add functionality here if needed
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Fixed locations section - removed "OVERFLOWED BY BOTTOM" text
                SizedBox(
                  height: 100, // Increased height to prevent overflow
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('doctors')
                        .get().asStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error loading locations'));
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No locations available'));
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
                        return const Center(child: Text('No locations available'));
                      }

                      final locationsList = locations.toList();

                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: locationsList.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              // Set search to this location
                              _searchByLocation(locationsList[index]);
                            },
                            child: SizedBox(
                              width: 80,
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.0),
                                      color: Colors.grey[300],
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.location_on_outlined,
                                          color: Colors.grey, size: 24),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    locationsList[index],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                // Add bottom padding to ensure content isn't cut off by nav bar
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border_outlined),
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
}