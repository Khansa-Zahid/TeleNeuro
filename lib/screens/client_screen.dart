import 'package:flutter/material.dart';
import 'dart:io'; // Required for File
import 'package:image_picker/image_picker.dart'; // Package to pick images
import 'find_doctor_screen.dart'; // Import your FindDoctorScreen

class ClientScreen extends StatefulWidget {
  const ClientScreen({Key? key}) : super(key: key);

  @override
  _ClientScreenState createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  File? _mriScanFile;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickMriScan() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _mriScanFile = File(pickedFile.path);
      });
    }
  }

  void _submitDetails() {
    if (_nameController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _mriScanFile == null) {
      // Show an alert if any field is empty
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please fill all fields and upload an MRI scan.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      // Proceed to the NextScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NextScreen()), // Navigate to NextScreen
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Patient Details'),
        backgroundColor: Colors.teal[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please fill in your details and upload your MRI scan.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickMriScan,
              child: const Text('Upload MRI Scan'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600]),
            ),
            if (_mriScanFile != null) ...[
              const SizedBox(height: 16),
              Text('Uploaded MRI Scan: ${_mriScanFile!.path.split('/').last}'),
            ],
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _submitDetails,
                child: const Text('Submit Details'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dummy NextScreen class for demonstration
class NextScreen extends StatelessWidget {
  const NextScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // After a short delay , navigate to FindDoctorScreen
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FindDoctorScreen()),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Next Steps'),
        backgroundColor: Colors.teal[600],
      ),
      body: Center(
        child: const Text('You have successfully submitted your details! Navigating to Find a Doctor...'),
      ),
    );
  }
}

