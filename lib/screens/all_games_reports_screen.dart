import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'emotion_game_reports_screen.dart';

class AllGamesReportsScreen extends StatelessWidget {
  final String? childId;
  final String? childName;
  final bool isParentView;

  const AllGamesReportsScreen({
    super.key,
    this.childId,
    this.childName,
    this.isParentView = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final targetUserId = childId ?? user?.uid ?? '';

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isParentView && childName != null
                ? '$childName\'s Game Reports'
                : 'All Game Reports',
          ),
          backgroundColor: const Color(0xFFFF6B9D),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabs: const [
              Tab(text: 'All', icon: Icon(Icons.dashboard)),
              Tab(text: 'Emotion', icon: Icon(Icons.sentiment_satisfied)),
              Tab(text: 'Social', icon: Icon(Icons.people)),
              Tab(text: 'Eyes', icon: Icon(Icons.visibility)),
              Tab(text: 'Repeat', icon: Icon(Icons.memory)),
              Tab(text: 'Tetris', icon: Icon(Icons.grid_4x4)),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6B9D), Color(0xFFFFB6B9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: TabBarView(
            children: [
              _buildAllGamesTab(context, targetUserId),
              // Emotion tab - use the detailed emotion game reports screen
              EmotionGameReportsScreen(
                childId: childId,
                childName: childName,
                isParentView: isParentView,
                hideAppBar: true, // Hide AppBar when used in tabs
              ),
              _buildGameTypeTab(context, targetUserId, 'social_skills_training'),
              _buildGameTypeTab(context, targetUserId, 'eyes_game'),
              _buildGameTypeTab(context, targetUserId, 'repeat_game'),
              _buildGameTypeTab(context, targetUserId, 'tetris_game'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllGamesTab(BuildContext context, String targetUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('gameReports')
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
          return _buildEmptyState('No game reports yet');
        }

        final reports = snapshot.data!.docs;
        final allReportsData = reports.map((doc) => doc.data() as Map<String, dynamic>).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverallStatsCard(allReportsData),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'All Game Sessions',
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
              // Display all game reports including emotion games
              ...reports.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildGameReportCard(context, data, doc.id);
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameTypeTab(BuildContext context, String targetUserId, String gameType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('gameReports')
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
          return _buildEmptyState('No ${_getGameName(gameType)} reports yet');
        }

        // Filter by game type and sort in memory
        final allReports = snapshot.data!.docs;
        final filteredReports = allReports.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['gameType'] == gameType;
        }).toList();
        
        if (filteredReports.isEmpty) {
          return _buildEmptyState('No ${_getGameName(gameType)} reports yet');
        }
        
        // Already sorted by completedAt descending from query
        final gameReportsData = filteredReports.map((doc) => doc.data() as Map<String, dynamic>).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGameTypeStatsCard(gameReportsData, gameType),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${_getGameName(gameType)} Sessions',
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
              ...filteredReports.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildGameReportCard(context, data, doc.id);
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
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
              Icons.sports_esports_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatsCard(List<Map<String, dynamic>> allReports) {
    if (allReports.isEmpty) return const SizedBox.shrink();

    final totalSessions = allReports.length;
    final gameTypeCounts = <String, int>{};
    for (final report in allReports) {
      final gameType = report['gameType'] as String? ?? 'unknown';
      gameTypeCounts[gameType] = (gameTypeCounts[gameType] ?? 0) + 1;
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
                      '$totalSessions total ${totalSessions == 1 ? 'session' : 'sessions'}',
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
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: gameTypeCounts.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _getGameColor(entry.key).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getGameColor(entry.key).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getGameIcon(entry.key),
                      color: _getGameColor(entry.key),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_getGameName(entry.key)}: ${entry.value}',
                      style: TextStyle(
                        color: _getGameColor(entry.key),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGameTypeStatsCard(List<Map<String, dynamic>> reports, String gameType) {
    if (reports.isEmpty) return const SizedBox.shrink();

    final gameName = _getGameName(gameType);
    final gameColor = _getGameColor(gameType);
    final gameIcon = _getGameIcon(gameType);

    // Calculate stats based on game type
    String? statText;
    if (gameType == 'eyes_game') {
      final totalBreathing = reports.fold<int>(
        0,
        (sum, r) => sum + (r['breathingSessions'] as int? ?? 0),
      );
      final totalDuration = reports.fold<int>(
        0,
        (sum, r) => sum + (r['totalBreathingDurationSeconds'] as int? ?? 0),
      );
      statText = '$totalBreathing sessions • ${(totalDuration / 60).toStringAsFixed(1)} min';
    } else if (gameType == 'emotion_character_quiz') {
      final totalQuizzes = reports.length;
      final totalQuestions = reports.fold<int>(
        0,
        (sum, r) => sum + (r['totalQuestions'] as int? ?? 0),
      );
      final totalCorrect = reports.fold<int>(
        0,
        (sum, r) => sum + (r['score'] as int? ?? 0),
      );
      final avgAccuracy = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0.0;
      statText = '$totalQuizzes quizzes • ${avgAccuracy.toStringAsFixed(0)}% avg';
    } else if (gameType == 'social_skills_training') {
      final totalSessions = reports.length;
      final totalRounds = reports.fold<int>(
        0,
        (sum, r) => sum + (r['totalRounds'] as int? ?? 0),
      );
      final totalScore = reports.fold<int>(
        0,
        (sum, r) => sum + (r['totalScore'] as int? ?? 0),
      );
      final avgAccuracy = totalRounds > 0 ? (totalScore / totalRounds) * 100 : 0.0;
      statText = '$totalSessions sessions • ${avgAccuracy.toStringAsFixed(0)}% avg';
    } else if (gameType == 'repeat_game' || gameType == 'tetris_game') {
      final bestScore = reports.fold<int>(
        0,
        (sum, r) => math.max(sum, r['score'] as int? ?? 0),
      );
      final avgScore = reports.fold<int>(0, (sum, r) => sum + (r['score'] as int? ?? 0)) /
          reports.length;
      statText = 'Best: $bestScore • Avg: ${avgScore.toStringAsFixed(0)}';
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gameColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(gameIcon, color: gameColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gameName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: gameColor,
                  ),
                ),
                if (statText != null)
                  Text(
                    statText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${reports.length}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: gameColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameReportCard(BuildContext context, Map<String, dynamic> data, String reportId) {
    final gameType = data['gameType'] as String? ?? 'unknown';
    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
    final gameColor = _getGameColor(gameType);
    final gameIcon = _getGameIcon(gameType);
    String gameName = _getGameName(gameType);
    
    // For social skills training, show the primary module
    if (gameType == 'social_skills_training') {
      final primaryModule = data['primaryModule'] as String?;
      if (primaryModule != null && primaryModule != 'Mixed Session') {
        gameName = primaryModule;
      }
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
        onTap: () => _showReportDetails(context, data, gameType),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: gameColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(gameIcon, color: gameColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gameName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (gameType == 'social_skills_training')
                          Text(
                            'Social Skills Training',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
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
                  _buildGameTypeScore(data, gameType, gameColor),
                ],
              ),
              const SizedBox(height: 12),
              _buildGameTypeDetails(data, gameType),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTypeScore(Map<String, dynamic> data, String gameType, Color color) {
    if (gameType == 'eyes_game') {
      final focusCounter = data['focusCounter'] as int? ?? 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Focus: $focusCounter',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      );
    } else if (gameType == 'emotion_character_quiz') {
      final score = data['score'] as int? ?? 0;
      final totalQuestions = data['totalQuestions'] as int? ?? 10;
      final accuracy = data['accuracy'] as double? ?? 0.0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$score/$totalQuestions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      );
    } else if (gameType == 'social_skills_training') {
      final totalScore = data['totalScore'] as int? ?? 0;
      final totalRounds = data['totalRounds'] as int? ?? 0;
      final accuracy = data['accuracy'] as double? ?? 0.0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${(accuracy * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      );
    } else {
      final score = data['score'] as int? ?? 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Score: $score',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      );
    }
  }

  Widget _buildGameTypeDetails(Map<String, dynamic> data, String gameType) {
    if (gameType == 'emotion_character_quiz') {
      final score = data['score'] as int? ?? 0;
      final totalQuestions = data['totalQuestions'] as int? ?? 10;
      final accuracy = data['accuracy'] as double? ?? 0.0;
      final duration = data['quizDurationSeconds'] as int? ?? 0;
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildDetailChip('Accuracy', '${(accuracy * 100).toStringAsFixed(0)}%', Colors.purple),
          _buildDetailChip('Duration', '${(duration / 60).toStringAsFixed(1)} min', Colors.blue),
          _buildDetailChip('Questions', '$totalQuestions', Colors.green),
        ],
      );
    } else if (gameType == 'eyes_game') {
      final duration = data['sessionDurationSeconds'] as int? ?? 0;
      final breathingSessions = data['breathingSessions'] as int? ?? 0;
      final breathingDuration = data['totalBreathingDurationSeconds'] as int? ?? 0;
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildDetailChip('Duration', '${(duration / 60).toStringAsFixed(1)} min', Colors.blue),
          _buildDetailChip('Breathing', '$breathingSessions sessions', Colors.green),
          if (breathingDuration > 0)
            _buildDetailChip('Breath Time', '${(breathingDuration / 60).toStringAsFixed(1)} min', Colors.purple),
        ],
      );
    } else if (gameType == 'social_skills_training') {
      final totalScore = data['totalScore'] as int? ?? 0;
      final totalRounds = data['totalRounds'] as int? ?? 0;
      final accuracy = data['accuracy'] as double? ?? 0.0;
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildDetailChip('Accuracy', '${(accuracy * 100).toStringAsFixed(0)}%', Colors.purple),
          _buildDetailChip('Score', '$totalScore/$totalRounds', Colors.blue),
        ],
      );
    } else if (gameType == 'repeat_game') {
      final round = data['round'] as int? ?? 0;
      return _buildDetailChip('Round', '$round', Colors.orange);
    } else if (gameType == 'tetris_game') {
      final level = data['level'] as int? ?? 0;
      final lines = data['linesCleared'] as int? ?? 0;
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildDetailChip('Level', '$level', Colors.blue),
          _buildDetailChip('Lines', '$lines', Colors.green),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showReportDetails(BuildContext context, Map<String, dynamic> data, String gameType) {
    if (gameType == 'emotion_character_quiz') {
      // Navigate to emotion game reports screen for detailed view
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmotionGameReportsScreen(
            childId: childId,
            childName: childName,
            isParentView: isParentView,
          ),
        ),
      );
      return;
    }

    if (gameType == 'social_skills_training') {
      _showSocialSkillsDetails(context, data);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getGameColor(gameType),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_getGameIcon(gameType), color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_getGameName(gameType)} Details',
                        style: const TextStyle(
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildGameTypeDetailContent(data, gameType),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTypeDetailContent(Map<String, dynamic> data, String gameType) {
    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
    final gameColor = _getGameColor(gameType);

    if (gameType == 'emotion_character_quiz') {
      final score = data['score'] as int? ?? 0;
      final totalQuestions = data['totalQuestions'] as int? ?? 10;
      final accuracy = data['accuracy'] as double? ?? 0.0;
      final duration = data['quizDurationSeconds'] as int? ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Score', '$score / $totalQuestions', gameColor),
          _buildDetailRow('Accuracy', '${(accuracy * 100).toStringAsFixed(1)}%', gameColor),
          _buildDetailRow('Duration', '${(duration / 60).toStringAsFixed(1)} minutes', gameColor),
          if (completedAt != null)
            _buildDetailRow('Completed', DateFormat('MMM dd, yyyy • hh:mm a').format(completedAt), gameColor),
        ],
      );
    } else if (gameType == 'eyes_game') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Session Duration', '${((data['sessionDurationSeconds'] as int? ?? 0) / 60).toStringAsFixed(1)} minutes', gameColor),
          _buildDetailRow('Focus Counter', '${data['focusCounter'] ?? 0}', gameColor),
          _buildDetailRow('Breathing Sessions', '${data['breathingSessions'] ?? 0}', gameColor),
          _buildDetailRow('Breathing Duration', '${((data['totalBreathingDurationSeconds'] as int? ?? 0) / 60).toStringAsFixed(1)} minutes', gameColor),
          if (completedAt != null)
            _buildDetailRow('Completed', DateFormat('MMM dd, yyyy • hh:mm a').format(completedAt), gameColor),
        ],
      );
    } else if (gameType == 'repeat_game') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Score', '${data['score'] ?? 0}', gameColor),
          _buildDetailRow('Round', '${data['round'] ?? 0}', gameColor),
          _buildDetailRow('Best Score', '${data['bestScore'] ?? 0}', gameColor),
          if (completedAt != null)
            _buildDetailRow('Completed', DateFormat('MMM dd, yyyy • hh:mm a').format(completedAt), gameColor),
        ],
      );
    } else if (gameType == 'social_skills_training') {
      final totalScore = data['totalScore'] as int? ?? 0;
      final totalRounds = data['totalRounds'] as int? ?? 0;
      final accuracy = data['accuracy'] as double? ?? 0.0;
      final duration = data['sessionDurationSeconds'] as int? ?? 0;
      final conversationScore = data['conversationScore'] as int? ?? 0;
      final conversationRounds = data['conversationRounds'] as int? ?? 0;
      final turnTakingScore = data['turnTakingScore'] as int? ?? 0;
      final turnTakingRounds = data['turnTakingRounds'] as int? ?? 0;
      final emotionScore = data['emotionRecognitionScore'] as int? ?? 0;
      final emotionRounds = data['emotionRecognitionRounds'] as int? ?? 0;
      final eyeContactScore = data['eyeContactScore'] as int? ?? 0;
      final eyeContactRounds = data['eyeContactRounds'] as int? ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Total Score', '$totalScore / $totalRounds', gameColor),
          _buildDetailRow('Overall Accuracy', '${(accuracy * 100).toStringAsFixed(1)}%', gameColor),
          _buildDetailRow('Duration', '${(duration / 60).toStringAsFixed(1)} minutes', gameColor),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Module Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B73FF),
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Conversation', '$conversationScore / $conversationRounds', const Color(0xFF4ECDC4)),
          _buildDetailRow('Turn-Taking', '$turnTakingScore / $turnTakingRounds', const Color(0xFFFF6B9D)),
          _buildDetailRow('Emotion Recognition', '$emotionScore / $emotionRounds', const Color(0xFFFFE66D)),
          _buildDetailRow('Eye Contact', '$eyeContactScore / $eyeContactRounds', const Color(0xFF95E1D3)),
          if (completedAt != null)
            _buildDetailRow('Completed', DateFormat('MMM dd, yyyy • hh:mm a').format(completedAt), gameColor),
        ],
      );
    } else if (gameType == 'tetris_game') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Score', '${data['score'] ?? 0}', gameColor),
          _buildDetailRow('Level', '${data['level'] ?? 0}', gameColor),
          _buildDetailRow('Lines Cleared', '${data['linesCleared'] ?? 0}', gameColor),
          _buildDetailRow('Best Score', '${data['bestScore'] ?? 0}', gameColor),
          if (completedAt != null)
            _buildDetailRow('Completed', DateFormat('MMM dd, yyyy • hh:mm a').format(completedAt), gameColor),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getGameName(String gameType) {
    switch (gameType) {
      case 'eyes_game':
        return 'Eyes Game';
      case 'repeat_game':
        return 'Repeat Game';
      case 'tetris_game':
        return 'Tetris';
      case 'emotion_character_quiz':
        return 'Emotion Friend';
      case 'social_skills_training':
        return 'Social Skills Training';
      default:
        return 'Unknown Game';
    }
  }

  Color _getGameColor(String gameType) {
    switch (gameType) {
      case 'eyes_game':
        return const Color(0xFF4ECDC4);
      case 'repeat_game':
        return const Color(0xFFFFE66D);
      case 'tetris_game':
        return const Color(0xFF95E1D3);
      case 'emotion_character_quiz':
        return const Color(0xFF9B59B6);
      case 'social_skills_training':
        return const Color(0xFF6B73FF);
      default:
        return Colors.grey;
    }
  }

  IconData _getGameIcon(String gameType) {
    switch (gameType) {
      case 'eyes_game':
        return Icons.visibility;
      case 'repeat_game':
        return Icons.memory;
      case 'tetris_game':
        return Icons.grid_4x4;
      case 'emotion_character_quiz':
        return Icons.sentiment_satisfied;
      case 'social_skills_training':
        return Icons.people;
      default:
        return Icons.sports_esports;
    }
  }

  void _showSocialSkillsDetails(BuildContext context, Map<String, dynamic> data) {
    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
    final totalScore = data['totalScore'] as int? ?? 0;
    final totalRounds = data['totalRounds'] as int? ?? 0;
    final accuracy = data['accuracy'] as double? ?? 0.0;
    final duration = data['sessionDurationSeconds'] as int? ?? 0;
    final conversationScore = data['conversationScore'] as int? ?? 0;
    final conversationRounds = data['conversationRounds'] as int? ?? 0;
    final turnTakingScore = data['turnTakingScore'] as int? ?? 0;
    final turnTakingRounds = data['turnTakingRounds'] as int? ?? 0;
    final emotionScore = data['emotionRecognitionScore'] as int? ?? 0;
    final emotionRounds = data['emotionRecognitionRounds'] as int? ?? 0;
    final eyeContactScore = data['eyeContactScore'] as int? ?? 0;
    final eyeContactRounds = data['eyeContactRounds'] as int? ?? 0;

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
                  color: const Color(0xFF6B73FF),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Social Skills Training Details',
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
                      _buildDetailRow('Total Score', '$totalScore / $totalRounds', const Color(0xFF6B73FF)),
                      _buildDetailRow('Overall Accuracy', '${(accuracy * 100).toStringAsFixed(1)}%', const Color(0xFF6B73FF)),
                      _buildDetailRow('Session Duration', '${(duration / 60).toStringAsFixed(1)} minutes', const Color(0xFF6B73FF)),
                      if (completedAt != null)
                        _buildDetailRow('Completed', DateFormat('MMM dd, yyyy • hh:mm a').format(completedAt), const Color(0xFF6B73FF)),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                      const Text(
                        'Module Performance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B73FF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Conversation Practice', '$conversationScore / $conversationRounds', const Color(0xFF4ECDC4)),
                      _buildDetailRow('Turn-Taking Game', '$turnTakingScore / $turnTakingRounds', const Color(0xFFFF6B9D)),
                      _buildDetailRow('Emotion Recognition', '$emotionScore / $emotionRounds', const Color(0xFFFFE66D)),
                      _buildDetailRow('Eye Contact Practice', '$eyeContactScore / $eyeContactRounds', const Color(0xFF95E1D3)),
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
}

