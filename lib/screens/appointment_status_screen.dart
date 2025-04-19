import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentStatusScreen extends StatelessWidget {
  final String clientId;

  const AppointmentStatusScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Appointments"),
        backgroundColor: Colors.teal.shade400,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('client_id', isEqualTo: clientId)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No appointments found."));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!.docs.map((doc) {
              var appointment = doc.data() as Map<String, dynamic>;
              String doctorId = appointment['doctor_id'] ?? '';
              String appointmentType = appointment['appointment_type'] ?? 'Unknown';

              return FutureBuilder(
                future: _fetchDoctorName(doctorId),
                builder: (context, AsyncSnapshot<String> doctorSnapshot) {
                  String doctorName = doctorSnapshot.data ?? "Unknown";

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.teal),
                      title: Text("Dr. $doctorName"),
                      subtitle: Text("Type: $appointmentType\nStatus: ${appointment['status'] ?? 'Unknown'}"),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _getStatusColor(appointment['status']),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          appointment['status'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // Fetch doctor name using doctor_id
  Future<String> _fetchDoctorName(String doctorId) async {
    try {
      if (doctorId.isEmpty) return "Unknown";
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance.collection('doctors').doc(doctorId).get();
      return doctorDoc.exists ? doctorDoc['name'] : "Unknown";  // <-- Corrected field name
    } catch (e) {
      print("Error fetching doctor name: $e");
      return "Unknown";
    }
  }

  // Function to get color based on appointment status
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case "pending":
        return Colors.orange;
      case "accepted":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
