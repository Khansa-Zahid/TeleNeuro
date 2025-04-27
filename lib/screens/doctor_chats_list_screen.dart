import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'doctor_chat_screen.dart';
import 'package:intl/intl.dart';
import 'select_patient_screen.dart';

class DoctorChatsListScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorChatsListScreen({
    required this.doctorId,
    required this.doctorName,
    Key? key,
  }) : super(key: key);

  @override
  _DoctorChatsListScreenState createState() => _DoctorChatsListScreenState();
}

class _DoctorChatsListScreenState extends State<DoctorChatsListScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _patientsData = [];

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all patients for quick reference
      QuerySnapshot patientsSnapshot =
          await _firestore.collection('clients').get();

      _patientsData = patientsSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading patient data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No messages yet';

    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      // Today, just show time
      return DateFormat.jm().format(dateTime); // e.g., 2:30 PM
    } else if (dateTime.day == now.day - 1 &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      // Yesterday
      return 'Yesterday';
    } else {
      // Show date
      return DateFormat('MMM d').format(dateTime); // e.g., Jan 5
    }
  }

  Map<String, dynamic> _getPatientInfo(String patientId) {
    try {
      return _patientsData.firstWhere(
        (patient) => patient['id'] == patientId,
        orElse: () =>
            {'name': 'Unknown Patient', 'age': 'Unknown', 'gender': 'Unknown'},
      );
    } catch (e) {
      return {'name': 'Unknown Patient', 'age': 'Unknown', 'gender': 'Unknown'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Patient Consultations"),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelectPatientScreen(
                doctorId: widget.doctorId,
                isForChat: true,
              ),
            ),
          ).then((_) {
            // Refresh data when returning from select patient screen
            setState(() {});
          });
        },
        backgroundColor: Colors.indigo.shade700,
        child: Icon(Icons.chat, color: Colors.white),
        tooltip: "Start New Chat",
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _chatService.getChats(widget.doctorId, true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No patient conversations yet",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Your patient consultations will appear here",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                var chats = snapshot.data!.docs;
                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    var chat = chats[index].data() as Map<String, dynamic>;
                    String chatId = chats[index].id;
                    String patientId = chat['patient_id'] ?? '';
                    var patientInfo = _getPatientInfo(patientId);
                    String lastMessage =
                        chat['last_message'] ?? 'Start consultation';
                    Timestamp? lastMessageTime =
                        chat['last_message_time'] as Timestamp?;
                    bool isLastMessageFromPatient =
                        chat['last_sender_id'] == patientId;

                    // Check for unread messages (messages to the doctor that aren't read)
                    bool hasUnreadMessages = false;
                    // This would ideally be set based on a count of unread messages
                    // You could add this to the chat document in Firestore

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DoctorChatScreen(
                              chatId: chatId,
                              doctorId: widget.doctorId,
                              patientId: patientId,
                              doctorName: widget.doctorName,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: hasUnreadMessages
                              ? Colors.blue.shade50
                              : Colors.white,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Patient Avatar
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.indigo.shade100,
                                  child: Text(
                                    patientInfo['name'].toString().isNotEmpty
                                        ? patientInfo['name']
                                            .toString()[0]
                                            .toUpperCase()
                                        : 'P',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade700,
                                    ),
                                  ),
                                ),
                                if (hasUnreadMessages)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(width: 16),
                            // Chat Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        patientInfo['name'] ??
                                            'Unknown Patient',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: hasUnreadMessages
                                              ? Colors.indigo.shade800
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        _formatTimestamp(lastMessageTime),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: hasUnreadMessages
                                              ? Colors.indigo.shade800
                                              : Colors.grey.shade600,
                                          fontWeight: hasUnreadMessages
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (patientInfo.containsKey('age') &&
                                          patientInfo['age'] != null)
                                        Text(
                                          "${patientInfo['age']} yrs",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.indigo.shade600,
                                          ),
                                        ),
                                      if (patientInfo.containsKey('age') &&
                                          patientInfo['age'] != null)
                                        SizedBox(width: 8),
                                      if (patientInfo.containsKey('gender') &&
                                          patientInfo['gender'] != null)
                                        Text(
                                          "${patientInfo['gender']}",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.indigo.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (isLastMessageFromPatient)
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: hasUnreadMessages
                                              ? Colors.indigo.shade800
                                              : Colors.grey.shade500,
                                        ),
                                      if (isLastMessageFromPatient)
                                        SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          lastMessage,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: hasUnreadMessages
                                                ? Colors.indigo.shade800
                                                : Colors.grey.shade700,
                                            fontWeight: hasUnreadMessages
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
