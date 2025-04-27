import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'package:intl/intl.dart';

class PatientChatScreen extends StatefulWidget {
  final String chatId;
  final String doctorId;
  final String patientId;
  final String patientName;

  const PatientChatScreen({
    required this.chatId,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    Key? key,
  }) : super(key: key);

  @override
  _PatientChatScreenState createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  late String _doctorName = "Doctor";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDoctorInfo();
    _markMessagesAsRead();
  }

  Future<void> _fetchDoctorInfo() async {
    try {
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .get();

      if (doctorDoc.exists) {
        var data = doctorDoc.data() as Map<String, dynamic>;
        setState(() {
          _doctorName = data['name'] ?? "Doctor";
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching doctor info: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.chatId, widget.patientId);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _chatService.sendMessage(
        widget.chatId,
        _messageController.text.trim(),
        widget.patientId, // sender is patient
        widget.doctorId, // receiver is doctor
        senderName: widget.patientName,
        senderRole: 'patient',
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
        title: _isLoading
            ? Text("Loading...")
            : Text("Chat with Dr. $_doctorName"),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              // Show doctor info dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("Chat Information"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Doctor: $_doctorName"),
                      SizedBox(height: 8),
                      Text("Patient: ${widget.patientName}"),
                      SizedBox(height: 8),
                      Text(
                          "Please note that chat messages are stored securely and may be referenced during your treatment."),
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
          // Chat header with doctor info
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.teal.shade50,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade200,
                  child: Icon(Icons.medical_services, color: Colors.white),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dr. $_doctorName",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "Your secure medical chat",
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
                          "Send a message to start the conversation",
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
                    bool isMe = message["sender_id"] == widget.patientId;
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
                              // Doctor avatar shown for doctor's messages
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.teal.shade600,
                                  child: Text(
                                    "D",
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
                                        ? Colors.teal.shade500
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

                              // Space after patient's message
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
                    backgroundColor: Colors.teal.shade600,
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
}
