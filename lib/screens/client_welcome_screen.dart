import 'package:flutter/material.dart';
import 'dart:async';
import 'find_doctor_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  final String patientName;

  const WelcomeScreen({super.key, required this.patientName});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _time = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  void _updateTime() {
    setState(() {
      _time = _formatTime();
    });
  }

  String _formatTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal[500],
       // title: const Text("Welcome"),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal[500]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.teal),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.patientName,
                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Patient",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.teal),
              title: const Text("Edit Profile"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Edit Profile clicked")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_services, color: Colors.teal),
              title: const Text("Consult a Doctor"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context)=>FindDoctorScreen())
                );

              },
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Greeting and Time
            const SizedBox(height: 20),
            Text(
              "Hi ${widget.patientName}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _time,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Icons for "Request History" and "Notifications"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.teal, size: 30),
                        onPressed: () {},
                      ),
                      const Text("Request History", style: TextStyle(color: Colors.teal))
                    ],
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications, color: Colors.teal, size: 30),
                        onPressed: () {},
                      ),
                      const Text("Notifications", style: TextStyle(color: Colors.teal))
                    ],
                  ),
                ],
              ),
            ),

            // Spacer to push button to the bottom
            const Spacer(),

            // Bottom button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Colors.teal),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.teal,
                ),
                child: const Text(""),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
