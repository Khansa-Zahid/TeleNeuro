import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'video_call_screen.dart';
import 'chat_service.dart';
import 'patient_chat_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final String doctorName;
  final String specialization;
  final String appointmentType;
  final String appointmentId;

  const BookingConfirmationScreen({
    super.key,
    required this.doctorName,
    required this.specialization,
    required this.appointmentType,
    required this.appointmentId,
  });

  @override
  _BookingConfirmationScreenState createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  late Stream<DocumentSnapshot> _appointmentStream;
  final ChatService _chatService = ChatService();
  Map<String, dynamic>? _appointmentData;

  @override
  void initState() {
    super.initState();
    _setupAppointmentStream();
  }

  void _setupAppointmentStream() {
    _appointmentStream = FirebaseFirestore.instance
        .collection("appointments")
        .doc(widget.appointmentId)
        .snapshots();
  }

  Future<void> _initiateChat(String doctorId, String patientId) async {
    try {
      String chatId = await _chatService.getChatId(doctorId, patientId);
      if (chatId.isNotEmpty && mounted) {
        // Get patient name
        DocumentSnapshot patientSnapshot = await FirebaseFirestore.instance
            .collection('clients')
            .doc(patientId)
            .get();
        String patientName = 'Patient';
        if (patientSnapshot.exists) {
          final patientData = patientSnapshot.data() as Map<String, dynamic>;
          patientName = patientData['name'] ?? 'Patient';
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientChatScreen(
              chatId: chatId,
              doctorId: doctorId,
              patientId: patientId,
              patientName: patientName,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to initiate chat")),
        );
      }
    } catch (e) {
      print("Error starting chat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _initiateVideoCall(String doctorId, String patientId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          doctorId: doctorId,
          patientId: patientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointment Status"),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _appointmentStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _appointmentData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            _appointmentData = snapshot.data!.data() as Map<String, dynamic>;
          }

          if (_appointmentData == null) {
            return const Center(child: Text("Appointment not found"));
          }

          String status = _appointmentData!["status"] ?? "pending";
          String doctorId = _appointmentData!["doctor_id"] ?? "";
          String patientId = _appointmentData!["client_id"] ?? "";
          String appointmentType =
              _appointmentData!["appointment_type"] ?? widget.appointmentType;
          String patientName = _appointmentData!["client_name"] ?? "Patient";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),

                // Status Banner
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Status: $status",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 30),

                // Status Icon
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 80,
                ),

                const SizedBox(height: 20),

                // Status Text
                Text(
                  _getStatusMessage(status),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
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

                // Action buttons that only appear if status is "Accepted"
                if (status.toLowerCase() == "accepted")
                  Column(
                    children: [
                      if (appointmentType == "Video Call")
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () =>
                              _initiateVideoCall(doctorId, patientId),
                          icon:
                              const Icon(Icons.video_call, color: Colors.white),
                          label: const Text(
                            "Start Video Call",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (appointmentType == "Message")
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _initiateChat(doctorId, patientId),
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text(
                            "Start Chat",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),

                // Back to Home Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.home, color: Colors.white),
                  label: const Text(
                    "Back to Home",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
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
        subtitle: Text(value,
            style: const TextStyle(fontSize: 16, color: Colors.black87)),
        leading: const Icon(Icons.info, color: Colors.teal),
      ),
    );
  }

  // Helper function to get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange;
      case "accepted":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper function to get icon based on status
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Icons.hourglass_empty;
      case "accepted":
        return Icons.check_circle_outline;
      case "rejected":
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  // Helper function to get message based on status
  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return "Your request is waiting for doctor's approval";
      case "accepted":
        return "Your appointment has been accepted!";
      case "rejected":
        return "Your appointment request was declined";
      default:
        return "Unknown status";
    }
  }
}
