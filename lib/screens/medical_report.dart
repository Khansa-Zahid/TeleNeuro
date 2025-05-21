import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicalReportScreen extends StatelessWidget {
  final String currentDoctorId;

  const MedicalReportScreen({
    Key? key,
    required this.currentDoctorId,
  }) : super(key: key);

  /// Saves the medical report metadata to Firestore
  static Future<void> saveReportMetadata({
    required String patientId,
    required String doctorId,
    required String diagnosis,
    required String reportUrl,
    required String reportType,
    required String severity,
    required double confidence,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('medical_reports').add({
        'patientId': patientId,
        'doctorId': doctorId,
        'diagnosis': diagnosis,
        'report_url': reportUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'reportType': reportType,
        'severity': severity,
        'confidence': confidence,
      });
    } catch (e) {
      print('Error saving report metadata: $e');
      rethrow;
    }
  }

  /// Fetches medical reports for the current doctor
  Stream<QuerySnapshot> getDoctorReports(String doctorId) {
    return FirebaseFirestore.instance
        .collection('medical_reports')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Reports'),
        backgroundColor: Colors.teal[700],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getDoctorReports(currentDoctorId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final reports = snapshot.data!.docs;

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reports available',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reports will appear here when patients send them',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return _buildReportList(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildReportList(BuildContext context, QuerySnapshot snapshot) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: snapshot.docs.length,
      itemBuilder: (context, index) {
        final doc = snapshot.docs[index];
        final data = doc.data() as Map<String, dynamic>;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              data['reportType'] ?? 'Medical Report',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Diagnosis: ${data['diagnosis']}'),
                Text('Patient ID: ${data['patientId']}'),
                Text('Date: ${_formatDate(data['timestamp'])}'),
                if (data['severity'] != null)
                  Text(
                    'Severity: ${data['severity']}',
                    style: TextStyle(
                      color: _getSeverityColor(data['severity']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (data['confidence'] != null)
                  Text(
                    'Confidence: ${(data['confidence'] is double ? (data['confidence'] * 100).toStringAsFixed(2) : data['confidence'].toString())}%',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
              ],
            ),
            trailing: ElevatedButton.icon(
              onPressed: () => _openPdf(context, data['report_url']),
              icon: const Icon(Icons.download),
              label: const Text('View PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    final date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  Future<void> _openPdf(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open PDF')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }
}
