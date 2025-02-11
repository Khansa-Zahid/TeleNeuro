import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'appointment_type_screen.dart'; // Ensure this import is present

class FindDoctorScreen extends StatefulWidget {
  const FindDoctorScreen({super.key});

  @override
  _FindDoctorScreenState createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  List<Map<String, String>> doctors = [];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  _loadDoctors() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      doctors = [
        {
          'name': prefs.getString('doctor1Name') ?? '',
          'specialization': prefs.getString('doctor1Specialization') ?? '',
          'email': prefs.getString('doctor1Email') ?? '',
          'phoneNumber': prefs.getString('doctor1PhoneNumber') ?? '',
        },
        {
          'name': prefs.getString('doctor2Name') ?? '',
          'specialization': prefs.getString('doctor2Specialization') ?? '',
          'email': prefs.getString('doctor2Email') ?? '',
          'phoneNumber': prefs.getString('doctor2PhoneNumber') ?? '',
        },
        // Add more doctor entries as needed
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Doctor'),
        backgroundColor: Colors.teal,
      ),
      body: ListView.builder(
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
                  backgroundColor: Colors.teal, // Change here
                ),
                child: const Text('Book'),
              ),
            ),
          );
        },
      ),
    );
  }
}