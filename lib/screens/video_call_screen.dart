import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'dart:math' as math;

class VideoCallScreen extends StatefulWidget {
  final String doctorId;
  final String patientId;

  const VideoCallScreen(
      {super.key, required this.doctorId, required this.patientId});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  String? doctorName;
  String? patientName;
  String? userId;
  String? userName;
  String? callId;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _generateCallId();
    fetchUserDetails();
  }

  void _generateCallId() {
    final random = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    callId = 'call_${widget.doctorId}_${widget.patientId}_$timestamp';
  }

  void fetchUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      userId = user.uid;
      userName = user.displayName ?? 'User';
    });

    try {
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

      // Save call record to Firestore
      await _saveCallRecord();
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }

  Future<void> _saveCallRecord() async {
    try {
      await FirebaseFirestore.instance.collection('calls').add({
        'callId': callId,
        'doctorId': widget.doctorId,
        'patientId': widget.patientId,
        'doctorName': doctorName,
        'patientName': patientName,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    } catch (e) {
      print('Error saving call record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (doctorName == null ||
        patientName == null ||
        userId == null ||
        callId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.teal,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Video Call with Dr. $doctorName'),
        backgroundColor: Colors.teal,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ZegoUIKitPrebuiltCall(
                appID: 164793523, // Replace with your ZegoCloud App ID
                appSign:
                    '512c9d20436ad392ed2ceef649e272c3870a29cf4e97837b15951fcd382e7605', // Replace with your ZegoCloud App Sign
                callID: callId!,
                userID: userId!,
                userName: userName!,
                config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
                  ..bottomMenuBar.isVisible = true
                  ..topMenuBar.isVisible = true
                  ..bottomMenuBar.backgroundColor = Colors.teal.withOpacity(0.8)
                  ..topMenuBar.backgroundColor = Colors.teal.withOpacity(0.8)
                  ..avatarBuilder = (BuildContext context, Size size,
                      ZegoUIKitUser? user, Map extraInfo) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.teal.shade100,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: size.width * 0.5,
                          color: Colors.teal,
                        ),
                      ),
                    );
                  },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}
