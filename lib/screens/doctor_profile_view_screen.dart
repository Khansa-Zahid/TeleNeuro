import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment_type_screen.dart';

class DoctorProfileViewScreen extends StatefulWidget {
  final String doctorId;

  const DoctorProfileViewScreen({required this.doctorId, Key? key})
      : super(key: key);

  @override
  _DoctorProfileViewScreenState createState() =>
      _DoctorProfileViewScreenState();
}

class _DoctorProfileViewScreenState extends State<DoctorProfileViewScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _doctorData = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  Future<void> _fetchDoctorData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot doc =
          await _firestore.collection('doctors').doc(widget.doctorId).get();

      if (doc.exists) {
        setState(() {
          _doctorData = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
        print("Doctor data fetched: $_doctorData");
        print("Available Timings: ${_doctorData['availableTimings']}");
      } else {
        setState(() {
          _isLoading = false;
        });
        print("Doctor document does not exist");
      }
    } catch (e) {
      print("Error fetching doctor data: $e");
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading doctor profile: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        title: Text("Doctor Profile"),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.teal))
          : _doctorData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "Doctor profile not found",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchDoctorData,
                        child: Text("Retry"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildProfileHeader(),
                          _buildDetailsCard(),
                          _buildAdditionalInfo(),
                          SizedBox(height: 80), // Space for the button
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBookAppointmentButton(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildBookAppointmentButton() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            // Get the current user's ID
            // This should be passed from the previous screen or stored in a global state
            String? patientId;

            // If you're navigating from FindDoctorScreen, you should receive patientId
            // For now, try to get it from the arguments
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is Map<String, dynamic> && args.containsKey('patientId')) {
              patientId = args['patientId'];
            }

            if (patientId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        "Patient ID not found. Please try from the Find Doctor screen.")),
              );
              return;
            }

            // Fetch patient data
            DocumentSnapshot patientSnapshot =
                await _firestore.collection('clients').doc(patientId).get();

            if (patientSnapshot.exists) {
              final patientData =
                  patientSnapshot.data() as Map<String, dynamic>;
              final patientName = patientData['name'] ?? 'Unknown Patient';

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppointmentTypeScreen(
                    doctorId: widget.doctorId,
                    doctorName: _doctorData['name'] ?? 'Unknown Doctor',
                    specialization:
                        _doctorData['specialization'] ?? 'Not specified',
                    patientId: patientId!,
                    patientName: patientName,
                    channelName: patientId,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Patient not found in database")),
              );
            }
          } catch (e) {
            print("Error navigating to appointment screen: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: $e")),
            );
          }
        },
        icon: Icon(Icons.calendar_today, color: Colors.white),
        label: Text(
          "Book Appointment",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade700,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      color: Colors.teal.shade700,
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white,
            backgroundImage: _doctorData['profileImage'] != null &&
                    _doctorData['profileImage'].toString().isNotEmpty
                ? NetworkImage(_doctorData['profileImage'])
                : null,
            child: _doctorData['profileImage'] == null ||
                    _doctorData['profileImage'].toString().isEmpty
                ? Text(
                    _getDoctorInitials(),
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700),
                  )
                : null,
          ),
          SizedBox(height: 16),
          Text(
            _doctorData['name'] ?? 'Unknown Doctor',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _doctorData['specialization'] ?? 'Specialization not specified',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Qualifications"),
            SizedBox(height: 8),
            Text(
              _doctorData['qualification'] ?? 'Not specified',
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 32),
            _buildSectionTitle("Experience"),
            SizedBox(height: 8),
            Text(
              "${_doctorData['experience'] ?? 'Not specified'} years",
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 32),
            _buildSectionTitle("Contact Information"),
            SizedBox(height: 12),
            _buildContactItem(
              Icons.email,
              "Email",
              _doctorData['email'] ?? 'Not available',
            ),
            SizedBox(height: 8),
            _buildContactItem(
              Icons.phone,
              "Phone",
              _doctorData['phoneNumber'] ?? 'Not available',
            ),
            SizedBox(height: 8),
            _buildContactItem(
              Icons.location_on,
              "Clinic Address",
              _doctorData['clinicAddress'] ?? 'Not available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Available Timings"),
            SizedBox(height: 12),
            _buildAvailabilityTimings(),
            if (_doctorData['lastUpdated'] != null) ...[
              Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "Profile last updated: ${_formatTimestamp(_doctorData['lastUpdated'])}",
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityTimings() {
    print(
        "Building availability timings with data: ${_doctorData['availableTimings']}");

    // Handle the case when availableTimings is not present or empty
    if (_doctorData['availableTimings'] == null) {
      return Text(
        'No availability specified',
        style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
      );
    }

    // Handle the case when availableTimings is a string (old format)
    if (_doctorData['availableTimings'] is String) {
      return Text(
        _doctorData['availableTimings'],
        style: TextStyle(fontSize: 16),
      );
    }

    try {
      // Safely convert to Map<String, dynamic>
      Map<String, dynamic> timings;
      if (_doctorData['availableTimings'] is Map) {
        timings = Map<String, dynamic>.from(_doctorData['availableTimings']);
      } else {
        return Text(
          'Invalid availability data format',
          style: TextStyle(
              fontSize: 16, fontStyle: FontStyle.italic, color: Colors.red),
        );
      }

      if (timings.isEmpty) {
        return Text(
          'No available times specified',
          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        );
      }

      // Sort days of the week in conventional order
      List<String> orderedDays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];

      // Filter and sort the days based on the orderedDays
      List<String> availableDays = timings.keys.toList();
      availableDays.sort((a, b) {
        int indexA = orderedDays.indexOf(a);
        int indexB = orderedDays.indexOf(b);
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: availableDays.map((day) {
          var daySchedule = timings[day];

          // Check if daySchedule is a valid Map
          if (daySchedule == null) {
            return SizedBox.shrink();
          }

          // Convert to Map if it's not already
          Map<String, dynamic> scheduleMap;
          if (daySchedule is Map) {
            scheduleMap = Map<String, dynamic>.from(daySchedule);
          } else {
            return SizedBox.shrink();
          }

          String startTime = scheduleMap['startTime']?.toString() ?? '00:00';
          String endTime = scheduleMap['endTime']?.toString() ?? '00:00';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Container(
                  width: 100,
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '$startTime - $endTime',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } catch (e) {
      print("Error displaying availability: $e");
      return Text(
        'Error displaying availability: $e',
        style: TextStyle(
            fontSize: 14, fontStyle: FontStyle.italic, color: Colors.red),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.teal.shade800,
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.teal, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getDoctorInitials() {
    String name = _doctorData['name'] ?? '';
    if (name.isEmpty) return '?';

    List<String> nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return (nameParts[0][0] + nameParts[1][0]).toUpperCase();
    } else {
      return name[0].toUpperCase();
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      if (timestamp is Timestamp) {
        DateTime dateTime = timestamp.toDate();
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
      return 'Unknown format';
    } catch (e) {
      return 'Error parsing date';
    }
  }
}
