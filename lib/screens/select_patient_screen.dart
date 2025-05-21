import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_prescription_screen.dart';
import 'doctor_chat_screen.dart';
import 'chat_service.dart';

class SelectPatientScreen extends StatefulWidget {
  final String doctorId;
  final bool isForChat;
  final Function(String, String)? onPatientSelected;

  const SelectPatientScreen({
    Key? key,
    required this.doctorId,
    this.onPatientSelected,
    this.isForChat = false,
  }) : super(key: key);

  @override
  _SelectPatientScreenState createState() => _SelectPatientScreenState();
}

class _SelectPatientScreenState extends State<SelectPatientScreen> {
  final ChatService _chatService = ChatService();
  Set<String> patientIds = {};
  List<Map<String, dynamic>> patients = [];
  List<Map<String, dynamic>> filteredPatients = [];
  TextEditingController searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRelevantPatients();
    searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRelevantPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, Map<String, dynamic>> patientsMap = {};

      // 1. Fetch patients from accepted appointments
      try {
        QuerySnapshot appointmentSnapshot = await FirebaseFirestore.instance
            .collection('appointments')
            .where('doctor_id', isEqualTo: widget.doctorId)
            .where('status',
                isEqualTo: 'accepted') // Only get accepted appointments
            .get();

        for (var doc in appointmentSnapshot.docs) {
          try {
            Map<String, dynamic> appointmentData =
                doc.data() as Map<String, dynamic>;
            String patientId = appointmentData['client_id']?.toString() ?? '';
            if (patientId.isEmpty) continue;

            String status = appointmentData['status']?.toString() ?? 'pending';

            // Safely extract timestamp
            Timestamp interactionTime = Timestamp.now();
            try {
              if (appointmentData.containsKey('appointment_date')) {
                var dateValue = appointmentData['appointment_date'];
                if (dateValue is Timestamp) {
                  interactionTime = dateValue;
                }
              } else if (appointmentData.containsKey('date_time')) {
                var dateValue = appointmentData['date_time'];
                if (dateValue is Timestamp) {
                  interactionTime = dateValue;
                }
              } else if (appointmentData.containsKey('created_at')) {
                var dateValue = appointmentData['created_at'];
                if (dateValue is Timestamp) {
                  interactionTime = dateValue;
                }
              }
            } catch (e) {
              print("Error extracting date from appointment: $e");
            }

            if (!patientsMap.containsKey(patientId)) {
              patientsMap[patientId] = {
                'id': patientId,
                'name': 'Loading...',
                'hasAppointment': true,
                'appointmentStatus': status,
                'lastInteraction': interactionTime,
                'hasPrescription': false
              };
            } else {
              patientsMap[patientId]?['hasAppointment'] = true;
              patientsMap[patientId]?['appointmentStatus'] = status;

              // Update interaction time if more recent
              Timestamp currentTimestamp =
                  patientsMap[patientId]?['lastInteraction'];
              if (interactionTime.compareTo(currentTimestamp) > 0) {
                patientsMap[patientId]?['lastInteraction'] = interactionTime;
              }
            }
          } catch (docError) {
            print("Error processing appointment document: $docError");
          }
        }
      } catch (appointmentError) {
        print("Error fetching appointments: $appointmentError");
      }

