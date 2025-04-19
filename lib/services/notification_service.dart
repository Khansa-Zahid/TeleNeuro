import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initializeNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request Notification Permission
    NotificationSettings permissionSettings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (permissionSettings.authorizationStatus == AuthorizationStatus.denied) {
      print("Notification permission denied");
      return;
    }

    // Get FCM Token
    String? token = await messaging.getToken();
    print("FCM Token: $token");

    // Initialize Local Notifications
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        print("User tapped on notification: ${response.payload}");
      },
    );

    // Listen to Foreground Notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Received a notification: ${message.notification?.title}");
      _showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("User tapped on notification: ${message.notification?.title}");
    });
  }

  static void _showNotification(RemoteMessage message) async {
    // Save to Firestore
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': message.notification?.title ?? "New Notification",
      'message': message.notification?.body ?? "You have a new update",
      'timestamp': FieldValue.serverTimestamp(),
    });

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      "high_importance_channel",
      "High Importance Notifications",
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);

    _localNotificationsPlugin.show(
      0,
      message.notification?.title ?? "New Notification",
      message.notification?.body ?? "You have a new update",
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }
}
