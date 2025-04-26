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
  _PatientProfileCompletionScreenState createState() =>
      _PatientProfileCompletionScreenState();
}

class _PatientProfileCompletionScreenState
    extends State<PatientProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _medicalConditionsController =
      TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _insuranceDetailsController =
      TextEditingController();
  File? _profileImage;
  File? _medicalReport;
  String? _selectedGender;
  bool isLoading = false;
  bool _isLoadingData = true;
  String? _existingProfileImageUrl;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _checkUserAuthentication();
    _fetchExistingPatientData();
  }

  void _checkUserAuthentication() {
    User? user = _auth.currentUser;
    if (user == null) {
      // Redirect to login screen if no user is found
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  Future<void> _fetchExistingPatientData() async {
    setState(() => _isLoadingData = true);

    try {
      // Check both collections where patient data might be stored
      DocumentSnapshot clientDoc =
          await _firestore.collection('clients').doc(widget.patientId).get();

      if (clientDoc.exists) {
        Map<String, dynamic> data =
            clientDoc.data() as Map<String, dynamic>? ?? {};

        _nameController.text = data['fullName'] ?? data['name'] ?? '';
        _dobController.text = data['dob'] ?? '';
        _selectedGender = data['gender'];
        _phoneController.text = data['phoneNumber'] ?? data['phone'] ?? '';
        _emailController.text = data['email'] ?? '';
        _homeAddressController.text = data['address'] ?? '';
        _bloodGroupController.text = data['bloodGroup'] ?? '';
        _medicalConditionsController.text = data['medicalConditions'] ?? '';
        _allergiesController.text = data['allergies'] ?? '';
        _medicationsController.text = data['medications'] ?? '';
        _emergencyContactController.text = data['emergencyContact'] ?? '';
        _insuranceDetailsController.text =
            data['insuranceDetails'] ?? data['insurance'] ?? '';
        _existingProfileImageUrl =
            data['profileImageUrl'] ?? data['profileImage'];
      }
    } catch (e) {
      print("Error fetching patient data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not load existing profile data")));
    }

    setState(() => _isLoadingData = false);
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickMedicalReport() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
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
      String? profileImageUrl = _existingProfileImageUrl;
      String? medicalReportUrl;

      // Upload profile image if selected
      if (_profileImage != null) {
        profileImageUrl = await _uploadFile(
            _profileImage!, 'profile_images/${widget.patientId}.jpg');
      }

      // Upload medical report if selected
      if (_medicalReport != null) {
        medicalReportUrl = await _uploadFile(
            _medicalReport!, 'medical_reports/${widget.patientId}.pdf');
      }

      // Create a data map with all the patient information
      Map<String, dynamic> patientData = {
        'fullName': _nameController.text.trim(),
        'name': _nameController.text
            .trim(), // For compatibility with both field names
        'dob': _dobController.text.trim(),
        'gender': _selectedGender,
        'phoneNumber': _phoneController.text.trim(),
        'phone': _phoneController.text
            .trim(), // For compatibility with both field names
        'email': _emailController.text.trim(),
        'address': _homeAddressController.text.trim(),
        'bloodGroup': _bloodGroupController.text.trim(),
        'medicalConditions': _medicalConditionsController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'medications': _medicationsController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'insuranceDetails': _insuranceDetailsController.text.trim(),
        'insurance': _insuranceDetailsController.text
            .trim(), // For compatibility with both field names
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Only add image URLs if they exist
      if (profileImageUrl != null) {
        patientData['profileImageUrl'] = profileImageUrl;
        patientData['profileImage'] =
            profileImageUrl; // For compatibility with both field names
      }

      if (medicalReportUrl != null) {
        patientData['medicalReportUrl'] = medicalReportUrl;
      }

      // Save to 'clients' collection to ensure consistency
      await _firestore.collection('clients').doc(widget.patientId).set(
            patientData,
            SetOptions(
                merge:
                    true), // Use merge to keep existing data not updated here
          );

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile saved successfully!")));

      // Go back to previous screen after saving
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
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
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : _existingProfileImageUrl != null
                                  ? NetworkImage(_existingProfileImageUrl!)
                                      as ImageProvider
                                  : null,
                          child: (_profileImage == null &&
                                  _existingProfileImageUrl == null)
                              ? const Icon(Icons.camera_alt,
                                  size: 50, color: Colors.white)
                              : null,
                          backgroundColor: Colors.teal.shade200,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(_nameController, 'Full Name', Icons.person,
                        required: true),
                    _buildDateField(required: true),
                    _buildDropdownField(required: true),
                    _buildTextField(
                        _phoneController, 'Phone Number', Icons.phone,
                        required: true),
                    _buildTextField(
                        _emailController, 'Email Address', Icons.email,
                        required: true),
                    _buildTextField(
                        _homeAddressController, 'Home Address', Icons.home),
                    _buildTextField(
                        _bloodGroupController, 'Blood Group', Icons.bloodtype,
                        required: true),
                    _buildTextField(_medicalConditionsController,
                        'Existing Medical Conditions', Icons.local_hospital),
                    _buildTextField(_allergiesController,
                        'Allergies (Any drug/food allergies)', Icons.warning),
                    _buildTextField(_medicationsController,
                        'Current Medications', Icons.medication),
                    _buildTextField(_emergencyContactController,
                        'Emergency Contact Name & Phone', Icons.contact_phone,
                        required: true),
                    _buildTextField(
                        _insuranceDetailsController,
                        'Health Insurance Details (if applicable)',
                        Icons.security),
                    const SizedBox(height: 20),
                    const Text(
                        'Medical History (Optional: Upload Medical Reports)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickMedicalReport,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_medicalReport != null
                          ? 'Medical Report Selected'
                          : 'Upload Medical Report'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: !isLoading ? _saveProfile : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: const Size(200, 50),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Save Profile',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter $label';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDateField({bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _dobController,
        decoration: InputDecoration(
          labelText: required ? 'Date of Birth *' : 'Date of Birth',
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        readOnly: true,
        onTap: _pickDate,
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your date of birth';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDropdownField({bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          labelText: required ? 'Gender *' : 'Gender',
          prefixIcon: const Icon(Icons.wc),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: ['Male', 'Female', 'Other'].map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedGender = newValue;
          });
        },
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your gender';
                }
                return null;
              }
            : null,
      ),
    );
  }
}
