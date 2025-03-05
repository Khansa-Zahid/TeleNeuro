import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment_type_screen.dart';

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
      QuerySnapshot querySnapshot = await _firestore.collection('doctors').get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('No doctors found in Firestore.');
        return [];
      }

      List<Map<String, String>> doctorsList = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>?;

        if (data == null) {
          return {
            'doctorId': doc.id, // Firestore document ID as doctor ID
            'name': 'Unknown',
            'specialization': 'Not specified',
            'email': 'No email',
            'phoneNumber': 'No phone',
          };
        }

        return {
          'doctorId': doc.id,
          'name': data['name']?.toString() ?? 'Unknown',
          'specialization': data['specialization']?.toString() ?? 'Not specified',
          'email': data['email']?.toString() ?? 'No email',
          'phoneNumber': data['phoneNumber']?.toString() ?? 'No phone',
        };
      }).toList();

      return doctorsList;
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Doctor'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _fetchDoctors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No doctors found.'));
          }

          List<Map<String, String>> doctors = snapshot.data!;

          return ListView.builder(
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: const Icon(Icons.medical_services, size: 40, color: Colors.teal),
                  title: Text(
                    doctor['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Specialization: ${doctor['specialization'] ?? ''}'),
                      Text('Email: ${doctor['email'] ?? ''}'),
                      Text('Phone: ${doctor['phoneNumber'] ?? ''}'),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppointmentTypeScreen(
                            doctorId: doctor['doctorId']!,
                            doctorName: doctor['name']!,
                            specialization: doctor['specialization']!,
                            patientId: widget.patientId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text('Book'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
