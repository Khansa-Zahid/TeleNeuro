import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  final String userId;

  const NotificationScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: userId)
            .orderBy('timestamp', descending: true) // Ensure Firestore index is created
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong."));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications available."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

              // Handle null values safely
              String title = data['title'] ?? "No Title";
              String message = data['message'] ?? "No Message";
              bool isRead = data['isRead'] ?? false;

              // Safely format timestamp
              String formattedTime = "Unknown Time";
              if (data['timestamp'] is Timestamp) {
                formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(
                  (data['timestamp'] as Timestamp).toDate(),
                );
              }

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      const SizedBox(height: 5),
                      Text(
                        formattedTime,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    isRead ? Icons.done_all : Icons.markunread,
                    color: isRead ? Colors.green : Colors.blue,
                  ),
                  onTap: () {
                    if (!isRead) {
                      FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(doc.id)
                          .update({'isRead': true}).catchError((error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error updating: $error")),
                        );
                      });
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
