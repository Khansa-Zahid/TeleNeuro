import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

class VideoCallScreen extends StatefulWidget {
  final String doctorId;
  final String patientId;

  const VideoCallScreen({super.key, required this.doctorId, required this.patientId});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  String? doctorName;
  String? patientName;
  String? userId;
  String? userName;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    fetchUserDetails();
  }

  void fetchUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      userId = user.uid;
      userName = user.displayName ?? 'User';
    });

    // Fetch doctor details
    final doctorDoc = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(widget.doctorId)
        .get();
    if (doctorDoc.exists) {
      setState(() {
        doctorName = doctorDoc['name'];
      });
    }

    // Fetch patient details
    final patientDoc = await FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.patientId)
        .get();
    if (patientDoc.exists) {
      setState(() {
        patientName = patientDoc['name'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (doctorName == null || patientName == null || userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Video Call with $doctorName'),
        backgroundColor: Colors.teal,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ZegoUIKitPrebuiltCall(
                appID: 164793523, // Replace with your ZegoCloud App ID
                appSign: '512c9d20436ad392ed2ceef649e272c3870a29cf4e97837b15951fcd382e7605', // Replace with your ZegoCloud App Sign
                callID: widget.patientId, // Use patientId as the call ID
                userID: userId!, // Current user's ID
                userName: userName!, // Current user's name
                config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
                  ..bottomMenuBar.isVisible = true
                  ..topMenuBar.isVisible = true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
