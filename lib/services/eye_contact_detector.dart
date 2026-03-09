import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Real-time eye contact detection using ML Kit
class EyeContactDetector {
  static final EyeContactDetector _instance = EyeContactDetector._internal();
  factory EyeContactDetector() => _instance;
  EyeContactDetector._internal();

  FaceDetector? _faceDetector;
  CameraController? _cameraController;
  bool _isInitialized = false;
  
  // Eye contact tracking
  Offset? _characterPosition; // Position of virtual character on screen
  double _eyeContactThreshold = 0.3; // Distance threshold for eye contact
  bool _isLookingAtCharacter = false;
  DateTime? _lastEyeContactTime;
  int _consecutiveEyeContactFrames = 0;
  int _requiredFrames = 10; // Need 10 consecutive frames for valid eye contact

  // Callbacks
  Function(bool)? onEyeContactChanged;
  Function(double)? onEyeContactProgress;

  /// Initialize the detector
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize face detector
      _faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          enableLandmarks: true,
          enableClassification: true,
          enableTracking: true,
          minFaceSize: 0.15,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      // Initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

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
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing eye contact detector: $e');
      return false;
    }
  }

  /// Set the character position for eye contact tracking
  void setCharacterPosition(Offset position) {
    _characterPosition = position;
  }

  /// Start detecting eye contact
  Future<void> startDetection() async {
    if (!_isInitialized || _cameraController == null) return;

    try {
      await _cameraController!.startImageStream((CameraImage image) {
        _processFrame(image);
      });
    } catch (e) {
      print('Error starting eye contact detection: $e');
    }
  }

  /// Stop detection
  Future<void> stopDetection() async {
    try {
      await _cameraController?.stopImageStream();
    } catch (e) {
      print('Error stopping eye contact detection: $e');
    }
  }

  /// Process a camera frame
  Future<void> _processFrame(CameraImage image) async {
    if (_faceDetector == null || _characterPosition == null) return;

    try {
      // Convert camera image to InputImage
      final inputImage = _cameraImageToInputImage(image);
      
      // Detect faces
      final faces = await _faceDetector!.processImage(inputImage);
      
      if (faces.isEmpty) {
        _updateEyeContactStatus(false);
        return;
      }

      final face = faces.first;
      
      // Get eye landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      
      if (leftEye == null || rightEye == null) {
        _updateEyeContactStatus(false);
        return;
      }

      // Calculate eye center position
      final eyeCenter = Offset(
        (leftEye.position.x + rightEye.position.x) / 2,
        (leftEye.position.y + rightEye.position.y) / 2,
      );

      // Calculate head pose (using head Euler angles)
      final headY = face.headEulerAngleY ?? 0.0; // Left/right rotation
      final headZ = face.headEulerAngleZ ?? 0.0; // Tilt
      
      // Calculate distance from eye center to character position
      // Normalize to screen coordinates (0-1 range)
      final screenWidth = image.width.toDouble();
      final screenHeight = image.height.toDouble();
      
      final normalizedEyeX = eyeCenter.dx / screenWidth;
      final normalizedEyeY = eyeCenter.dy / screenHeight;
      
      // Character position is in screen coordinates, need to normalize
      // Assuming character is centered, we calculate relative position
      final eyeDirection = _calculateEyeDirection(face, normalizedEyeX, normalizedEyeY);
      
      // Check if looking at character (within threshold)
      final distance = _calculateDistanceToCharacter(eyeDirection, headY, headZ);
      final isLooking = distance < _eyeContactThreshold && 
                       headY.abs() < 15 && // Head not turned too much
                       headZ.abs() < 15;  // Head not tilted too much

      _updateEyeContactStatus(isLooking);
    } catch (e) {
      print('Error processing frame: $e');
    }
  }

  /// Calculate eye direction based on face landmarks
  Offset _calculateEyeDirection(Face face, double eyeX, double eyeY) {
    // Use head pose angles to estimate gaze direction
    final headY = face.headEulerAngleY ?? 0.0;
    final headZ = face.headEulerAngleZ ?? 0.0;
    
    // Convert head angles to direction vector
    // Positive Y = looking right, Negative Y = looking left
    // Positive Z = looking up, Negative Z = looking down
    return Offset(
      headY / 30.0, // Normalize to -1 to 1 range
      -headZ / 30.0, // Invert Z (positive Z means head up, but we want positive Y)
    );
  }

  /// Calculate distance from eye direction to character position
  double _calculateDistanceToCharacter(Offset eyeDirection, double headY, double headZ) {
    if (_characterPosition == null) return 1.0; // Far away if no character
    
    // Character position is in screen coordinates (0-1 normalized)
    // We need to compare eye direction with character position
    // For simplicity, we'll use head angles as proxy for gaze direction
    
    // Calculate expected gaze direction to character
    // Assuming character is at center (0.5, 0.5) for now
    // In real implementation, use actual character screen position
    final characterScreenX = 0.5; // Normalized
    final characterScreenY = 0.5; // Normalized
    
    // Estimate gaze direction from head pose
    final gazeX = (headY / 30.0).clamp(-1.0, 1.0);
    final gazeY = (-headZ / 30.0).clamp(-1.0, 1.0);
    
    // Calculate distance (Euclidean)
    final distance = math.sqrt(
      math.pow(gazeX - (characterScreenX - 0.5) * 2, 2) +
      math.pow(gazeY - (characterScreenY - 0.5) * 2, 2)
    );
    
    return distance;
  }

  /// Update eye contact status
  void _updateEyeContactStatus(bool isLooking) {
    if (isLooking) {
      _consecutiveEyeContactFrames++;
      if (_consecutiveEyeContactFrames >= _requiredFrames && !_isLookingAtCharacter) {
        _isLookingAtCharacter = true;
        _lastEyeContactTime = DateTime.now();
        onEyeContactChanged?.call(true);
      }
    } else {
      _consecutiveEyeContactFrames = 0;
      if (_isLookingAtCharacter) {
        _isLookingAtCharacter = false;
        onEyeContactChanged?.call(false);
      }
    }

    // Calculate progress (0.0 to 1.0)
    final progress = (_consecutiveEyeContactFrames / _requiredFrames).clamp(0.0, 1.0);
    onEyeContactProgress?.call(progress);
  }

  /// Convert CameraImage to InputImage
  InputImage _cameraImageToInputImage(CameraImage image) {
    // For simplicity, we'll use a workaround
    // In production, you'd want to properly convert the image format
    // This is a simplified version - you may need to adjust based on your needs
    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.yuv420,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  /// Get current eye contact status
  bool get isLookingAtCharacter => _isLookingAtCharacter;

  /// Get eye contact duration
  Duration? get eyeContactDuration {
    if (_lastEyeContactTime == null) return null;
    return DateTime.now().difference(_lastEyeContactTime!);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopDetection();
    await _cameraController?.dispose();
    await _faceDetector?.close();
    _isInitialized = false;
  }
}

