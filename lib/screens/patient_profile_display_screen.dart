import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PatientProfileDisplayScreen extends StatefulWidget {
  final String patientId;

  const PatientProfileDisplayScreen({super.key, required this.patientId});

  @override
  _PatientProfileDisplayScreenState createState() =>
      _PatientProfileDisplayScreenState();
}

class _PatientProfileDisplayScreenState
    extends State<PatientProfileDisplayScreen> {
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
      DocumentSnapshot doc =
          await _firestore.collection('clients').doc(widget.patientId).get();

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
            "name": data["fullName"] ?? data["name"] ?? "N/A",
            "gender": data["gender"] ?? "N/A",
            "dob": dobString, // Keep as String for display
            "age": dob != null ? _calculateAge(dob).toString() : "N/A",
            "phoneNumber": data["phoneNumber"] ?? data["phone"] ?? "N/A",
            "email": data["email"] ?? "N/A",
            "address": data["address"] ?? "N/A",
            "bloodGroup": data["bloodGroup"] ?? "N/A",
            "medicalConditions": data["medicalConditions"] ?? "N/A",
            "allergies": data["allergies"] ?? "N/A",
            "medications": data["medications"] ?? "N/A",
            "emergencyContact": data["emergencyContact"] ?? "N/A",
            "insurance": data["insuranceDetails"] ?? data["insurance"] ?? "N/A",
            "medicalHistory": data["medicalHistory"] ?? "N/A",
            "profileImage": data["profileImageUrl"] ?? data["profileImage"],
            "lastUpdated": data["lastUpdated"] ?? data["timestamp"] ?? null,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/patientProfileCompletionScreen',
                arguments: widget.patientId,
              ).then((_) {
                // Refresh data when returning from edit screen
                _fetchPatientData();
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : patientData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "No profile data found",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/patientProfileCompletionScreen',
                            arguments: widget.patientId,
                          ).then((_) {
                            // Refresh data when returning from edit screen
                            _fetchPatientData();
                          });
                        },
                        child: const Text('Complete Your Profile'),
                      ),
                    ],
                  ),
                )
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
                            backgroundImage:
                                patientData!['profileImage'] != null
                                    ? NetworkImage(patientData!['profileImage'])
                                    : null,
                            child: patientData!['profileImage'] == null
                                ? Icon(Icons.person,
                                    size: 50, color: Colors.teal[700])
                                : null,
                          ),
                          const SizedBox(height: 20),

                          // Last Updated information
                          if (patientData!['lastUpdated'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                "Last Updated: ${_formatTimestamp(patientData!['lastUpdated'])}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          // Basic Info Section
                          _buildSectionHeader("Basic Information"),
                          _buildProfileDetail(
                              "Full Name", patientData!['name']),
                          if (patientData!['gender'] != "N/A")
                            _buildProfileDetail(
                                "Gender", patientData!['gender']),
                          _buildProfileDetail(
                              "Date of Birth", patientData!['dob'] ?? "N/A"),
                          _buildProfileDetail("Age", patientData!['age']),
                          _buildProfileDetail(
                              "Phone", patientData!['phoneNumber']),
                          _buildProfileDetail("Email", patientData!['email']),

                          if (patientData!['address'] != "N/A")
                            _buildProfileDetail(
                                "Address", patientData!['address']),

                          // Medical Info Section
                          const SizedBox(height: 20),
                          _buildSectionHeader("Medical Information"),
                          _buildProfileDetail(
                              "Blood Group", patientData!['bloodGroup']),

                          if (patientData!['medicalConditions'] != "N/A")
                            _buildProfileDetail("Medical Conditions",
                                patientData!['medicalConditions']),

                          if (patientData!['allergies'] != "N/A")
                            _buildProfileDetail(
                                "Allergies", patientData!['allergies']),

                          if (patientData!['medications'] != "N/A")
                            _buildProfileDetail("Current Medications",
                                patientData!['medications']),

                          // Emergency Info Section
                          const SizedBox(height: 20),
                          _buildSectionHeader("Emergency Information"),
                          _buildProfileDetail("Emergency Contact",
                              patientData!['emergencyContact']),

                          if (patientData!['insurance'] != "N/A")
                            _buildProfileDetail(
                                "Health Insurance", patientData!['insurance']),

                          if (patientData!['medicalHistory'] != "N/A")
                            _buildProfileDetail("Medical History",
                                patientData!['medicalHistory']),

                          const SizedBox(height: 30),

                          // Edit Profile Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/patientProfileCompletionScreen',
                                arguments: widget.patientId,
                              ).then((_) {
                                // Refresh data when returning from edit screen
                                _fetchPatientData();
                              });
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text(
                              'Edit Profile',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),

                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.teal[700],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildProfileDetail(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 15),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value?.toString() ?? "N/A", // Handle null values
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Unknown";

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      try {
        // Try to parse if it's a string
        dateTime = DateTime.parse(timestamp.toString());
      } catch (e) {
        return "Unknown";
      }
    }

    // Format the date
    return DateFormat('MMM d, yyyy, h:mm a').format(dateTime);
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--; // Subtract 1 if birthday hasn't occurred yet this year
    }
    return age;
  }
}
