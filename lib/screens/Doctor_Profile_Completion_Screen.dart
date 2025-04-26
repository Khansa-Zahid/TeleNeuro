import 'dart:io';
import 'dart:convert';
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

class _DoctorProfileCompletionScreenState
    extends State<DoctorProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _clinicAddressController =
      TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();

  File? _profileImage;
  String? _currentProfileImageUrl;
  bool isLoading = false;
  bool _profileLoaded = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Available days with checkboxes
  final List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  Map<String, bool> _selectedDays = {};
  Map<String, TimeOfDay> _startTimes = {};
  Map<String, TimeOfDay> _endTimes = {};

  // Default time values
  final TimeOfDay _defaultStartTime = TimeOfDay(hour: 9, minute: 0);
  final TimeOfDay _defaultEndTime = TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    // Initialize selected days map with all days set to false initially
    for (String day in _weekdays) {
      _selectedDays[day] = false;
      _startTimes[day] = _defaultStartTime;
      _endTimes[day] = _defaultEndTime;
    }
    _fetchDoctorData();
  }

  Future<void> _fetchDoctorData() async {
    setState(() {
      isLoading = true;
    });

    try {
      DocumentSnapshot doc =
          await _firestore.collection('doctors').doc(widget.doctorId).get();
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _nameController.text = data['name'] ?? '';
            _specializationController.text = data['specialization'] ?? '';
            _qualificationController.text = data['qualification'] ?? '';
            _experienceController.text = data['experience']?.toString() ?? '';
            _phoneController.text = data['phoneNumber']?.toString() ?? '';
            _clinicAddressController.text = data['clinicAddress'] ?? '';
            _currentProfileImageUrl = data['profileImage'];

            // Parse available timings if they exist
            if (data['availableTimings'] != null &&
                data['availableTimings'] is Map) {
              Map<String, dynamic> timings =
                  Map<String, dynamic>.from(data['availableTimings']);
              timings.forEach((day, timing) {
                if (timing != null && timing is Map) {
                  _selectedDays[day] = true;

                  if (timing['startTime'] != null) {
                    List<String> startParts = timing['startTime'].split(':');
                    if (startParts.length == 2) {
                      _startTimes[day] = TimeOfDay(
                          hour: int.parse(startParts[0]),
                          minute: int.parse(startParts[1]));
                    }
                  }

                  if (timing['endTime'] != null) {
                    List<String> endParts = timing['endTime'].split(':');
                    if (endParts.length == 2) {
                      _endTimes[day] = TimeOfDay(
                          hour: int.parse(endParts[0]),
                          minute: int.parse(endParts[1]));
                    }
                  }
                }
              });
            }

            _profileLoaded = true;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return _currentProfileImageUrl;

    try {
      setState(() {
        isLoading = true;
      });

      Reference storageRef = _storage
          .ref()
          .child('profile_pictures/doctor_${widget.doctorId}.jpg');
      UploadTask uploadTask = storageRef.putFile(_profileImage!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return _currentProfileImageUrl;
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickStartTime(String day) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTimes[day] ?? _defaultStartTime,
    );

    if (picked != null) {
      setState(() {
        _startTimes[day] = picked;
      });
    }
  }

  Future<void> _pickEndTime(String day) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTimes[day] ?? _defaultEndTime,
    );

    if (picked != null) {
      setState(() {
        _endTimes[day] = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Map<String, dynamic> _getAvailableTimingsData() {
    Map<String, dynamic> timings = {};

    for (String day in _weekdays) {
      if (_selectedDays[day] == true) {
        timings[day] = {
          'startTime': _formatTimeOfDay(_startTimes[day] ?? _defaultStartTime),
          'endTime': _formatTimeOfDay(_endTimes[day] ?? _defaultEndTime),
        };
      }
    }

    return timings;
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool obscureText = false,
      TextInputType keyboardType = TextInputType.text}) {
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

  Widget _buildAvailabilitySection() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.teal[700]),
                const SizedBox(width: 8),
                Text(
                  'Available Timings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Select days and hours when you are available for appointments:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            ..._weekdays.map((day) => _buildDayTimeSelector(day)).toList(),
            const SizedBox(height: 8),
            if (_selectedDays.values.every((selected) => !selected))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Please select at least one day with timing',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTimeSelector(String day) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: _selectedDays[day],
            activeColor: Colors.teal[700],
            onChanged: (value) {
              setState(() {
                _selectedDays[day] = value ?? false;
              });
            },
          ),
          SizedBox(
            width: 100,
            child: Text(day, style: const TextStyle(fontSize: 16)),
          ),
          if (_selectedDays[day] == true) ...[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _pickStartTime(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatTimeOfDay(_startTimes[day] ?? _defaultStartTime),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const Text(' to ', style: TextStyle(fontSize: 14)),
                  InkWell(
                    onTap: () => _pickEndTime(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatTimeOfDay(_endTimes[day] ?? _defaultEndTime),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _validateAvailability() {
    return _selectedDays.values.any((selected) => selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      appBar: AppBar(
        title: const Text('Update Your Profile'),
        backgroundColor: Colors.teal[700],
      ),
      body: isLoading && !_profileLoaded
          ? Center(child: CircularProgressIndicator(color: Colors.teal[700]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : (_currentProfileImageUrl != null &&
                                        _currentProfileImageUrl!.isNotEmpty
                                    ? NetworkImage(_currentProfileImageUrl!)
                                        as ImageProvider
                                    : null),
                            child: (_profileImage == null &&
                                    (_currentProfileImageUrl == null ||
                                        _currentProfileImageUrl!.isEmpty))
                                ? Icon(Icons.camera_alt,
                                    size: 50, color: Colors.teal[700])
                                : null,
                            backgroundColor: Colors.teal[200],
                          ),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.teal[700],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(_nameController, 'Full Name', Icons.person),
                    _buildTextField(_specializationController, 'Specialization',
                        Icons.work),
                    _buildTextField(_qualificationController, 'Qualification',
                        Icons.school),
                    _buildTextField(_experienceController,
                        'Years of Experience', Icons.star,
                        keyboardType: TextInputType.number),
                    _buildTextField(
                        _phoneController, 'Phone Number', Icons.phone,
                        keyboardType: TextInputType.phone),
                    _buildTextField(_clinicAddressController, 'Clinic Address',
                        Icons.location_on),
                    _buildAvailabilitySection(),
                    const SizedBox(height: 20),
                    isLoading
                        ? CircularProgressIndicator(color: Colors.teal[700])
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 50, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              if (_formKey.currentState!.validate() &&
                                  _validateAvailability()) {
                                setState(() => isLoading = true);

                                try {
                                  String? profileImageUrl =
                                      await _uploadProfileImage();

                                  Map<String, dynamic> availableTimings =
                                      _getAvailableTimingsData();

                                  await _firestore
                                      .collection('doctors')
                                      .doc(widget.doctorId)
                                      .update({
                                    'name': _nameController.text.trim(),
                                    'specialization':
                                        _specializationController.text.trim(),
                                    'qualification':
                                        _qualificationController.text.trim(),
                                    'experience':
                                        _experienceController.text.trim(),
                                    'phoneNumber': _phoneController.text.trim(),
                                    'clinicAddress':
                                        _clinicAddressController.text.trim(),
                                    'availableTimings': availableTimings,
                                    'profileImage': profileImageUrl ?? "",
                                    'lastUpdated': FieldValue.serverTimestamp(),
                                  });

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('Profile updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ));

                                  Future.delayed(const Duration(seconds: 1),
                                      () {
                                    Navigator.pop(context);
                                  });
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Error updating profile: $e')));
                                } finally {
                                  setState(() => isLoading = false);
                                }
                              } else if (!_validateAvailability()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please select at least one day with timing'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: const Text('Save Profile',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
