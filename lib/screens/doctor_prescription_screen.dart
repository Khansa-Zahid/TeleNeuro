import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DoctorPrescriptionScreen extends StatefulWidget {
  final String doctorId;
  final String patientId;

  const DoctorPrescriptionScreen(
      {required this.doctorId, required this.patientId, super.key});

  @override
  _DoctorPrescriptionScreenState createState() =>
      _DoctorPrescriptionScreenState();
}

class _DoctorPrescriptionScreenState extends State<DoctorPrescriptionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _notesController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<Map<String, String>> medications = [];
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Patient details controllers
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientAgeController = TextEditingController();
  final TextEditingController _patientGenderController =
      TextEditingController();

  String patientName = "Loading...";
  String patientAge = "";
  String patientGender = "";
  String doctorName = "Loading...";
  String specialization = "Loading...";
  bool _isLoading = false;
  bool _hasAppointment = false;
  String _appointmentStatus = "";
  bool _patientExists = false;
  bool _showCreatePatientForm = false;

  @override
  void initState() {
    super.initState();
    print(
        "DoctorPrescriptionScreen initialized with doctorId: ${widget.doctorId}, patientId: ${widget.patientId}");
    _validatePatientId();
    _fetchDoctorData();
    _initializeNotifications();
    _addMedication();
  }

  Future<void> _validatePatientId() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Validate that the patientId format is correct (not empty and matches expected format)
      if (widget.patientId.isEmpty) {
        print("Patient ID is empty");
        _handleInvalidPatient(
            "The patient ID is empty. Please select a valid patient.");
        return;
      }

      // Check if the patient exists in Firestore
      await _fetchPatientData();

      if (_patientExists) {
        _checkAppointment();
      }
    } catch (e) {
      print("Error validating patient ID: $e");
      _handleInvalidPatient("Error validating patient: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleInvalidPatient(String errorMessage) {
    if (mounted) {
      print(errorMessage);
      setState(() {
        patientName = "Patient Not Found";
        _patientExists = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Create Patient',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _showCreatePatientForm = true;
            });
          },
        ),
      ));
    }
  }

  Future<void> _createNewPatient() async {
    if (_patientNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Patient name is required"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate a new patient ID if the current one is invalid
      String newPatientId =
          widget.patientId.isEmpty || !_isValidDocumentId(widget.patientId)
              ? FirebaseFirestore.instance.collection('clients').doc().id
              : widget.patientId;

      print("Creating new patient with ID: $newPatientId");

      // Create the patient document
      await _firestore.collection('clients').doc(newPatientId).set({
        'name': _patientNameController.text,
        'age': _patientAgeController.text.isEmpty
            ? null
            : int.tryParse(_patientAgeController.text),
        'gender': _patientGenderController.text,
        'created_by_doctor': widget.doctorId,
        'created_at': FieldValue.serverTimestamp(),
      });

      print("Patient created successfully");
      setState(() {
        patientName = _patientNameController.text;
        patientAge = _patientAgeController.text;
        patientGender = _patientGenderController.text;
        _patientExists = true;
        _showCreatePatientForm = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Patient created successfully"),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print("Error creating patient: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to create patient: $e"),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isValidDocumentId(String id) {
    // Firestore document IDs must not contain '/', '.', '..', or exceed 1500 bytes
    return id.isNotEmpty &&
        !id.contains('/') &&
        !id.contains('.') &&
        id != '..';
  }

  Future<void> _fetchPatientData() async {
    print("Fetching patient data for ID: ${widget.patientId}");
    try {
      DocumentSnapshot doc =
          await _firestore.collection('clients').doc(widget.patientId).get();

      print("Patient document exists: ${doc.exists}");

      if (doc.exists && mounted) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print("Patient data fetched: ${data.toString()}");

        setState(() {
          patientName = data['name'] ?? "Unknown Patient";
          patientAge = data['age']?.toString() ?? "";
          patientGender = data['gender'] ?? "";
          _patientExists = true;

          // Pre-fill the form fields in case editing is needed
          _patientNameController.text = patientName;
          _patientAgeController.text = patientAge;
          _patientGenderController.text = patientGender;
        });
        print("Patient name set to: $patientName");
      } else if (mounted) {
        setState(() {
          patientName = "Patient Not Found";
          _patientExists = false;
        });
        print("Patient document does not exist");
        _handleInvalidPatient(
            "Patient with ID ${widget.patientId} does not exist");
      }
    } catch (e) {
      print("Error fetching patient data: $e");
      if (mounted) {
        _handleInvalidPatient("Failed to load patient: $e");
      }
    }
  }

  Future<void> _fetchDoctorData() async {
    print("Fetching doctor data for ID: ${widget.doctorId}");
    try {
      DocumentSnapshot doc =
          await _firestore.collection('doctors').doc(widget.doctorId).get();

      print("Doctor document exists: ${doc.exists}");

      if (doc.exists && mounted) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print("Doctor data fetched: ${data.toString()}");

        setState(() {
          doctorName = data['name'] ?? "Unknown Doctor";
          specialization = data['specialization'] ?? "No Specialization";
        });
        print("Doctor name set to: $doctorName");
      } else if (mounted) {
        setState(() {
          doctorName = "Unknown Doctor";
          specialization = "No Specialization";
        });
        print("Doctor document does not exist");
      }
    } catch (e) {
      print("Error fetching doctor data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to load doctor information: $e"),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _checkAppointment() async {
    print("Checking for appointments between doctor and patient");
    try {
      QuerySnapshot appointmentSnapshot = await _firestore
          .collection("appointments")
          .where("doctor_id", isEqualTo: widget.doctorId)
          .where("client_id", isEqualTo: widget.patientId)
          .orderBy("date_time", descending: true)
          .limit(1)
          .get();

      print("Found ${appointmentSnapshot.docs.length} appointments");

      if (appointmentSnapshot.docs.isNotEmpty && mounted) {
        Map<String, dynamic> data =
            appointmentSnapshot.docs.first.data() as Map<String, dynamic>;
        print("Latest appointment: ${data.toString()}");

        setState(() {
          _hasAppointment = true;
          _appointmentStatus = data['status'] ?? "unknown";
        });
        print("Has appointment: $_hasAppointment, status: $_appointmentStatus");
      }
    } catch (e) {
      print("Error checking appointment: $e");
    }
  }

  void _initializeNotifications() {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      flutterLocalNotificationsPlugin.initialize(initializationSettings);
    } catch (e) {
      print("Error initializing notifications: $e");
    }
  }

  Future<void> _sendNotification() async {
    try {
      await _firestore.collection('notifications').add({
        'client_id': widget.patientId,
        'title': 'New Prescription',
        'body': 'Dr. $doctorName has added a new prescription for you.',
        'timestamp': FieldValue.serverTimestamp(),
        'doctorId': widget.doctorId,
        'status': 'unread',
      });
      print("Notification sent successfully");
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  void _addMedication() {
    setState(() {
      medications.add({"name": "", "dosage": "", "frequency": ""});
    });
  }

  void _removeMedication(int index) {
    if (medications.length > 1) {
      setState(() {
        medications.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("At least one medication is required"),
          backgroundColor: Colors.orange));
    }
  }

  bool _validateMedications() {
    for (int i = 0; i < medications.length; i++) {
      if (medications[i]["name"]?.isEmpty ?? true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Medicine #${i + 1} name cannot be empty"),
            backgroundColor: Colors.red));
        return false;
      }
      if (medications[i]["dosage"]?.isEmpty ?? true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Medicine #${i + 1} dosage cannot be empty"),
            backgroundColor: Colors.red));
        return false;
      }
      if (medications[i]["frequency"]?.isEmpty ?? true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Medicine #${i + 1} frequency cannot be empty"),
            backgroundColor: Colors.red));
        return false;
      }
    }
    return true;
  }

  Future<void> _savePrescriptionDirectly() async {
    print("Creating prescription directly without appointment check");
    try {
      String prescriptionId =
          "presc_${widget.doctorId}_${widget.patientId}_${DateTime.now().millisecondsSinceEpoch}";

      List<Map<String, dynamic>> medicationsList = medications
          .map((med) => {
                'name': med['name'] ?? '',
                'dosage': med['dosage'] ?? '',
                'frequency': med['frequency'] ?? '',
              })
          .toList();

      print("Saving prescription with ID: $prescriptionId");
      print("Medications: $medicationsList");

      await _firestore.collection('prescriptions').doc(prescriptionId).set({
        'prescription_id': prescriptionId,
        'doctor_id': widget.doctorId,
        'patient_id': widget.patientId,
        'date': Timestamp.now(),
        'medications': medicationsList,
        'additional_notes': _notesController.text,
        'created_manually': true,
      });

      await _sendNotification();
      print("Prescription saved successfully");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Prescription saved successfully!"),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error saving prescription directly: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to save prescription: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _savePrescription() async {
    print("Saving prescription");
    if (!_validateMedications()) {
      print("Medication validation failed");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // First try using the service (which requires an appointment)
      if (_hasAppointment && _appointmentStatus == "accepted") {
        print(
            "Using FirestoreService to save prescription (has accepted appointment)");
        try {
          await FirestoreService().addPrescription(widget.doctorId,
              widget.patientId, medications, _notesController.text);
          await _sendNotification();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Prescription saved successfully!"),
                backgroundColor: Colors.green));
            Navigator.pop(context);
          }
          return;
        } catch (serviceError) {
          print(
              "Error with FirestoreService: $serviceError, trying direct method...");
          // If the service fails, fall back to direct method
        }
      }

      // Fall back to direct method if no appointment or service failed
      await _savePrescriptionDirectly();
    } catch (e) {
      print("Error in _savePrescription: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to save prescription: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showCreatePatientForm
            ? "Create New Patient"
            : "Write Prescription"),
        backgroundColor: Colors.teal,
        actions: [
          if (!_showCreatePatientForm && !_patientExists)
            IconButton(
              icon: Icon(Icons.person_add),
              onPressed: () {
                setState(() {
                  _showCreatePatientForm = true;
                });
              },
              tooltip: "Create New Patient",
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.teal))
          : _showCreatePatientForm
              ? _buildCreatePatientForm()
              : Form(
                  key: _formKey,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Patient:",
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey)),
                                      Text(patientName,
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: _patientExists
                                                  ? Colors.teal
                                                  : Colors.red)),
                                      if (_patientExists &&
                                          (patientAge.isNotEmpty ||
                                              patientGender.isNotEmpty))
                                        Text(
                                          [
                                            if (patientAge.isNotEmpty)
                                              "$patientAge years",
                                            if (patientGender.isNotEmpty)
                                              patientGender,
                                          ].join(', '),
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700]),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("Doctor:",
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey)),
                                      Text(doctorName,
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal)),
                                      Text(specialization,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_patientExists)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red[800]),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Patient doesn't exist",
                                        style: TextStyle(
                                          color: Colors.red[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "You need to create a patient record first. Click the button below to create a new patient.",
                                  style: TextStyle(color: Colors.red[800]),
                                ),
                                SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showCreatePatientForm = true;
                                    });
                                  },
                                  icon: Icon(Icons.person_add),
                                  label: Text("Create New Patient"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_patientExists && !_hasAppointment)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange[800]),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "No active appointment found with this patient. Prescription will be created directly.",
                                    style: TextStyle(color: Colors.orange[800]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_patientExists) ...[
                          SizedBox(height: 16),
                          Text("Medications",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Expanded(
                            child: medications.isEmpty
                                ? Center(
                                    child: Text(
                                      "Add medications using the button below",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: medications.length,
                                    itemBuilder: (context, index) {
                                      return Card(
                                        margin: EdgeInsets.only(bottom: 12),
                                        child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text("Medicine #${index + 1}",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  IconButton(
                                                    icon: Icon(Icons.delete,
                                                        color: Colors.red),
                                                    onPressed: () =>
                                                        _removeMedication(
                                                            index),
                                                  ),
                                                ],
                                              ),
                                              TextFormField(
                                                decoration: InputDecoration(
                                                  labelText: "Medicine Name*",
                                                  border: OutlineInputBorder(),
                                                ),
                                                initialValue: medications[index]
                                                    ["name"],
                                                onChanged: (value) =>
                                                    medications[index]["name"] =
                                                        value,
                                                validator: (value) =>
                                                    value?.isEmpty ?? true
                                                        ? "Required"
                                                        : null,
                                              ),
                                              SizedBox(height: 8),
                                              TextFormField(
                                                decoration: InputDecoration(
                                                  labelText: "Dosage*",
                                                  hintText: "e.g., 500mg, 5ml",
                                                  border: OutlineInputBorder(),
                                                ),
                                                initialValue: medications[index]
                                                    ["dosage"],
                                                onChanged: (value) =>
                                                    medications[index]
                                                        ["dosage"] = value,
                                                validator: (value) =>
                                                    value?.isEmpty ?? true
                                                        ? "Required"
                                                        : null,
                                              ),
                                              SizedBox(height: 8),
                                              TextFormField(
                                                decoration: InputDecoration(
                                                  labelText: "Frequency*",
                                                  hintText:
                                                      "e.g., Twice daily, After meals",
                                                  border: OutlineInputBorder(),
                                                ),
                                                initialValue: medications[index]
                                                    ["frequency"],
                                                onChanged: (value) =>
                                                    medications[index]
                                                        ["frequency"] = value,
                                                validator: (value) =>
                                                    value?.isEmpty ?? true
                                                        ? "Required"
                                                        : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              labelText: "Additional Notes",
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _addMedication,
                                  icon: Icon(Icons.add),
                                  label: Text("Add Medicine"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _savePrescription,
                                  icon: Icon(Icons.save),
                                  label: Text("Save Prescription"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildCreatePatientForm() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Create New Patient",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          TextFormField(
            controller: _patientNameController,
            decoration: InputDecoration(
              labelText: "Patient Name*",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          SizedBox(height: 12),
          TextFormField(
            controller: _patientAgeController,
            decoration: InputDecoration(
              labelText: "Age",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake),
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 12),
          TextFormField(
            controller: _patientGenderController,
            decoration: InputDecoration(
              labelText: "Gender",
              hintText: "Male, Female, Other",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.people),
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createNewPatient,
                  icon: Icon(Icons.save),
                  label: Text("Create Patient"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showCreatePatientForm = false;
                    });
                  },
                  icon: Icon(Icons.arrow_back),
                  label: Text("Go Back"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
