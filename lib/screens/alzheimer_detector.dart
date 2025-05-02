import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AlzheimerDetector extends StatefulWidget {
  final String patientId;

  const AlzheimerDetector({super.key, required this.patientId});

  @override
  _AlzheimerDetectorState createState() => _AlzheimerDetectorState();
}

class AlzheimerDetectorModel {
  static const String MODEL_FILE = 'lib/assets/alzh_model.tflite';
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  Future<void> loadModel() async {
    try {
      print('Starting model loading process...');
      print('Loading model from: $MODEL_FILE');

      final options = InterpreterOptions();

      // Enable XNNPACK for better performance (if available)
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          options.addDelegate(XNNPackDelegate());
          print('XNNPACK delegate added successfully');
        }
      } catch (e) {
        print('XNNPACK not available: $e');
      }

      // Load the model from the exact path
      _interpreter = await Interpreter.fromAsset(MODEL_FILE, options: options);

      if (_interpreter == null) {
        throw Exception('Failed to initialize model interpreter');
      }

      _isModelLoaded = true;
      print('Model loaded successfully');

      // Print model details for debugging
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

      // Resize image to model's expected dimensions (256x256)
      img.Image resizedImage = img.copyResize(
        originalImage,
        width: 256,
        height: 256,
        interpolation: img.Interpolation.cubic,
      );

      print('Image resized to: ${resizedImage.width}x${resizedImage.height}');

      // Convert to float32 array and normalize pixel values to [0,1]
      final inputBuffer = Float32List(1 * 256 * 256 * 3);
      int pixelIndex = 0;

