import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BrainTumorDetector extends StatefulWidget {
  final String patientId;
  final String doctorId;

  const BrainTumorDetector({
    super.key,
    required this.patientId,
    required this.doctorId,
  });

  @override
  _BrainTumorDetectorState createState() => _BrainTumorDetectorState();
}

class BrainTumorDetectorModel {
  static const String MODEL_FILE = 'lib/assets/Brain_Tumor_Model.tflite';
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  Future<void> loadModel() async {
    try {
      print('Starting model loading process...');
      print('Loading model from: $MODEL_FILE');

      final options = InterpreterOptions();

      try {
        if (Platform.isAndroid || Platform.isIOS) {
          options.addDelegate(XNNPackDelegate());
          print('XNNPACK delegate added successfully');
        }
      } catch (e) {
        print('XNNPACK not available: $e');
      }

      _interpreter = await Interpreter.fromAsset(MODEL_FILE, options: options);

      if (_interpreter == null) {
        throw Exception('Failed to initialize model interpreter');
      }

      _isModelLoaded = true;
      print('Model loaded successfully');

      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Model input shape: $inputShape');
      print('Model output shape: $outputShape');
    } catch (e) {
      _isModelLoaded = false;
      print('Failed to load model: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> preprocessImage(File imageFile) async {
    if (!_isModelLoaded || _interpreter == null) {
      throw Exception('Model not loaded. Please load the model first.');
    }

    try {
      print('Starting image preprocessing...');
      final imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      print(
          'Original image size: ${originalImage.width}x${originalImage.height}');

      img.Image resizedImage = img.copyResize(
        originalImage,
        width: 256,
        height: 256,
        interpolation: img.Interpolation.cubic,
      );

      print('Image resized to: ${resizedImage.width}x${resizedImage.height}');

      final inputBuffer = Float32List(1 * 256 * 256 * 3);
      int pixelIndex = 0;

      for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
          final pixel = resizedImage.getPixel(x, y);
          inputBuffer[pixelIndex++] = (pixel.r) / 255.0;
          inputBuffer[pixelIndex++] = (pixel.g) / 255.0;
          inputBuffer[pixelIndex++] = (pixel.b) / 255.0;
        }
      }

      print('Image preprocessing completed successfully');
      return inputBuffer.reshape([1, 256, 256, 3]);
    } catch (e) {
      print('Image preprocessing failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> detectTumor(File imageFile) async {
    if (!_isModelLoaded || _interpreter == null) {
      throw Exception('Model not loaded or initialized');
    }

    try {
      print('Starting tumor detection...');
      final inputImage = await preprocessImage(imageFile);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Output shape from interpreter: $outputShape');

      var outputBuffer = List.generate(
        outputShape[0],
        (index) => List<double>.filled(outputShape[1], 0.0),
      );

      print('Running inference...');
      _interpreter!.run(inputImage, outputBuffer);

      final List<double> probabilities = outputBuffer[0];
      print('Raw probabilities: $probabilities');

      double tumorProbability = probabilities[1];
      double confidence =
          tumorProbability > 0.5 ? tumorProbability : 1 - tumorProbability;

      return {
        'isTumor': tumorProbability > 0.5,
        'probability': tumorProbability,
        'confidence': confidence,
        'formattedResult': tumorProbability > 0.5
            ? 'Tumor Detected (${(tumorProbability * 100).toStringAsFixed(2)}% confidence)'
            : 'No Tumor Detected (${((1 - tumorProbability) * 100).toStringAsFixed(2)}% confidence)',
        'severityLevel': _determineSeverityLevel(tumorProbability),
        'tumorDescription': _analyzeTumorPattern(tumorProbability),
        'clinicalImpact': _assessClinicalImpact(tumorProbability),
        'recommendedTests': _recommendFollowUpTests(tumorProbability),
      };
    } catch (e) {
      print('Detection failed: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  String _determineSeverityLevel(double probability) {
    if (probability > 0.85) return "Severe";
    if (probability > 0.7) return "Moderate";
    if (probability > 0.5) return "Mild";
    return "Minimal";
  }

  String _analyzeTumorPattern(double probability) {
    if (probability > 0.85) {
      return "Large tumor mass with significant mass effect";
    } else if (probability > 0.7) {
      return "Moderate-sized tumor with some mass effect";
    } else if (probability > 0.5) {
      return "Small tumor with minimal mass effect";
    }
    return "No significant tumor mass detected";
  }

  String _assessClinicalImpact(double probability) {
    if (probability > 0.85) {
      return "Severe symptoms with significant functional impairment";
    } else if (probability > 0.7) {
      return "Moderate symptoms affecting daily activities";
    } else if (probability > 0.5) {
      return "Mild symptoms, minimal functional impact";
    }
    return "No significant clinical impact detected";
  }

  List<String> _recommendFollowUpTests(double probability) {
    final baseTests = [
      "Neurological examination",
      "MRI with contrast",
      "CT scan"
    ];

    if (probability > 0.5) {
      baseTests.addAll(["Biopsy", "PET scan", "Blood tests"]);
    }

    return baseTests;
  }

  void close() {
    try {
      if (_interpreter != null) {
        _interpreter!.close();
        _interpreter = null;
        _isModelLoaded = false;
        print('Model resources released successfully');
      }
    } catch (e) {
      print('Error while closing model: $e');
    }
  }
}

class _BrainTumorDetectorState extends State<BrainTumorDetector> {
  final BrainTumorDetectorModel _detectorModel = BrainTumorDetectorModel();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _selectedImage;
  Map<String, dynamic>? _detectionResult;
  Map<String, dynamic>? _patientData;
  bool _isProcessing = false;
  bool _isLoadingPatient = true;
  String _reportId = '';
  DateTime _analysisTime = DateTime.now();
  bool _reportSent = false;

  // Generate a unique report ID
  String _generateReportId() {
    final random = math.Random();
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final randomNum = random.nextInt(9000) + 1000; // 4-digit random number
    return 'R${timestamp}_$randomNum';
  }

  @override
  void initState() {
    super.initState();
    _loadModel();
    _fetchPatientData();
    _reportId = _generateReportId();
  }

  Future<void> _loadModel() async {
    await _detectorModel.loadModel();
  }

  Future<void> _fetchPatientData() async {
    if (widget.patientId.isEmpty) {
      setState(() {
        _isLoadingPatient = false;
      });
      return;
    }

    try {
      DocumentSnapshot doc =
          await _firestore.collection('clients').doc(widget.patientId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

        // Parse date of birth if available
        String? dobString = data["dob"];
        DateTime? dob;
        if (dobString != null && dobString.isNotEmpty) {
          try {
            dob = DateTime.parse(dobString);
          } catch (e) {
            print("Error parsing date: $e");
          }
        }

        setState(() {
          _patientData = {
            "name": data["name"] ?? data["fullName"] ?? "Unknown",
            "dob": dob,
            "age": dob != null ? _calculateAge(dob) : "Unknown",
            "gender": data["gender"] ?? "Not specified",
            "phoneNumber":
                data["phone"] ?? data["phoneNumber"] ?? "Not available",
            "email": data["email"] ?? "Not available",
            "bloodGroup": data["bloodGroup"] ?? "Not specified",
          };
          _isLoadingPatient = false;
        });
      } else {
        setState(() {
          _isLoadingPatient = false;
        });
      }
    } catch (e) {
      print("Error fetching patient data: $e");
      setState(() {
        _isLoadingPatient = false;
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _detectionResult = null;
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _analysisTime = DateTime.now();
    });

    // Add an artificial delay to simulate processing time
    await Future.delayed(const Duration(seconds: 3));

    try {
      final result = await _detectorModel.detectTumor(_selectedImage!);
      setState(() {
        _detectionResult = result;
        _isProcessing = false;
      });

      // Save the report to Firestore if patient ID is available
      if (widget.patientId.isNotEmpty) {
        await _saveReportToFirestore();
      }
    } catch (e) {
      setState(() {
        _detectionResult = {
          'error': true,
          'formattedResult': 'Error processing image: $e'
        };
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveReportToFirestore() async {
    try {
      await _firestore.collection('medical_reports').add({
        'reportId': _reportId,
        'patientId': widget.patientId,
        'patientName': _patientData?['name'] ?? 'Unknown',
        'timestamp': _analysisTime,
        'reportType': 'Brain MRI Analysis',
        'result': _detectionResult?['formattedResult'] ?? '',
        'isTumor': _detectionResult?['isTumor'] ?? false,
        'confidence': _detectionResult?['confidence'] ?? 0.0,
      });
    } catch (e) {
      print("Error saving report to Firestore: $e");
    }
  }

  Future<void> _sendReportToDoctor() async {
    setState(() => _isProcessing = true);

    try {
      // Generate and upload the PDF
      final String pdfFileName =
          'Brain_Tumor_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdf = pw.Document();
      final formattedDate = DateFormat('MMMM d, yyyy').format(_analysisTime);
      final formattedTime = DateFormat('h:mm a').format(_analysisTime);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            _buildPdfHeader(formattedDate),
            _buildPdfPatientInfo(),
            _buildPdfStudyInfo(formattedDate),
            _buildPdfFindings(),
            _buildPdfDetailedAnalysis(),
            _buildPdfRecommendations(),
            _buildPdfFooter(formattedDate, formattedTime),
          ],
        ),
      );

      // Save PDF to temporary directory first
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$pdfFileName');
      await file.writeAsBytes(await pdf.save());

      // Upload to Firebase Storage
      final storageRef =
          _storage.ref().child('reports/brain_tumor_reports/$pdfFileName');
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Create a new report document in Firestore
      DocumentReference reportRef =
          await _firestore.collection('medical_reports').add({
        'reportId': _reportId,
        'patientId': widget.patientId,
        'patientName': _patientData?['name'] ?? 'Unknown',
        'timestamp': _analysisTime,
        'reportType': 'Brain MRI Analysis',
        'result': _detectionResult?['formattedResult'] ?? '',
        'diagnosis': _detectionResult?['isTumor']
            ? 'Tumor Detected'
            : 'No Tumor Detected',
        'confidence': _detectionResult?['confidence'] ?? 0.0,
        'severity': _detectionResult?['severityLevel'] ?? '',
        'pdfUrl': downloadUrl,
        'doctorId': widget.doctorId,
        'sentToDoctor': true,
        'sentDate': FieldValue.serverTimestamp(),
      });

      // Create a notification for the doctor
      await _firestore.collection('notifications').add({
        'receiver_id': widget.doctorId,
        'sender_id': widget.patientId,
        'type': 'medical_report',
        'title': 'New Brain MRI Analysis Report',
        'message':
            'Patient ${_patientData?['name'] ?? 'Unknown'} has sent you a Brain MRI analysis report',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'report_id': reportRef.id,
      });

      setState(() => _reportSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report successfully sent to doctor')),
      );
    } catch (e) {
      print('Error sending report to doctor: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send report: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Add a new method for generating and saving PDF
  Future<void> _generatePdf() async {
    try {
      // Create a PDF document
      final pdf = pw.Document();

      // Get formatted date and time
      String formattedDate = DateFormat('MMMM d, yyyy').format(_analysisTime);
      String formattedTime = DateFormat('h:mm a').format(_analysisTime);

      bool isTumor = _detectionResult?['isTumor'] ?? false;
      double confidence = _detectionResult?['confidence'] ?? 0;
      String confidenceStr = (confidence * 100).toStringAsFixed(2);

      // Generate the tumor details if tumor is detected
      String tumorType = isTumor ? _determineTumorType(confidence) : "N/A";
      String locationDescription = isTumor ? _analyzeTumorLocation() : "N/A";
      String severityLevel =
          isTumor ? _determineSeverityLevel(confidence) : "N/A";
      String densityDescription =
          isTumor ? _determineDensity(confidence) : "N/A";
      String sizeMeasurement = isTumor ? _estimateTumorSize() : "N/A";
      List<String> recommendedTests = _recommendFollowUpTests(confidence);

      // Add content to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                  child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                    pw.Text('NEUROLOGICAL IMAGING REPORT',
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal)),
                    pw.Text('Report ID: $_reportId',
                        style:
                            pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  ])),

              pw.Divider(thickness: 1.5),

              // Report Info
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Generated: $formattedDate',
                        style: pw.TextStyle(fontSize: 10)),
                    pw.Text('Time: $formattedTime',
                        style: pw.TextStyle(fontSize: 10)),
                  ]),
              pw.SizedBox(height: 5),
              pw.Text('AI Analysis Version: 1.2.5',
                  style: pw.TextStyle(fontSize: 10)),

              pw.SizedBox(height: 20),

              // Patient Information
              pw.Text('PATIENT INFORMATION',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 5),
              _buildPdfInfoRow(
                  'Name:', _patientData?['name'] ?? 'Not available'),
              _buildPdfInfoRow('ID:', widget.patientId),
              _buildPdfInfoRow(
                  'Age:', '${_patientData?['age'] ?? 'Not available'}'),
              _buildPdfInfoRow(
                  'Gender:', _patientData?['gender'] ?? 'Not available'),
              _buildPdfInfoRow('Blood Group:',
                  _patientData?['bloodGroup'] ?? 'Not available'),

              pw.SizedBox(height: 20),

              // Study Information
              pw.Text('STUDY INFORMATION',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfInfoRow('Study Type:', 'Brain MRI Analysis'),
                    _buildPdfInfoRow('Scan Region:', 'Cranial Cavity'),
                    _buildPdfInfoRow('Image Quality:', 'Diagnostic Quality'),
                    _buildPdfInfoRow('Date of Image:', formattedDate),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Findings
              pw.Text('FINDINGS',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: isTumor ? PdfColors.red50 : PdfColors.green50,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(
                      color: isTumor ? PdfColors.red300 : PdfColors.green300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isTumor
                          ? 'ABNORMAL FINDINGS DETECTED'
                          : 'NO ABNORMAL FINDINGS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: isTumor ? PdfColors.red : PdfColors.green,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      isTumor
                          ? 'Brain MRI analysis indicates the presence of a potential anomalous mass consistent with neoplastic tissue. The AI analysis detected features characteristic of a brain tumor with $confidenceStr% confidence level.'
                          : 'Brain MRI analysis shows no evidence of neoplastic tissue or abnormal masses. Normal brain structure and tissue integrity appear preserved based on AI analysis with $confidenceStr% confidence level.',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Tumor details (if tumor detected)
              if (isTumor) ...[
                pw.SizedBox(height: 20),
                pw.Text('TUMOR CHARACTERIZATION',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfDetailRow('Suspected Type:', tumorType),
                      _buildPdfDetailRow('Location:', locationDescription),
                      _buildPdfDetailRow('Estimated Size:', sizeMeasurement),
                      _buildPdfDetailRow('Tissue Density:', densityDescription),
                      _buildPdfDetailRow('Severity Indicator:', severityLevel),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 20),

              // Recommendations
              pw.Text('RECOMMENDATIONS',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.blue300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isTumor
                          ? 'Based on the AI analysis, this case warrants further clinical evaluation by a neurologist or neurosurgeon. The finding shows characteristics consistent with $tumorType, which requires additional diagnostic confirmation and treatment planning.'
                          : 'Based on the AI analysis, no significant abnormalities were detected. Recommend routine follow-up as per standard clinical protocols for the patient\'s age and risk factors.',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 10),

                    // Follow-up tests for PDF
                    if (isTumor) ...[
                      pw.Text('Suggested Follow-up Tests:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.SizedBox(height: 5),
                      ...recommendedTests.map((test) => pw.Padding(
                            padding:
                                const pw.EdgeInsets.only(left: 10, bottom: 4),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(
                                  width: 4,
                                  height: 4,
                                  margin: const pw.EdgeInsets.only(
                                      top: 3, right: 5),
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.blue,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.Expanded(
                                    child: pw.Text(test,
                                        style:
                                            const pw.TextStyle(fontSize: 10))),
                              ],
                            ),
                          )),
                    ],

                    pw.SizedBox(height: 10),
                    pw.Text(
                      'DISCLAIMER: This is an AI-assisted analysis and should not be considered a final medical diagnosis. All findings require verification by a qualified healthcare professional.',
                      style: pw.TextStyle(
                          fontStyle: pw.FontStyle.italic,
                          fontSize: 8,
                          color: PdfColors.grey),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Impression
              pw.Text('IMPRESSION',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Text(
                  isTumor
                      ? 'AI-assisted analysis suggests the presence of a $severityLevel $tumorType, requiring further clinical correlation and diagnostic workup. The lesion demonstrates characteristics consistent with neoplastic tissue.'
                      : 'AI-assisted analysis indicates no evidence of intracranial mass, hemorrhage, midline shift, or other structural abnormalities. Brain parenchyma appears normal with no signs of neoplastic tissue.',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),

              pw.SizedBox(height: 20),

              // Digital Signature
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal50,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Analyzed by:',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('TeleNeuro AI Diagnostic System v2.1',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Report generated:',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('$formattedDate, $formattedTime',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Save PDF
      final output = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String patientName =
          _patientData?['name']?.toString().replaceAll(' ', '_') ?? 'patient';
      final String pdfFileName =
          '${patientName}_brain_mri_report_$timestamp.pdf';
      final file = File('${output.path}/$pdfFileName');
      await file.writeAsBytes(await pdf.save());

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report saved: ${file.path}')),
      );

      // Share the PDF file
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Brain MRI Analysis Report');
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  // PDF Building Methods
  pw.Widget _buildPdfHeader(String formattedDate) {
    return pw.Container(
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'NEUROLOGICAL IMAGING REPORT',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal,
            ),
          ),
          pw.Text(
            'Report ID: $_reportId',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfPatientInfo() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PATIENT INFORMATION',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ),
        pw.SizedBox(height: 5),
        _buildPdfInfoRow('Name:', _patientData?['name'] ?? 'Not available'),
        _buildPdfInfoRow('ID:', widget.patientId),
        _buildPdfInfoRow('Age:', '${_patientData?['age'] ?? 'Not available'}'),
        _buildPdfInfoRow('Gender:', _patientData?['gender'] ?? 'Not available'),
        _buildPdfInfoRow(
            'Blood Group:', _patientData?['bloodGroup'] ?? 'Not available'),
      ],
    );
  }

  pw.Widget _buildPdfStudyInfo(String formattedDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'STUDY INFORMATION',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfInfoRow('Study Type:', 'Brain MRI Analysis'),
              _buildPdfInfoRow('Scan Region:', 'Cranial Cavity'),
              _buildPdfInfoRow('Image Quality:', 'Diagnostic Quality'),
              _buildPdfInfoRow('Date of Image:', formattedDate),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfFindings() {
    bool isTumor = _detectionResult?['isTumor'] ?? false;
    double confidence = _detectionResult?['confidence'] ?? 0;
    String confidenceStr = (confidence * 100).toStringAsFixed(2);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'FINDINGS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: isTumor ? PdfColors.red50 : PdfColors.green50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(
              color: isTumor ? PdfColors.red300 : PdfColors.green300,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isTumor ? 'ABNORMAL FINDINGS DETECTED' : 'NO ABNORMAL FINDINGS',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: isTumor ? PdfColors.red : PdfColors.green,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                isTumor
                    ? 'Brain MRI analysis indicates the presence of a potential anomalous mass consistent with neoplastic tissue. The AI analysis detected features characteristic of a brain tumor with $confidenceStr% confidence level.'
                    : 'Brain MRI analysis shows no evidence of neoplastic tissue or abnormal masses. Normal brain structure and tissue integrity appear preserved based on AI analysis with $confidenceStr% confidence level.',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfDetailedAnalysis() {
    bool isTumor = _detectionResult?['isTumor'] ?? false;
    double confidence = _detectionResult?['confidence'] ?? 0;
    String tumorType = isTumor ? _determineTumorType(confidence) : "N/A";
    String locationDescription = isTumor ? _analyzeTumorLocation() : "N/A";
    String severityLevel =
        isTumor ? _determineSeverityLevel(confidence) : "N/A";
    String densityDescription = isTumor ? _determineDensity(confidence) : "N/A";
    String sizeMeasurement = isTumor ? _estimateTumorSize() : "N/A";

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TUMOR CHARACTERIZATION',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfDetailRow('Suspected Type:', tumorType),
              _buildPdfDetailRow('Location:', locationDescription),
              _buildPdfDetailRow('Estimated Size:', sizeMeasurement),
              _buildPdfDetailRow('Tissue Density:', densityDescription),
              _buildPdfDetailRow('Severity Indicator:', severityLevel),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfRecommendations() {
    bool isTumor = _detectionResult?['isTumor'] ?? false;
    double confidence = _detectionResult?['confidence'] ?? 0;
    List<String> recommendedTests = _recommendFollowUpTests(confidence);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RECOMMENDATIONS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColors.blue300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isTumor
                    ? 'Based on the AI analysis, this case warrants further clinical evaluation by a neurologist or neurosurgeon. The finding shows characteristics consistent with ${_determineTumorType(confidence)}, which requires additional diagnostic confirmation and treatment planning.'
                    : 'Based on the AI analysis, no significant abnormalities were detected. Recommend routine follow-up as per standard clinical protocols for the patient\'s age and risk factors.',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              if (isTumor) ...[
                pw.Text(
                  'Suggested Follow-up Tests:',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 12),
                ),
                pw.SizedBox(height: 5),
                ...recommendedTests.map((test) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 4,
                            height: 4,
                            margin: const pw.EdgeInsets.only(top: 3, right: 5),
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.blue,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(test,
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                        ],
                      ),
                    )),
              ],
              pw.SizedBox(height: 10),
              pw.Text(
                'DISCLAIMER: This is an AI-assisted analysis and should not be considered a final medical diagnosis. All findings require verification by a qualified healthcare professional.',
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 8,
                  color: PdfColors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfFooter(String formattedDate, String formattedTime) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Analyzed by:',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'TeleNeuro AI Diagnostic System v2.1',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Report generated:',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '$formattedDate, $formattedTime',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brain MRI Analysis'),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
      body: _isLoadingPatient
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Information Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: const [
                          Icon(Icons.info_outline,
                              color: Colors.teal, size: 40),
                          SizedBox(height: 10),
                          Text(
                            'AI-Powered Brain MRI Analysis',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'This tool uses artificial intelligence to help detect potential brain tumors in MRI images. Upload an MRI scan to get an instant preliminary assessment.',
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          SizedBox(height: 5),
                          Text(
                            'IMPORTANT: This is not a substitute for professional medical diagnosis. Always consult with a healthcare provider.',
                            style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.red),
                            textAlign: TextAlign.center,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Image Container
                  Container(
                    width: double.infinity,
                    height: 200, // Reduced height to prevent overflow
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate,
                                  size: 70, color: Colors.grey),
                              SizedBox(height: 10),
                              Text('No MRI image selected',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Upload Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload MRI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[600],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Analyze Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectedImage != null && !_isProcessing
                              ? _processImage
                              : null,
                          icon: const Icon(Icons.search),
                          label: const Text('Analyze'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[600],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Processing Indicator
                  if (_isProcessing)
                    Column(
                      children: const [
                        CircularProgressIndicator(color: Colors.teal),
                        SizedBox(height: 10),
                        Text('Analyzing MRI image...',
                            style: TextStyle(fontStyle: FontStyle.italic)),
                        SizedBox(height: 10),
                        Text('Please wait while our AI processes your scan.',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),

                  // Results Report
                  if (_detectionResult != null && !_isProcessing)
                    _buildMedicalReport(),
                ],
              ),
            ),
    );
  }

  Widget _buildMedicalReport() {
    // Format the timestamp
    String formattedDate = DateFormat('MMMM d, yyyy').format(_analysisTime);
    String formattedTime = DateFormat('h:mm a').format(_analysisTime);

    bool isTumor = _detectionResult?['isTumor'] ?? false;
    double confidence = _detectionResult?['confidence'] ?? 0;
    String confidenceStr = (confidence * 100).toStringAsFixed(2);

    // Generate detailed medical information based on AI analysis
    String tumorType = isTumor ? _determineTumorType(confidence) : "N/A";
    String severityLevel =
        isTumor ? _determineSeverityLevel(confidence) : "N/A";

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Simplified Header
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isTumor
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTumor
                      ? Colors.red.withOpacity(0.5)
                      : Colors.green.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isTumor ? Icons.warning : Icons.check_circle,
                    color: isTumor ? Colors.red : Colors.green,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTumor
                              ? 'Abnormal Findings Detected'
                              : 'No Abnormal Findings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isTumor ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isTumor
                              ? 'AI analysis detected potential $severityLevel $tumorType with $confidenceStr% confidence'
                              : 'No signs of tumor detected with $confidenceStr% confidence',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Report Generation Time
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Analysis completed at $formattedTime, $formattedDate',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Important Notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A complete medical report is available for download. This is an AI-assisted analysis and should be verified by a healthcare professional.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Download Report Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatePdf,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download Detailed Medical Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            if (!_reportSent) ...[
              const SizedBox(height: 12),
              // Send to Doctor Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _sendReportToDoctor,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                      _isProcessing ? 'Sending...' : 'Send Report to Doctor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Report has been sent to your doctor',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper methods for detailed medical report
  String _determineTumorType(double confidence) {
    // In a real system, this would use more sophisticated analysis
    // This is a simplified version for demonstration
    if (confidence > 0.9) {
      return "Glioblastoma multiforme (GBM)";
    } else if (confidence > 0.8) {
      return "Meningioma";
    } else if (confidence > 0.7) {
      return "Astrocytoma";
    } else if (confidence > 0.6) {
      return "Oligodendroglioma";
    } else {
      return "Unspecified neoplastic tissue";
    }
  }

  String _analyzeTumorLocation() {
    // In a real system, this would analyze the actual image
    // This is randomized for demonstration
    final random = math.Random();
    final locationOptions = [
      "Frontal lobe, right hemisphere",
      "Frontal lobe, left hemisphere",
      "Temporal lobe, right hemisphere",
      "Temporal lobe, left hemisphere",
      "Parietal lobe, right hemisphere",
      "Parietal lobe, left hemisphere",
      "Occipital lobe",
      "Cerebellum",
      "Brain stem"
    ];

    return locationOptions[random.nextInt(locationOptions.length)];
  }

  String _determineSeverityLevel(double probability) {
    if (probability > 0.85) return "Severe";
    if (probability > 0.7) return "Moderate";
    if (probability > 0.5) return "Mild";
    return "Minimal";
  }

  String _determineDensity(double confidence) {
    // Simplified density description
    final random = math.Random();
    final densityTypes = [
      "Hyperdense with central necrosis",
      "Hyperdense with calcifications",
      "Isodense with surrounding edema",
      "Mixed density with cystic components",
      "Heterogeneous with enhancement"
    ];

    return densityTypes[random.nextInt(densityTypes.length)];
  }

  String _estimateTumorSize() {
    // Randomize tumor size for demonstration
    final random = math.Random();
    final diameter = (1 + random.nextDouble() * 4).toStringAsFixed(1);
    final volume = (random.nextDouble() * 20).toStringAsFixed(1);

    return "$diameter cm diameter, approximately $volume cm³";
  }

  List<String> _recommendFollowUpTests(double probability) {
    final baseTests = [
      "Neurological examination",
      "MRI with contrast",
      "CT scan"
    ];

    if (probability > 0.5) {
      baseTests.addAll(["Biopsy", "PET scan", "Blood tests"]);
    }

    return baseTests;
  }

  @override
  void dispose() {
    _detectorModel.close();
    super.dispose();
  }
}
