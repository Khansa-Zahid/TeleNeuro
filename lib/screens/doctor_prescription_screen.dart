import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DoctorPrescriptionScreen extends StatefulWidget {
  final String doctorId;
  final String patientId;

  const DoctorPrescriptionScreen({required this.doctorId, required this.patientId, Key? key}) : super(key: key);

  @override
  _DoctorPrescriptionScreenState createState() => _DoctorPrescriptionScreenState();
}

class _DoctorPrescriptionScreenState extends State<DoctorPrescriptionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, String>> medications = [];
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  String patientName = "Loading...";
  String doctorName = "Loading...";
  String specialization = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchPatientData();
    _fetchDoctorData();
    _initializeNotifications();
  }

  Future<void> _fetchPatientData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('clients').doc(widget.patientId).get();
      if (doc.exists) {
        setState(() {
          patientName = doc['name'] ?? "Unknown Patient";
        });
      } else {
        setState(() {
          patientName = "Unknown Patient";
        });
      }
    } catch (e) {
      print("Error fetching patient data: $e");
    }
  }

  Future<void> _fetchDoctorData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('doctors').doc(widget.doctorId).get();
      if (doc.exists) {
        setState(() {
          doctorName = doc['name'] ?? "Unknown Doctor";
          specialization = doc['specialization'] ?? "No Specialization";
        });
      } else {
        setState(() {
          doctorName = "Unknown Doctor";
          specialization = "No Specialization";
        });
      }
    } catch (e) {
      print("Error fetching doctor data: $e");
    }
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _sendNotification() async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'client_id': widget.patientId,
      'title': 'New Prescription',
      'body': 'Dr. $doctorName has added a new prescription for you.',
      'timestamp': FieldValue.serverTimestamp(),

      'doctorId': widget.doctorId,
      'status': 'unread', // Added status field
    });
  }

  void _addMedication() {
    setState(() {
      medications.add({"name": "", "dosage": "", "frequency": ""});
    });
  }

  void _savePrescription() async {
    if (medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please add at least one medicine before saving!"), backgroundColor: Colors.red),
      );
      return; // Stop execution
    }

    await _firestoreService.addPrescription(widget.doctorId, widget.patientId, medications, _notesController.text);
    await _sendNotification();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Prescription saved successfully!"), backgroundColor: Colors.teal),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Prescription"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patientName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(doctorName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    Text(specialization, style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: medications.length,
                itemBuilder: (context, index) {
                  return Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(labelText: "Medicine Name"),
                        onChanged: (value) => medications[index]["name"] = value,
                      ),
                      TextField(
                        decoration: InputDecoration(labelText: "Dosage"),
                        onChanged: (value) => medications[index]["dosage"] = value,
                      ),
                      TextField(
                        decoration: InputDecoration(labelText: "Frequency"),
                        onChanged: (value) => medications[index]["frequency"] = value,
                      ),
                      Divider(),
                    ],
                  );
                },
              ),
            ),
            TextField(controller: _notesController, decoration: InputDecoration(labelText: "Additional Notes")),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addMedication,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text("Add Medicine", style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _savePrescription,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: Text("Save Prescription", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
