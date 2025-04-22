import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MaterialApp(
    home: BrainTumorDetector(),
    debugShowCheckedModeBanner: false,
  ));
}

class BrainTumorDetector extends StatefulWidget {
  @override
  _BrainTumorDetectorState createState() => _BrainTumorDetectorState();
}

class BrainTumorDetectorModel {
  static const String MODEL_FILE = 'lib/assets/Brain_Tumor_Model.tflite';
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(MODEL_FILE);
      print('Model loaded successfully');
    } catch (e) {
      print('Failed to load model: $e');
    }
  }

  Future<List<List<List<List<double>>>>> preprocessImage(File imageFile) async {
    img.Image? originalImage = img.decodeImage(await imageFile.readAsBytes());
    if (originalImage == null) throw Exception('Failed to decode image');

    // Resize image to 256x256 (as required by model)
    img.Image resizedImage =
        img.copyResize(originalImage, width: 256, height: 256);

    // Convert to tensor (1, 256, 256, 3)
    List<List<List<List<double>>>> inputImage = List.generate(
      1, // Batch size
      (_) => List.generate(
        256,
        (y) => List.generate(
          256,
          (x) {
            int pixel = resizedImage.getPixel(x, y);
            return [
              img.getRed(pixel) / 255.0, // Normalize R
              img.getGreen(pixel) / 255.0, // Normalize G
              img.getBlue(pixel) / 255.0 // Normalize B
            ];
          },
        ),
      ),
    );

    return inputImage;
  }

  Future<String> detectTumor(File imageFile) async {
    if (_interpreter == null) throw Exception('Model not loaded');

    List<List<List<List<double>>>> inputImage =
        await preprocessImage(imageFile);

    // Define output tensor for binary classification (1, 2)
    final outputTensor = List.filled(1 * 2, 0.0).reshape([1, 2]);

    _interpreter?.run(inputImage, outputTensor);

    double tumorProbability = outputTensor[0][1];

    return tumorProbability > 0.5
        ? 'Tumor Detected (${(tumorProbability * 100).toStringAsFixed(2)}% confidence)'
        : 'No Tumor Detected (${((1 - tumorProbability) * 100).toStringAsFixed(2)}% confidence)';
  }

  void close() {
    _interpreter?.close();
  }
}

class _BrainTumorDetectorState extends State<BrainTumorDetector> {
  final BrainTumorDetectorModel _detectorModel = BrainTumorDetectorModel();
  File? _selectedImage;
  String? _detectionResult;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _detectorModel.loadModel();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _detectionResult = null;
      });
    } else {
      print("No image selected");
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _detectorModel.detectTumor(_selectedImage!);
      setState(() {
        _detectionResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _detectionResult = 'Error processing image: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brain MRI Analysis'),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
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
                    Icon(Icons.info_outline, color: Colors.teal, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'AI-Powered Brain MRI Analysis',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'This tool uses artificial intelligence to help detect potential brain tumors in MRI images. Upload an MRI scan to get an instant preliminary assessment.',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'IMPORTANT: This is not a substitute for professional medical diagnosis. Always consult with a healthcare provider.',
                      style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Image Container
            Container(
              width: double.infinity,
              height: 250,
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

            const SizedBox(height: 20),

            // Upload Button
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload MRI Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),

            const SizedBox(height: 20),

            // Detect Button
            ElevatedButton.icon(
              onPressed: _selectedImage != null && !_isProcessing
                  ? _processImage
                  : null,
              icon: const Icon(Icons.search),
              label: const Text('Analyze MRI Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                disabledBackgroundColor: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            // Result Display
            if (_isProcessing)
              Column(
                children: const [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 10),
                  Text('Analyzing image...',
                      style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),

            if (_detectionResult != null && !_isProcessing)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                color: _detectionResult!.contains('No Tumor Detected')
                    ? Colors.green[50]
                    : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        _detectionResult!.contains('No Tumor Detected')
                            ? Icons.check_circle
                            : Icons.warning,
                        color: _detectionResult!.contains('No Tumor Detected')
                            ? Colors.green
                            : Colors.red,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Analysis Result:',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _detectionResult!,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Remember: This AI analysis should be verified by a medical professional.',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detectorModel.close();
    super.dispose();
  }
}
