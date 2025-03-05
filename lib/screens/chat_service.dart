import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Method to get Chat ID
  Future<String> getChatId(String doctorId, String patientId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('chats')
          .where('doctor_id', isEqualTo: doctorId)
          .where('patient_id', isEqualTo: patientId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.id; // Return existing chat ID
      } else {
        DocumentReference newChat = await _firestore.collection('chats').add({
          'doctor_id': doctorId,
          'patient_id': patientId,
          'created_at': FieldValue.serverTimestamp(),
        });
        return newChat.id;
      }
    } catch (e) {
      print("Error getting chat ID: $e");
      return "";
    }
  }

  // ✅ Method to Send Message
  Future<void> sendMessage(String chatId, String message, String senderId, String receiverId) async {
    try {
      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'text': message,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  // ✅ Method to Get Messages Stream
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