      // 2. Fetch patients with prescriptions
      try {
        QuerySnapshot prescriptionSnapshot = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('doctor_id', isEqualTo: widget.doctorId)
            .get();

        for (var doc in prescriptionSnapshot.docs) {
          try {
            Map<String, dynamic> prescriptionData =
                doc.data() as Map<String, dynamic>;
            String patientId = prescriptionData['patient_id']?.toString() ?? '';
            if (patientId.isEmpty) continue;

            Timestamp interactionTime = Timestamp.now();
            try {
              if (prescriptionData.containsKey('date')) {
                var dateValue = prescriptionData['date'];
                if (dateValue is Timestamp) {
                  interactionTime = dateValue;
                }
              }
            } catch (e) {
              print("Error extracting date from prescription: $e");
            }

            if (!patientsMap.containsKey(patientId)) {
              patientsMap[patientId] = {
                'id': patientId,
                'name': 'Loading...',
                'hasAppointment': false,
                'appointmentStatus': 'none',
                'lastInteraction': interactionTime,
                'hasPrescription': true
              };
            } else {
              patientsMap[patientId]?['hasPrescription'] = true;

              // Update interaction time if more recent
              Timestamp currentTimestamp =
                  patientsMap[patientId]?['lastInteraction'];
              if (interactionTime.compareTo(currentTimestamp) > 0) {
                patientsMap[patientId]?['lastInteraction'] = interactionTime;
              }
            }
          } catch (docError) {
            print("Error processing prescription document: $docError");
          }
        }
      } catch (prescriptionError) {
        print("Error fetching prescriptions: $prescriptionError");
      }

      // 3. Fetch active chats if needed
      if (widget.isForChat) {
        try {
          QuerySnapshot chatSnapshot = await FirebaseFirestore.instance
              .collection('chats')
              .where('doctor_id', isEqualTo: widget.doctorId)
              .get();

          for (var doc in chatSnapshot.docs) {
            try {
              Map<String, dynamic> chatData =
                  doc.data() as Map<String, dynamic>;
              String patientId = chatData['patient_id']?.toString() ?? '';
              if (patientId.isEmpty) continue;

              Timestamp interactionTime = Timestamp.now();
              try {
                if (chatData.containsKey('last_message_time')) {
                  var dateValue = chatData['last_message_time'];
                  if (dateValue is Timestamp) {
                    interactionTime = dateValue;
                  }
                }
              } catch (e) {
                print("Error extracting date from chat: $e");
              }

              if (!patientsMap.containsKey(patientId)) {
                patientsMap[patientId] = {
                  'id': patientId,
                  'name': 'Loading...',
                  'hasAppointment': false,
                  'appointmentStatus': 'none',
                  'lastInteraction': interactionTime,
                  'hasPrescription': false,
                  'hasChat': true
                };
              } else {
                patientsMap[patientId]?['hasChat'] = true;

                // Update interaction time if more recent
                Timestamp currentTimestamp =
                    patientsMap[patientId]?['lastInteraction'];
                if (interactionTime.compareTo(currentTimestamp) > 0) {
                  patientsMap[patientId]?['lastInteraction'] = interactionTime;
                }
              }
            } catch (docError) {
              print("Error processing chat document: $docError");
            }
          }
        } catch (chatError) {
          print("Error fetching chats: $chatError");
        }
      }

      // Fetch patient details
      List<String> patientIdList = patientsMap.keys.toList();
      if (patientIdList.isNotEmpty) {
        for (int i = 0; i < patientIdList.length; i += 10) {
          try {
            int endIndex =
                (i + 10 > patientIdList.length) ? patientIdList.length : i + 10;
            List<String> batch = patientIdList.sublist(i, endIndex);

            QuerySnapshot patientSnapshot = await FirebaseFirestore.instance
                .collection('clients')
                .where(FieldPath.documentId, whereIn: batch)
                .get();

            for (var doc in patientSnapshot.docs) {
              try {
                String patientId = doc.id;
                Map<String, dynamic> patientData =
                    doc.data() as Map<String, dynamic>;
                if (patientsMap.containsKey(patientId)) {
                  patientsMap[patientId]?['name'] =
                      patientData['name']?.toString() ?? 'Unknown Patient';
                  patientsMap[patientId]?['email'] =
                      patientData['email']?.toString() ?? 'No email';
                  patientsMap[patientId]?['phone'] =
                      patientData['phoneNumber']?.toString() ?? 'No phone';
                }
              } catch (docError) {
                print("Error processing patient document: $docError");
              }
            }
          } catch (batchError) {
            print("Error fetching patient batch: $batchError");
          }
        }
      }

      // Convert map to list and sort by appointment status (accepted first) then last interaction
      List<Map<String, dynamic>> patientsList = patientsMap.values.toList();

