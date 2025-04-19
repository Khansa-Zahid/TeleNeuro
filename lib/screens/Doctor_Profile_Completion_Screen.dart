import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DoctorProfileCompletionScreen extends StatefulWidget {
  final String doctorId;

  const DoctorProfileCompletionScreen({super.key, required this.doctorId});

  @override
  _DoctorProfileCompletionScreenState createState() =>
      _DoctorProfileCompletionScreenState();
}

class _DoctorProfileCompletionScreenState extends State<DoctorProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _clinicAddressController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _availableTimingsController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  File? _profileImage;
  bool isLoading = false;
  TimeOfDay? _selectedTime;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    //_fetchDoctorData();
  }

  Future<void> _fetchDoctorData() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('doctors').doc(widget.doctorId).get();
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          _nameController.text = data['name'] ?? '';
          _specializationController.text = data['specialization'] ?? '';
          _qualificationController.text = data['qualification'] ?? '';
          _experienceController.text = data['experience'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _clinicAddressController.text = data['clinicAddress'] ?? '';
          _availableTimingsController.text = data['availableTimings'] ?? '';
          _emailController.text = data['email'] ?? '';
        }
      }
    } catch (e) {
      print('Error fetching doctor data: $e');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    try {
      Reference storageRef = _storage.ref().child('profile_pictures/doctor_${widget.doctorId}.jpg');
      UploadTask uploadTask = storageRef.putFile(_profileImage!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

  Future<bool> _reauthenticateUser() async {
    try {
      User? user = _auth.currentUser;
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: _passwordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reauthentication failed: $e'))
      );
      return false;
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _availableTimingsController.text = picked.format(context);
      });
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.teal[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) => value!.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.teal[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? Icon(Icons.camera_alt, size: 50, color: Colors.teal[700])
                      : null,
                  backgroundColor: Colors.teal[200],
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(_nameController, 'Full Name', Icons.person),
              _buildTextField(_specializationController, 'Specialization', Icons.work),
              _buildTextField(_qualificationController, 'Qualification', Icons.school),
              _buildTextField(_experienceController, 'Experience', Icons.star),
              _buildTextField(_phoneController, 'Phone', Icons.phone, keyboardType: TextInputType.phone),
              _buildTextField(_clinicAddressController, 'Clinic Address', Icons.location_on),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  controller: _availableTimingsController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Available Timings',
                    prefixIcon: Icon(Icons.access_time, color: Colors.teal[700]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onTap: _pickTime,
                  validator: (value) => value!.isEmpty ? 'Please select available time' : null,
                ),
              ),

              _buildTextField(_emailController, 'New Email', Icons.email),
              _buildTextField(_passwordController, 'Enter Password to Confirm', Icons.lock, obscureText: true),

              const SizedBox(height: 30),

              isLoading
                  ? CircularProgressIndicator(color: Colors.teal[700])
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => isLoading = true);
                    if (widget.doctorId != _auth.currentUser?.uid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Unauthorized'))
                      );
                      setState(() => isLoading = false);
                      return;
                    }
                    bool isAuthenticated = await _reauthenticateUser();
                    if (!isAuthenticated) return;
                    String? profileImageUrl = await _uploadProfileImage();
                    await _firestore.collection('doctors').doc(widget.doctorId).update({
                      'name': _nameController.text.trim(),
                      'profileImage': profileImageUrl ?? "",
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Profile updated successfully!'))
                    );
                    setState(() => isLoading = false);
                  }
                },
                child: const Text('Save Profile', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
