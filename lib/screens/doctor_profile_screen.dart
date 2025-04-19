import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';
import 'chat_service.dart';
import 'doctor_appointments_screen.dart';
import 'profile_selection_screen.dart';
import 'Doctor_Profile_Completion_Screen.dart';
import 'doctor_prescription_screen.dart';
import 'select_patient_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;

  const DoctorProfileScreen({super.key, required this.doctorId});

  @override
  _DoctorProfileScreenState createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final ChatService _chatService = ChatService();
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
    _fetchNotifications();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) => _updateTime());
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
      DocumentSnapshot doc = await _firestore.collection('doctors').doc(widget.doctorId).get();
      if (doc.exists && mounted) {
        setState(() {
          doctorName = doc['name'] ?? "Unknown Doctor";
        });
      }
    } catch (e) {
      debugPrint("Error fetching doctor name: $e");
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('receiver_id', isEqualTo: widget.doctorId)
          .where('read', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        notifications = snapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    }
  }

  Future<void> _markAsRead(String docId) async {
    try {
      await _firestore.collection('notifications').doc(docId).update({'read': true});
      _fetchNotifications();
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  void openChat(String patientId) async {
    String chatId = await _chatService.getChatId(widget.doctorId, patientId);

    if (chatId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            doctorId: widget.doctorId,
            patientId: patientId,
          ),
        ),
      );
    } else {
      print("Failed to get chat ID.");
    }
  }

  VoidCallback _chatScreen() {
    return () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectPatientScreen(
            doctorId: widget.doctorId,
            isForChat: true,
          ),
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[500],
        actions: [_buildNotificationIcon()],
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
          onPressed: () => setState(() => isDropdownVisible = !isDropdownVisible),
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
        gradient: LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade200]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)
        ],
      ),
      child: Column(
        children: [
          Text("Welcome, Dr. $doctorName!",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 5),
          Text(currentTime,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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
            MaterialPageRoute(builder: (context) => DoctorAppointmentsScreen(doctorId: widget.doctorId)),
          ),
        ),
        _buildDashboardCard(
          icon: Icons.chat,
          title: "Chat with Patients",
          color: Colors.green,
          onTap: _chatScreen(),
        ),
        _buildDashboardCard(
          icon: Icons.folder_shared,
          title: "Reports",
          color: Colors.purple,
          onTap: () {}, // Future feature
        ),
        _buildDashboardCard(
          icon: Icons.person,
          title: "Update Profile",
          color: Colors.teal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DoctorProfileCompletionScreen(doctorId: widget.doctorId)),
          ),
        ),
        _buildDashboardCard(
          icon: Icons.description,
          title: "Prescriptions",
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SelectPatientScreen(doctorId: widget.doctorId)),
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
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationDropdown() {
    return Positioned(
      top: kToolbarHeight + 10,
      right: 10,
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: Container(
          width: 300,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: notifications.isEmpty
              ? const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("No new notifications"),
          )
              : ListView.builder(
            shrinkWrap: true,
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                title: Text(notif['title'] ?? 'Notification',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(notif['message'] ?? ''),
                trailing: const Icon(Icons.check, color: Colors.green),
                onTap: () => _markAsRead(notif['id']),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.teal[500]),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 45, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Dr. $doctorName",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            icon: Icons.calendar_today,
            title: "Appointments",
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DoctorAppointmentsScreen(doctorId: widget.doctorId)),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.description,
            title: "Prescriptions",
            color: Colors.deepPurple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SelectPatientScreen(doctorId: widget.doctorId)),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: "Logout",
            color: Colors.red,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: onTap,
    );
  }
}