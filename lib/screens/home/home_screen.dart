import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:doctor_finder_flutter/screens/doctor/doctor_detail_screen.dart';
import 'package:doctor_finder_flutter/screens/profile/my_account_screen.dart';
import 'package:doctor_finder_flutter/widgets/common/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearchResults = false;
  List<DocumentSnapshot> _searchResults = [];

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  LatLng _currentPosition = const LatLng(37.42796133580664, -122.085749655962);
  bool _isLoading = true;

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

        _loadNearbyDoctors();
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
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

        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final double lat = (data['latitude'] as num).toDouble();
          final double lng = (data['longitude'] as num).toDouble();

          final doctorLocation = LatLng(lat, lng);
          final doctorName = _getStringValue(data, ['name', 'fullName', 'doctorName', 'firstName']);
          final specialty = _getStringValue(data, ['specialty', 'specialization', 'speciality', 'profession']);

          final marker = Marker(
            markerId: MarkerId(doc.id),
            position: doctorLocation,
            infoWindow: InfoWindow(
              title: doctorName,
              snippet: '$doctorName - $specialty',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DoctorDetailScreen(doctorId: doc.id),
                  ),
                );
              },
            ),
            icon: BitmapDescriptor.defaultMarker,
          );

          setState(() {
            _markers.add(marker);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading nearby doctors: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

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

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });

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
    setState(() {
      _showSearchResults = true;
      _searchResults = [];
    });

    try {
      final QuerySnapshot doctorsSnapshot = await _doctorsCollection.get();
      final List<DocumentSnapshot> matchingDocs = [];

      for (var doc in doctorsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final searchableFields = [
          _getStringValue(data, ['name', 'fullName', 'doctorName', 'firstName']),
          _getStringValue(data, ['specialty', 'specialization', 'speciality', 'profession']),
          _getStringValue(data, ['location', 'city', 'area', 'address']),
        ];

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

      // Focus map on first result if available
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
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching doctors: $e');
    }
  }

  String _getStringValue(Map<String, dynamic> data, List<String> possibleKeys) {
    for (String key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null && data[key].toString().isNotEmpty) {
        return data[key].toString();
      }
    }
    return possibleKeys.first == 'name' ? 'Unknown Doctor' :
    possibleKeys.first == 'location' ? 'Location not specified' :
    'Not specified';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 30.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome! How may we be of service?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search doctor, specialty or location',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
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
                      zoomControlsEnabled: false,
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

                          final name = _getStringValue(doctorData, [
                            'name', 'fullName', 'doctorName', 'firstName',
                          ]);

                          final specialty = _getStringValue(doctorData, [
                            'specialty', 'specialization', 'speciality', 'profession',
                          ]);

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DoctorDetailScreen(doctorId: doctorId),
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
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.white,
                                    ),
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
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 100,
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

                      final Set<String> locations = {};
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final location = _getStringValue(data, [
                          'location', 'city', 'area', 'address',
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
                              _searchController.text = locationsList[index];
                              _handleSearch(locationsList[index]);
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

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildSearchResultItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = _getStringValue(data, [
      'name', 'fullName', 'doctorName', 'firstName',
    ]);
    final specialty = _getStringValue(data, [
      'specialty', 'specialization', 'speciality', 'profession',
    ]);
    final location = _getStringValue(data, [
      'location', 'city', 'area', 'address',
    ]);

    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: const Icon(
          Icons.person,
          size: 25,
          color: Colors.white,
        ),
      ),
      title: Text(name),
      subtitle: Text('$specialty • $location'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorDetailScreen(doctorId: doc.id),
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (index == 1) {
      // Navigate to profile
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MyAccountScreen()),
      );
    }
  }
}