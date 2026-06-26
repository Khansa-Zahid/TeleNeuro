import 'package:flutter/material.dart';
import 'patient_login_screen.dart';
import 'patient_signup_screen.dart';

class ClientScreen extends StatelessWidget {
  const ClientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Patient Portal',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal[700],
        elevation: 4,
      ),
      body: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Welcome Image/Icon
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.teal[200],
              child: const Icon(Icons.health_and_safety, size: 50, color: Colors.teal),
            ),
            const SizedBox(height: 20),

            // Welcome Text
            const Text(
              'Welcome to the Patient Portal!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Text(
              'Login or sign up to manage your health records, book appointments.dart, and consult with doctors.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 30),

            // Login Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClientLoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 20),

            // Sign Up Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClientSignupScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.teal[700]!),
                ),
                elevation: 4,
              ),
              child: Text(
                'Sign Up',
                style: TextStyle(fontSize: 18, color: Colors.teal[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
