import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'patient_chat_screen.dart';
import 'package:intl/intl.dart';

class PatientChatsListScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientChatsListScreen({
    required this.patientId,
    required this.patientName,
    Key? key,
  }) : super(key: key);

  @override
  _PatientChatsListScreenState createState() => _PatientChatsListScreenState();
}

class _PatientChatsListScreenState extends State<PatientChatsListScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _doctorsData = [];

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all doctors for quick reference
      QuerySnapshot doctorsSnapshot =
          await _firestore.collection('doctors').get();

      _doctorsData = doctorsSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading doctor data: $e");
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

  Map<String, dynamic> _getDoctorInfo(String doctorId) {
    try {
      return _doctorsData.firstWhere(
        (doctor) => doctor['id'] == doctorId,
        orElse: () => {'name': 'Unknown Doctor', 'specialization': 'Unknown'},
      );
    } catch (e) {
      return {'name': 'Unknown Doctor', 'specialization': 'Unknown'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Consultations"),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _chatService.getChats(widget.patientId, false),
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
                          "No chats yet",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Book an appointment with a doctor to start chatting",
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
                    String doctorId = chat['doctor_id'] ?? '';
                    var doctorInfo = _getDoctorInfo(doctorId);
                    String lastMessage =
                        chat['last_message'] ?? 'Start chatting';
                    Timestamp? lastMessageTime =
                        chat['last_message_time'] as Timestamp?;
                    bool isLastMessageFromDoctor =
                        chat['last_sender_id'] == doctorId;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientChatScreen(
                              chatId: chatId,
                              doctorId: doctorId,
                              patientId: widget.patientId,
                              patientName: widget.patientName,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Doctor Avatar
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.teal.shade100,
                              child: Text(
                                doctorInfo['name'].toString().isNotEmpty
                                    ? doctorInfo['name']
                                        .toString()[0]
                                        .toUpperCase()
                                    : 'D',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                ),
                              ),
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
                                        "Dr. ${doctorInfo['name']}",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _formatTimestamp(lastMessageTime),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    doctorInfo['specialization'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.teal.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (isLastMessageFromDoctor)
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.grey.shade500,
                                        ),
                                      if (isLastMessageFromDoctor)
                                        SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          lastMessage,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/find_doctor',
              arguments: {'patientId': widget.patientId});
        },
        backgroundColor: Colors.teal.shade700,
        child: Icon(Icons.add_comment),
        tooltip: 'Find a doctor to chat with',
      ),
    );
  }
}
