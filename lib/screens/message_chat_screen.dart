import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MessageChatScreen extends StatefulWidget {
  final String doctorName;
  final String specialization;

  const MessageChatScreen({
    super.key,
    required this.doctorName,
    required this.specialization,
  });

  @override
  _MessageChatScreenState createState() => _MessageChatScreenState();
}

class _MessageChatScreenState extends State<MessageChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("messages");
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _listenForMessages();
  }

  void _listenForMessages() {
    _dbRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data is Map<dynamic, dynamic>) {
        setState(() {
          _messages.clear();
          data.forEach((key, value) {
            if (value is Map<dynamic, dynamic>) {
              _messages.add({
                "id": key,
                "text": value["text"] ?? "",
                "sender": value["sender"] ?? "Unknown",
                "timestamp": value["timestamp"] ?? 0,
              });
            }
          });
          _messages.sort((a, b) => (a["timestamp"] as int).compareTo(b["timestamp"] as int));
        });
      }
    });
  }

  void _sendMessage() {
    final messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      _dbRef.push().set({
        "text": messageText,
        "sender": widget.doctorName, // Using doctor's name dynamically
        "timestamp": ServerValue.timestamp,
      });
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.doctorName} (${widget.specialization})"),
        backgroundColor: Colors.teal[700],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text("No messages yet..."))
                : ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ListTile(
                  title: Text(msg["text"], style: const TextStyle(fontSize: 16)),
                  subtitle: Text("From: ${msg["sender"]}"),
                  trailing: Text(
                    DateTime.fromMillisecondsSinceEpoch(msg["timestamp"] as int).toLocal().toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
