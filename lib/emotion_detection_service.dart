import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

class EmotionDetectionService {
  static final EmotionDetectionService _instance =
      EmotionDetectionService._internal();
  factory EmotionDetectionService() => _instance;
  EmotionDetectionService._internal();

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isInitialized = false;
  bool _isDetecting = false;
  Timer? _detectionTimer;

  // Emotion labels
  final List<String> _emotionLabels = [
    'angry',
    'disgust',
    'fear',
    'happy',
    'neutral',
    'sad',
    'surprise'
  ];

  // Getter for camera controller
  CameraController? get cameraController => _cameraController;

  // Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        print('Camera permission denied');
        return false;
      }

      // Initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No cameras available');
        return false;
      }

      // Use front camera for selfie mode
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Initialize Google ML Kit face detector
      _faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          enableLandmarks: true,
          enableClassification: true,
          enableTracking: true,
          minFaceSize: 0.15,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      // Initialize emotion classification
      await _initializeEmotionClassification();

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing emotion detection: $e');
      return false;
    }
  }

  // Initialize emotion classification
  Future<void> _initializeEmotionClassification() async {
    try {
      // For now, we'll use a rule-based approach
      // In a real implementation, you would load a trained ML model
      print('Emotion classification initialized successfully');
    } catch (e) {
      print('Error initializing emotion classification: $e');
    }
  }

  // Start emotion detection with periodic logging
  Future<void> startEmotionDetection() async {
    if (!_isInitialized || _isDetecting) return;

    _isDetecting = true;

    // Start detection timer - every 5 seconds
    _detectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      detectAndLogEmotion();
    });
  }

  // Stop emotion detection
  Future<void> stopEmotionDetection() async {
    _isDetecting = false;
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  // Detect emotion and log to Firestore
  Future<void> detectAndLogEmotion() async {
    if (!_isInitialized || _cameraController == null) return;

    try {
      // Take a picture
      final image = await _cameraController!.takePicture();
      final file = File(image.path);

      // Detect faces using ML Kit
      final faces = await _detectFaces(file);

      if (faces.isNotEmpty) {
        // Get the first detected face
        final face = faces.first;

        // Classify emotion based on face features
        final emotionResult = _classifyEmotionWithConfidence(face);

        // Only log if confidence is above threshold
        if (emotionResult['confidence'] > 0.6) {
          await _logEmotionToFirestore(
              emotionResult['emotion'], emotionResult['confidence']);
          print(
              'Detected emotion: ${emotionResult['emotion']} (confidence: ${emotionResult['confidence'].toStringAsFixed(2)})');
        } else {
          print(
              'Low confidence emotion detected: ${emotionResult['emotion']} (confidence: ${emotionResult['confidence'].toStringAsFixed(2)})');
        }
      }
    } catch (e) {
      print('Error detecting emotion: $e');
    }
  }

  // Detect faces in the image using Google ML Kit
  Future<List<Face>> _detectFaces(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector!.processImage(inputImage);
      return faces;
    } catch (e) {
      print('Error detecting faces: $e');
      return [];
    }
  }

  // Classify emotion based on face features
  String _classifyEmotion(Face face) {
    final result = _classifyEmotionWithConfidence(face);
    return result['emotion'] as String;
  }

  // Classify emotion with confidence score
  Map<String, dynamic> _classifyEmotionWithConfidence(Face face) {
    // Get face features
    final smilingProb = face.smilingProbability ?? 0.0;
    final leftEyeOpenProb = face.leftEyeOpenProbability ?? 0.0;
    final rightEyeOpenProb = face.rightEyeOpenProbability ?? 0.0;
    final headEulerAngleY = face.headEulerAngleY ?? 0.0;
    final headEulerAngleZ = face.headEulerAngleZ ?? 0.0;

    // Calculate average eye openness
    final avgEyeOpenness = (leftEyeOpenProb + rightEyeOpenProb) / 2.0;

    // Calculate head movement magnitude
    final headMovement = (headEulerAngleY.abs() + headEulerAngleZ.abs()) / 2.0;

    print('Debug - Smiling: ${smilingProb.toStringAsFixed(2)}, '
        'Left Eye: ${leftEyeOpenProb.toStringAsFixed(2)}, '
        'Right Eye: ${rightEyeOpenProb.toStringAsFixed(2)}, '
        'Head Y: ${headEulerAngleY.toStringAsFixed(2)}, '
        'Head Z: ${headEulerAngleZ.toStringAsFixed(2)}');

    // Improved emotion classification with confidence scores

    // Happy: High smiling probability (most reliable)
    if (smilingProb > 0.5) {
      return {
        'emotion': 'happy',
        'confidence': (smilingProb * 1.2).clamp(0.0, 1.0)
      };
    }

    // Surprise: Eyes very wide open, head tilted back
    if (avgEyeOpenness > 0.85 && headEulerAngleZ.abs() > 6) {
      return {
        'emotion': 'surprise',
        'confidence': ((avgEyeOpenness * 0.6) + (headEulerAngleZ.abs() / 20.0))
            .clamp(0.0, 1.0)
      };
    }

    // Fear: Very low smiling, eyes either very wide or very closed
    if (smilingProb < 0.25 &&
        ((avgEyeOpenness > 0.9) || (avgEyeOpenness < 0.4))) {
      return {
        'emotion': 'fear',
        'confidence': ((1.0 - smilingProb) * 0.8).clamp(0.0, 1.0)
      };
    }

    // Angry: Low smiling, eyes narrowed, head tilted (more sensitive)
    if (smilingProb < 0.4 &&
        avgEyeOpenness < 0.7 &&
        headEulerAngleY.abs() > 5) {
      return {
        'emotion': 'angry',
        'confidence':
            (((1.0 - smilingProb) * 0.6) + (headEulerAngleY.abs() / 25.0))
                .clamp(0.0, 1.0)
      };
    }

    // Angry: Alternative detection - very low smiling with narrowed eyes (no head tilt required)
    if (smilingProb < 0.3 && avgEyeOpenness < 0.6) {
      return {
        'emotion': 'angry',
        'confidence': ((1.0 - smilingProb) * 0.7).clamp(0.0, 1.0)
      };
    }

    // Sad: Low smiling, eyes partially closed, minimal head movement
    if (smilingProb < 0.4 && avgEyeOpenness < 0.7 && headMovement < 5) {
      return {
        'emotion': 'sad',
        'confidence': ((1.0 - smilingProb) * 0.7).clamp(0.0, 1.0)
      };
    }

    // Disgust: Low smiling, moderate head movement
    if (smilingProb < 0.35 && headMovement > 4 && headMovement < 15) {
      return {
        'emotion': 'disgust',
        'confidence': ((1.0 - smilingProb) * 0.6).clamp(0.0, 1.0)
      };
    }

    // Default to neutral
    return {'emotion': 'neutral', 'confidence': 0.5};
  }

  // Log emotion to Firestore
  Future<void> _logEmotionToFirestore(String emotion, double confidence) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final timestamp = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('emotions')
          .add({
        'emotion': emotion,
        'timestamp': timestamp,
        'confidence': confidence,
      });

      print(
          'Emotion logged to Firestore: $emotion (confidence: ${confidence.toStringAsFixed(2)})');
    } catch (e) {
      print('Error logging emotion to Firestore: $e');
    }
  }

  // Get recent emotions from Firestore
  Future<List<Map<String, dynamic>>> getRecentEmotions({int limit = 10}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('emotions')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'emotion': data['emotion'],
          'timestamp': data['timestamp'],
          'confidence': data['confidence'],
        };
      }).toList();
    } catch (e) {
      print('Error getting recent emotions: $e');
      return [];
    }
  }

  // Get emotion statistics
  Future<Map<String, int>> getEmotionStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('emotions')
          .get();

      final stats = <String, int>{};
      for (final doc in snapshot.docs) {
        final emotion = doc.data()['emotion'] as String;
        stats[emotion] = (stats[emotion] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error getting emotion stats: $e');
      return {};
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    await stopEmotionDetection();
    await _cameraController?.dispose();
    _isInitialized = false;
  }
}
