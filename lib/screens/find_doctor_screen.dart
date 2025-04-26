import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment_type_screen.dart';
import 'doctor_profile_view_screen.dart';

class FindDoctorScreen extends StatefulWidget {
  final String patientId;

  const FindDoctorScreen({super.key, required this.patientId});

  @override
  _FindDoctorScreenState createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, String>>> _fetchDoctors() async {
    try {
      QuerySnapshot querySnapshot =
          await _firestore.collection('doctors').get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('No doctors found in Firestore.');
        return [];
      }

      return querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'doctorId': doc.id,
          'name': data['name']?.toString() ?? 'Unknown',
          'specialization':
              data['specialization']?.toString() ?? 'Not specified',
          'email': data['email']?.toString() ?? 'No email',
          'phoneNumber': data['phoneNumber']?.toString() ?? 'No phone',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        title: const Text('Find a Doctor',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade400,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _fetchDoctors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingAnimation();
          } else if (snapshot.hasError) {
            return _buildErrorMessage(snapshot.error.toString());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildNoDataMessage();
          }

          List<Map<String, String>> doctors = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: ListView.builder(
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final doctor = doctors[index];
                return _buildDoctorCard(doctor);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.teal),
          SizedBox(height: 10),
          Text("Loading doctors...",
              style: TextStyle(fontSize: 16, color: Colors.teal)),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Center(
      child: Text(
        "Error: $message",
        style: const TextStyle(fontSize: 16, color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return const Center(
      child: Text(
        "No doctors found.",
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, String> doctor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Doctor Avatar with Initials
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.teal.shade300,
                  child: Text(
                    doctor['name']!.isNotEmpty
                        ? doctor['name']![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 15),

                // Doctor Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor['name']!,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Specialization: ${doctor['specialization']!}",
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade700),
                      ),
                      if (doctor['email'] != null &&
                          doctor['email']!.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.email,
                              size: 16,
                              color: Colors.teal,
                            ),
                            const SizedBox(
                                width: 4), // Spacing between icon and text
                            Flexible(
                              child: Text(
                                doctor['email']!,
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade600),
                                overflow:
                                    TextOverflow.ellipsis, // Handle overflow
                              ),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: Colors.teal,
                          ),
                          const SizedBox(
                              width: 4), // Spacing between icon and text
                          Flexible(
                            child: Text(
                              doctor['phoneNumber']!,
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600),
                              overflow:
                                  TextOverflow.ellipsis, // Handle overflow
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View Profile Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorProfileViewScreen(
                          doctorId: doctor['doctorId']!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person, size: 16),
                  label: const Text("View Profile"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal.shade700,
                    side: BorderSide(color: Colors.teal.shade300),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),

                // Book Appointment Button
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      DocumentSnapshot patientSnapshot = await _firestore
                          .collection('clients')
                          .doc(widget.patientId)
                          .get();

                      if (patientSnapshot.exists) {
                        final patientData =
                            patientSnapshot.data() as Map<String, dynamic>;
                        final patientName =
                            patientData['name'] ?? 'Unknown Patient';

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AppointmentTypeScreen(
                              doctorId: doctor['doctorId']!,
                              doctorName: doctor['name']!,
                              specialization: doctor['specialization']!,
                              patientId: widget.patientId,
                              patientName: patientName,
                              channelName: widget.patientId,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Patient not found in database")),
                        );
                      }
                    } catch (e) {
                      print("Error fetching patient data: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text("Book Appointment"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade500,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
