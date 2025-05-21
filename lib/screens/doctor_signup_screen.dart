import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorSignupScreen extends StatefulWidget {
  const DoctorSignupScreen({super.key});

  @override
  State<DoctorSignupScreen> createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String email = '';
  String phoneNumber = '';
  String specialization = '';
  String password = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        // Send email verification
        await userCredential.user!.sendEmailVerification();

        await _firestore
            .collection('doctors')
            .doc(userCredential.user!.uid)
            .set({
          'name': name,
          'email': email,
          'phoneNumber': phoneNumber,
          'specialization': specialization,
          'uid': userCredential.user!.uid,
        });

        // Show a message to the user to check their email
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Signup successful! Please check your email for verification.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signup Failed: ${e.toString()}')),
        );
      }
    }
  }

  Widget _inputField({
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.black87),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
        ),
        onChanged: onChanged,
        validator: validator,
        obscureText: obscureText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F7F4),
      appBar: AppBar(
        title: const Text("Doctor Signup"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 15,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Create Your Account",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _inputField(
                    hint: "Full Name",
                    icon: Icons.person,
                    onChanged: (val) => name = val,
                    validator: (val) =>
                        val!.isEmpty ? 'Name is required' : null,
                  ),
                  _inputField(
                    hint: "Email Address",
                    icon: Icons.email,
                    onChanged: (val) => email = val,
                    validator: (val) =>
                        val!.isEmpty ? 'Email is required' : null,
                  ),
                  _inputField(
                    hint: "Phone Number",
                    icon: Icons.phone,
                    onChanged: (val) => phoneNumber = val,
                    validator: (val) =>
                        val!.isEmpty ? 'Phone number is required' : null,
                  ),
                  _inputField(
                    hint: "Specialization",
                    icon: Icons.medical_services,
                    onChanged: (val) => specialization = val,
                    validator: (val) =>
                        val!.isEmpty ? 'Specialization is required' : null,
                  ),
                  _inputField(
                    hint: "Password",
                    icon: Icons.lock,
                    onChanged: (val) => password = val,
                    validator: (val) =>
                        val!.isEmpty ? 'Password is required' : null,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _signup,
                      icon: const Icon(Icons.check),
                      label: const Text("Sign Up"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
