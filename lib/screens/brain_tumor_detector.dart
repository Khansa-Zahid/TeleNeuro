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
    img.Image resizedImage = img.copyResize(originalImage, width: 256, height: 256);

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
              img.getRed(pixel) / 255.0,   // Normalize R
              img.getGreen(pixel) / 255.0, // Normalize G
              img.getBlue(pixel) / 255.0   // Normalize B
            ];
          },
        ),
      ),
    );

    return inputImage;
  }

  Future<String> detectTumor(File imageFile) async {
    if (_interpreter == null) throw Exception('Model not loaded');

    List<List<List<List<double>>>> inputImage = await preprocessImage(imageFile);

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

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _detectorModel.loadModel();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
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
    try {
      final result = await _detectorModel.detectTumor(_selectedImage!);
      setState(() {
        _detectionResult = result;
      });
    } catch (e) {
      setState(() {
        _detectionResult = 'Error processing image: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Brain Tumor Detector'),backgroundColor: Colors.teal[500],),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedImage != null) Image.file(_selectedImage!, height: 200),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Select MRI Image'),
            ),
            if (_detectionResult != null)
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  _detectionResult!,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ElevatedButton(
              onPressed: _processImage,
              child: Text('Detect Tumor'),
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
