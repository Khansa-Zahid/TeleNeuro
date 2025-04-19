import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PatientProfileDisplayScreen extends StatefulWidget {
  final String patientId;

  const PatientProfileDisplayScreen({super.key, required this.patientId});

  @override
  _PatientProfileDisplayScreenState createState() => _PatientProfileDisplayScreenState();
}

class _PatientProfileDisplayScreenState extends State<PatientProfileDisplayScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? patientData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatientData();
  }

  Future<void> _fetchPatientData() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('clients').doc(widget.patientId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

        // Fetch dob as a string
        String? dobString = data["dob"];
        DateTime? dob;
        if (dobString != null && dobString.isNotEmpty) {
          try {
            dob = DateTime.parse(dobString); // Convert to DateTime
          } catch (e) {
            print("❌ Error parsing date: $e");
            dob = null;
          }
        }

        setState(() {
          patientData = {
            "name": data["fullName"] ?? "N/A",
            "dob": dob,  // Keep as DateTime
            "age": dob != null ? _calculateAge(dob).toString() : "N/A",
            "phoneNumber": data["phone"] ?? "N/A",
            "email": data["email"] ?? "N/A",
            "address": data["address"] ?? "N/A",
            "bloodGroup": data["bloodGroup"] ?? "N/A",
            "medicalConditions": data["medicalConditions"] ?? "N/A",
            "allergies": data["allergies"] ?? "N/A",
            "medications": data["medications"] ?? "N/A",
            "emergencyContact": data["emergencyContact"] ?? "N/A",
            "insurance": data["insuranceDetails"] ?? "N/A",
            "medicalHistory": data["medicalHistory"] ?? "N/A",
          };
          isLoading = false;
        });

        print("✅ Successfully Retrieved Patient Data: $patientData");
      } else {
        print("⚠️ No document found in Firestore for ID: ${widget.patientId}");
        setState(() {
          isLoading = false;
          patientData = null;
        });
      }
    } catch (e) {
      print("❌ Error fetching patient data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }






  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      appBar: AppBar(
        title: const Text('Patient Profile'),
        backgroundColor: Colors.teal[700],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : patientData == null
          ? const Center(child: Text("No profile data found"))
          : SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: patientData!['profileImage'] != null
                      ? NetworkImage(patientData!['profileImage'])
                      : null,
                  child: patientData!['profileImage'] == null
                      ? Icon(Icons.person, size: 50, color: Colors.teal[700])
                      : null,
                ),
                const SizedBox(height: 20),

                /// **Fields**
                _buildProfileDetail("Full Name", patientData!['name']),
                _buildProfileDetail(
                  "Age",
                  patientData!['dob'] != null
                      ? _calculateAge(DateTime.parse(patientData!['dob'])) // Convert String to DateTime
                      : "N/A", // Handle null case
                ),

                _buildProfileDetail("Phone", patientData!['phoneNumber']),
                _buildProfileDetail("Email", patientData!['email']),
                _buildProfileDetail("Address", patientData!['address']),
                _buildProfileDetail("Blood Group", patientData!['bloodGroup']),
                _buildProfileDetail("Medical Conditions", patientData!['medicalConditions']),
                _buildProfileDetail("Allergies", patientData!['allergies']),
                _buildProfileDetail("Current Medications", patientData!['medications']),
                _buildProfileDetail("Emergency Contact", patientData!['emergencyContact']),
                _buildProfileDetail("Health Insurance", patientData!['insurance']),
                _buildProfileDetail("Medical History", patientData!['medicalHistory']),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),


    );
  }

  Widget _buildProfileDetail(String title, dynamic value) {
    print("⚡ Displaying $title: $value"); // Debugging
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 15),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value.toString(), // Now it will always display a value
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;  // Subtract 1 if birthday hasn't occurred yet this year
    }
    return age;
  }


}
