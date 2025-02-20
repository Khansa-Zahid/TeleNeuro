import 'package:flutter/material.dart';
import 'booking_confirmation_screen.dart';
import 'message_chat_screen.dart';

class AppointmentTypeScreen extends StatelessWidget {
  final String doctorName;
  final String specialization;

  const AppointmentTypeScreen({
    super.key,
    required this.doctorName,
    required this.specialization,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointment Type"),
        backgroundColor: Colors.teal[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Choose an appointment type:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      appointmentType: "Voice Call",
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
                      appointmentType: "Video Call",
                    ),
                  ),
                );
              },
              child: const Text("Video Call"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MessageChatScreen(
                      doctorName: doctorName,
                      specialization: specialization,
                    ),
                  ),
                );
              },
              child: const Text("Message"),
            ),
          ],
        ),
      ),
    );
  }
}
