import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

/// Adaptive difficulty service using ML-based performance analysis
class AdaptiveDifficultyService {
  static final AdaptiveDifficultyService _instance = AdaptiveDifficultyService._internal();
  factory AdaptiveDifficultyService() => _instance;
  AdaptiveDifficultyService._internal();

  /// Calculate optimal difficulty based on performance history
  Future<Map<String, dynamic>> calculateOptimalDifficulty({
    required String module, // 'conversation', 'turnTaking', 'emotionRecognition', 'eyeContact'
    int? currentRound,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return _getDefaultDifficulty(module);

      // Get recent performance data
      final recentReports = await _getRecentPerformance(user.uid, module);
      
      if (recentReports.isEmpty) {
        return _getDefaultDifficulty(module);
      }

      // Analyze performance trends
      final performanceAnalysis = _analyzePerformance(recentReports, module);
      
      // Calculate adaptive difficulty
      return _calculateDifficulty(performanceAnalysis, module, currentRound ?? 1);
    } catch (e) {
      print('Error calculating adaptive difficulty: $e');
      return _getDefaultDifficulty(module);
    }
  }

  /// Get recent performance data
  Future<List<Map<String, dynamic>>> _getRecentPerformance(String userId, String module) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('gameReports')
          .where('gameType', isEqualTo: 'social_skills_training')
          .orderBy('completedAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting recent performance: $e');
      return [];
    }
  }

  /// Analyze performance trends
  Map<String, dynamic> _analyzePerformance(
    List<Map<String, dynamic>> reports,
    String module,
  ) {
    if (reports.isEmpty) {
      return {
        'avgAccuracy': 0.5,
        'trend': 'stable',
        'consistency': 0.5,
        'moduleScore': 0.0,
      };
    }

    // Extract module-specific scores
    final moduleScores = <double>[];
    final accuracies = <double>[];

    for (final report in reports) {
      double? moduleScore;
      switch (module) {
        case 'conversation':
          final score = report['conversationScore'] as int? ?? 0;
          final rounds = report['conversationRounds'] as int? ?? 1;
          moduleScore = rounds > 0 ? score / rounds : 0.0;
          break;
        case 'turnTaking':
          final score = report['turnTakingScore'] as int? ?? 0;
          final rounds = report['turnTakingRounds'] as int? ?? 1;
          moduleScore = rounds > 0 ? score / rounds : 0.0;
          break;
        case 'emotionRecognition':
          final score = report['emotionRecognitionScore'] as int? ?? 0;
          final rounds = report['emotionRecognitionRounds'] as int? ?? 1;
          moduleScore = rounds > 0 ? score / rounds : 0.0;
          break;
        case 'eyeContact':
          final score = report['eyeContactScore'] as int? ?? 0;
          final rounds = report['eyeContactRounds'] as int? ?? 1;
          moduleScore = rounds > 0 ? score / rounds : 0.0;
          break;
      }

      if (moduleScore != null) {
        moduleScores.add(moduleScore);
      }

      final accuracy = report['accuracy'] as double? ?? 0.0;
      accuracies.add(accuracy);
    }

    // Calculate statistics
    final avgAccuracy = accuracies.isNotEmpty
        ? accuracies.reduce((a, b) => a + b) / accuracies.length
        : 0.5;

    final avgModuleScore = moduleScores.isNotEmpty
        ? moduleScores.reduce((a, b) => a + b) / moduleScores.length
        : 0.5;

    // Calculate trend (improving, declining, stable)
    String trend = 'stable';
    if (moduleScores.length >= 3) {
      final recent = moduleScores.take(3).reduce((a, b) => a + b) / 3;
      final older = moduleScores.skip(3).take(3).length >= 3
          ? moduleScores.skip(3).take(3).reduce((a, b) => a + b) / 3
          : recent;
      
      if (recent > older + 0.1) {
        trend = 'improving';
      } else if (recent < older - 0.1) {
        trend = 'declining';
      }
    }

    // Calculate consistency (lower variance = higher consistency)
    double consistency = 0.5;
    if (moduleScores.length >= 2) {
      final mean = avgModuleScore;
      final variance = moduleScores
          .map((s) => math.pow(s - mean, 2))
          .reduce((a, b) => a + b) / moduleScores.length;
      consistency = 1.0 - (variance.clamp(0.0, 0.25) * 4); // Normalize to 0-1
    }

    return {
      'avgAccuracy': avgAccuracy,
      'avgModuleScore': avgModuleScore,
      'trend': trend,
      'consistency': consistency,
      'moduleScore': avgModuleScore,
    };
  }

  /// Calculate optimal difficulty based on analysis
  Map<String, dynamic> _calculateDifficulty(
    Map<String, dynamic> analysis,
    String module,
    int currentRound,
  ) {
    final avgScore = analysis['moduleScore'] as double;
    final trend = analysis['trend'] as String;
    final consistency = analysis['consistency'] as double;

    // Base difficulty adjustment
    double difficultyMultiplier = 1.0;
    
    // Adjust based on performance
    if (avgScore > 0.8) {
      // High performance - increase difficulty
      difficultyMultiplier = 1.2;
    } else if (avgScore < 0.5) {
      // Low performance - decrease difficulty
      difficultyMultiplier = 0.8;
    }

    // Adjust based on trend
    if (trend == 'improving') {
      difficultyMultiplier *= 1.1; // Slightly increase
    } else if (trend == 'declining') {
      difficultyMultiplier *= 0.9; // Slightly decrease
    }

    // Adjust based on consistency
    if (consistency > 0.7) {
      // Very consistent - can handle more challenge
      difficultyMultiplier *= 1.05;
    } else if (consistency < 0.3) {
      // Inconsistent - need more stability
      difficultyMultiplier *= 0.95;
    }

    // Module-specific difficulty calculations
    switch (module) {
      case 'conversation':
        return {
          'scenarioComplexity': (3 * difficultyMultiplier).round().clamp(1, 5),
          'responseOptions': 4, // Keep options constant
          'hintLevel': avgScore < 0.6 ? 'high' : avgScore < 0.8 ? 'medium' : 'low',
        };

      case 'turnTaking':
        final baseSequenceLength = 3 + currentRound;
        return {
          'sequenceLength': (baseSequenceLength * difficultyMultiplier).round().clamp(3, 10),
          'turnSpeed': (1.0 * difficultyMultiplier).clamp(0.5, 2.0), // seconds between turns
        };

      case 'emotionRecognition':
        return {
          'emotionComplexity': (2 * difficultyMultiplier).round().clamp(1, 4),
          'optionsCount': 4,
          'displayTime': (3.0 / difficultyMultiplier).clamp(1.0, 5.0), // seconds
        };

      case 'eyeContact':
        return {
          'targetDuration': (3.0 * difficultyMultiplier).round().clamp(2, 5), // seconds
          'movementSpeed': (1.0 * difficultyMultiplier).clamp(0.5, 2.0),
          'validationStrictness': avgScore > 0.7 ? 'high' : 'medium',
        };

      default:
        return _getDefaultDifficulty(module);
    }
  }

  /// Get default difficulty settings
  Map<String, dynamic> _getDefaultDifficulty(String module) {
    switch (module) {
      case 'conversation':
        return {
          'scenarioComplexity': 2,
          'responseOptions': 4,
          'hintLevel': 'medium',
        };
      case 'turnTaking':
        return {
          'sequenceLength': 4,
          'turnSpeed': 1.0,
        };
      case 'emotionRecognition':
        return {
          'emotionComplexity': 2,
          'optionsCount': 4,
          'displayTime': 3.0,
        };
      case 'eyeContact':
        return {
          'targetDuration': 3,
          'movementSpeed': 1.0,
          'validationStrictness': 'medium',
        };
      default:
        return {};
    }
  }

  /// Predict future performance
  Future<Map<String, dynamic>> predictPerformance({
    required String module,
    int sessionsAhead = 5,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'predictedAccuracy': 0.5, 'confidence': 0.5};

      final recentReports = await _getRecentPerformance(user.uid, module);
      if (recentReports.length < 3) {
        return {'predictedAccuracy': 0.5, 'confidence': 0.3};
      }

      final analysis = _analyzePerformance(recentReports, module);
      final currentScore = analysis['moduleScore'] as double;
      final trend = analysis['trend'] as String;

      // Simple linear prediction
      double predictedScore = currentScore;
      if (trend == 'improving') {
        predictedScore += 0.05 * sessionsAhead;
      } else if (trend == 'declining') {
        predictedScore -= 0.03 * sessionsAhead;
      }

      predictedScore = predictedScore.clamp(0.0, 1.0);

      // Confidence based on consistency
      final consistency = analysis['consistency'] as double;
      final confidence = consistency * 0.7 + 0.3; // Base confidence

      return {
        'predictedAccuracy': predictedScore,
        'confidence': confidence,
        'sessionsToTarget': _calculateSessionsToTarget(currentScore, 0.8), // Target 80% accuracy
      };
    } catch (e) {
      print('Error predicting performance: $e');
      return {'predictedAccuracy': 0.5, 'confidence': 0.5};
    }
  }

  /// Calculate sessions needed to reach target
  int _calculateSessionsToTarget(double currentScore, double target) {
    if (currentScore >= target) return 0;
    
    final gap = target - currentScore;
    // Assume 0.05 improvement per session on average
    return (gap / 0.05).ceil().clamp(1, 20);
  }
}

