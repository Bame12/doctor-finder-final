import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'homepage.dart';
import 'myaccountpage.dart'; // Import the MyAccountPage

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _contactsController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // For gender selection
  String? _selectedGender;
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Check if we need to set reCAPTCHA verification for this platform
    _configureRecaptchaIfNeeded();
  }

  // Configure reCAPTCHA verification settings
  Future<void> _configureRecaptchaIfNeeded() async {
    try {
      // Only set reCAPTCHA verification timeout for web platform
      if (kIsWeb) {
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: kDebugMode, // Disable for testing if in debug mode
        );
      }
    } catch (e) {
      print('Error configuring reCAPTCHA: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _firstNameController.dispose();
    _surnameController.dispose();
    _contactsController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    // First validate form
    if (!_formKey.currentState!.validate()) {
      // Show message if validation fails
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the form errors')),
      );
      return;
    }
    
    // Validate gender selection
    if (_selectedGender == null) {
      setState(() {
        _errorMessage = "Please select your gender";
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create user with email and password
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _newPasswordController.text,
      );
      
      // Get full name by combining first name and surname
      final String fullName = "${_firstNameController.text.trim()} ${_surnameController.text.trim()}";
      
      // Store additional user information in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'fullName': fullName,
        'firstName': _firstNameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'email': _emailController.text.trim(),
        'username': _usernameController.text.trim(),
        'contacts': _contactsController.text.trim(),
        'gender': _selectedGender,
        'created_at': FieldValue.serverTimestamp(),
        'role': 'patient', // Default role
      });

      // Navigate to account page after successful registration
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        
        // Show dialog asking if user wants to view their profile
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Registration Successful'),
              content: const Text('Your account has been created successfully. Would you like to view your profile?'),
              actions: [
                TextButton(
                  onPressed: () {
                    // Navigate to the HomePage if user doesn't want to view profile
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                      (route) => false,
                    );
                  },
                  child: const Text('Go to Home'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to the MyAccountPage with the user ID
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyAccountPage(
                          userId: userCredential.user!.uid,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('View Profile'),
                ),
              ],
            );
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Email/password accounts are not enabled. Contact support.';
      } else {
        // Log the error code to help with debugging
        print('Firebase Auth error code: ${e.code}');
        errorMessage = 'Error: ${e.message}';
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      print('Registration error: ${e.toString()}');
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      // Set loading state to false regardless of outcome
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Customer Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First Name
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First name/s',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name(s)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              
              // Surname
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(
                  labelText: 'Surname',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your surname';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              
              // Gender selection
              const Text('Gender', style: TextStyle(fontSize: 16.0)),
              Row(
                children: <Widget>[
                  Radio<String>(
                    value: 'Male',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  const Text('Male'),
                  const SizedBox(width: 16.0),
                  Radio<String>(
                    value: 'Female',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  const Text('Female'),
                  const SizedBox(width: 16.0),
                  Radio<String>(
                    value: 'Other',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  const Text('Other'),
                ],
              ),
              if (_selectedGender == null && _errorMessage != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Please select your gender',
                    style: TextStyle(color: Colors.red, fontSize: 12.0),
                  ),
                ),
              const SizedBox(height: 16.0),
              
              // Contacts
              TextFormField(
                controller: _contactsController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contacts',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your contact number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              
              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              
              // Username
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              
              // New Password
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              
              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              
              // Error Message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              
              const SizedBox(height: 24.0),
              
              // Register Button
              ElevatedButton(
                onPressed: _isLoading ? null : _registerUser,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      )
                    : const Text('REGISTER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}