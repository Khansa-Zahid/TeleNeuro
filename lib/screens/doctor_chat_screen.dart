import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'package:intl/intl.dart';

class DoctorChatScreen extends StatefulWidget {
  final String chatId;
  final String doctorId;
  final String patientId;
  final String doctorName;

  const DoctorChatScreen({
    required this.chatId,
    required this.doctorId,
    required this.patientId,
    required this.doctorName,
    Key? key,
  }) : super(key: key);

  @override
  _DoctorChatScreenState createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  late String _patientName = "Patient";
  bool _isLoading = true;
  Map<String, dynamic> _patientData = {};

  @override
  void initState() {
    super.initState();
    _fetchPatientInfo();
    _markMessagesAsRead();
  }

  Future<void> _fetchPatientInfo() async {
    try {
      DocumentSnapshot patientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.patientId)
          .get();

      if (patientDoc.exists) {
        var data = patientDoc.data() as Map<String, dynamic>;
        setState(() {
          _patientName = data['name'] ?? "Patient";
          _patientData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching patient info: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.chatId, widget.doctorId);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _chatService.sendMessage(
        widget.chatId,
        _messageController.text.trim(),
        widget.doctorId, // sender is doctor
        widget.patientId, // receiver is patient
        senderName: widget.doctorName,
        senderRole: 'doctor',
      );
      _messageController.clear();
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

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
      return 'Yesterday, ${DateFormat.jm().format(dateTime)}';
    } else {
      // Otherwise show date and time
      return DateFormat('MMM d, h:mm a')
          .format(dateTime); // e.g., Jan 5, 2:30 PM
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            _isLoading ? Text("Loading...") : Text("Chat with $_patientName"),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.medical_information),
            onPressed: () {
              // Show patient info dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("Patient Information"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Patient: $_patientName",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      if (_patientData.containsKey('age'))
                        Text("Age: ${_patientData['age']}"),
                      if (_patientData.containsKey('gender'))
                        Text("Gender: ${_patientData['gender']}"),
                      if (_patientData.containsKey('phoneNumber'))
                        Text("Phone: ${_patientData['phoneNumber']}"),
                      if (_patientData.containsKey('medicalHistory'))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 8),
                            Text("Medical History:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("${_patientData['medicalHistory']}"),
                          ],
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: Text("Close"),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat header with patient info
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.indigo.shade50,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo.shade200,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$_patientName",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "Secure patient consultation",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // Messages area
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.chatId),
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
                        Icon(Icons.chat_bubble_outline,
                            size: 80, color: Colors.grey.shade400),
                        SizedBox(height: 16),
                        Text(
                          "No messages yet",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Send a message to start the consultation",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message =
                        messages[index].data() as Map<String, dynamic>;
                    bool isMe = message["sender_id"] == widget.doctorId;
                    Timestamp? timestamp = message["timestamp"] as Timestamp?;

                    return Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Patient avatar shown for patient's messages
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.indigo.shade300,
                                  child: Text(
                                    "P",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],

                              // Message bubble
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.indigo.shade500
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    message["text"] ?? "",
                                    style: TextStyle(
                                      color:
                                          isMe ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),

                              // Space after doctor's message
                              if (isMe) SizedBox(width: 8),
                            ],
                          ),

                          // Timestamp
                          Padding(
                            padding: EdgeInsets.only(
                              top: 4,
                              left: isMe ? 0 : 40,
                              right: isMe ? 8 : 0,
                            ),
                            child: Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Doctor quick response options
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildQuickReply("How can I help you today?"),
                _buildQuickReply("What symptoms are you experiencing?"),
                _buildQuickReply("Please tell me more about your condition."),
                _buildQuickReply("Have you taken any medication?"),
                _buildQuickReply(
                    "I recommend scheduling a video call appointment."),
              ],
            ),
          ),

          // Message input area
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  offset: Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.indigo.shade600,
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReply(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: InkWell(
        onTap: () {
          _messageController.text = text;
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.indigo.shade300),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
