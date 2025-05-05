import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'favoritespage.dart'; // Import for navigation
import 'homepage.dart'; // Import for navigation

class MyAccountPage extends StatefulWidget {
  final String? userId;

  const MyAccountPage({super.key, this.userId});

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  bool _isEditing = false;
  String? _errorMessage;
  bool _isDarkMode = false;
  final int _selectedIndex = 2; // My Account is selected by default (index 2)
  
  // User data
  Map<String, dynamic> _userData = {};
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _contactsController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _contactsController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // Load user data from Firestore
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user ID or use the one passed to the widget
      final String userId = widget.userId ?? _auth.currentUser!.uid;
      
      // Fetch user data from Firestore
      final DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        if (mounted) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
            
            // Initialize controllers with user data
            _contactsController.text = _userData['contacts'] ?? '';
            _usernameController.text = _userData['username'] ?? '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'User data not found';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading user data: ${e.toString()}';
        });
      }
      debugPrint('Error loading user data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Save updated user data to Firestore
  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the form errors')),
      );
      return;
    }

    // Store the current context before async operation
    final BuildContext contextBeforeAsync = context;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String userId = widget.userId ?? _auth.currentUser!.uid;
      
      // Create updated user data with only contacts and username
      final Map<String, dynamic> updatedData = {
        'contacts': _contactsController.text.trim(),
        'username': _usernameController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // Update user document in Firestore
      await _firestore.collection('users').doc(userId).update(updatedData);
      
      // Refresh user data
      await _loadUserData();
      
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        
        ScaffoldMessenger.of(contextBeforeAsync).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error updating profile: ${e.toString()}';
        });
      }
      debugPrint('Error updating profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Handle navigation based on item tapped in bottom navigation bar
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // No need to navigate if already on the page
    
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FavoritesPage()),
      );
    } else if (index == 2) {
      // Already on My Account page
    }
  }

  // Modified logout function to navigate back to main.dart's HomePageWithSearch
  Future<void> _logout() async {
    try {
      await _auth.signOut();
      
      // Navigate back to the main screen (HomePageWithSearch) after logout
      if (mounted) {
        // Use Navigator.pushNamedAndRemoveUntil to go back to the main route
        // and remove all routes in between
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/', // Root route which is HomePageWithSearch in main.dart
          (route) => false, // Remove all routes
        );
      }
    } catch (e) {
      debugPrint('Error during logout: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: ${e.toString()}')),
        );
      }
    }
  }

  // Toggle theme mode
  void _toggleThemeMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Apply theme based on dark mode setting
    final ThemeData theme = _isDarkMode 
        ? ThemeData.dark().copyWith(
            primaryColor: Colors.blueGrey[800],
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.blueGrey[900],
            ),
          )
        : ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blue,
            ),
          );
          
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Account'),
          actions: [
            // Theme toggle
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleThemeMode,
              tooltip: _isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            ),
            // Edit button (only appears when not in editing mode)
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
                tooltip: 'Edit Profile',
              ),
            // Logout button
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
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
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: _isEditing ? _buildEditForm() : _buildProfileView(),
    );
  }

  Widget _buildProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: _isDarkMode ? Colors.blueGrey.shade700 : Colors.blue.shade100,
                child: Text(
                  _getInitials(),
                  style: TextStyle(
                    fontSize: 40,
                    color: _isDarkMode ? Colors.white : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _userData['fullName'] ?? 'User',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // User information
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoTile('Email', '${_userData['email'] ?? 'N/A'}'),
                _buildInfoTile('Username', '${_userData['username'] ?? 'N/A'}'),
                _buildInfoTile('Gender', '${_userData['gender'] ?? 'N/A'}'),
                _buildInfoTile('Contact', '${_userData['contacts'] ?? 'N/A'}'),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Edit Profile button
        Center(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Logout button
        Center(
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit Profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          // Display name (non-editable)
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Information (Non-editable)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReadOnlyField('Full Name', _userData['fullName'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _buildReadOnlyField('Email', _userData['email'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _buildReadOnlyField('Gender', _userData['gender'] ?? 'N/A'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Editable Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Username
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a username';
              }
              return null;
            },
          ),
          const SizedBox(height: 16.0),
          
          // Contacts
          TextFormField(
            controller: _contactsController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your contact number';
              }
              return null;
            },
          ),
          const SizedBox(height: 32.0),
          
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    // Reset form fields to original values
                    _contactsController.text = _userData['contacts'] ?? '';
                    _usernameController.text = _userData['username'] ?? '';
                  });
                },
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _saveUserData,
                icon: const Icon(Icons.save),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      )
                    : const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: _isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: _isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  String _getInitials() {
    final String fullName = _userData['fullName'] ?? '';
    final List<String> nameParts = fullName.split(' ');
    
    if (nameParts.isEmpty || fullName.isEmpty) {
      return '?';
    }
    
    if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    }
    
    return '${nameParts[0][0]}${nameParts[nameParts.length - 1][0]}'.toUpperCase();
  }
}