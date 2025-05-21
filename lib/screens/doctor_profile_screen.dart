import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'doctor_appointments_screen.dart';
import 'profile_selection_screen.dart';
import 'Doctor_Profile_Completion_Screen.dart';
import 'doctor_prescription_screen.dart';
import 'select_patient_screen.dart';
import 'doctor_chats_list_screen.dart';
import 'chat_service.dart';
import 'doctor_reports_screen.dart';
import 'chat_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;

  const DoctorProfileScreen({super.key, required this.doctorId});

  @override
  _DoctorProfileScreenState createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String currentTime = '';
  String doctorName = "Loading...";
  List<Map<String, dynamic>> notifications = [];
  bool isDropdownVisible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _fetchDoctorName();
    _setupNotificationsStream();
    _timer =
        Timer.periodic(const Duration(minutes: 1), (timer) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      currentTime = DateFormat.Hm().format(DateTime.now());
    });
  }

  Future<void> _fetchDoctorName() async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('doctors').doc(widget.doctorId).get();
      if (doc.exists && mounted) {
        setState(() {
          doctorName = doc['name'] ?? "Unknown Doctor";
        });
      }
    } catch (e) {
      debugPrint("Error fetching doctor name: $e");
    }
  }

  void _setupNotificationsStream() {
    // Listen for notifications with receiver_id
    _firestore
        .collection('notifications')
        .where('receiver_id', isEqualTo: widget.doctorId)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          // Create a Set to track unique notification IDs
          Set<String> uniqueIds = {};
          notifications = [];

          // Add notifications from receiver_id query
          for (var doc in snapshot.docs) {
            var data = doc.data();
            data['id'] = doc.id;
            uniqueIds.add(doc.id);
            notifications.add(data);
          }
        });
      }
    });

    // Also listen for notifications with client_id
    _firestore
        .collection('notifications')
        .where('client_id', isEqualTo: widget.doctorId)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          // Add notifications from client_id query, avoiding duplicates
          for (var doc in snapshot.docs) {
            if (!notifications.any((n) => n['id'] == doc.id)) {
              var data = doc.data();
              data['id'] = doc.id;
              notifications.add(data);
            }
          }
          // Sort notifications by timestamp
          notifications.sort((a, b) {
            var aTime = a['timestamp'] as Timestamp?;
            var bTime = b['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
        });
      }
    });
  }

  Future<void> _markAsRead(String docId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(docId)
          .update({'read': true});
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  void _handleNotificationClick(Map<String, dynamic> notification) {
    String type = notification['type'] ?? '';
    switch (type) {
      case 'message':
        if (notification['chat_id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelectPatientScreen(
                doctorId: widget.doctorId,
                isForChat: true,
              ),
            ),
          );
        }
        break;
      case 'consultation_request':
        if (notification['patient_id'] != null) {
          _showConsultationRequestDialog(notification);
        }
        break;
      case 'appointment':
        if (notification['appointment_id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorAppointmentsScreen(
                doctorId: widget.doctorId,
              ),
            ),
          );
        }
        break;
      case 'prescription':
        if (notification['patient_id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorPrescriptionScreen(
                doctorId: widget.doctorId,
                patientId: notification['patient_id'],
              ),
            ),
          );
        }
        break;
      case 'report':
        if (notification['report_id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorReportsScreen(
                doctorId: widget.doctorId,
              ),
            ),
          );
        }
        break;
    }
  }

  Future<void> _showConsultationRequestDialog(
      Map<String, dynamic> notification) async {
    final ChatService chatService = ChatService();
    String patientId = notification['patient_id'];
    String patientName = notification['message']
        .toString()
        .split(' would like to consult with you')[0];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Consultation Request from $patientName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Would you like to accept this consultation request?'),
              SizedBox(height: 10),
              Text('Patient: $patientName',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Reject request
                await FirebaseFirestore.instance
                    .collection('consultation_requests')
                    .where('doctor_id', isEqualTo: widget.doctorId)
                    .where('patient_id', isEqualTo: patientId)
                    .where('status', isEqualTo: 'pending')
                    .get()
                    .then((snapshot) {
                  if (snapshot.docs.isNotEmpty) {
                    snapshot.docs.first.reference
                        .update({'status': 'rejected'});
                  }
                });

                // Notify patient
                await FirebaseFirestore.instance
                    .collection('notifications')
                    .add({
                  'receiver_id': patientId,
                  'sender_id': widget.doctorId,
                  'title': 'Consultation Request Rejected',
                  'message': 'Your consultation request was not accepted',
                  'timestamp': FieldValue.serverTimestamp(),
                  'read': false,
                  'type': 'consultation_rejected',
                });
              },
              child: Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Accept request
                await FirebaseFirestore.instance
                    .collection('consultation_requests')
                    .where('doctor_id', isEqualTo: widget.doctorId)
                    .where('patient_id', isEqualTo: patientId)
                    .where('status', isEqualTo: 'pending')
                    .get()
                    .then((snapshot) async {
                  if (snapshot.docs.isNotEmpty) {
                    String requestId = snapshot.docs.first.id;
                    await chatService.acceptConsultationRequest(requestId);
                  }
                });
              },
              child: Text('Accept', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  void _navigateToChatsList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectPatientScreen(
          doctorId: widget.doctorId,
          isForChat: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("Dashboard",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade700,
        actions: [
          _buildNotificationIcon(),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 20),
                Expanded(child: _buildDashboardGrid()),
              ],
            ),
          ),
          if (isDropdownVisible) _buildNotificationDropdown(),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications, size: 30, color: Colors.white),
          onPressed: () =>
              setState(() => isDropdownVisible = !isDropdownVisible),
        ),
        if (notifications.isNotEmpty)
          Positioned(
            right: 6,
            top: 6,
            child: CircleAvatar(
              backgroundColor: Colors.red,
              radius: 10,
              child: Text(
                '${notifications.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.teal.shade600, Colors.indigo.shade300]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2)
        ],
      ),
      child: Column(
        children: [
          Text("Welcome, Dr. $doctorName!",
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 5),
          Text(currentTime,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _buildDashboardCard(
          icon: Icons.calendar_today,
          title: "Appointments",
          color: Colors.orange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    DoctorAppointmentsScreen(doctorId: widget.doctorId)),
          ),
        ),
        _buildDashboardCard(
          icon: Icons.chat,
          title: "Patient Consultations",
          color: Colors.indigo,
          onTap: _navigateToChatsList,
        ),
        _buildDashboardCard(
          icon: Icons.folder_shared,
          title: "Reports",
          color: Colors.purple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    DoctorReportsScreen(doctorId: widget.doctorId)),
          ),
        ),
        _buildDashboardCard(
          icon: Icons.person,
          title: "Update Profile",
          color: Colors.teal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    DoctorProfileCompletionScreen(doctorId: widget.doctorId)),
          ),
        ),
        _buildDashboardCard(
          icon: Icons.description,
          title: "Prescriptions",
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    SelectPatientScreen(doctorId: widget.doctorId)),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationDropdown() {
    return Positioned(
      top: 0,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 300,
          constraints: const BoxConstraints(maxHeight: 400),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => isDropdownVisible = false),
                  ),
                ],
              ),
              const Divider(),
              notifications.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(
                          child: Text("No new notifications",
                              style: TextStyle(color: Colors.grey))),
                    )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          return _buildNotificationItem(notifications[index]);
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    String notifType = notification['type'] ?? 'general';
    IconData iconData;
    Color iconColor;

    switch (notifType) {
      case 'appointment_request':
        iconData = Icons.calendar_today;
        iconColor = Colors.orange;
        break;
      case 'message':
        iconData = Icons.chat;
        iconColor = Colors.green;
        break;
      case 'consultation_request':
        iconData = Icons.medical_services;
        iconColor = Colors.indigo;
        break;
      case 'prescription':
        iconData = Icons.medication;
        iconColor = Colors.blue;
        break;
      case 'report':
        iconData = Icons.assessment;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.green;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.2),
        child: Icon(iconData, color: iconColor),
      ),
      title: Text(
        notification['title'] ?? 'Notification',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification['message'] ?? ''),
          if (notification['timestamp'] != null)
            Text(
              DateFormat('MMM d, h:mm a').format(
                (notification['timestamp'] as Timestamp).toDate(),
              ),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
      onTap: () {
        _markAsRead(notification['id']);
        _handleNotificationClick(notification);
        setState(() => isDropdownVisible = false);
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.teal.shade700),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.indigo),
                ),
                const SizedBox(height: 10),
                Text(
                  "Dr. $doctorName",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            Icons.dashboard,
            "Dashboard",
            () => Navigator.pop(context),
          ),
          _buildDrawerItem(
            Icons.calendar_today,
            "Appointments",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DoctorAppointmentsScreen(doctorId: widget.doctorId),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.chat,
            "Patient Consultations",
            () {
              Navigator.pop(context);
              _navigateToChatsList();
            },
          ),
          _buildDrawerItem(
            Icons.folder_shared,
            "Medical Reports",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DoctorReportsScreen(doctorId: widget.doctorId),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.person,
            "Update Profile",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DoctorProfileCompletionScreen(doctorId: widget.doctorId),
                ),
              );
            },
          ),
          const Divider(),
          _buildDrawerItem(
            Icons.logout,
            "Logout",
            () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProfileSelectionScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal.shade700),
      title: Text(title),
      onTap: onTap,
    );
  }
}