      try {
        patientsList.sort((a, b) {
          try {
            // First sort by appointment status (accepted > pending > other)
            if (a['appointmentStatus'] == 'accepted' &&
                b['appointmentStatus'] != 'accepted') {
              return -1;
            } else if (a['appointmentStatus'] != 'accepted' &&
                b['appointmentStatus'] == 'accepted') {
              return 1;
            }

            // If both have same status, sort by last interaction (most recent first)
            Timestamp aTimestamp = a['lastInteraction'] as Timestamp;
            Timestamp bTimestamp = b['lastInteraction'] as Timestamp;
            return bTimestamp.compareTo(aTimestamp);
          } catch (sortError) {
            print("Error during sort comparison: $sortError");
            return 0;
          }
        });
      } catch (sortError) {
        print("Error sorting patients list: $sortError");
      }

      if (mounted) {
        setState(() {
          patientIds = Set<String>.from(patientIdList);
          patients = patientsList;
          filteredPatients = patientsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching patients: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching patients: $e")),
        );
        setState(() {
          _isLoading = false;
          patients = [];
          filteredPatients = [];
        });
      }
    }
  }

  void _filterPatients() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredPatients = patients
          .where((patient) =>
              patient['name'].toString().toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _handlePatientSelection(String patientId) async {
    if (widget.isForChat) {
      // Handle chat initiation
      String chatId = await _chatService.getChatId(widget.doctorId, patientId);
      if (chatId.isNotEmpty) {
        // Fetch doctor name
        try {
          DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(widget.doctorId)
              .get();

          String doctorName = "Doctor";
          if (doctorDoc.exists) {
            Map<String, dynamic> doctorData =
                doctorDoc.data() as Map<String, dynamic>;
            doctorName = doctorData['name'] ?? "Doctor";
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorChatScreen(
                chatId: chatId,
                doctorId: widget.doctorId,
                patientId: patientId,
                doctorName: doctorName,
              ),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading doctor data: $e")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to start chat")),
        );
      }
    } else {
      // Handle prescription creation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorPrescriptionScreen(
            doctorId: widget.doctorId,
            patientId: patientId,
          ),
        ),
      ).then((_) {
        // Refresh the list when returning from prescription screen
        _fetchRelevantPatients();
      });
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return 'Today, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day - 1) {
      return 'Yesterday, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isForChat ? "Start Chat with Patient" : "Select Patient"),
        backgroundColor: Colors.teal.shade700,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search Patient",
                prefixIcon: Icon(Icons.search, color: Colors.teal.shade700),
                filled: true,
                fillColor: Colors.teal.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.teal))
                : filteredPatients.isEmpty
                    ? Center(
                        child: Text(
                          "No relevant patients found",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = filteredPatients[index];
                          final bool hasAppointment =
                              patient['hasAppointment'] == true;
                          final String appointmentStatus =
                              patient['appointmentStatus'] ?? 'none';
                          final bool hasPrescription =
                              patient['hasPrescription'] == true;

                          return GestureDetector(
                            onTap: () => _handlePatientSelection(patient['id']),
                            child: Card(
                              color: Colors.teal.shade50,
                              elevation: 3,
                              margin: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.teal.shade700,
                                          child: Icon(Icons.person,
                                              color: Colors.white),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                patient['name'],
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal.shade900,
                                                ),
                                              ),
                                              if (patient['email'] != null)
                                                Text(
                                                  patient['email'],
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          widget.isForChat
                                              ? Icons.chat
                                              : Icons.medical_services,
                                          color: Colors.teal.shade700,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            if (hasAppointment)
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(
                                                          appointmentStatus)
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: _getStatusColor(
                                                        appointmentStatus),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  appointmentStatus
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: _getStatusColor(
                                                        appointmentStatus),
                                                  ),
                                                ),
                                              ),
                                            SizedBox(width: 8),
                                            if (hasPrescription)
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.blue,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  "PRESCRIBED",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          _formatTimestamp(
                                              patient['lastInteraction']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
