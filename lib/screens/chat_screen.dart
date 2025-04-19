import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String doctorId;
  final String patientId;

  const ChatScreen({
    required this.chatId,
    required this.doctorId,
    required this.patientId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();

  // Method to send a message
  void sendMessage() {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid; // Get current user's ID

    if (_messageController.text.isNotEmpty) {
      _chatService.sendMessage(
        widget.chatId,
        _messageController.text,
        currentUserId, // senderId is the current user
        currentUserId == widget.doctorId ? widget.patientId : widget.doctorId, // receiverId is opposite
      );
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid; // Get current user's ID

    return Scaffold(
      appBar: AppBar(
        title: Text("Chat with ${currentUserId == widget.doctorId ? widget.patientId : widget.doctorId}"),
        backgroundColor: Colors.teal[500],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.chatId), // Get chat messages from Firestore
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs.reversed.toList(); // Reverse the list to show the latest message at the bottom
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    bool isMe = message["sender_id"] == currentUserId; // Check if the current user is the sender

                    // Determine the sender label ("Doctor" or "Patient")
                    String senderLabel = message["sender_id"] == widget.doctorId
                        ? "Doctor"
                        : "Patient";

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft, // Align message based on sender
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start, // Align label based on sender
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text(
                              senderLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.blue : Colors.black54,
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.blue[400] // Color for the sender's message
                                  : Colors.grey[300], // Color for the receiver's message
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              message["text"],
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                                fontSize: 16,
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
          Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.teal),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
