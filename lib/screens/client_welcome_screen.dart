import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_selection_screen.dart';
import 'find_doctor_screen.dart';
import 'patient_prescription_screen.dart';
import 'appointment_status_screen.dart';
import 'patient_profile_completion_screen.dart';
import 'patient_profile_display_screen.dart';
import 'brain_tumor_detector.dart';

class WelcomeScreen extends StatefulWidget {
  final String patientName;
  final String patientId;

  const WelcomeScreen({
    super.key,
    required this.patientName,
    required this.patientId,
  });

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _time = '';
  late Timer _timer;
  int unreadNotifications = 0;
  List<Map<String, dynamic>> notifications = [];
  bool showDropdown = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
    _fetchUnreadNotifications();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final newTime = _formatTime();
    if (mounted && newTime != _time) {
      setState(() {
        _time = newTime;
      });
    }
  }

  String _formatTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _fetchUnreadNotifications() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('client_id', isEqualTo: widget.patientId)
        .where('status', isEqualTo: 'unread') // Use string literal
        // .where('title', whereIn: ['New Appointment Request', 'Appointment Update'])
        // .get();
        .snapshots()
        .listen((snapshot) {
      print("Fetched Notifications: ${snapshot.docs.length}");
      for (var doc in snapshot.docs) {
        print("Notification: ${doc.data()}");
      }

      setState(() {
        unreadNotifications = snapshot.docs.length;
        notifications = snapshot.docs.map((doc) {
          return {
            'id': doc.id, // Assign document ID manually
            ...doc.data(),
          };
        }).toList();
      });
    });
  }

  void _toggleDropdown() {
    if (mounted) {
      setState(() {
        showDropdown = !showDropdown;
      });
    }
  }

  void _markAsRead(String notificationId) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId) // Use document ID
        .update({'status': 'read'});
  }

  void _logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade400,
        title: const Text(
          "Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Stack(
            clipBehavior: Clip.none, // Allows positioning outside Stack
            children: [
              IconButton(
                icon: const Icon(Icons.notifications,
                    size: 30, color: Colors.white),
                onPressed: _toggleDropdown,
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: 6, // Adjust left/right
                  top: 6, // Move above the bell icon
                  child: CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 10,
                    child: Text(
                      unreadNotifications.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.teal.shade400),
              accountName: Text(
                widget.patientName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: const Text(
                "Patient",
                style: TextStyle(color: Colors.white70),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.teal),
              ),
            ),
            _drawerItem(Icons.person, "Edit Profile", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientProfileCompletionScreen(
                      patientId: widget.patientId),
                ),
              );
            }),
            //  _drawerItem(Icons.notifications, "Notifications", () {}),
            _drawerItem(Icons.medical_services, "Find a Doctor", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        FindDoctorScreen(patientId: widget.patientId)),
              );
            }),
            const Divider(),
            _drawerItem(Icons.logout, "Logout", () => _logout(context)),
          ],
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      children: [
                        // _dashboardCard(
                        //     Icons.history, "Request History", Colors.orange),
                        _dashboardCard(Icons.dashboard,
                            "Patient Profile Display", Colors.blue, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientProfileDisplayScreen(
                                  patientId: widget.patientId),
                            ),
                          );
                        }),
                        _dashboardCard(Icons.account_circle, "Patient Profile",
                            Colors.blue, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PatientProfileCompletionScreen(
                                      patientId: widget.patientId),
                            ),
                          );
                        }),
                        _dashboardCard(Icons.local_hospital, "Consult a Doctor",
                            Colors.green, () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => FindDoctorScreen(
                                      patientId: widget.patientId)));
                        }),
                        _dashboardCard(
                            Icons.medical_information, "Reports", Colors.purple,
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientPrescriptionScreen(
                                  patientId: widget.patientId),
                            ),
                          );
                        }),
                        _dashboardCard(
                            Icons.event_note, "My Appointments", Colors.red,
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AppointmentStatusScreen(
                                  clientId: widget.patientId),
                            ),
                          );
                        }),
                        _dashboardCard(Icons.medical_services, "AI Diagnose",
                            Colors.deepPurple, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BrainTumorDetector(
                                  patientId: widget.patientId),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔥 Dropdown Positioned Below AppBar
          if (showDropdown)
            Positioned(
              top: kToolbarHeight + 10, // Places it below the AppBar
              right: 10,
              child: Material(
                elevation: 5,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: notifications.isNotEmpty
                        ? notifications.map((notif) {
                            return ListTile(
                              title: Text(notif['title'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(notif['message'] ?? ''),
                              onTap: () {
                                _markAsRead(notif['id']);
                                _toggleDropdown();
                              },
                            );
                          }).toList()
                        : [
                            const Text("No new notifications",
                                style: TextStyle(color: Colors.grey))
                          ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal.shade600),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }

  Widget _buildNotificationDropdown() {
    return Positioned(
      top: 60,
      right: 10,
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 250,
          constraints: BoxConstraints(
            maxHeight: 400, // Prevents excessive height
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            // 🔥 Scrollable content prevents overflow
            child: Column(
              mainAxisSize: MainAxisSize.min, // Avoids unnecessary space
              children: notifications.map((notification) {
                return ListTile(
                  title: Text(notification['title'] ?? 'No Title'),
                  subtitle: Text(notification['body'] ?? 'No Body'),
                  onTap: () {
                    setState(() {
                      showDropdown = false;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.teal.shade400, Colors.teal.shade200]),
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
          Text(
            widget.patientName,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(_time,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _dashboardCard(IconData icon, String title, Color color,
      [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 8,
                offset: const Offset(0, 4)),
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
}
