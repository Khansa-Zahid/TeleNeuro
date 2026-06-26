import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notification_service.dart';
import 'dart:convert';

// Import Screens
import 'screens/onboarding_screen.dart';
import 'screens/doctor_signup_screen.dart';
import 'screens/doctor_login_screen.dart';
import 'screens/find_doctor_screen.dart';
import 'screens/doctor_screen.dart';
import 'screens/patient_login_screen.dart';
import 'screens/patient_signup_screen.dart';
import 'screens/patient_profile_completion_screen.dart';
import 'screens/patient_profile_display_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Firebase options
final FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyDJodDDsyLbb9xvMRRUDNmlhV8EW4hTRis",
  authDomain: "fypteleneuro.firebaseapp.com",
  projectId: "fypteleneuro",
  storageBucket: "fypteleneuro.appspot.com",
  messagingSenderId: "205605587304",
  appId: "1:205605587304:web:1a40cedb7f911cc531eedd",
  measurementId: "G-BTCBSZ9JQS",
);

// This needs to be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: firebaseOptions,
      );
    }
    print('Handling background message: ${message.messageId}');
  } catch (e) {
    print('Error in background handler: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase only if it hasn't been initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        name: 'PrimaryApp',
        options: firebaseOptions,
      );
    }

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize notifications
    await NotificationService.initializeNotifications();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Received foreground message: ${message.messageId}");
      // Show local notification
      if (message.notification != null) {
        flutterLocalNotificationsPlugin.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked: ${message.messageId}");
      // Handle notification click
      if (message.data.isNotEmpty) {
        NotificationService.handleNotificationClick(message.data);
      }
    });

    runApp(const MyApp());
  } catch (e) {
    print("Error initializing app: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeleNeuro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const OnboardingScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/doctor':
            return MaterialPageRoute(
                builder: (context) => const DoctorScreen());
          case '/signup':
            return MaterialPageRoute(
                builder: (context) => const DoctorSignupScreen());
          case '/login':
            return MaterialPageRoute(
                builder: (context) => const DoctorLoginScreen());
          case '/findDoctor':
            final String? patientId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) =>
                  FindDoctorScreen(patientId: patientId ?? "default_id"),
            );
          case '/clientLoginScreen':
            return MaterialPageRoute(builder: (context) => ClientLoginScreen());
          case '/clientSignupScreen':
            return MaterialPageRoute(
                builder: (context) => ClientSignupScreen());
          case '/patientProfileCompletionScreen':
            final String patientId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) =>
                  PatientProfileCompletionScreen(patientId: patientId),
            );
          case '/patientProfileDisplayScreen':
            final String patientId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) =>
                  PatientProfileDisplayScreen(patientId: patientId),
            );
          default:
            return MaterialPageRoute(
                builder: (context) => const OnboardingScreen());
        }
      },
    );
  }
}

// Setup Firebase Messaging & Local Notifications
Future<void> setupFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission for notifications
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.denied) {
    print("Notification permission denied");
    return;
  }

  // Get FCM token
  String? token = await messaging.getToken();
  print("FCM Token: $token");

  // Initialize local notifications
  const AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: androidInitializationSettings);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Handle background and terminated notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Received a notification: ${message.notification?.title}");
    showNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("User tapped on notification: ${message.notification?.title}");
  });
}

// Show Local Notifications
void showNotification(RemoteMessage message) {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    "high_importance_channel",
    "High Importance Notifications",
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  flutterLocalNotificationsPlugin.show(
    0,
    message.notification?.title ?? "New Notification",
    message.notification?.body ?? "You have a new update",
    notificationDetails,
  );
}
