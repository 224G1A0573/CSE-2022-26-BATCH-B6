import '../emotion_detection_service.dart';

/// Emotion mirroring service - detects child's emotions and compares with displayed emotions
class EmotionMirroringService {
  static final EmotionMirroringService _instance = EmotionMirroringService._internal();
  factory EmotionMirroringService() => _instance;
  EmotionMirroringService._internal();

  final EmotionDetectionService _emotionService = EmotionDetectionService();
  String? _currentDisplayedEmotion;
  String? _detectedChildEmotion;
  double _matchConfidence = 0.0;
  bool _isActive = false;

  // Callbacks
  Function(String emotion, double confidence)? onEmotionDetected;
  Function(bool isMatch, double confidence)? onEmotionMatch;

  /// Initialize the service
  Future<bool> initialize() async {
    return await _emotionService.initialize();
  }

  /// Start emotion mirroring
  Future<void> startMirroring({required String displayedEmotion}) async {
    if (_isActive) return;

    _currentDisplayedEmotion = displayedEmotion;
    _isActive = true;

    // Start emotion detection
    await _emotionService.startEmotionDetection();

    // Monitor emotions periodically
    _monitorEmotions();
  }

  /// Stop emotion mirroring
  Future<void> stopMirroring() async {
    _isActive = false;
    await _emotionService.stopEmotionDetection();
  }

  /// Update displayed emotion
  void updateDisplayedEmotion(String emotion) {
    _currentDisplayedEmotion = emotion;
    _checkEmotionMatch();
  }

  /// Monitor emotions and check for matches
  Future<void> _monitorEmotions() async {
    while (_isActive) {
      try {
        // Get recent emotions
        final recentEmotions = await _emotionService.getRecentEmotions(limit: 1);
        
        if (recentEmotions.isNotEmpty) {
          final latest = recentEmotions.first;
          final emotion = latest['emotion'] as String;
          final confidence = latest['confidence'] as double? ?? 0.0;

          if (confidence > 0.6) {
            _detectedChildEmotion = emotion;
            onEmotionDetected?.call(emotion, confidence);
            _checkEmotionMatch();
          }
        }

        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Error monitoring emotions: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Check if detected emotion matches displayed emotion
  void _checkEmotionMatch() {
    if (_currentDisplayedEmotion == null || _detectedChildEmotion == null) return;

    // Map emotions to common categories
    final normalizedDisplayed = _normalizeEmotion(_currentDisplayedEmotion!);
    final normalizedDetected = _normalizeEmotion(_detectedChildEmotion!);

    final isMatch = normalizedDisplayed == normalizedDetected;
    
    // Calculate confidence based on emotion mapping
    _matchConfidence = _calculateMatchConfidence(
      _currentDisplayedEmotion!,
      _detectedChildEmotion!,
    );

    onEmotionMatch?.call(isMatch, _matchConfidence);
  }

  /// Normalize emotion names to common categories
  String _normalizeEmotion(String emotion) {
    final lower = emotion.toLowerCase();
    
    if (lower.contains('happy') || lower.contains('joy') || lower.contains('smile')) {
      return 'happy';
    }
    if (lower.contains('sad') || lower.contains('sorrow')) {
      return 'sad';
    }
    if (lower.contains('angry') || lower.contains('anger') || lower.contains('mad')) {
      return 'angry';
    }
    if (lower.contains('surprise') || lower.contains('surprised')) {
      return 'surprised';
    }
    if (lower.contains('fear') || lower.contains('scared') || lower.contains('afraid')) {
      return 'scared';
    }
    if (lower.contains('confused') || lower.contains('confusion')) {
      return 'confused';
    }
    
    return 'neutral';
  }

  /// Calculate match confidence
  double _calculateMatchConfidence(String displayed, String detected) {
    final normalizedDisplayed = _normalizeEmotion(displayed);
    final normalizedDetected = _normalizeEmotion(detected);

    if (normalizedDisplayed == normalizedDetected) {
      return 1.0; // Perfect match
    }

    // Partial matches (related emotions)
    final relatedEmotions = {
      'happy': ['excited', 'joyful'],
      'sad': ['disappointed', 'down'],
      'angry': ['frustrated', 'annoyed'],
      'surprised': ['excited', 'shocked'],
      'scared': ['anxious', 'worried'],
      'confused': ['uncertain', 'puzzled'],
    };

    if (relatedEmotions.containsKey(normalizedDisplayed)) {
      final related = relatedEmotions[normalizedDisplayed]!;
      if (related.contains(normalizedDetected)) {
        return 0.7; // Related emotion
      }
    }

    return 0.0; // No match
  }

  /// Get current match status
  Map<String, dynamic> getMatchStatus() {
    return {
      'displayedEmotion': _currentDisplayedEmotion,
      'detectedEmotion': _detectedChildEmotion,
      'isMatch': _currentDisplayedEmotion != null && 
                 _detectedChildEmotion != null &&
                 _normalizeEmotion(_currentDisplayedEmotion!) == 
                 _normalizeEmotion(_detectedChildEmotion!),
      'confidence': _matchConfidence,
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopMirroring();
    await _emotionService.dispose();
  }
}

