
import 'package:flutter/material.dart';
import '../widgets/profile_option_card.dart';
import 'client_screen.dart';
import 'doctor_screen.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        flexibleSpace: const Center(
          child: Text(
            'Profile Selection',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: Colors.teal[600],
      ),
      body: Container(
        color: Colors.teal[50],
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Select your preferred profile type to Register',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                // Navigate to Client screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClientScreen(),
                  ),
                );
              },
              child: ProfileOptionCard(
                icon: Icons.person,
                title: 'Patient',
                subtitle: 'Book Appointments',
                    //'Consult with Doctors.',
                color: Colors.white,
                titleColor: Colors.teal[800]!, // Ensure it's non-null
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                // Navigate to Doctor screen without any parameters
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DoctorScreen(), // No doctor parameter
                  ),
                );
              },
              child: ProfileOptionCard(
                icon: Icons.local_hospital,
                title: 'Doctor',
                subtitle: 'Book Appointments',
                    //' Consult with patients.',
                color: Colors.white,
                titleColor: Colors.teal[800]!, // Ensure it's non-null
              ),
            ),
          ],
        ),
      ),
    );
  }
}