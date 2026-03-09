import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

/// Predictive analytics service for progress forecasting
class PredictiveAnalyticsService {
  static final PredictiveAnalyticsService _instance = PredictiveAnalyticsService._internal();
  factory PredictiveAnalyticsService() => _instance;
  PredictiveAnalyticsService._internal();

  /// Get comprehensive progress predictions
  Future<Map<String, dynamic>> getProgressPredictions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return _getEmptyPredictions();

      // Get all social skills training reports
      final reports = await _getAllReports(user.uid);
      
      if (reports.isEmpty) {
        return _getEmptyPredictions();
      }

      // Analyze trends for each module
      final conversationPrediction = _predictModuleProgress(reports, 'conversation');
      final turnTakingPrediction = _predictModuleProgress(reports, 'turnTaking');
      final emotionPrediction = _predictModuleProgress(reports, 'emotionRecognition');
      final eyeContactPrediction = _predictModuleProgress(reports, 'eyeContact');

      // Overall progress prediction
      final overallProgress = _predictOverallProgress(reports);

      // Identify areas needing attention
      final areasNeedingAttention = _identifyWeakAreas(reports);

      // Calculate recommended practice schedule
      final practiceSchedule = _calculatePracticeSchedule(reports);

      return {
        'overall': overallProgress,
        'modules': {
          'conversation': conversationPrediction,
          'turnTaking': turnTakingPrediction,
          'emotionRecognition': emotionPrediction,
          'eyeContact': eyeContactPrediction,
        },
        'areasNeedingAttention': areasNeedingAttention,
        'recommendedSchedule': practiceSchedule,
        'confidence': _calculateConfidence(reports),
      };
    } catch (e) {
      print('Error getting progress predictions: $e');
      return _getEmptyPredictions();
    }
  }

  /// Get all social skills training reports
  Future<List<Map<String, dynamic>>> _getAllReports(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('gameReports')
          .where('gameType', isEqualTo: 'social_skills_training')
          .orderBy('completedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting reports: $e');
      return [];
    }
  }

  /// Predict progress for a specific module
  Map<String, dynamic> _predictModuleProgress(
    List<Map<String, dynamic>> reports,
    String module,
  ) {
    // Extract module scores over time
    final scores = <double>[];
    final timestamps = <DateTime>[];

    for (final report in reports.reversed) {
      double? score;
      switch (module) {
        case 'conversation':
          final s = report['conversationScore'] as int? ?? 0;
          final r = report['conversationRounds'] as int? ?? 1;
          score = r > 0 ? s / r : 0.0;
          break;
        case 'turnTaking':
          final s = report['turnTakingScore'] as int? ?? 0;
          final r = report['turnTakingRounds'] as int? ?? 1;
          score = r > 0 ? s / r : 0.0;
          break;
        case 'emotionRecognition':
          final s = report['emotionRecognitionScore'] as int? ?? 0;
          final r = report['emotionRecognitionRounds'] as int? ?? 1;
          score = r > 0 ? s / r : 0.0;
          break;
        case 'eyeContact':
          final s = report['eyeContactScore'] as int? ?? 0;
          final r = report['eyeContactRounds'] as int? ?? 1;
          score = r > 0 ? s / r : 0.0;
          break;
      }

      if (score != null) {
        scores.add(score);
        final timestamp = (report['completedAt'] as Timestamp?)?.toDate();
        if (timestamp != null) {
          timestamps.add(timestamp);
        }
      }
    }

    if (scores.isEmpty) {
      return {
        'currentScore': 0.5,
        'predictedScore7Days': 0.5,
        'predictedScore30Days': 0.5,
        'trend': 'stable',
        'improvementRate': 0.0,
      };
    }

    // Calculate current score
    final currentScore = scores.last;

    // Calculate trend using linear regression
    final trend = _calculateTrend(scores, timestamps);

    // Predict future scores
    final predicted7Days = _predictScore(scores, timestamps, daysAhead: 7);
    final predicted30Days = _predictScore(scores, timestamps, daysAhead: 30);

    // Calculate improvement rate
    final improvementRate = scores.length >= 2
        ? (scores.last - scores.first) / scores.length
        : 0.0;

    return {
      'currentScore': currentScore,
      'predictedScore7Days': predicted7Days.clamp(0.0, 1.0),
      'predictedScore30Days': predicted30Days.clamp(0.0, 1.0),
      'trend': trend,
      'improvementRate': improvementRate,
      'sessionsToMastery': _calculateSessionsToMastery(currentScore, improvementRate),
    };
  }

  /// Calculate trend using linear regression
  String _calculateTrend(List<double> scores, List<DateTime> timestamps) {
    if (scores.length < 3) return 'stable';

    // Simple linear regression
    final n = scores.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = scores[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

    if (slope > 0.01) {
      return 'improving';
    } else if (slope < -0.01) {
      return 'declining';
    } else {
      return 'stable';
    }
  }

  /// Predict score N days ahead
  double _predictScore(List<double> scores, List<DateTime> timestamps, {required int daysAhead}) {
    if (scores.isEmpty) return 0.5;
    if (scores.length == 1) return scores.first;

    // Simple linear extrapolation
    final recentScores = scores.length >= 3 ? scores.sublist(scores.length - 3) : scores;
    final avgRecent = recentScores.reduce((a, b) => a + b) / recentScores.length;

    // Estimate daily improvement rate
    double dailyImprovement = 0.0;
    if (scores.length >= 2 && timestamps.length >= 2) {
      final timeDiff = timestamps.last.difference(timestamps.first).inDays;
      if (timeDiff > 0) {
        dailyImprovement = (scores.last - scores.first) / timeDiff;
      }
    }

    // Predict future score
    final predicted = avgRecent + (dailyImprovement * daysAhead);
    return predicted.clamp(0.0, 1.0);
  }

  /// Calculate sessions needed to reach mastery (80% accuracy)
  int _calculateSessionsToMastery(double currentScore, double improvementRate) {
    if (currentScore >= 0.8) return 0;
    if (improvementRate <= 0) return 999; // Not improving

    final gap = 0.8 - currentScore;
    return (gap / improvementRate).ceil().clamp(1, 100);
  }

  /// Predict overall progress
  Map<String, dynamic> _predictOverallProgress(List<Map<String, dynamic>> reports) {
    if (reports.isEmpty) {
      return {
        'currentAccuracy': 0.5,
        'predictedAccuracy7Days': 0.5,
        'predictedAccuracy30Days': 0.5,
        'overallTrend': 'stable',
      };
    }

    final accuracies = reports.map((r) => r['accuracy'] as double? ?? 0.0).toList();
    final currentAccuracy = accuracies.first; // Most recent

    // Calculate trend
    final trend = _calculateTrend(accuracies, 
        reports.map((r) => (r['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now()).toList());

    // Predict future accuracies
    final predicted7Days = _predictScore(accuracies, 
        reports.map((r) => (r['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now()).toList(),
        daysAhead: 7);
    final predicted30Days = _predictScore(accuracies,
        reports.map((r) => (r['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now()).toList(),
        daysAhead: 30);

    return {
      'currentAccuracy': currentAccuracy,
      'predictedAccuracy7Days': predicted7Days,
      'predictedAccuracy30Days': predicted30Days,
      'overallTrend': trend,
    };
  }

  /// Identify areas needing attention
  List<Map<String, dynamic>> _identifyWeakAreas(List<Map<String, dynamic>> reports) {
    final weakAreas = <Map<String, dynamic>>[];

    if (reports.isEmpty) return weakAreas;

    final recent = reports.take(5).toList();
    
    // Check each module
    final modules = ['conversation', 'turnTaking', 'emotionRecognition', 'eyeContact'];
    final moduleNames = {
      'conversation': 'Conversation Practice',
      'turnTaking': 'Turn-Taking Game',
      'emotionRecognition': 'Emotion Recognition',
      'eyeContact': 'Eye Contact Practice',
    };

    for (final module in modules) {
      double avgScore = 0.0;
      int count = 0;

      for (final report in recent) {
        double? score;
        switch (module) {
          case 'conversation':
            final s = report['conversationScore'] as int? ?? 0;
            final r = report['conversationRounds'] as int? ?? 1;
            score = r > 0 ? s / r : 0.0;
            break;
          case 'turnTaking':
            final s = report['turnTakingScore'] as int? ?? 0;
            final r = report['turnTakingRounds'] as int? ?? 1;
            score = r > 0 ? s / r : 0.0;
            break;
          case 'emotionRecognition':
            final s = report['emotionRecognitionScore'] as int? ?? 0;
            final r = report['emotionRecognitionRounds'] as int? ?? 1;
            score = r > 0 ? s / r : 0.0;
            break;
          case 'eyeContact':
            final s = report['eyeContactScore'] as int? ?? 0;
            final r = report['eyeContactRounds'] as int? ?? 1;
            score = r > 0 ? s / r : 0.0;
            break;
        }

        if (score != null) {
          avgScore += score;
          count++;
        }
      }

      if (count > 0) {
        avgScore /= count;
        if (avgScore < 0.6) {
          weakAreas.add({
            'module': moduleNames[module] ?? module,
            'currentScore': avgScore,
            'recommendation': _getRecommendation(module, avgScore),
          });
        }
      }
    }

    return weakAreas;
  }

  /// Get recommendation for improvement
  String _getRecommendation(String module, double score) {
    switch (module) {
      case 'conversation':
        return 'Practice more conversation scenarios. Try responding with complete sentences.';
      case 'turnTaking':
        return 'Focus on waiting for your turn. Practice with shorter sequences first.';
      case 'emotionRecognition':
        return 'Spend more time observing facial expressions. Practice identifying emotions slowly.';
      case 'eyeContact':
        return 'Practice maintaining eye contact for longer periods. Start with shorter durations.';
      default:
        return 'Keep practicing!';
    }
  }

  /// Calculate recommended practice schedule
  Map<String, dynamic> _calculatePracticeSchedule(List<Map<String, dynamic>> reports) {
    final weakAreas = _identifyWeakAreas(reports);
    
    return {
      'recommendedFrequency': weakAreas.length > 2 ? 'daily' : 'everyOtherDay',
      'recommendedDuration': '15-20 minutes',
      'focusAreas': weakAreas.map((a) => a['module']).toList(),
      'estimatedImprovement': '2-4 weeks for noticeable progress',
    };
  }

  /// Calculate prediction confidence
  double _calculateConfidence(List<Map<String, dynamic>> reports) {
    if (reports.length < 3) return 0.3;
    if (reports.length < 10) return 0.5;
    return 0.8; // High confidence with more data
  }

  /// Get empty predictions structure
  Map<String, dynamic> _getEmptyPredictions() {
    return {
      'overall': {
        'currentAccuracy': 0.5,
        'predictedAccuracy7Days': 0.5,
        'predictedAccuracy30Days': 0.5,
        'overallTrend': 'stable',
      },
      'modules': {},
      'areasNeedingAttention': [],
      'recommendedSchedule': {
        'recommendedFrequency': 'everyOtherDay',
        'recommendedDuration': '15-20 minutes',
        'focusAreas': [],
        'estimatedImprovement': '2-4 weeks',
      },
      'confidence': 0.3,
    };
  }
}

