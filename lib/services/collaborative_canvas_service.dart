import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

class DrawingPoint {
  final String id;
  final double x;
  final double y;
  final String color; // Hex color
  final double strokeWidth;
  final String userId;
  final int timestamp;

  DrawingPoint({
    required this.id,
    required this.x,
    required this.y,
    required this.color,
    required this.strokeWidth,
    required this.userId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'color': color,
      'strokeWidth': strokeWidth,
      'userId': userId,
      'timestamp': timestamp,
    };
  }

  factory DrawingPoint.fromJson(Map<dynamic, dynamic> json) {
    final point = DrawingPoint(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      color: json['color'] as String,
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      userId: json['userId'] as String,
      timestamp: json['timestamp'] as int,
    );
    // Debug first point only
    if (json['id'] != null && (json['id'] as String).endsWith('001')) {
      print(
          '🔍 Sample point parsed: x=${point.x}, y=${point.y}, color=${point.color}');
    }
    return point;
  }
}

class CollaborativeCanvasService {
  static FirebaseDatabase get _database {
    // Initialize with proper database URL
    try {
      return FirebaseDatabase.instance;
    } catch (e) {
      print('Error getting Firebase Database instance: $e');
      print(
          'Make sure Firebase Realtime Database is enabled in Firebase Console');
      rethrow;
    }
  }

  static const Uuid _uuid = Uuid();

  // Create a new canvas session
  static Future<String> createCanvasSession({
    required String therapistId,
    required String childId,
  }) async {
    final sessionId = _uuid.v4();

    print('Creating session with ID: $sessionId');
    print('Therapist: $therapistId, Child: $childId');

    try {
      // Add timeout to prevent hanging forever
      await _database.ref('canvasSessions/$sessionId').set({
        'therapistId': therapistId,
        'childId': childId,
        'createdAt': ServerValue.timestamp,
        'isActive': true,
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('TIMEOUT: Firebase Realtime Database not responding!');
          throw Exception(
              'Firebase Realtime Database is not enabled or not responding. '
              'Please enable it in Firebase Console.');
        },
      );

      print('Session created successfully!');
      return sessionId;
    } catch (e) {
      print('Error creating session: $e');
      rethrow;
    }
  }

  // Add a drawing point to the session
  static Future<void> addDrawingPoint({
    required String sessionId,
    required DrawingPoint point,
  }) async {
    await _database
        .ref('canvasSessions/$sessionId/points/${point.id}')
        .set(point.toJson());
  }

  // Listen to all drawing points in a session
  static Stream<List<DrawingPoint>> getDrawingPoints(String sessionId) {
    return _database
        .ref('canvasSessions/$sessionId/points')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) {
        return <DrawingPoint>[];
      }

      final Map<dynamic, dynamic> pointsMap =
          event.snapshot.value as Map<dynamic, dynamic>;

      final points = pointsMap.entries
          .map((entry) => DrawingPoint.fromJson(entry.value))
          .toList();

      // Sort by timestamp
      points.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return points;
    });
  }

  // Clear canvas
  static Future<void> clearCanvas(String sessionId) async {
    await _database.ref('canvasSessions/$sessionId/points').remove();
  }

  // End session
  static Future<void> endSession(String sessionId) async {
    await _database.ref('canvasSessions/$sessionId').update({
      'isActive': false,
      'endedAt': ServerValue.timestamp,
    });
  }

  // Check if session is active
  static Future<bool> isSessionActive(String sessionId) async {
    final snapshot =
        await _database.ref('canvasSessions/$sessionId/isActive').get();
    return snapshot.value as bool? ?? false;
  }

  // Generate unique point ID
  static String generatePointId() {
    return _uuid.v4();
  }

  // Convert hex color string to Color
  static ui.Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return ui.Color(int.parse(buffer.toString(), radix: 16));
  }

  // Convert Color to hex string
  static String colorToHex(ui.Color color) {
    return '#${color.value.toRadixString(16).substring(2)}';
  }
}
