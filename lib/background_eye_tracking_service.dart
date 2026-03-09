import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class BackgroundEyeTrackingService {
  static final BackgroundEyeTrackingService _instance =
      BackgroundEyeTrackingService._internal();
  factory BackgroundEyeTrackingService() => _instance;
  BackgroundEyeTrackingService._internal();

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isInitialized = false;
  bool _isTracking = false;
  Timer? _trackingTimer;
  String? _currentUserId;
  String? _childName;

  // Screen dimensions (you can adjust these based on device)
  double screenWidth = 1920;
  double screenHeight = 1080;

  // Smoothing queue for gaze positions
  final List<Map<String, double>> _gazeQueue = [];
  final int _smoothingWindow = 5;

  // Initialize background eye tracking
  Future<bool> initializeForChild(String userId) async {
    if (_isInitialized && _currentUserId == userId) return true;

    _currentUserId = userId;

    try {
      // Get child's data
      await _fetchChildData();

      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        print('Camera permission denied for eye tracking');
        return false;
      }

      // Initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No cameras available for eye tracking');
        return false;
      }

      // Use front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Medium resolution for better eye tracking
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Initialize Google ML Kit face detector with landmarks
      _faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          enableLandmarks: true, // Essential for eye tracking
          enableClassification: true,
          enableTracking: true,
          minFaceSize: 0.15,
          performanceMode:
              FaceDetectorMode.accurate, // Accurate mode for eye tracking
        ),
      );

      _isInitialized = true;

      // Update Firestore
      await _updateFirestoreStatus(true);

      print('Background eye tracking initialized for child: $_childName');
      return true;
    } catch (e) {
      print('Error initializing background eye tracking: $e');
      return false;
    }
  }

  // Fetch child data
  Future<void> _fetchChildData() async {
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (childDoc.exists) {
        final data = childDoc.data();
        _childName = data?['displayName'] ?? 'Child';
      }
    } catch (e) {
      print('Error fetching child data: $e');
    }
  }

  // Update Firestore status
  Future<void> _updateFirestoreStatus(bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set({
        'eyeTrackingActive': isActive,
        'eyeTrackingLastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating Firestore: $e');
    }
  }

  // Start background eye tracking
  Future<void> startBackgroundTracking() async {
    if (!_isInitialized || _isTracking) return;

    _isTracking = true;

    // Track eye position every 500ms (2 times per second)
    _trackingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isTracking) {
        _captureAndTrackEyes();
      }
    });

    print('Background eye tracking started');
  }

  // Capture image and track eyes
  Future<void> _captureAndTrackEyes() async {
    if (!_isInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Capture image
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      // Detect faces
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;

        // Get eye landmarks
        final leftEye = face.landmarks[FaceLandmarkType.leftEye];
        final rightEye = face.landmarks[FaceLandmarkType.rightEye];

        if (leftEye != null && rightEye != null) {
          // Calculate gaze position
          final gazeData = _calculateGazePosition(face, leftEye, rightEye);

          // Log to Firestore
          await _logGazeData(gazeData);
        }
      }

      // Delete temporary image
      await File(image.path).delete();
    } catch (e) {
      print('Error tracking eyes: $e');
    }
  }

  // Calculate gaze position from face landmarks
  Map<String, dynamic> _calculateGazePosition(
    Face face,
    FaceLandmark leftEye,
    FaceLandmark rightEye,
  ) {
    // Get bounding box
    final boundingBox = face.boundingBox;

    // Calculate normalized eye positions (0.0 to 1.0)
    final leftEyeX =
        (leftEye.position.x - boundingBox.left) / boundingBox.width;
    final leftEyeY =
        (leftEye.position.y - boundingBox.top) / boundingBox.height;
    final rightEyeX =
        (rightEye.position.x - boundingBox.left) / boundingBox.width;
    final rightEyeY =
        (rightEye.position.y - boundingBox.top) / boundingBox.height;

    // Average the eye positions
    final gazeX = (leftEyeX + rightEyeX) / 2;
    final gazeY = (leftEyeY + rightEyeY) / 2;

    // Apply smoothing
    final smoothedGaze = _applySmoothig(gazeX, gazeY);

    // Map to screen coordinates
    final screenX = smoothedGaze['x']! * screenWidth;
    final screenY = smoothedGaze['y']! * screenHeight;

    // Get head rotation
    final headEulerAngleY = face.headEulerAngleY ?? 0.0;
    final headEulerAngleZ = face.headEulerAngleZ ?? 0.0;

    // Calculate gaze direction based on head rotation and eye position
    String gazeDirection = _determineGazeDirection(
      smoothedGaze['x']!,
      smoothedGaze['y']!,
      headEulerAngleY,
      headEulerAngleZ,
    );

    return {
      'gazeX': smoothedGaze['x'],
      'gazeY': smoothedGaze['y'],
      'screenX': screenX,
      'screenY': screenY,
      'gazeDirection': gazeDirection,
      'headRotationY': headEulerAngleY,
      'headRotationZ': headEulerAngleZ,
      'leftEyeOpenProbability': face.leftEyeOpenProbability ?? 0.0,
      'rightEyeOpenProbability': face.rightEyeOpenProbability ?? 0.0,
    };
  }

  // Apply moving average smoothing
  Map<String, double> _applySmoothig(double gazeX, double gazeY) {
    _gazeQueue.add({'x': gazeX, 'y': gazeY});

    // Keep only last N positions
    if (_gazeQueue.length > _smoothingWindow) {
      _gazeQueue.removeAt(0);
    }

    // Calculate average
    double avgX = 0;
    double avgY = 0;
    for (var gaze in _gazeQueue) {
      avgX += gaze['x']!;
      avgY += gaze['y']!;
    }
    avgX /= _gazeQueue.length;
    avgY /= _gazeQueue.length;

    return {'x': avgX, 'y': avgY};
  }

  // Determine gaze direction
  String _determineGazeDirection(
    double gazeX,
    double gazeY,
    double headRotationY,
    double headRotationZ,
  ) {
    // Combine eye position and head rotation
    final adjustedX = gazeX + (headRotationY / 100); // Adjust for head rotation
    final adjustedY = gazeY + (headRotationZ / 100);

    // Determine direction
    if (adjustedY < 0.3) {
      return 'up';
    } else if (adjustedY > 0.7) {
      return 'down';
    } else if (adjustedX < 0.3) {
      return 'left';
    } else if (adjustedX > 0.7) {
      return 'right';
    } else {
      return 'center';
    }
  }

  // Log gaze data to Firestore
  Future<void> _logGazeData(Map<String, dynamic> gazeData) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('eyeTracking')
          .add({
        ...gazeData,
        'timestamp': FieldValue.serverTimestamp(),
        'childName': _childName,
      });

      // Also update latest gaze in user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set({
        'latestGazeDirection': gazeData['gazeDirection'],
        'latestGazeUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print(
          'Gaze tracked: ${gazeData['gazeDirection']} (${gazeData['screenX']?.toInt()}, ${gazeData['screenY']?.toInt()})');
    } catch (e) {
      print('Error logging gaze data: $e');
    }
  }

  // Stop background eye tracking
  Future<void> stopBackgroundTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    _trackingTimer?.cancel();
    _trackingTimer = null;

    await _updateFirestoreStatus(false);

    print('Background eye tracking stopped');
  }

  // Clean up resources
  Future<void> dispose() async {
    await stopBackgroundTracking();

    _cameraController?.dispose();
    _cameraController = null;

    _faceDetector?.close();
    _faceDetector = null;

    _gazeQueue.clear();
    _isInitialized = false;

    print('Eye tracking service disposed');
  }

  // Get current tracking status
  bool get isTracking => _isTracking;
  bool get isInitialized => _isInitialized;
}
