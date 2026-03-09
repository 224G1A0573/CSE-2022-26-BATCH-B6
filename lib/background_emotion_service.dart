import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'email_notification_service.dart';

class BackgroundEmotionService {
  static final BackgroundEmotionService _instance =
      BackgroundEmotionService._internal();
  factory BackgroundEmotionService() => _instance;
  BackgroundEmotionService._internal();

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isInitialized = false;
  bool _isDetecting = false;
  Timer? _detectionTimer;
  String? _currentUserId;
  String? _parentEmail;
  String? _childName;
  bool _hasNotifiedParent = false;

  // Eye tracking data (merged into emotion service)
  bool _eyeTrackingEnabled = true;

  // Initialize background emotion detection
  Future<bool> initializeForChild(String userId) async {
    if (_isInitialized && _currentUserId == userId) return true;

    _currentUserId = userId;

    try {
      // Get child's data and parent email
      await _fetchChildAndParentData();

      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        print('Camera permission denied for background detection');
        return false;
      }

      // Initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No cameras available for background detection');
        return false;
      }

      // Use front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low, // Use low resolution for background processing
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
          performanceMode:
              FaceDetectorMode.fast, // Use fast mode for background
        ),
      );

      _isInitialized = true;

      // Send notification to parent about emotion detection
      if (!_hasNotifiedParent && _parentEmail != null) {
        await _sendParentNotification();
      }

      return true;
    } catch (e) {
      print('Error initializing background emotion detection: $e');
      return false;
    }
  }

  // Fetch child and parent data
  Future<void> _fetchChildAndParentData() async {
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (childDoc.exists) {
        final childData = childDoc.data()!;

        // Prefer guardianEmail if present; otherwise use parentEmail
        final guardianEmail = childData['guardianEmail'] as String?;
        if (guardianEmail != null && guardianEmail.isNotEmpty) {
          _parentEmail = guardianEmail;
        } else {
          _parentEmail = childData['parentEmail'] as String?;
        }

        // If missing or placeholder, try to find a real parent or fabricate from child email
        if (_parentEmail == null ||
            _parentEmail!.isEmpty ||
            _parentEmail == 'parent@gmail.com' ||
            _parentEmail == 'parent@bloombuddy.com') {
          _parentEmail = await _findOrCreateParentEmail(childData);
        }

        _childName =
            childData['name'] ?? childData['displayName'] ?? 'Your Child';

        // Ensure all required fields exist
        await _ensureRequiredFields(childData);

        // Update child's emotion detection status
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .update({
              'emotionDetectionActive': true,
              'emotionDetectionStartedAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      print('Error fetching child and parent data: $e');
    }
  }

  // Find or create parent email
  Future<String> _findOrCreateParentEmail(
    Map<String, dynamic> childData,
  ) async {
    try {
      // Try to find a parent user in the system
      final parentQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();

      if (parentQuery.docs.isNotEmpty) {
        final parentData = parentQuery.docs.first.data();
        final parentEmail = parentData['email'] as String?;
        if (parentEmail != null && parentEmail.isNotEmpty) {
          print('Found parent email: $parentEmail');
          return parentEmail;
        }
      }

      // If no parent found, create a default parent email based on child's email
      final childEmail = childData['email'] as String? ?? '';
      if (childEmail.isNotEmpty) {
        // Create a parent email by modifying the child's email
        final emailParts = childEmail.split('@');
        if (emailParts.length == 2) {
          final parentEmail = 'parent.${emailParts[0]}@${emailParts[1]}';
          print('Created default parent email: $parentEmail');
          return parentEmail;
        }
      }

      // Final fallback
      const defaultParentEmail = 'parent@bloombuddy.com';
      print('Using default parent email: $defaultParentEmail');
      return defaultParentEmail;
    } catch (e) {
      print('Error finding parent email: $e');
      return 'parent@bloombuddy.com';
    }
  }

  // Ensure all required fields exist in child document
  Future<void> _ensureRequiredFields(Map<String, dynamic> childData) async {
    try {
      final updates = <String, dynamic>{};

      // Add parentEmail if missing
      if (childData['parentEmail'] == null ||
          childData['parentEmail'].toString().isEmpty) {
        updates['parentEmail'] = _parentEmail;
      }

      // Add emotion detection fields if missing
      if (childData['emotionDetectionActive'] == null) {
        updates['emotionDetectionActive'] = false;
      }

      if (childData['emotionDetectionStartedAt'] == null) {
        updates['emotionDetectionStartedAt'] = null;
      }

      if (childData['emotionDetectionStoppedAt'] == null) {
        updates['emotionDetectionStoppedAt'] = null;
      }

      // Update the document if any fields are missing
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .update(updates);

        print(
          'Added missing fields to child document: ${updates.keys.join(', ')}',
        );
      }
    } catch (e) {
      print('Error ensuring required fields: $e');
    }
  }

  // Send notification to parent
  Future<void> _sendParentNotification() async {
    if (_parentEmail == null || _currentUserId == null || _childName == null)
      return;

    try {
      final emailService = EmailNotificationService();

      // Send email notification to parent
      final success = await emailService.sendEmotionDetectionNotification(
        parentEmail: _parentEmail!,
        childName: _childName!,
        childId: _currentUserId!,
      );

      if (success) {
        _hasNotifiedParent = true;

        // Log the notification in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('notifications')
            .add({
              'type': 'emotion_detection_started',
              'recipient': _parentEmail,
              'message':
                  'Emotion detection activated for child safety monitoring',
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'sent',
            });

        print('Parent notification sent successfully to: $_parentEmail');
      } else {
        print('Failed to send parent notification to: $_parentEmail');
      }
    } catch (e) {
      print('Error sending parent notification: $e');
    }
  }

  // Start background emotion detection
  Future<void> startBackgroundDetection() async {
    if (!_isInitialized || _isDetecting) return;

    _isDetecting = true;
    print('Starting background emotion detection for child: $_currentUserId');

    // Start detection timer - every 10 seconds for background processing
    _detectionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _detectAndLogEmotion();
    });
  }

  // Stop background emotion detection
  Future<void> stopBackgroundDetection() async {
    _isDetecting = false;
    _detectionTimer?.cancel();
    _detectionTimer = null;

    if (_currentUserId != null) {
      // Update child's emotion detection status
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .update({
            'emotionDetectionActive': false,
            'emotionDetectionStoppedAt': FieldValue.serverTimestamp(),
          });
    }

    print('Stopped background emotion detection');
  }

  // Detect emotion and log to Firestore
  Future<void> _detectAndLogEmotion() async {
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

        // Log emotion to Firestore
        await _logEmotionToFirestore(
          emotionResult['emotion'],
          emotionResult['confidence'],
        );

        // ALSO do eye tracking from the same face detection!
        if (_eyeTrackingEnabled) {
          await _trackAndLogGaze(face);
        }

        // Parent emotion alerts disabled by product requirement

        print(
          'Background emotion detected: ${emotionResult['emotion']} (confidence: ${emotionResult['confidence'].toStringAsFixed(2)})',
        );
      }

      // Clean up the temporary image file
      await file.delete();
    } catch (e) {
      print('Error in background emotion detection: $e');
    }
  }

  // Track and log gaze direction (EYE TRACKING)
  Future<void> _trackAndLogGaze(Face face) async {
    try {
      if (_currentUserId == null) return;

      // Get eye landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      if (leftEye == null || rightEye == null) return;

      // Calculate gaze direction based on head pose and eye positions
      final headEulerY = face.headEulerAngleY ?? 0.0; // Left-right rotation
      final headEulerZ = face.headEulerAngleZ ?? 0.0; // Tilt

      // Estimate gaze direction
      String gazeDirection = 'center';
      if (headEulerY > 15) {
        gazeDirection = 'right';
      } else if (headEulerY < -15) {
        gazeDirection = 'left';
      } else if (headEulerZ > 10) {
        gazeDirection = 'down';
      } else if (headEulerZ < -10) {
        gazeDirection = 'up';
      }

      // Calculate average eye position
      final avgEyeX = (leftEye.position.x + rightEye.position.x) / 2;
      final avgEyeY = (leftEye.position.y + rightEye.position.y) / 2;

      // Log to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('eyeTracking')
          .add({
            'gazeDirection': gazeDirection,
            'headEulerY': headEulerY,
            'headEulerZ': headEulerZ,
            'avgEyeX': avgEyeX,
            'avgEyeY': avgEyeY,
            'timestamp': FieldValue.serverTimestamp(),
          });

      print('Eye tracking logged: $gazeDirection');
    } catch (e) {
      print('Error tracking eyes: $e');
    }
  }

  // Detect faces in the image using Google ML Kit
  Future<List<Face>> _detectFaces(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector!.processImage(inputImage);
      return faces;
    } catch (e) {
      print('Error detecting faces in background: $e');
      return [];
    }
  }

  // Classify emotion with confidence score (same as before)
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

    // Improved emotion classification with confidence scores

    // Happy: High smiling probability (most reliable)
    if (smilingProb > 0.5) {
      return {
        'emotion': 'happy',
        'confidence': (smilingProb * 1.2).clamp(0.0, 1.0),
      };
    }

    // Surprise: Eyes very wide open, head tilted back
    if (avgEyeOpenness > 0.85 && headEulerAngleZ.abs() > 6) {
      return {
        'emotion': 'surprise',
        'confidence': ((avgEyeOpenness * 0.6) + (headEulerAngleZ.abs() / 20.0))
            .clamp(0.0, 1.0),
      };
    }

    // Fear: Very low smiling, eyes either very wide or very closed
    if (smilingProb < 0.25 &&
        ((avgEyeOpenness > 0.9) || (avgEyeOpenness < 0.4))) {
      return {
        'emotion': 'fear',
        'confidence': ((1.0 - smilingProb) * 0.8).clamp(0.0, 1.0),
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
                .clamp(0.0, 1.0),
      };
    }

    // Angry: Alternative detection - very low smiling with narrowed eyes (no head tilt required)
    if (smilingProb < 0.3 && avgEyeOpenness < 0.6) {
      return {
        'emotion': 'angry',
        'confidence': ((1.0 - smilingProb) * 0.7).clamp(0.0, 1.0),
      };
    }

    // Sad: Low smiling, eyes partially closed, minimal head movement
    if (smilingProb < 0.4 && avgEyeOpenness < 0.7 && headMovement < 5) {
      return {
        'emotion': 'sad',
        'confidence': ((1.0 - smilingProb) * 0.7).clamp(0.0, 1.0),
      };
    }

    // Disgust: Low smiling, moderate head movement
    if (smilingProb < 0.35 && headMovement > 4 && headMovement < 15) {
      return {
        'emotion': 'disgust',
        'confidence': ((1.0 - smilingProb) * 0.6).clamp(0.0, 1.0),
      };
    }

    // Default to neutral
    return {'emotion': 'neutral', 'confidence': 0.5};
  }

  // Parent emotion alerts disabled by product requirement

  // Log emotion to Firestore
  Future<void> _logEmotionToFirestore(String emotion, double confidence) async {
    try {
      if (_currentUserId == null) return;

      final timestamp = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('emotions')
          .add({
            'emotion': emotion,
            'timestamp': timestamp,
            'confidence': confidence,
            'source': 'background_detection',
          });

      print(
        'Background emotion logged to Firestore: $emotion (confidence: ${confidence.toStringAsFixed(2)})',
      );
    } catch (e) {
      print('Error logging background emotion to Firestore: $e');
    }
  }

  // Get background detection status
  bool get isDetecting => _isDetecting;
  bool get isInitialized => _isInitialized;

  // Dispose resources
  Future<void> dispose() async {
    await stopBackgroundDetection();
    await _cameraController?.dispose();
    _isInitialized = false;
    _currentUserId = null;
    _parentEmail = null;
    _hasNotifiedParent = false;
  }
}
