import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';
import 'screens/doctor_list_screen.dart'; // Import the Doctor List Screen
import 'screens/doctor_signup_screen.dart'; // Import the Doctor Signup Screen
import 'screens/doctor_login_screen.dart'; // Import the Doctor Login Screen
import 'screens/find_doctor_screen.dart'; // Import the Find Doctor Screen
import 'screens/doctor_screen.dart'; // Import the Doctor Screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeleNeuro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: OnboardingScreen(), // Removed const keyword
      routes: {
        '/doctor': (context) => const DoctorScreen(),
        '/signup': (context) => const DoctorSignupScreen(),
        '/login': (context) => const DoctorLoginScreen(),
        '/findDoctor': (context) => const FindDoctorScreen(),
        '/doctorList': (context) => DoctorListScreen(), // Removed const keyword
      },
    );
  }
}