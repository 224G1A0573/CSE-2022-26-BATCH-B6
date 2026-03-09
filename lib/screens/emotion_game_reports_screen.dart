import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EmotionGameReportsScreen extends StatelessWidget {
  final String? childId;
  final String? childName;
  final bool isParentView;
  final bool hideAppBar;

  const EmotionGameReportsScreen({
    super.key,
    this.childId,
    this.childName,
    this.isParentView = false,
    this.hideAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final targetUserId = childId ?? user?.uid ?? '';

    Widget content = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B9D), Color(0xFFFFB6B9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .collection('emotionGameReports')
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_emotions_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Reports Yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Emotion game quiz reports will appear here once the child completes quizzes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final reports = snapshot.data!.docs;
            final allReportsData = reports.map((doc) => doc.data() as Map<String, dynamic>).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Statistics Card
                  _buildOverallStatsCard(allReportsData),
                  const SizedBox(height: 16),

                  // Recent Reports Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Quiz Sessions',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Individual Report Cards
                  ...reports.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildReportCard(context, data, doc.id);
                  }).toList(),
                ],
              ),
            );
          },
        ),
      );

    if (hideAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isParentView && childName != null
              ? '$childName\'s Emotion Reports'
              : 'Emotion Game Reports',
        ),
        backgroundColor: const Color(0xFFFF6B9D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: content,
    );
  }

  Widget _buildOverallStatsCard(List<Map<String, dynamic>> allReports) {
    if (allReports.isEmpty) return const SizedBox.shrink();

    // Calculate overall statistics
    final totalQuizzes = allReports.length;
    final totalQuestions = allReports.fold<int>(
      0,
      (sum, report) => sum + (report['totalQuestions'] as int? ?? 0),
    );
    final totalCorrect = allReports.fold<int>(
      0,
      (sum, report) => sum + (report['score'] as int? ?? 0),
    );
    final overallAccuracy = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0.0;

    // Calculate emotion-specific stats
    final emotionStats = <String, Map<String, int>>{};
    for (final emotion in ['happy', 'angry', 'sad', 'confused']) {
      int total = 0;
      int correct = 0;
      for (final report in allReports) {
        final stats = report['emotionStats'] as Map<String, dynamic>?;
        if (stats != null && stats[emotion] != null) {
          final emotionData = stats[emotion] as Map<String, dynamic>;
          total += emotionData['totalQuestions'] as int? ?? 0;
          correct += emotionData['correctAnswers'] as int? ?? 0;
        }
      }
      emotionStats[emotion] = {'total': total, 'correct': correct};
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B9D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Color(0xFFFF6B9D),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Statistics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B9D),
                      ),
                    ),
                    Text(
                      '$totalQuizzes ${totalQuizzes == 1 ? 'quiz' : 'quizzes'} completed',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Overall Accuracy
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Overall Accuracy',
                '${overallAccuracy.toStringAsFixed(1)}%',
                Icons.trending_up,
                const Color(0xFF4ECDC4),
              ),
              _buildStatItem(
                'Total Questions',
                '$totalQuestions',
                Icons.quiz,
                const Color(0xFF9B59B6),
              ),
              _buildStatItem(
                'Correct Answers',
                '$totalCorrect',
                Icons.check_circle,
                const Color(0xFF2ECC71),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          // Emotion-specific stats
          const Text(
            'Emotion Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6B9D),
            ),
          ),
          const SizedBox(height: 12),
          ...emotionStats.entries.map((entry) {
            final emotion = entry.key;
            final stats = entry.value;
            final accuracy = stats['total']! > 0
                ? (stats['correct']! / stats['total']!) * 100
                : 0.0;
            return _buildEmotionStatRow(emotion, stats['total']!, stats['correct']!, accuracy);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionStatRow(String emotion, int total, int correct, double accuracy) {
    final emotionColors = {
      'happy': const Color(0xFFFFD700),
      'angry': const Color(0xFFE74C3C),
      'sad': const Color(0xFF3498DB),
      'confused': const Color(0xFF9B59B6),
    };
    final color = emotionColors[emotion] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                emotion.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emotion.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: accuracy / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${accuracy.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($correct/$total)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> data, String reportId) {
    final score = data['score'] as int? ?? 0;
    final totalQuestions = data['totalQuestions'] as int? ?? 10;
    final accuracy = data['accuracy'] as double? ?? 0.0;
    final quizDuration = data['quizDurationSeconds'] as int? ?? 0;
    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
    final answers = data['answers'] as List<dynamic>? ?? [];
    final emotionStats = data['emotionStats'] as Map<String, dynamic>? ?? {};

    final percentage = (accuracy * 100).round();
    Color scoreColor;
    IconData scoreIcon;
    String scoreText;

    if (percentage >= 90) {
      scoreColor = const Color(0xFF2ECC71);
      scoreIcon = Icons.star;
      scoreText = 'Excellent!';
    } else if (percentage >= 70) {
      scoreColor = const Color(0xFF4ECDC4);
      scoreIcon = Icons.thumb_up;
      scoreText = 'Great Job!';
    } else if (percentage >= 50) {
      scoreColor = const Color(0xFFFFD700);
      scoreIcon = Icons.sentiment_satisfied;
      scoreText = 'Good Try!';
    } else {
      scoreColor = const Color(0xFFFF6B9D);
      scoreIcon = Icons.sentiment_neutral;
      scoreText = 'Keep Practicing!';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showReportDetails(context, data, reportId),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(scoreIcon, color: scoreColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz Session',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (completedAt != null)
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(completedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$score/$totalQuestions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Score and Accuracy
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('Accuracy', '${percentage}%', scoreColor),
                  _buildMiniStat('Duration', '${(quizDuration / 60).toStringAsFixed(1)} min', Colors.blue),
                  _buildMiniStat('Status', scoreText, scoreColor),
                ],
              ),
              const SizedBox(height: 16),
              // Emotion Breakdown
              if (emotionStats.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Emotion Breakdown',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B9D),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: emotionStats.entries.map((entry) {
                    final emotion = entry.key;
                    final stats = entry.value as Map<String, dynamic>;
                    final emotionTotal = stats['totalQuestions'] as int? ?? 0;
                    final emotionCorrect = stats['correctAnswers'] as int? ?? 0;
                    final emotionAccuracy = stats['accuracy'] as double? ?? 0.0;

                    final emotionColors = {
                      'happy': const Color(0xFFFFD700),
                      'angry': const Color(0xFFE74C3C),
                      'sad': const Color(0xFF3498DB),
                      'confused': const Color(0xFF9B59B6),
                    };
                    final color = emotionColors[emotion] ?? Colors.grey;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            emotion.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(emotionAccuracy * 100).round()}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              // Tap to view details
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to view details →',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showReportDetails(BuildContext context, Map<String, dynamic> data, String reportId) {
    final score = data['score'] as int? ?? 0;
    final totalQuestions = data['totalQuestions'] as int? ?? 10;
    final accuracy = data['accuracy'] as double? ?? 0.0;
    final quizDuration = data['quizDurationSeconds'] as int? ?? 0;
    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
    final answers = data['answers'] as List<dynamic>? ?? [];
    final emotionStats = data['emotionStats'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B9D),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_emotions, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Quiz Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary
                      _buildDetailSection(
                        'Summary',
                        [
                          _buildDetailRow('Score', '$score / $totalQuestions'),
                          _buildDetailRow('Accuracy', '${(accuracy * 100).toStringAsFixed(1)}%'),
                          _buildDetailRow('Duration', '${(quizDuration / 60).toStringAsFixed(1)} minutes'),
                          if (completedAt != null)
                            _buildDetailRow('Completed', DateFormat('MMM dd, yyyy • hh:mm a').format(completedAt)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Emotion Stats
                      if (emotionStats.isNotEmpty) ...[
                        _buildDetailSection(
                          'Emotion Performance',
                          emotionStats.entries.map((entry) {
                            final emotion = entry.key;
                            final stats = entry.value as Map<String, dynamic>;
                            final emotionTotal = stats['totalQuestions'] as int? ?? 0;
                            final emotionCorrect = stats['correctAnswers'] as int? ?? 0;
                            final emotionAccuracy = stats['accuracy'] as double? ?? 0.0;
                            return _buildDetailRow(
                              emotion.toUpperCase(),
                              '${emotionCorrect}/${emotionTotal} (${(emotionAccuracy * 100).toStringAsFixed(0)}%)',
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Question-by-Question Breakdown
                      if (answers.isNotEmpty) ...[
                        const Text(
                          'Question Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B9D),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...answers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final answer = entry.value as Map<String, dynamic>;
                          final correctEmotion = answer['correctEmotion'] as String? ?? '';
                          final selectedEmotion = answer['selectedEmotion'] as String? ?? '';
                          final isCorrect = answer['isCorrect'] as bool? ?? false;
                          return _buildQuestionCard(index + 1, correctEmotion, selectedEmotion, isCorrect);
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B9D),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int questionNum, String correctEmotion, String selectedEmotion, bool isCorrect) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green[300]! : Colors.red[300]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCorrect ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                isCorrect ? Icons.check : Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question $questionNum',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Correct: ${correctEmotion.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'Selected: ${selectedEmotion.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

