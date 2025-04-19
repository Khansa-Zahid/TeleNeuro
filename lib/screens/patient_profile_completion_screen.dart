import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class PatientProfileCompletionScreen extends StatefulWidget {
  final String patientId;
  const PatientProfileCompletionScreen({super.key, required this.patientId});

  @override
  _PatientProfileCompletionScreenState createState() => _PatientProfileCompletionScreenState();
}

class _PatientProfileCompletionScreenState extends State<PatientProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _medicalConditionsController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _insuranceDetailsController = TextEditingController();
  File? _profileImage;
  File? _medicalReport;
  String? _selectedGender;
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _checkUserAuthentication();
  }

  void _checkUserAuthentication() {
    User? user = _auth.currentUser;
    if (user == null) {
      // Redirect to login screen if no user is found
      Navigator.pushReplacementNamed(context, "/login");
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

  Future<void> _pickMedicalReport() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _medicalReport = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      String? profileImageUrl;
      String? medicalReportUrl;

      // Upload profile image if selected
      if (_profileImage != null) {
        profileImageUrl = await _uploadFile(_profileImage!, 'profile_images/${widget.patientId}.jpg');
      }

      // Upload medical report if selected
      if (_medicalReport != null) {
        medicalReportUrl = await _uploadFile(_medicalReport!, 'medical_reports/${widget.patientId}.pdf');
      }

      await _firestore.collection('patients').doc(widget.patientId).set({
        'fullName': _nameController.text,
        'dob': _dobController.text,
        'gender': _selectedGender,
        'phoneNumber': _phoneController.text,
        'email': _emailController.text,
        'address': _homeAddressController.text,
        'bloodGroup': _bloodGroupController.text,
        'medicalConditions': _medicalConditionsController.text,
        'allergies': _allergiesController.text,
        'medications': _medicationsController.text,
        'emergencyContact': _emergencyContactController.text,
        'insuranceDetails': _insuranceDetailsController.text,
        'profileImageUrl': profileImageUrl,
        'medicalReportUrl': medicalReportUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile saved successfully!"))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"))
      );
    }

    setState(() => isLoading = false);
  }

  Future<String> _uploadFile(File file, String path) async {
    UploadTask uploadTask = _storage.ref().child(path).putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Your Profile'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null ? Icon(Icons.camera_alt, size: 50, color: Colors.white) : null,
                    backgroundColor: Colors.teal.shade200,
                  ),
                ),
              ),
              SizedBox(height: 20),
              _buildTextField(_nameController, 'Full Name', Icons.person),
              _buildDateField(),
              _buildDropdownField(),
              _buildTextField(_phoneController, 'Phone Number', Icons.phone),
              _buildTextField(_emailController, 'Email Address', Icons.email),
              _buildTextField(_homeAddressController, 'Home Address', Icons.home),
              _buildTextField(_bloodGroupController, 'Blood Group', Icons.bloodtype),
              _buildTextField(_medicalConditionsController, 'Existing Medical Conditions', Icons.local_hospital),
              _buildTextField(_allergiesController, 'Allergies (Any drug/food allergies)', Icons.warning),
              _buildTextField(_medicationsController, 'Current Medications', Icons.medication),
              _buildTextField(_emergencyContactController, 'Emergency Contact Name & Phone', Icons.contact_phone),
              _buildTextField(_insuranceDetailsController, 'Health Insurance Details (if applicable)', Icons.security),
              SizedBox(height: 20),
              Text('Medical History (Optional: Upload Medical Reports)', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickMedicalReport,
                icon: Icon(Icons.upload_file),
                label: Text('Upload Medical Report'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Save Profile'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _dobController,
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        readOnly: true,
        onTap: _pickDate,
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          labelText: 'Gender',
          prefixIcon: Icon(Icons.wc),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: ['Male', 'Female', 'Other'].map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (String? newValue) {
          setState(() { _selectedGender = newValue; });
        },
      ),
    );
  }
}
