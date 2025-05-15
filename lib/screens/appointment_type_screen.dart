import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'booking_confirmation_screen.dart';
import 'patient_chat_screen.dart';
import 'chat_service.dart';
import 'video_call_screen.dart';
import 'brain_tumor_detector.dart';
import 'alzheimer_detector.dart';
import 'multiple_sclerosis_detector.dart';

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
  State<AppointmentTypeScreen> createState() => _AppointmentTypeScreenState();
}

class _AppointmentTypeScreenState extends State<AppointmentTypeScreen> {
  final ChatService _chatService = ChatService();
  String? chatId;
  bool hasAcceptedAppointment = false;
  String? existingAppointmentType;

  bool _isLoading = false;
  Map<String, dynamic> _consultationRequestData = {
    'exists': false,
    'status': 'none'
  };

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _checkExistingAppointments();
    _checkConsultationRequest();
  }

  Future<void> _checkConsultationRequest() async {
    setState(() => _isLoading = true);

    try {
      var result = await _chatService.checkConsultationRequest(
          widget.doctorId, widget.patientId);
      setState(() {
        _consultationRequestData = result;
        _isLoading = false;
      });
    } catch (e) {
      print("Error checking consultation request: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendConsultationRequest() async {
    setState(() => _isLoading = true);

    try {
      bool result = await _chatService.createConsultationRequest(
        widget.doctorId,
        widget.patientId,
        widget.patientName,
      );
      setState(() {
        _consultationRequestData = {
          'exists': true,
          'status': result ? 'accepted' : 'pending'
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result
            ? "Consultation request accepted!"
            : "Consultation request sent! Please wait for doctor to accept."),
        backgroundColor: result ? Colors.green : Colors.orangeAccent,
      ));
    } catch (e) {
      print("Error sending consultation request: $e");
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending request: $e")),
      );
    }
  }

  Future<void> _checkExistingAppointments() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final existingAppointments = await firestore
          .collection("appointments")
          .where("client_id", isEqualTo: widget.patientId)
          .where("doctor_id", isEqualTo: widget.doctorId)
          .where("status", isEqualTo: "accepted")
          .get();

      if (existingAppointments.docs.isNotEmpty) {
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
        setState(() => chatId = id);
      }
    } catch (e) {
      print("Error initializing chat: $e");
    }
  }

  void _navigateToChat(String chatId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientChatScreen(
          chatId: chatId,
          doctorId: widget.doctorId,
          patientId: widget.patientId,
          patientName: widget.patientName,
        ),
      ),
    );
  }

  void _startVideoCall() {
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

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = Colors.teal,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasPendingRequest = _consultationRequestData['status'] == 'pending';
    bool hasAcceptedConsultation =
        _consultationRequestData['status'] == 'accepted';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 4,
        title: Text(
          hasAcceptedAppointment || hasAcceptedConsultation
              ? "Contact Doctor"
              : "Consult with Doctor",
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.teal,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasAcceptedAppointment || hasAcceptedConsultation) ...[
                    const SizedBox(height: 10),
                    const Text(
                      "Your consultation request has been accepted!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard(
                      icon: Icons.chat,
                      title: "Message Doctor",
                      subtitle: "Chat securely with your doctor",
                      onTap: () async {
                        if (chatId != null) {
                          _navigateToChat(chatId!);
                        } else {
                          String id = await _chatService.getChatId(
                              widget.doctorId, widget.patientId);
                          _navigateToChat(id);
                        }
                      },
                      color: Colors.teal,
                    ),
                    _buildOptionCard(
                      icon: Icons.video_call,
                      title: "Start Video Call",
                      subtitle: "Talk face-to-face with your doctor",
                      onTap: _startVideoCall,
                      color: Colors.teal,
                    ),
                    _buildOptionCard(
                      icon: Icons.medical_services,
                      title: "AI Diagnose",
                      subtitle: "Analyze brain MRI scans with AI",
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Select Diagnosis Type'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              BrainTumorDetector(
                                                  patientId: widget.patientId),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.medical_services),
                                    label: const Text('Brain Tumor Detection'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AlzheimerDetector(
                                                  patientId: widget.patientId),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.medical_services),
                                    label: const Text('Alzheimer\'s Detection'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              MultipleSclerosisDetector(
                                                  patientId: widget.patientId),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.medical_services),
                                    label: const Text(
                                        'Multiple Sclerosis Detection'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      color: Colors.teal,
                    ),
                  ] else if (hasPendingRequest) ...[
                    const Spacer(),
                    const Icon(Icons.hourglass_top,
                        size: 60, color: Colors.amber),
                    const SizedBox(height: 16),
                    const Text(
                      "Your consultation request is pending...",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "You will be notified once the doctor accepts your request.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                    const Spacer(),
                  ] else ...[
                    const Spacer(),
                    const Text(
                      "Request a consultation",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.medical_services),
                      label: const Text("Request Consultation"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _sendConsultationRequest,
                    ),
                    const Spacer(),
                  ],
                  ElevatedButton.icon(
                    icon:
                        const Icon(Icons.cancel_outlined, color: Colors.white),
                    label: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
    );
  }
}
