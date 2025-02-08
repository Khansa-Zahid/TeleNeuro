import 'package:flutter/material.dart';
import 'doctor_list_screen.dart';

class AppointmentStatusScreen extends StatelessWidget {
  final bool isAccepted;

  const AppointmentStatusScreen({
    Key? key,
    required this.isAccepted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointment Status"),
        backgroundColor: Colors.teal[700],
      ),
      body: Center(
        child: isAccepted
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            const Text(
              "Your appointment has been accepted!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  DoctorListScreen(),
                  ),
                );
              },
              child: const Text("Back to Doctor List"),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cancel,
              size: 100,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              "Your appointment has been rejected.",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  DoctorListScreen(),
                  ),
                );
              },
              child: const Text("Choose Another Doctor"),
            ),
          ],
        ),
      ),
    );
  }
}