import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'booking_confirmation_screen.dart';
import 'chat_screen.dart';
import 'chat_service.dart';
import 'video_call_screen.dart';

class AppointmentTypeScreen extends StatefulWidget {
  final String patientId;
  final String patientName; // New parameter added
  final String doctorId;
  final String doctorName;
  final String specialization;
  final String channelName;

  const AppointmentTypeScreen({
    super.key,
    required this.patientId,
    required this.patientName, // Required now
    required this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.channelName,
  });

  @override
  _AppointmentTypeScreenState createState() => _AppointmentTypeScreenState();
}

class _AppointmentTypeScreenState extends State<AppointmentTypeScreen> {
  final ChatService _chatService = ChatService();
  String? chatId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      String id = await _chatService.getChatId(widget.doctorId, widget.patientId);
      if (id.isNotEmpty) {
        setState(() {
          chatId = id;
        });
      }
    } catch (e) {
      print("Error initializing chat: $e");
    }
  }
  void _navigateToChat(String chatId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          doctorId: widget.doctorId,
          patientId: widget.patientId,
        ),
      ),
    );
  }

  Future<void> _bookAppointment(String appointmentType) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      DocumentReference appointmentRef = await firestore.collection("appointments").add({
        "client_id": widget.patientId,
        "doctor_id": widget.doctorId,
        "status": "pending",
        "date_time": DateTime.now().toIso8601String(),
        "appointment_type": appointmentType,
      });

      String appointmentId = appointmentRef.id;

      await _storeNotification(
        receiverId: widget.doctorId,
        title: "New Appointment Request",
        message: "A patient has booked an appointment.",
        type: "appointment",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment booked successfully!")),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmationScreen(
            doctorName: widget.doctorName,
            specialization: widget.specialization,
            appointmentType: appointmentType,
            appointmentId: appointmentId,
          ),
        ),
      );
    } catch (e) {
      print("Error booking appointment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to book appointment. Try again.")),
      );
    }
  }

  Future<void> _storeNotification({
    required String receiverId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await FirebaseFirestore.instance.collection("notifications").add({
        "receiver_id": receiverId,
        "title": title,
        "message": message,
        "type": type,
        "timestamp": FieldValue.serverTimestamp(),
        "read": false,
      });
    } catch (e) {
      print("Error storing notification: $e");
    }
  }

  Widget _buildAppointmentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal[700],
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.teal[700]),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Appointment Type"),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Select how you want to consult with the doctor:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            _buildAppointmentOption(
              title: "Video Call",
              subtitle: "Have a face-to-face consultation.",
              icon: Icons.video_call,
              onTap: () => _bookAppointment("Video Call"),
            ),

            const SizedBox(height: 12),

            _buildAppointmentOption(
              title: "Message",
              subtitle: "Chat with the doctor for quick queries.",
              icon: Icons.chat_bubble_outline,
              onTap: () async {
                if (chatId == null || chatId!.isEmpty) {
                  try {
                    String id = await _chatService.getChatId(widget.doctorId, widget.patientId);
                    setState(() {
                      chatId = id;
                    });
                    _navigateToChat(id);
                  } catch (e) {
                    print("Error fetching chat ID: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to start chat. Please try again.")),
                    );
                  }
                } else {
                  _navigateToChat(chatId!);
                }
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.cancel, color: Colors.white),
              label: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
