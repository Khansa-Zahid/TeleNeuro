import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'booking_confirmation_screen.dart';
import 'chat_screen.dart';
import 'chat_service.dart';
import 'video_call_screen.dart';

class AppointmentTypeScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String specialization;
  final String channelName;

  const AppointmentTypeScreen({
    super.key,
    required this.patientId,
    required this.patientName,
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
  bool hasAcceptedAppointment = false;
  String? existingAppointmentType;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _checkExistingAppointments();
  }

  Future<void> _checkExistingAppointments() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      QuerySnapshot existingAppointments = await firestore
          .collection("appointments")
          .where("client_id", isEqualTo: widget.patientId)
          .where("doctor_id", isEqualTo: widget.doctorId)
          .where("status", isEqualTo: "accepted")
          .get();

      if (existingAppointments.docs.isNotEmpty) {
        // Get the appointment type from the first accepted appointment
        var appointmentData =
            existingAppointments.docs.first.data() as Map<String, dynamic>;

        setState(() {
          hasAcceptedAppointment = true;
          existingAppointmentType =
              appointmentData['appointment_type'] as String?;
        });
      }
    } catch (e) {
      print("Error checking existing appointments: $e");
    }
  }

  Future<void> _initializeChat() async {
    try {
      String id =
          await _chatService.getChatId(widget.doctorId, widget.patientId);
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

      // First, check if there's an existing accepted appointment between this patient and doctor
      QuerySnapshot existingAppointments = await firestore
          .collection("appointments")
          .where("client_id", isEqualTo: widget.patientId)
          .where("doctor_id", isEqualTo: widget.doctorId)
          .where("status", isEqualTo: "accepted")
          .get();

      // If there's an existing accepted appointment, go directly to chat or video call
      if (existingAppointments.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "You already have an accepted appointment with this doctor")),
        );

        // Go directly to the chat or video call based on appointment type
        if (appointmentType == "Message") {
          String chatId =
              await _chatService.getChatId(widget.doctorId, widget.patientId);
          if (chatId.isNotEmpty) {
            _navigateToChat(chatId);
          }
        } else if (appointmentType == "Video Call") {
          _initiateVideoCall();
        }
        return;
      }

      // Create appointment with pending status
      DocumentReference appointmentRef =
          await firestore.collection("appointments").add({
        "client_id": widget.patientId,
        "doctor_id": widget.doctorId,
        "status": "pending",
        "date_time": DateTime.now().toIso8601String(),
        "appointment_type": appointmentType,
        "client_name": widget.patientName,
      });

      String appointmentId = appointmentRef.id;

      // Send notification to doctor about pending appointment
      await _storeNotification(
        receiverId: widget.doctorId,
        title: "New Appointment Request",
        message:
            "${widget.patientName} has requested a ${appointmentType} appointment",
        type: "appointment_request",
        appointmentId: appointmentId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment request sent to doctor")),
      );

      // Navigate to booking confirmation screen to show status
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
        const SnackBar(
            content: Text("Failed to send appointment request. Try again.")),
      );
    }
  }

  Future<void> _storeNotification({
    required String receiverId,
    required String title,
    required String message,
    required String type,
    String? appointmentId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection("notifications").add({
        "receiver_id": receiverId,
        "title": title,
        "message": message,
        "type": type,
        "appointment_id": appointmentId,
        "sender_id": widget.patientId,
        "timestamp": FieldValue.serverTimestamp(),
        "read": false,
      });
    } catch (e) {
      print("Error storing notification: $e");
    }
  }

  void _initiateVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          doctorId: widget.doctorId,
          patientId: widget.patientId,
        ),
      ),
    );
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
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        title: hasAcceptedAppointment
            ? const Text("Contact Doctor")
            : const Text("Choose Appointment Type"),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasAcceptedAppointment)
              // Show message and options for already accepted appointments
              Column(children: [
                const Text(
                  "You already have an accepted appointment with this doctor.",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (existingAppointmentType == "Video Call" ||
                    existingAppointmentType == null)
                  _buildAppointmentOption(
                    title: "Video Call",
                    subtitle: "Have a face-to-face consultation.",
                    icon: Icons.video_call,
                    onTap: _initiateVideoCall,
                  ),
                const SizedBox(height: 12),
                if (existingAppointmentType == "Message" ||
                    existingAppointmentType == null)
                  _buildAppointmentOption(
                    title: "Message",
                    subtitle: "Chat with the doctor for quick queries.",
                    icon: Icons.chat_bubble_outline,
                    onTap: () async {
                      if (chatId != null && chatId!.isNotEmpty) {
                        _navigateToChat(chatId!);
                      } else {
                        String id = await _chatService.getChatId(
                            widget.doctorId, widget.patientId);
                        if (id.isNotEmpty) {
                          _navigateToChat(id);
                        }
                      }
                    },
                  ),
              ])
            else
              // Show options for new appointment requests
              Column(
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
                    onTap: () => _bookAppointment("Message"),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.cancel, color: Colors.white),
              label: const Text(
                "Cancel",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
