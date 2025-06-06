import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:doctor_finder_flutter/firebase_options.dart';
import 'package:doctor_finder_flutter/screens/home/home_screen.dart';
import 'package:doctor_finder_flutter/screens/auth/login_screen.dart';
import 'package:doctor_finder_flutter/screens/auth/registration_screen.dart';
import 'package:doctor_finder_flutter/screens/profile/my_account_screen.dart';
import 'package:doctor_finder_flutter/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Failed to initialize Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Finder',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/profile': (context) => const MyAccountScreen(),
      },
    );
  }
}