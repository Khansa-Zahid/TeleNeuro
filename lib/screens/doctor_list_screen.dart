import 'package:flutter/material.dart';
import 'doctor_screen.dart';

class DoctorListScreen extends StatelessWidget {
  final List<Map<String, String>> doctors = [
    {'name': 'Dr. John Doe', 'specialty': 'Cardiologist'},
    {'name': 'Dr. Jane Smith', 'specialty': 'Neurologist'},
    // Add more doctors as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor List'),
      ),
      body: ListView.builder(
        itemCount: doctors.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(doctors[index]['name']!),
            subtitle: Text(doctors[index]['specialty']!),
            onTap: () {
              // Navigate to DoctorScreen without any parameters
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DoctorScreen(), // No doctor parameter
                ),
              );
            },
          );
        },
      ),
    );
  }
}