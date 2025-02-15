import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment_type_screen.dart';

class FindDoctorScreen extends StatefulWidget {
  const FindDoctorScreen({super.key});

  @override
  _FindDoctorScreenState createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, String>>> _fetchDoctors() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('doctors').get();

      if (querySnapshot.docs.isEmpty) {
        print('No doctors found in Firestore.');
      }

      List<Map<String, String>> doctorsList = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;

        print('Fetched Doctor: $data'); // Debugging

        return {
          'name': (data['name'] ?? 'Unknown').toString(),
          'specialization': (data['specialization'] ?? 'Not specified').toString(),
          'email': (data['email'] ?? 'No email').toString(),
          'phoneNumber': (data['phoneNumber'] ?? 'No phone').toString(),
        };
      }).toList();

      return doctorsList;
    } catch (e) {
      print('Error fetching doctors: $e');
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
                            doctorName: doctor['name'] ?? '',
                            specialization: doctor['specialization'] ?? '',
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
