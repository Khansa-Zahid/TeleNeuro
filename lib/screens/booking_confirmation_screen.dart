import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final String doctorName;
  final String specialization;
  final String appointmentType;
  final String appointmentId; // Needed to fetch status

  const BookingConfirmationScreen({
    super.key,
    required this.doctorName,
    required this.specialization,
    required this.appointmentType,
    required this.appointmentId,
  });

  @override
  _BookingConfirmationScreenState createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  String appointmentStatus = "Fetching...";

  @override
  void initState() {
    super.initState();
    _fetchAppointmentStatus();
  }

  Future<void> _fetchAppointmentStatus() async {
    try {
      DocumentSnapshot appointmentSnapshot = await FirebaseFirestore.instance
          .collection("appointments")
          .doc(widget.appointmentId)
          .get();

      if (appointmentSnapshot.exists) {
        setState(() {
          appointmentStatus = appointmentSnapshot["status"];
        });
      } else {
        setState(() {
          appointmentStatus = "Unknown";
        });
      }
    } catch (e) {
      print("Error fetching appointment status: $e");
      setState(() {
        appointmentStatus = "Error fetching status";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointment Confirmed"),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // Status Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: _getStatusColor(appointmentStatus),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Status: $appointmentStatus",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 30),

            // Success Icon
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 80,
            ),

            const SizedBox(height: 20),

            // Confirmation Text
            const Text(
              "Your appointment is confirmed!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            Text(
              "Details of your appointment are below:",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            // Appointment Details
            _buildDetailTile("Doctor", widget.doctorName),
            _buildDetailTile("Specialization", widget.specialization),
            _buildDetailTile("Appointment Type", widget.appointmentType),

            const SizedBox(height: 40),

            // Back to Home Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.home, color: Colors.white),
              label: const Text(
                "Back to Home",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Appointment Details
  Widget _buildDetailTile(String title, String value) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        leading: const Icon(Icons.info, color: Colors.teal),
      ),
    );
  }

  // Helper function to get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange;
      case "confirmed":
        return Colors.green;
      case "cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
