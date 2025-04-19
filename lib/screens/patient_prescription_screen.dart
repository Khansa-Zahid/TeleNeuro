import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class PatientPrescriptionScreen extends StatefulWidget {
  final String patientId;

  const PatientPrescriptionScreen({required this.patientId, Key? key}) : super(key: key);

  @override
  _PatientPrescriptionScreenState createState() => _PatientPrescriptionScreenState();
}

class _PatientPrescriptionScreenState extends State<PatientPrescriptionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _generatePdf(String prescriptionId, Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Prescription", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text("Date: ${data['date'] != null ? DateFormat.yMMMd().format(data['date'].toDate()) : 'Not Available'}"),
            pw.Text("Doctor: ${data['doctor_name']}"),
            pw.Text("Medications:"),
            for (var med in data['medications'])
              pw.Text("- ${med['name']} - ${med['dosage']} (${med['frequency']})"),
            pw.Divider(),
            pw.Text("Notes: ${data['additional_notes'] ?? 'No notes provided'}"),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/prescription_$prescriptionId.pdf");
    await file.writeAsBytes(await pdf.save());

    Share.shareXFiles([XFile(file.path)], text: "Here is your prescription.");
  }


  Future<String> _fetchDoctorName(String doctorId) async {
    DocumentSnapshot doctorSnapshot = await _firestore.collection('doctors').doc(doctorId).get();
    return doctorSnapshot.exists ? doctorSnapshot['name'] ?? "Unknown Doctor" : "Unknown Doctor";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Prescriptions"),
        backgroundColor: Colors.teal[700],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('prescriptions').where('patient_id', isEqualTo: widget.patientId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text("No prescriptions found.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!.docs.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              return FutureBuilder<String>(
                future: _fetchDoctorName(data['doctor_id']),
                builder: (context, doctorSnapshot) {
                  if (!doctorSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text("Doctor: ${doctorSnapshot.data}",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal[800]),
                      ),
                      subtitle: Text("Date: ${data['date'] != null ? DateFormat.yMMMd().format(data['date'].toDate()) : 'Not Available'}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.download, color: Colors.green),
                        onPressed: () => _generatePdf(doc.id, {
                          ...data,
                          'doctor_name': doctorSnapshot.data,
                        }),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrescriptionDetailScreen(data: data, doctorName: doctorSnapshot.data!),
                          ),
                        );
                      },
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
}


class PrescriptionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String doctorName;

  const PrescriptionDetailScreen({required this.data, required this.doctorName, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prescription Details"),
        backgroundColor: Colors.teal[700],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('clients').doc(data['patient_id']).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Fetch patient name, default to "Unknown Patient" if not found
          String patientName = snapshot.data!.exists ? snapshot.data!['name'] ?? "Unknown Patient" : "Unknown Patient";

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Name & Doctor/Date Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Patient: $patientName",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Doctor: $doctorName",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Date: ${DateFormat.yMMMd().format(data['date'].toDate())}",
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Medications Section
                  Text(
                    "Medications:",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                  ),
                  const SizedBox(height: 5),
                  ...data['medications'].map<Widget>((med) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med['name'],
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                          ),
                          Text(
                            "Dosage: ${med['dosage']}",
                            style: TextStyle(fontSize: 15, color: Colors.black87),
                          ),
                          Text(
                            "Frequency: ${med['frequency']}",
                            style: TextStyle(fontSize: 15, color: Colors.black87),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 15),

                  // Notes Section (Moved to the Bottom)
                  if (data['additional_notes'] != null && data['additional_notes'].isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Notes:",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            data['additional_notes'],
                            style: TextStyle(fontSize: 15, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}
