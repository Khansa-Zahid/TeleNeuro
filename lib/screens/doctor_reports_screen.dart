import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DoctorReportsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorReportsScreen({Key? key, required this.doctorId})
      : super(key: key);

  @override
  _DoctorReportsScreenState createState() => _DoctorReportsScreenState();
}

class _DoctorReportsScreenState extends State<DoctorReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  final Map<String, String> _patientNames = {};
  final Map<String, Color> _reportTypeColors = {
    'Brain MRI Analysis': Colors.red.shade100,
    'Alzheimer MRI Analysis': Colors.orange.shade100,
    'Multiple Sclerosis MRI Analysis': Colors.purple.shade100,
  };

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);

    try {
      QuerySnapshot reportSnapshot;

      try {
        // This query requires a composite index
        reportSnapshot = await _firestore
            .collection('medical_reports')
            .where('doctorId', isEqualTo: widget.doctorId)
            .orderBy('timestamp', descending: true)
            .get();
      } catch (e) {
        // Check if it's an index error and show a helpful message
        if (e.toString().contains('The query requires an index')) {
          reportSnapshot = await _firestore
              .collection('medical_reports')
              .where('doctorId', isEqualTo: widget.doctorId)
              .get();

          // Show index creation dialog
          _showIndexErrorDialog(e.toString());
        } else {
          // Rethrow if it's not an index error
          rethrow;
        }
      }

      final List<Map<String, dynamic>> reports = [];

      for (var doc in reportSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final reportWithId = {
          'id': doc.id,
          ...data,
        };
        reports.add(reportWithId);

        // Fetch patient name if not already cached
        if (data['patientId'] != null &&
            !_patientNames.containsKey(data['patientId'])) {
          await _fetchPatientName(data['patientId']);
        }
      }

      // Sort manually if we couldn't use orderBy due to missing index
      if (!reportSnapshot.metadata.isFromCache) {
        reports.sort((a, b) {
          final aTime = a['timestamp'] as Timestamp?;
          final bTime = b['timestamp'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Descending order
        });
      }

      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching reports: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reports: $e')),
      );
    }
  }

  Future<void> _fetchPatientName(String patientId) async {
    try {
      final DocumentSnapshot patientDoc =
          await _firestore.collection('clients').doc(patientId).get();

      if (patientDoc.exists) {
        final data = patientDoc.data() as Map<String, dynamic>?;
        final name = data?['name'] ?? data?['fullName'] ?? 'Unknown Patient';

        setState(() {
          _patientNames[patientId] = name;
        });
      } else {
        setState(() {
          _patientNames[patientId] = 'Unknown Patient';
        });
      }
    } catch (e) {
      print('Error fetching patient name for $patientId: $e');
      setState(() {
        _patientNames[patientId] = 'Unknown Patient';
      });
    }
  }

  Future<void> _downloadReport(String pdfUrl, String reportType) async {
    try {
      setState(() => _isLoading = true);

      // Extract filename from URL
      final String fileName =
          '${reportType}_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Download the PDF from Firebase Storage
      final ref = _storage.refFromURL(pdfUrl);
      final file = File('${(await getTemporaryDirectory()).path}/$fileName');
      await ref.writeToFile(file);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '$reportType Report',
        text: 'Please find attached the $reportType report.',
      );
    } catch (e) {
      print('Error downloading report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download report: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _downloadReport(pdfUrl, reportType),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showIndexErrorDialog(String errorMessage) {
    // Extract the URL from the error message if present
    final RegExp urlRegex =
        RegExp(r'https:\/\/console\.firebase\.google\.com[^\s]+');
    final Match? match = urlRegex.firstMatch(errorMessage);
    final String? indexUrl = match?.group(0);

    if (!mounted) return;

    // Show dialog only if we're still mounted
    Future.microtask(() => showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Database Index Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This feature requires a database index to work properly. Please ask your developer to create the index by:',
                ),
                const SizedBox(height: 16),
                if (indexUrl != null) ...[
                  const Text(
                      '1. Visit the Firebase Console using the error link'),
                  const Text('2. Sign in with your Firebase account'),
                  const Text('3. Click "Create Index" on the page that opens'),
                  const SizedBox(height: 16),
                  const Text(
                      'Until the index is created, the reports may not be sorted by date.',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ] else
                  const Text(
                      'Ask your developer to create a composite index on "doctorId" and "timestamp" fields in the "medical_reports" collection.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              if (indexUrl != null)
                TextButton(
                  onPressed: () async {
                    try {
                      // Parse and launch the URL
                      final Uri uri = Uri.parse(indexUrl);
                      Navigator.of(context).pop();

                      // Check if we can launch the URL
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Opening Firebase Console...')),
                        );
                      } else {
                        // Show a dialog with the URL if we can't launch it
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Create Firebase Index'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                    'Please open this URL in your browser to create the index:'),
                                const SizedBox(height: 12),
                                SelectableText(
                                  indexUrl,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      print('Error launching URL: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open URL: $e')),
                      );
                    }
                  },
                  child: const Text('Create Index'),
                ),
            ],
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Reports'),
        backgroundColor: Colors.purple.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReports,
            tooltip: 'Refresh Reports',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingShimmer()
          : _reports.isEmpty
              ? _buildEmptyState()
              : _buildReportsList(),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          SizedBox(
            width: 80,
            height: 80,
            child: Icon(
              Icons.folder_open,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No reports available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Reports from patient diagnoses will appear here',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final patientId = report['patientId'];
        final patientName = _patientNames[patientId] ?? 'Loading...';
        final reportType = report['reportType'] ?? 'Unknown';
        final diagnosis =
            report['diagnosis'] ?? report['result'] ?? 'No diagnosis available';
        final confidence = report['confidence'] ?? '';

        // Format timestamp
        final timestamp = report['timestamp'] as Timestamp?;
        final formattedDate = timestamp != null
            ? DateFormat.yMMMd().add_jm().format(timestamp.toDate())
            : 'Unknown date';

        // Determine card color based on report type
        final cardColor = _reportTypeColors[reportType] ?? Colors.blue.shade100;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _downloadReport(report['pdfUrl'], reportType),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          reportType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Patient: $patientName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Diagnosis: $diagnosis',
                    style: TextStyle(
                      color: Colors.grey[800],
                    ),
                  ),
                  if (confidence != null &&
                          confidence.toString().isNotEmpty &&
                          confidence is! double
                      ? confidence.isNotEmpty
                      : true)
                    Text(
                      'Confidence: ${(confidence is double ? (confidence * 100).toStringAsFixed(2) : confidence.toString())}%',
                      style: TextStyle(
                        color: Colors.grey[800],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (report['pdfUrl'] != null)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('View Report'),
                          onPressed: () =>
                              _downloadReport(report['pdfUrl'], reportType),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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
    );
  }
}