      for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
          final pixel = resizedImage.getPixel(x, y);
          inputBuffer[pixelIndex++] = img.getRed(pixel) / 255.0; // R
          inputBuffer[pixelIndex++] = img.getGreen(pixel) / 255.0; // G
          inputBuffer[pixelIndex++] = img.getBlue(pixel) / 255.0; // B
        }
      }

      print('Image preprocessing completed successfully');
      return inputBuffer.reshape([1, 256, 256, 3]);
    } catch (e) {
      print('Image preprocessing failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> detectAlzheimer(File imageFile) async {
    if (!_isModelLoaded || _interpreter == null) {
      throw Exception('Model not loaded or initialized');
    }

    try {
      print('Starting Alzheimer detection...');
      // Preprocess the image
      final inputImage = await preprocessImage(imageFile);

      // Prepare output tensor with correct shape [1, 4]
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Output shape from interpreter: $outputShape');

      // Create output buffer with shape [1, 4]
      var outputBuffer = List.generate(
        outputShape[0],
        (index) => List<double>.filled(outputShape[1], 0.0),
      );

      print('Running inference...');
      // Run inference
      _interpreter!.run(inputImage, outputBuffer);

      // Extract probabilities from the first row since shape is [1, 4]
      final List<double> probabilities = outputBuffer[0];
      print('Raw probabilities: $probabilities');

      // Find maximum probability
      double maxProb = 0.0;
      int predictedClass = 0;

      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          predictedClass = i;
        }
      }

      print(
          'Inference completed. Predicted class: $predictedClass, Confidence: ${maxProb * 100}%');

      // Apply softmax if needed (uncomment if your model outputs logits)
      // final softmaxProbs = _softmax(probabilities);
      // maxProb = softmaxProbs[predictedClass];

      // Map class index to diagnosis
      final diagnosis = _getDiagnosisLabel(predictedClass);
      final confidence = (maxProb * 100).toStringAsFixed(2);

      return {
        'diagnosis': diagnosis,
        'probability': maxProb,
        'confidence': confidence,
        'formattedResult': '$diagnosis ($confidence% confidence)',
        'severityLevel': _determineSeverityLevel(maxProb),
        'atrophyDescription': _analyzeAtrophyPattern(predictedClass, maxProb),
        'cognitiveImpact': _assessCognitiveImpact(predictedClass, maxProb),
        'recommendedTests': _recommendFollowUpTests(predictedClass, maxProb),
      };
    } catch (e) {
      print('Detection failed: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Helper method to convert output to probabilities
  List<double> _softmax(List<double> logits) {
    double maxLogit = logits.reduce((a, b) => a > b ? a : b);
    List<double> expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
    double sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((x) => x / sumExp).toList();
  }

  String _getDiagnosisLabel(int classIndex) {
    switch (classIndex) {
      case 0:
        return 'Non Demented';
      case 1:
        return 'Mild Demented';
      case 2:
        return 'Very Mild Demented';
      case 3:
        return 'Moderate Demented';
      default:
        return 'Unknown';
    }
  }

  String _determineSeverityLevel(double probability) {
    if (probability > 0.85) return "Severe";
    if (probability > 0.7) return "Moderate";
    if (probability > 0.5) return "Mild";
    return "Minimal";
  }

  String _analyzeAtrophyPattern(int diagnosisIndex, double probability) {
    final patterns = [
      "No significant atrophy detected",
      "Mild hippocampal atrophy with temporal lobe involvement",
      "Moderate bilateral hippocampal atrophy",
      "Severe generalized cortical atrophy with hippocampal volume loss",
      "Frontotemporal atrophy pattern observed"
    ];
    return patterns[diagnosisIndex.clamp(0, patterns.length - 1)];
  }

  String _assessCognitiveImpact(int diagnosisIndex, double probability) {
    switch (diagnosisIndex) {
      case 0:
        return "No significant cognitive impact detected";
      case 1:
        return "Mild memory impairment, preserved daily function";
      case 2:
        return "Noticeable memory deficits, minimal functional impact";
      case 3:
        return "Significant cognitive decline affecting multiple domains";
      default:
        return "Cognitive impact assessment not available";
    }
  }

  List<String> _recommendFollowUpTests(int diagnosisIndex, double probability) {
    final baseTests = [
      "Comprehensive neuropsychological assessment",
      "Clinical dementia rating (CDR) evaluation"
    ];

    if (diagnosisIndex > 0) {
      baseTests.addAll([
        "MRI with volumetric analysis",
        "PET scan (amyloid or FDG)",
        "CSF biomarker analysis"
      ]);
    }

    if (diagnosisIndex > 1) {
      baseTests.addAll([
        "Genetic testing for APOE status",
        "Repeat neuroimaging in 6-12 months"
      ]);
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

class _AlzheimerDetectorState extends State<AlzheimerDetector> {
  final AlzheimerDetectorModel _detectorModel = AlzheimerDetectorModel();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  Map<String, dynamic>? _detectionResult;
  Map<String, dynamic>? _patientData;
  bool _isProcessing = false;
  bool _isLoadingPatient = true;
  bool _modelLoadingFailed = false;
  String _reportId = '';
  DateTime _analysisTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadModel();
    await _fetchPatientData();
    _reportId = _generateReportId();
  }

  String _generateReportId() {
    final random = math.Random();
    return 'R${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(9000) + 1000}';
  }

  Future<void> _loadModel() async {
    try {
      setState(() => _modelLoadingFailed = false);
      print('Initializing model loading...');
      await _detectorModel.loadModel();
      print('Model loaded successfully');
    } catch (e) {
      print('Model loading failed: $e');
      setState(() => _modelLoadingFailed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load AI model: $e'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _loadModel,
          ),
        ),
      );
    }
  }

  Future<void> _fetchPatientData() async {
    if (widget.patientId.isEmpty) {
      setState(() => _isLoadingPatient = false);
      return;
    }

    try {
      final doc =
          await _firestore.collection('clients').doc(widget.patientId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final dob = data["dob"] != null ? DateTime.tryParse(data["dob"]) : null;

        setState(() {
          _patientData = {
            "name": data["name"] ?? data["fullName"] ?? "Unknown",
            "dob": dob,
            "age": dob != null ? _calculateAge(dob) : "Unknown",
            "gender": data["gender"] ?? "Not specified",
            "phone": data["phone"] ?? data["phoneNumber"] ?? "Not available",
            "email": data["email"] ?? "Not available",
            "bloodGroup": data["bloodGroup"] ?? "Not specified",
          };
          _isLoadingPatient = false;
        });
      } else {
        setState(() => _isLoadingPatient = false);
      }
    } catch (e) {
      print("Error fetching patient data: $e");
      setState(() => _isLoadingPatient = false);
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _detectionResult = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null || _modelLoadingFailed) return;

    setState(() {
      _isProcessing = true;
      _analysisTime = DateTime.now();
    });

    try {
      final result = await _detectorModel.detectAlzheimer(_selectedImage!);

      if (result['probability'] == 0) {
        throw Exception('Model returned zero confidence predictions');
      }

      setState(() => _detectionResult = result);

      if (widget.patientId.isNotEmpty) {
        await _saveReportToFirestore();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
      setState(() => _detectionResult = {
            'error': true,
            'formattedResult': 'Error: ${e.toString()}'
          });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveReportToFirestore() async {
    try {
      await _firestore.collection('medical_reports').add({
        'reportId': _reportId,
        'patientId': widget.patientId,
        'patientName': _patientData?['name'] ?? 'Unknown',
        'timestamp': _analysisTime,
        'reportType': 'Alzheimer MRI Analysis',
        'result': _detectionResult?['formattedResult'] ?? '',
        'diagnosis': _detectionResult?['diagnosis'] ?? '',
        'confidence': _detectionResult?['confidence'] ?? 0.0,
        'severity': _detectionResult?['severityLevel'] ?? '',
        'imagePath': _selectedImage?.path ?? '',
      });
    } catch (e) {
      print("Error saving report: $e");
    }
  }

  Future<void> _generatePdf() async {
    try {
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
            if (_detectionResult?['diagnosis'] != 'Non Demented')
              _buildPdfDetailedAnalysis(),
            _buildPdfRecommendations(),
            _buildPdfFooter(formattedDate, formattedTime),
          ],
        ),
      );

      final directory = await getTemporaryDirectory();
      final fileName =
          'Alzheimer_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Alzheimer MRI Analysis Report',
        text: 'Please find attached the Alzheimer MRI analysis report.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  // PDF building helper methods
  pw.Widget _buildPdfHeader(String formattedDate) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('NEUROLOGICAL IMAGING REPORT',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal,
                )),
            pw.Text('Report ID: $_reportId',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ],
        ),
        pw.Divider(thickness: 1.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated: $formattedDate',
                style: pw.TextStyle(fontSize: 10)),
            pw.Text('AI Analysis Version: 1.2.5',
                style: pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfPatientInfo() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('PATIENT INFORMATION',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _buildPdfInfoRow('Name:', _patientData?['name'] ?? 'Unknown'),
              _buildPdfInfoRow('Patient ID:', widget.patientId),
              _buildPdfInfoRow('Age:', '${_patientData?['age'] ?? 'Unknown'}'),
              _buildPdfInfoRow('Gender:', _patientData?['gender'] ?? 'Unknown'),
              _buildPdfInfoRow(
                  'Blood Group:', _patientData?['bloodGroup'] ?? 'Unknown'),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStudyInfo(String formattedDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('STUDY INFORMATION',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _buildPdfInfoRow('Study Date:', formattedDate),
              _buildPdfInfoRow('Study Type:', 'MRI Brain'),
              _buildPdfInfoRow('Analysis Method:', 'AI-Powered Analysis'),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfFindings() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('FINDINGS',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_detectionResult?['formattedResult'] ??
                  'No findings available'),
              pw.SizedBox(height: 10),
              if (_detectionResult?['atrophyDescription'] != null)
                pw.Text(_detectionResult!['atrophyDescription']),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfDetailedAnalysis() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('DETAILED ANALYSIS',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfInfoRow('Severity Level:',
                  _detectionResult?['severityLevel'] ?? 'Unknown'),
              _buildPdfInfoRow('Cognitive Impact:',
                  _detectionResult?['cognitiveImpact'] ?? 'Unknown'),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfRecommendations() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('RECOMMENDATIONS',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_getRecommendationText(
                  _detectionResult?['diagnosis'] ?? 'Unknown')),
              pw.SizedBox(height: 10),
              ...(_detectionResult?['recommendedTests'] ?? [])
                  .map((test) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('• ',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Expanded(child: pw.Text(test)),
                          ],
                        ),
                      )),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfFooter(String formattedDate, String formattedTime) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 10),
        pw.Text('Generated on $formattedDate at $formattedTime',
            style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
            'This is an AI-assisted analysis and should be reviewed by a qualified medical professional.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alzheimer MRI Analysis'),
        backgroundColor: Colors.teal[700],
        actions: [
          if (_modelLoadingFailed)
            IconButton(
              icon: const Icon(Icons.warning, color: Colors.amber),
              onPressed: _loadModel,
              tooltip: 'Reload Model',
            ),
        ],
      ),
      body: _isLoadingPatient
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 20),
                  _buildImageContainer(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  if (_isProcessing) _buildProcessingIndicator(),
                  if (_detectionResult != null && !_isProcessing)
                    _buildResultsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.medical_services, size: 40, color: Colors.teal),
            const SizedBox(height: 10),
            Text(
              'AI-Powered Alzheimer MRI Analysis',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Upload an MRI scan to get an AI-assisted assessment of potential '
              'Alzheimer\'s disease markers. Results should be reviewed by a '
              'qualified medical professional.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (_modelLoadingFailed) ...[
              const SizedBox(height: 10),
              Text(
                'Warning: AI model failed to load. Tap the warning icon to retry.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageContainer() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: _selectedImage != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.contain,
                errorBuilder: (ctx, error, stack) => Center(
                  child: Text('Failed to load image',
                      style: TextStyle(color: Colors.grey[600])),
                ),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library, size: 50, color: Colors.grey[500]),
                const SizedBox(height: 10),
                Text(
                  'No MRI image selected',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.upload),
            label: const Text('Upload MRI'),
            onPressed: _pickImage,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.teal[600],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Analyze'),
            onPressed:
                _selectedImage != null && !_isProcessing && !_modelLoadingFailed
                    ? _processImage
                    : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.teal[800],
              disabledBackgroundColor: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 15),
          Text(
            'Analyzing MRI Image...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            'This may take a few moments',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final diagnosis = _detectionResult?['diagnosis'] ?? 'Unknown';
    final confidence = _detectionResult?['confidence'] ?? '0';
    final isNormal = diagnosis == 'Non Demented';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Results Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isNormal ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isNormal ? Colors.green[300]! : Colors.orange[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isNormal ? Icons.check_circle : Icons.warning,
                    color: isNormal ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNormal
                              ? 'No Abnormal Findings'
                              : 'Abnormal Findings Detected',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isNormal ? Colors.green : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$diagnosis ($confidence% confidence)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Detailed Findings
            if (!isNormal) ...[
              Text(
                'Detailed Findings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResultRow(
                      'Severity Level:',
                      _detectionResult?['severityLevel'] ?? 'Unknown',
                    ),
                    _buildResultRow(
                      'Atrophy Pattern:',
                      _detectionResult?['atrophyDescription'] ?? 'Unknown',
                    ),
                    _buildResultRow(
                      'Cognitive Impact:',
                      _detectionResult?['cognitiveImpact'] ?? 'Unknown',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Recommendations
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getRecommendationText(diagnosis),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  ...(_detectionResult?['recommendedTests'] ?? [])
                      .map<Widget>((test) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.arrow_right, size: 16),
                                const SizedBox(width: 4),
                                Expanded(child: Text(test)),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Download Report Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download Full Report'),
                onPressed: _generatePdf,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getRecommendationText(String diagnosis) {
    switch (diagnosis) {
      case 'Non Demented':
        return 'No significant abnormalities detected. Routine cognitive screening '
            'is recommended based on age and risk factors.';
      case 'Very Mild Demented':
        return 'Very mild cognitive changes detected. Recommend cognitive '
            'monitoring and lifestyle modifications.';
      case 'Mild Demented':
        return 'Mild cognitive impairment detected. Comprehensive evaluation '
            'and regular monitoring recommended.';
      case 'Moderate Demented':
        return 'Moderate cognitive decline detected. Immediate neurological '
            'consultation and intervention recommended.';
      default:
        return 'Further evaluation by a specialist is recommended.';
    }
  }

  @override
  void dispose() {
    try {
      print('Cleaning up model resources...');
      _detectorModel.close();
    } catch (e) {
      print('Error during model cleanup: $e');
    }
    super.dispose();
  }
}
