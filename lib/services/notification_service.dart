import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static Future<void> initializeNotifications() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permission granted');
    } else {
      print('Notification permission denied');
      return;
    }

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    // Save FCM token to Firestore
    if (token != null) {
      await _saveFcmToken(token);
    }

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification clicked: ${response.payload}');
        // Handle notification click
        if (response.payload != null) {
          Map<String, dynamic> data = jsonDecode(response.payload!);
          handleNotificationClick(data);
        }
      },
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
          'Notification clicked (background): ${message.notification?.title}');
      handleNotificationClick(message.data);
    });
  }

  static Future<void> _saveFcmToken(String token) async {
    try {
      // Get current user ID from your auth system
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcm_token': token});
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      DateTime.now().millisecond,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? 'You have a new update',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  // Handle notification click
  static void handleNotificationClick(Map<String, dynamic> data) {
    // Handle different types of notifications
    String type = data['type'] ?? '';
    switch (type) {
      case 'message':
        // Navigate to chat screen
        break;
      case 'appointment':
        // Navigate to appointment screen
        break;
      case 'prescription':
        // Navigate to prescription screen
        break;
      case 'report':
        // Navigate to report screen
        break;
      default:
        // Handle default case
        break;
    }
  }

  // Create a notification in Firestore
  static Future<void> createNotification({
    required String receiverId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      Map<String, dynamic> notificationData = {
        'receiver_id': receiverId,
        'title': title,
        'message': message,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        ...?additionalData,
      };

      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);

      // Get receiver's FCM token
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();

      String? fcmToken = userDoc.get('fcm_token') as String?;
      if (fcmToken != null) {
        // Send FCM notification
        await _sendFcmNotification(
          token: fcmToken,
          title: title,
          body: message,
          data: notificationData,
        );
      }
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  static Future<void> _sendFcmNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('fcm_messages').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending FCM notification: $e');
    }
  }
}

// This needs to be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
}
