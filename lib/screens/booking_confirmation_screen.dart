import 'package:flutter/material.dart';
import 'appointment_status_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final String doctorName;
  final String specialization;
  final String appointmentType;

  const BookingConfirmationScreen({
    Key? key,
    required this.doctorName,
    required this.specialization,
    required this.appointmentType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Confirmation"),
        centerTitle: true,
        backgroundColor: Colors.teal[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 100,
              color: Colors.teal,
            ),
            const SizedBox(height: 20),
            Text(
              "Your appointment with Dr. $doctorName has been successfully booked!",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Specialization: $specialization",
              style: const TextStyle (fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Appointment Type: $appointmentType",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Simulate appointment status
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppointmentStatusScreen(
                      isAccepted: true, // Change this to false to simulate rejection
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text("Confirm Booking"),
            ),
          ],
        ),
      ),
    );
  }
}