import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';
import 'screens/doctor_list_screen.dart';
import 'screens/doctor_signup_screen.dart';
import 'screens/doctor_login_screen.dart';
import 'screens/find_doctor_screen.dart';
import 'screens/doctor_screen.dart';
import 'screens/client_login_screen.dart';
import 'screens/client_signup_screen.dart';

void main()async {
  WidgetsFlutterBinding.ensureInitialized();
  if(kIsWeb) {
    Firebase.initializeApp(options: FirebaseOptions(
        apiKey: "AIzaSyDJodDDsyLbb9xvMRRUDNmlhV8EW4hTRis",
        authDomain: "fypteleneuro.firebaseapp.com",
        projectId: "fypteleneuro",
        storageBucket: "fypteleneuro.firebasestorage.app",
        messagingSenderId: "205605587304",
        appId: "1:205605587304:web:1a40cedb7f911cc531eedd",
        measurementId: "G-BTCBSZ9JQS"));
  }
  else{
    await Firebase.initializeApp();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeleNeuro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const OnboardingScreen(), // Removed const keyword
      routes: {
        '/doctor': (context) => const DoctorScreen(),
        '/signup': (context) => const DoctorSignupScreen(),
        '/login': (context) => const DoctorLoginScreen(),
        '/findDoctor': (context) => const FindDoctorScreen(),
        '/doctorList': (context) =>  DoctorListScreen(),
        '/clientLoginsScreen':(context) =>ClientLoginScreen(),
        '/clientSignupScreen':(context)=>ClientSignupScreen(),
      },
    );
  }
}