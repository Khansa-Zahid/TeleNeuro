import 'package:flutter/material.dart';
import '../find_doctor_screen.dart';

class RequestScreen extends StatelessWidget {
  final String patientId; // Add patientId as a required parameter

  const RequestScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Appointment"),
        centerTitle: true,
        backgroundColor: Colors.teal[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Allows scrolling for smaller screens
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Request a Center",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Fill in the details below to book an appointment.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildTextField("Name"),
              const SizedBox(height: 10),
              _buildTextField("Email", keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _buildTextField("Phone Number", keyboardType: TextInputType.phone),
              const SizedBox(height: 10),
              _buildTextField("Preferred Date", keyboardType: TextInputType.datetime),
              const SizedBox(height: 10),
              _buildTextField("Preferred Time", keyboardType: TextInputType.datetime),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to FindDoctorScreen and pass patientId
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FindDoctorScreen(patientId: patientId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor: Colors.teal[600],
                  ),
                  child: const Text("Submit"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build text fields
  Widget _buildTextField(String label, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    );
  }
}