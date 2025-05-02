import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to get Chat ID
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
          'last_message': '',
          'last_message_time': FieldValue.serverTimestamp(),
        });
        return newChat.id;
      }
    } catch (e) {
      print("Error getting chat ID: $e");
      return "";
    }
  }

  // Method to check if consultation request exists and its status
  Future<Map<String, dynamic>> checkConsultationRequest(
      String doctorId, String patientId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('consultation_requests')
          .where('doctor_id', isEqualTo: doctorId)
          .where('patient_id', isEqualTo: patientId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        var data = query.docs.first.data() as Map<String, dynamic>;
        return {
          'exists': true,
          'status': data['status'] ?? 'pending',
          'id': query.docs.first.id,
        };
      } else {
        return {
          'exists': false,
          'status': 'none',
          'id': '',
        };
      }
    } catch (e) {
      print("Error checking consultation request: $e");
      return {
        'exists': false,
        'status': 'error',
        'id': '',
      };
    }
  }

  // Method to create consultation request
  Future<bool> createConsultationRequest(
      String doctorId, String patientId, String patientName) async {
    try {
      // First check if a request already exists
      var checkResult = await checkConsultationRequest(doctorId, patientId);
      if (checkResult['exists']) {
        return checkResult['status'] == 'accepted';
      }

      // Create new consultation request
      await _firestore.collection('consultation_requests').add({
        'doctor_id': doctorId,
        'patient_id': patientId,
        'patient_name': patientName,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Add notification for doctor
      await _firestore.collection('notifications').add({
        'receiver_id': doctorId,
        'sender_id': patientId,
        'title': 'New Consultation Request',
        'message': '$patientName would like to consult with you',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'consultation_request',
        'patient_id': patientId,
      });

      return false;
    } catch (e) {
      print("Error creating consultation request: $e");
      return false;
    }
  }

  // Method to accept consultation request
  Future<bool> acceptConsultationRequest(String requestId) async {
    try {
      DocumentSnapshot requestDoc = await _firestore
          .collection('consultation_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return false;
      }

      var data = requestDoc.data() as Map<String, dynamic>;
      String doctorId = data['doctor_id'] ?? '';
      String patientId = data['patient_id'] ?? '';
      String patientName = data['patient_name'] ?? 'Patient';

      if (doctorId.isEmpty || patientId.isEmpty) {
        return false;
      }

      // Update request status
      await _firestore
          .collection('consultation_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'accepted_at': FieldValue.serverTimestamp(),
      });

      // Create chat if it doesn't exist
      String chatId = await getChatId(doctorId, patientId);

      // Add notification for patient
      await _firestore.collection('notifications').add({
        'receiver_id': patientId,
        'sender_id': doctorId,
        'title': 'Consultation Request Accepted',
        'message': 'Your doctor has accepted your consultation request',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'consultation_accepted',
        'chat_id': chatId,
      });

      return true;
    } catch (e) {
      print("Error accepting consultation request: $e");
      return false;
    }
  }

  // Method to Send Message
  Future<void> sendMessage(
      String chatId, String message, String senderId, String receiverId,
      {String? senderName, String? senderRole}) async {
    try {
      // First, add the message to the messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': message,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'sender_name': senderName ?? 'Unknown',
        'sender_role': senderRole ?? 'Unknown',
        'read': false,
      });

      // Then, update the chat document with the last message and timestamp
      await _firestore.collection('chats').doc(chatId).update({
        'last_message': message,
        'last_message_time': FieldValue.serverTimestamp(),
        'last_sender_id': senderId,
      });

      // Add a notification for the receiver
      await _firestore.collection('notifications').add({
        'receiver_id': receiverId,
        'sender_id': senderId,
        'title': 'New Message',
        'message':
            message.length > 30 ? message.substring(0, 30) + '...' : message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'message',
        'chat_id': chatId,
      });
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  // Method to Get Messages Stream
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Method to Get Chat Details
  Future<Map<String, dynamic>> getChatDetails(String chatId) async {
    try {
      DocumentSnapshot chatDoc =
          await _firestore.collection('chats').doc(chatId).get();

      if (chatDoc.exists) {
        return chatDoc.data() as Map<String, dynamic>;
      } else {
        return {};
      }
    } catch (e) {
      print("Error getting chat details: $e");
      return {};
    }
  }

  // Method to Get All Chats for a User (either doctor or patient)
  Stream<QuerySnapshot> getChats(String userId, bool isDoctor) {
    String field = isDoctor ? 'doctor_id' : 'patient_id';

    return _firestore
        .collection('chats')
        .where(field, isEqualTo: userId)
        .orderBy('last_message_time', descending: true)
        .snapshots();
  }

  // Method to Mark Messages as Read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Get all unread messages sent to this user
      QuerySnapshot unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiver_id', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      // Mark each message as read
      for (var doc in unreadMessages.docs) {
        await doc.reference.update({'read': true});
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }
}
