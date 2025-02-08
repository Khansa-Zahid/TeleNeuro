import 'package:flutter/material.dart';
import 'booking_confirmation_screen.dart';

class BookingScreen extends StatelessWidget {
  final String doctorName;
  final String specialization;

  const BookingScreen({
    Key? key,
    required this.doctorName,
    required this.specialization,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Appointment"),
        backgroundColor: Colors.teal[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Select Appointment Type with Dr. $doctorName",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingConfirmationScreen(
                      doctorName: doctorName,
                      specialization: specialization,
                      appointmentType: 'Voice Call',
                    ),
                  ),
                );
              },
              child: const Text("Voice Call"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingConfirmationScreen(
                      doctorName: doctorName,
                      specialization: specialization,
                      appointmentType: 'Video Call',
                    ),
                  ),
                );
              },
              child: const Text("Video Call"),
            ),
          ],
        ),
      ),
    );
  }
}