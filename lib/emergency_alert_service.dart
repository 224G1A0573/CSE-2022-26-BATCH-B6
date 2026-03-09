import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyAlertService {
  static final EmergencyAlertService _instance =
      EmergencyAlertService._internal();
  factory EmergencyAlertService() => _instance;
  EmergencyAlertService._internal();

  // Emergency emotion tracking
  final Map<String, List<Map<String, dynamic>>> _emotionHistory = {};
  final Map<String, Timer?> _emergencyTimers = {};
  final Map<String, bool> _hasSentEmergencyAlert = {};

  // Configuration
  static const Duration EMERGENCY_THRESHOLD =
      Duration(minutes: 1); // Changed to 1 minute as requested
  static const List<String> EMERGENCY_EMOTIONS = [
    'angry',
    'fear',
    'sad'
  ]; // Added 'sad' as requested
  static const double MIN_CONFIDENCE_THRESHOLD =
      0.5; // Lowered threshold for better detection

  // Start monitoring a child for emergency emotions
  Future<void> startMonitoring(String childId) async {
    print('Starting emergency monitoring for child: $childId');

    // Initialize tracking for this child
    _emotionHistory[childId] = [];
    _hasSentEmergencyAlert[childId] = false;

    // Start listening to emotion updates
    _listenToEmotionUpdates(childId);
  }

  // Stop monitoring a child
  Future<void> stopMonitoring(String childId) async {
    print('Stopping emergency monitoring for child: $childId');

    _emergencyTimers[childId]?.cancel();
    _emergencyTimers[childId] = null;
    _emotionHistory.remove(childId);
    _hasSentEmergencyAlert.remove(childId);
  }

  // Listen to emotion updates from Firestore
  void _listenToEmotionUpdates(String childId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(childId)
        .collection('emotions')
        .orderBy('timestamp', descending: true)
        .limit(20) // Listen to recent emotions
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final emotionData = doc.doc.data() as Map<String, dynamic>;
          _processEmotionUpdate(childId, emotionData);
        }
      }
    });
  }

  // Process new emotion update
  void _processEmotionUpdate(String childId, Map<String, dynamic> emotionData) {
    final emotion = emotionData['emotion'] as String?;
    final confidence = (emotionData['confidence'] as num?)?.toDouble() ?? 0.0;
    final timestamp = emotionData['timestamp'] as Timestamp?;

    if (emotion == null || timestamp == null) {
      print(
          'DEBUG: Invalid emotion data - emotion: $emotion, timestamp: $timestamp');
      return;
    }

    print(
      'DEBUG: Processing emotion - Child: $childId, Emotion: $emotion, Confidence: $confidence',
    );

    // Check if it's an emergency emotion
    final isEmergencyEmotion = EMERGENCY_EMOTIONS.contains(emotion);
    final hasSufficientConfidence = confidence >= MIN_CONFIDENCE_THRESHOLD;

    print(
        'DEBUG: Is emergency emotion: $isEmergencyEmotion, Has sufficient confidence: $hasSufficientConfidence');
    print('DEBUG: Emergency emotions list: $EMERGENCY_EMOTIONS');
    print('DEBUG: Min confidence threshold: $MIN_CONFIDENCE_THRESHOLD');

    // Process all emotions, but only trigger alerts for emergency emotions
    _addEmotionToHistory(childId, emotion, confidence, timestamp.toDate());

    if (isEmergencyEmotion && hasSufficientConfidence) {
      print(
          '🚨 EMERGENCY EMOTION DETECTED! Checking for sustained distress...');
      _checkForEmergencyCondition(childId);
    } else {
      print(
          'DEBUG: Non-emergency emotion or low confidence, not triggering alert');
    }
  }

  // Add emotion to history
  void _addEmotionToHistory(
    String childId,
    String emotion,
    double confidence,
    DateTime timestamp,
  ) {
    if (!_emotionHistory.containsKey(childId)) {
      _emotionHistory[childId] = [];
    }

    _emotionHistory[childId]!.add({
      'emotion': emotion,
      'confidence': confidence,
      'timestamp': timestamp,
    });

    // Keep only recent emotions (last 5 minutes)
    final cutoffTime = DateTime.now().subtract(const Duration(minutes: 5));
    _emotionHistory[childId]!.removeWhere(
      (entry) => (entry['timestamp'] as DateTime).isBefore(cutoffTime),
    );
  }

  // Check if emergency condition is met
  void _checkForEmergencyCondition(String childId) {
    if (_hasSentEmergencyAlert[childId] == true) {
      print('DEBUG: Emergency alert already sent for child: $childId');
      return;
    }

    final emotions = _emotionHistory[childId] ?? [];
    if (emotions.isEmpty) {
      print('DEBUG: No emotions in history for child: $childId');
      return;
    }

    print('DEBUG: Checking emergency condition for child: $childId');
    print('DEBUG: Total emotions in history: ${emotions.length}');

    // Check if we have sustained emergency emotions for the threshold duration
    final now = DateTime.now();
    final thresholdTime = now.subtract(EMERGENCY_THRESHOLD);

    // Count emergency emotions in the threshold period
    final emergencyEmotionsInPeriod = emotions.where((entry) {
      final entryTime = entry['timestamp'] as DateTime;
      final isInPeriod = entryTime.isAfter(thresholdTime);
      final isEmergencyEmotion = EMERGENCY_EMOTIONS.contains(entry['emotion']);

      if (isInPeriod && isEmergencyEmotion) {
        print(
            'DEBUG: Emergency emotion found - ${entry['emotion']} at ${entryTime.toString()}');
      }

      return isInPeriod && isEmergencyEmotion;
    }).length;

    print(
        'DEBUG: Emergency emotions in last ${EMERGENCY_THRESHOLD.inMinutes} minutes: $emergencyEmotionsInPeriod');

    // If we have any emergency emotions in the period, trigger alert (more sensitive)
    if (emergencyEmotionsInPeriod >= 1) {
      print('🚨 EMERGENCY CONDITION MET! Triggering alert...');
      _triggerEmergencyAlert(childId);
    } else {
      print(
          'DEBUG: Not enough emergency emotions yet. Need at least 1 in ${EMERGENCY_THRESHOLD.inMinutes} minutes.');
    }
  }

  // Reset emergency tracking
  void _resetEmergencyTracking(String childId) {
    _emergencyTimers[childId]?.cancel();
    _emergencyTimers[childId] = null;
    _hasSentEmergencyAlert[childId] = false;
    _emotionHistory[childId]?.clear();
  }

  // Trigger emergency alert (public for testing)
  Future<void> triggerEmergencyAlert(String childId) async {
    await _triggerEmergencyAlert(childId);
  }

  // Trigger emergency alert
  Future<void> _triggerEmergencyAlert(String childId) async {
    if (_hasSentEmergencyAlert[childId] == true) return;

    print('🚨 EMERGENCY ALERT TRIGGERED for child: $childId');
    _hasSentEmergencyAlert[childId] = true;

    try {
      // Get child and parent/therapist information
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .get();

      if (!childDoc.exists) {
        print('ERROR: Child document not found: $childId');
        return;
      }

      final childData = childDoc.data()!;
      final childName =
          childData['name'] ?? childData['displayName'] ?? 'Child';
      final parentEmail =
          childData['guardianEmail'] ?? childData['parentEmail'];
      final therapistId = childData['therapistId'];
      final therapistName = childData['therapistName'];

      print(
        'DEBUG: Child data - Name: $childName, ParentEmail: $parentEmail, TherapistId: $therapistId',
      );
      print('DEBUG: Child data keys: ${childData.keys.toList()}');
      print('DEBUG: guardianEmail: ${childData['guardianEmail']}');
      print('DEBUG: parentEmail: ${childData['parentEmail']}');

      // Get recent emotions for context
      final recentEmotions = _emotionHistory[childId] ?? [];
      final emotionSummary = _getEmotionSummary(recentEmotions);

      // Send notifications to parent and therapist
      await _sendEmergencyNotifications(
        childId: childId,
        childName: childName,
        parentEmail: parentEmail,
        therapistId: therapistId,
        therapistName: therapistName,
        emotionSummary: emotionSummary,
      );

      // Log emergency alert to Firestore
      await _logEmergencyAlert(childId, childName, emotionSummary);
    } catch (e) {
      print('Error triggering emergency alert: $e');
    }
  }

  // Get summary of recent emotions
  String _getEmotionSummary(List<Map<String, dynamic>> emotions) {
    if (emotions.isEmpty) return 'No recent emotion data';

    final emotionCounts = <String, int>{};
    for (var emotion in emotions) {
      final emotionType = emotion['emotion'] as String;
      emotionCounts[emotionType] = (emotionCounts[emotionType] ?? 0) + 1;
    }

    final summary = emotionCounts.entries
        .map((e) => '${e.key}: ${e.value} times')
        .join(', ');

    return 'Recent emotions: $summary';
  }

  // Send emergency notifications
  Future<void> _sendEmergencyNotifications({
    required String childId,
    required String childName,
    required String? parentEmail,
    required String? therapistId,
    required String? therapistName,
    required String emotionSummary,
  }) async {
    final alertMessage = '''
🚨 EMERGENCY ALERT 🚨

Your child $childName has been showing signs of distress (angry/fear/sad emotions) for more than 1 minute.

$emotionSummary

Please check on your child immediately.

Time: ${DateTime.now().toString()}
''';

    // Send notification to parent
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await _sendParentEmergencyNotification(
        childId: childId,
        childName: childName,
        parentEmail: parentEmail,
        message: alertMessage,
      );
    }

    // Send notification to therapist
    if (therapistId != null && therapistId.isNotEmpty) {
      await _sendTherapistEmergencyNotification(
        childId: childId,
        childName: childName,
        therapistId: therapistId,
        therapistName: therapistName,
        message: alertMessage,
      );
    }
  }

  // Send emergency notification to parent
  Future<void> _sendParentEmergencyNotification({
    required String childId,
    required String childName,
    required String parentEmail,
    required String message,
  }) async {
    try {
      print('DEBUG: Looking for parent with email: $parentEmail');

      // Try multiple ways to find the parent
      QuerySnapshot parentQuery;

      // First try: Look for parent by email
      parentQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: parentEmail)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();

      // If not found, try looking for any user with this email (might be guardianEmail)
      if (parentQuery.docs.isEmpty) {
        print('DEBUG: Parent not found by email, trying guardianEmail...');
        parentQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('guardianEmail', isEqualTo: parentEmail)
            .limit(1)
            .get();
      }

      // If still not found, try looking for any user with this email regardless of role
      if (parentQuery.docs.isEmpty) {
        print(
          'DEBUG: Parent not found by guardianEmail, trying any user with this email...',
        );
        parentQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: parentEmail)
            .limit(1)
            .get();
      }

      if (parentQuery.docs.isNotEmpty) {
        final parentId = parentQuery.docs.first.id;
        final parentData =
            parentQuery.docs.first.data() as Map<String, dynamic>;
        final parentRole = parentData['role'] ?? 'unknown';

        print(
          'DEBUG: Found parent - ID: $parentId, Role: $parentRole, Email: ${parentData['email']}',
        );

        // Create in-app notification for parent
        await FirebaseFirestore.instance
            .collection('users')
            .doc(parentId)
            .collection('notifications')
            .add({
          'type': 'emergency_alert',
          'title': '🚨 Emergency Alert - Child in Distress',
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'priority': 'high',
          'childId': childId,
          'childName': childName,
          'parentEmail': parentEmail,
        });

        print(
          '✅ Emergency notification sent to parent: $parentEmail (ID: $parentId)',
        );
      } else {
        print('❌ Parent not found with email: $parentEmail');

        // Let's also try to find any parent in the system as a fallback
        final anyParentQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'parent')
            .limit(1)
            .get();

        if (anyParentQuery.docs.isNotEmpty) {
          final fallbackParentId = anyParentQuery.docs.first.id;
          final fallbackParentData =
              anyParentQuery.docs.first.data() as Map<String, dynamic>;
          final fallbackParentEmail = fallbackParentData['email'] ?? 'unknown';

          print(
            'DEBUG: Using fallback parent - ID: $fallbackParentId, Email: $fallbackParentEmail',
          );

          await FirebaseFirestore.instance
              .collection('users')
              .doc(fallbackParentId)
              .collection('notifications')
              .add({
            'type': 'emergency_alert',
            'title': '🚨 Emergency Alert - Child in Distress',
            'message':
                '$message\n\nNote: Original parent ($parentEmail) not found, sent to fallback parent.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'priority': 'high',
            'childId': childId,
            'childName': childName,
            'parentEmail': parentEmail,
          });

          print(
            '✅ Emergency notification sent to fallback parent: $fallbackParentEmail',
          );
        }
      }
    } catch (e) {
      print('❌ Error sending emergency notification to parent: $e');
    }
  }

  // Send emergency notification to therapist
  Future<void> _sendTherapistEmergencyNotification({
    required String childId,
    required String childName,
    required String therapistId,
    required String? therapistName,
    required String message,
  }) async {
    try {
      // Create in-app notification for therapist
      await FirebaseFirestore.instance
          .collection('users')
          .doc(therapistId)
          .collection('notifications')
          .add({
        'type': 'emergency_alert',
        'title': '🚨 Emergency Alert - Child in Distress',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'priority': 'high',
        'childId': childId,
        'childName': childName,
        'therapistId': therapistId,
        'therapistName': therapistName,
      });

      print('Emergency notification sent to therapist: $therapistName');
    } catch (e) {
      print('Error sending emergency notification to therapist: $e');
    }
  }

  // Log emergency alert to Firestore
  Future<void> _logEmergencyAlert(
    String childId,
    String childName,
    String emotionSummary,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('emergencyAlerts').add({
        'childId': childId,
        'childName': childName,
        'emotionSummary': emotionSummary,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'alertType': 'sustained_distress',
      });

      print('Emergency alert logged to Firestore');
    } catch (e) {
      print('Error logging emergency alert: $e');
    }
  }

  // Reset emergency alert status (call this when child is safe)
  Future<void> resetEmergencyStatus(String childId) async {
    _hasSentEmergencyAlert[childId] = false;
    _emotionHistory[childId]?.clear();

    print('Emergency status reset for child: $childId');
  }

  // Get emergency status for a child
  bool isEmergencyActive(String childId) {
    return _hasSentEmergencyAlert[childId] == true;
  }

  // Get recent emotion history for a child
  List<Map<String, dynamic>> getEmotionHistory(String childId) {
    return _emotionHistory[childId] ?? [];
  }

  // Manual method to simulate emotion detection for testing
  Future<void> simulateEmotionDetection(
      String childId, String emotion, double confidence) async {
    print(
        '🧪 SIMULATING EMOTION DETECTION: $emotion with confidence $confidence');

    final emotionData = {
      'emotion': emotion,
      'confidence': confidence,
      'timestamp': Timestamp.now(),
    };

    _processEmotionUpdate(childId, emotionData);
  }
}
