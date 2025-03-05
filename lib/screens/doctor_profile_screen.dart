import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_teleneuro/screens/doctor_screen.dart';
import 'chat_screen.dart';
import 'chat_service.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;

  DoctorProfileScreen({required this.doctorId});

  @override
  _DoctorProfileScreenState createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<String>> getPreviousPatients() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('chats')
          .where('doctor_id', isEqualTo: widget.doctorId)
          .get();

      List<String> patientIds = querySnapshot.docs
          .map((doc) => doc['patient_id'].toString()) // Extract patient IDs
          .toList();

      return patientIds;
    } catch (e) {
      print("Error fetching previous patients: $e");
      return [];
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

  void showAppointments(BuildContext context) async {
    List<String> patientList = await getPreviousPatients();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(10),
          height: 400,
          child: patientList.isEmpty
              ? Center(child: Text("No appointments found."))
              : ListView.builder(
                  itemCount: patientList.length,
                  itemBuilder: (context, index) {
                    String patientId = patientList[index];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(Icons.person, color: Colors.blue),
                      ),
                      title: Text(
                        "Chat with $patientId",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Tap to start conversation"),
                      trailing: Icon(Icons.chat, color: Colors.blue),
                      onTap: () {
                        Navigator.pop(context);
                        openChat(patientId);
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Doctor Profile"),
        backgroundColor: Colors.teal[500],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal[500]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.blue),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Doctor Dashboard",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.blue),
              title: Text("Appointments"),
              onTap: () {
                Navigator.pop(context);
                showAppointments(context);
              },
            ),
            Divider(),
            ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Colors.blue,
                ),
                title: Text('Logout'),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DoctorScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
                // ),

                ),
          ],
        ),
      ),
      body: Center(
        child: Text(
          "Welcome, Doctor!",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
