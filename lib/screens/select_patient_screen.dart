import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_prescription_screen.dart';
import 'chat_screen.dart';
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
    try {
      Set<String> fetchedPatientIds = {};

      if (widget.isForChat) {
        // Fetch existing chats for this doctor
        QuerySnapshot chatSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .where('doctor_id', isEqualTo: widget.doctorId)
            .get();

        for (var doc in chatSnapshot.docs) {
          fetchedPatientIds.add(doc['patient_id'] as String);
        }

        if (fetchedPatientIds.isEmpty) {
          setState(() {
            patientIds = {};
            patients = [];
            filteredPatients = [];
          });
          return;
        }
      } else {
        // Fetch patients from accepted appointments
        QuerySnapshot appointmentSnapshot = await FirebaseFirestore.instance
            .collection('appointments')
            .where('doctor_id', isEqualTo: widget.doctorId)
            .where('status', isEqualTo: "accepted")
            .get();

        for (var doc in appointmentSnapshot.docs) {
          fetchedPatientIds.add(doc['client_id'] as String);
        }

        // Fetch patients from prescriptions
        QuerySnapshot prescriptionSnapshot = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('doctor_id', isEqualTo: widget.doctorId)
            .get();

        for (var doc in prescriptionSnapshot.docs) {
          fetchedPatientIds.add(doc['patient_id'] as String);
        }

        // Fetch patients from MRI uploads
        QuerySnapshot mriSnapshot = await FirebaseFirestore.instance
            .collection('mri_uploads')
            .where('doctor_id', isEqualTo: widget.doctorId)
            .get();

        for (var doc in mriSnapshot.docs) {
          fetchedPatientIds.add(doc['patient_id'] as String);
        }
      }

      if (fetchedPatientIds.isEmpty) {
        setState(() {
          patientIds = {};
          patients = [];
          filteredPatients = [];
        });
        return;
      }

      // Handle Firestore's whereIn() 10-item limit
      List<Map<String, dynamic>> patientList = [];
      List<String> patientIdList = fetchedPatientIds.toList();

      for (int i = 0; i < patientIdList.length; i += 10) {
        List<String> batch = patientIdList.sublist(
            i, i + 10 > patientIdList.length ? patientIdList.length : i + 10);

        QuerySnapshot patientSnapshot = await FirebaseFirestore.instance
            .collection('clients')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        patientList.addAll(patientSnapshot.docs.map((doc) => {
          "id": doc.id,
          "name": doc['name'] ?? "Unknown Patient"
        }).toList());
      }

      setState(() {
        patientIds = fetchedPatientIds;
        patients = patientList;
        filteredPatients = patientList;
      });

    } catch (e) {
      print("Error fetching patients: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching patients: $e")),
      );
    }
  }

  void _filterPatients() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredPatients = patients
          .where((patient) => patient['name'].toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _handlePatientSelection(String patientId) async {
    if (widget.isForChat) {
      // Handle chat initiation
      String chatId = await _chatService.getChatId(widget.doctorId, patientId);
      if (chatId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              doctorId: widget.doctorId,
              patientId: patientId,
            ),
          ),
        );
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isForChat ? "Select Patient to Chat" : "Select Patient"),
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
            child: filteredPatients.isEmpty
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
                return GestureDetector(
                  onTap: () => _handlePatientSelection(patient['id']),
                  child: Card(
                    color: Colors.teal.shade50,
                    elevation: 3,
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 10, horizontal: 15),
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade700,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        patient['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900,
                        ),
                      ),
                      trailing: Icon(
                        widget.isForChat ? Icons.chat : Icons.medical_services,
                        color: Colors.teal.shade700,
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
