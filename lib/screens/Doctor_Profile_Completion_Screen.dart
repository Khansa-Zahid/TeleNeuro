import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class DoctorProfileCompletionScreen extends StatefulWidget {
  const DoctorProfileCompletionScreen({super.key});

  @override
  _DoctorProfileCompletionScreenState createState() =>
      _DoctorProfileCompletionScreenState();
}

class _DoctorProfileCompletionScreenState
    extends State<DoctorProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _clinicAddressController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save profile data to Firestore
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      try {
        User? user = _auth.currentUser;

        // Save profile data to Firestore
        await _firestore.collection('doctors').doc(user!.uid).set({
          'name': _nameController.text,
          'specialty': _specialtyController.text,
          'phone': _phoneController.text,
          'clinicAddress': _clinicAddressController.text,
          'experience': _experienceController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Navigate to the dashboard after saving the profile
        Navigator.pushReplacementNamed(context, '/dashboard');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please complete your profile details below:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _specialtyController,
                  decoration: const InputDecoration(labelText: 'Specialty'),
                  validator: (value) => value!.isEmpty ? 'Please enter your specialty' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value!.isEmpty ? 'Please enter your phone number' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _clinicAddressController,
                  decoration: const InputDecoration(labelText: 'Clinic Address'),
                  validator: (value) =>
                  value!.isEmpty ? 'Please enter your clinic address' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _experienceController,
                  decoration: const InputDecoration(labelText: 'Years of Experience'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty
                      ? 'Please enter your years of experience'
                      : null,
                ),
                const SizedBox(height: 30),
                Center(
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text('Save Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
