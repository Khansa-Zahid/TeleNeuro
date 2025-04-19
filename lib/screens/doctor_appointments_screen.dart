import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorAppointmentsScreen({super.key, required this.doctorId});

  @override
  _DoctorAppointmentsScreenState createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  DateTime selectedDate = DateTime.now();
  bool isDarkMode = false;
  bool showAllAppointments = false;

  void _toggleDarkMode() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  void _toggleAppointmentsView() {
    setState(() {
      showAllAppointments = !showAllAppointments;
    });
  }

  void _changeDate(DateTime newDate) {
    setState(() {
      selectedDate = newDate;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchAppointments() async {
    QuerySnapshot snapshot = await firestore
        .collection("appointments")
        .where("doctor_id", isEqualTo: widget.doctorId)
        .get();

    List<Map<String, dynamic>> appointments = [];

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data["date_time"] != null) {
        DateTime appointmentDate = DateTime.parse(data["date_time"]);

        if (showAllAppointments ||
            (appointmentDate.year == selectedDate.year &&
                appointmentDate.month == selectedDate.month &&
                appointmentDate.day == selectedDate.day)) {

          DocumentSnapshot clientSnapshot = await firestore
              .collection("clients")
              .doc(data['client_id'])
              .get();

          var clientData = clientSnapshot.data() as Map<String, dynamic>?;

          if (clientData != null && clientData.containsKey('name')) {
            data['client_name'] = clientData['name'];
          } else {
            data['client_name'] = "Client Not Found";
          }

          data['formatted_time'] = DateFormat('dd MMM yyyy, hh:mm a').format(appointmentDate);
          data['appointment_id'] = doc.id;
          appointments.add(data);
        }
      }
    }
    return appointments;
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String clientId, String status) async {
    await firestore.collection("appointments").doc(appointmentId).update({"status": status});
    await _storeNotification(clientId, status);
    setState(() {});
  }

  Future<void> _storeNotification(String clientId, String status) async {
    await firestore.collection("notifications").add({
      "client_id": clientId,
      "title": "Appointment Update", // Add title to differentiate
      "message": "Your appointment has been $status.",
      "timestamp": FieldValue.serverTimestamp(),
      "status": "unread",
      "type": "appointment" // Add a type field for further filtering
    });
  }


  Widget _buildShimmerEffect() {
    return ListView.builder(
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekBar() {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.teal[800]),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(Duration(days: 7));
              });
            },
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                DateTime date = selectedDate.subtract(Duration(days: selectedDate.weekday - 1 - index));
                bool isSelected = date.day == selectedDate.day;

                return GestureDetector(
                  onTap: () => _changeDate(date),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.teal[300] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          DateFormat.E().format(date),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${date.day}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward, color: isDarkMode ? Colors.white : Colors.teal[800]),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.add(Duration(days: 7));
              });
            },
          ),
        ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.teal[50],
      appBar: AppBar(
        title: const Text("Appointments"),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.teal[700],
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: _toggleDarkMode,
          ),
          IconButton(
            icon: Icon(showAllAppointments ? Icons.filter_list : Icons.list_alt),
            onPressed: _toggleAppointmentsView,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekBar(),
          Expanded(
            child: FutureBuilder(
              future: _fetchAppointments(),
              builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerEffect();
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  children: snapshot.data!.map((data) {
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text("Appointment with ${data['client_name']}"),
                        subtitle: Text(
                          "Type: ${data['appointment_type']}\n"
                              "Status: ${data['status'].toUpperCase()}\n"
                              "Time: ${data['formatted_time']}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () => _updateAppointmentStatus(data['appointment_id'], data['client_id'], "Accepted"),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _updateAppointmentStatus(data['appointment_id'], data['client_id'], "Rejected"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}