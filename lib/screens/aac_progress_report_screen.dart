import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class AACProgressReportScreen extends StatefulWidget {
  final String? childId;
  final String? childName;
  final bool isParentView;

  const AACProgressReportScreen({
    super.key,
    this.childId,
    this.childName,
    this.isParentView = false,
  });

  @override
  State<AACProgressReportScreen> createState() => _AACProgressReportScreenState();
}

class _AACProgressReportScreenState extends State<AACProgressReportScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String _selectedPeriod = 'all'; // all, week, month

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    final targetUserId = widget.childId ?? user?.uid ?? '';
    if (targetUserId.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      print('📊 AAC Progress: Loading analytics for user: $targetUserId');
      // Get all AAC analytics
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('aac_analytics')
          .orderBy('timestamp', descending: true)
          .get();
      
      print('📊 AAC Progress: Found ${snapshot.docs.length} documents');

      final now = DateTime.now();
      DateTime? startDate;
      DateTime? endDate;
      
      if (_selectedPeriod == 'week') {
        // Last 7 days, excluding today
        endDate = DateTime(now.year, now.month, now.day); // Start of today
        startDate = endDate.subtract(const Duration(days: 7));
      } else if (_selectedPeriod == 'month') {
        // Last 30 days, excluding today
        endDate = DateTime(now.year, now.month, now.day); // Start of today
        startDate = endDate.subtract(const Duration(days: 30));
      }

      final filteredDocs = startDate != null
          ? snapshot.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final timestamp = data['timestamp'] as Timestamp?;
              if (timestamp == null) return false;
              final docDate = timestamp.toDate();
              // Include dates that are after startDate and before endDate (exclude today)
              return docDate.isAfter(startDate!) && 
                     (endDate == null || docDate.isBefore(endDate));
            }).toList()
          : snapshot.docs;

      // Process analytics
      final analytics = <String, dynamic>{
        'totalSymbols': 0,
        'totalSentences': 0,
        'symbolUsage': <String, int>{},
        'categoryUsage': <String, int>{},
        'sentenceLengths': <int>[],
        'dailyUsage': <String, int>{},
        'quickPhrasesUsed': <String, int>{},
        'mostUsedSymbols': <Map<String, dynamic>>[],
        'averageWordsPerSentence': 0.0,
        'totalWords': 0,
        'firstUsage': null,
        'lastUsage': null,
      };

      for (final doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final type = data['type'] as String? ?? '';
        final timestamp = data['timestamp'] as Timestamp?;

        if (timestamp != null) {
          final date = timestamp.toDate();
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          analytics['dailyUsage'][dateKey] = (analytics['dailyUsage'][dateKey] ?? 0) + 1;

          if (analytics['firstUsage'] == null || date.isBefore(analytics['firstUsage'])) {
            analytics['firstUsage'] = date;
          }
          if (analytics['lastUsage'] == null || date.isAfter(analytics['lastUsage'])) {
            analytics['lastUsage'] = date;
          }
        }

        if (type == 'symbol_usage') {
          analytics['totalSymbols']++;
          final symbol = data['symbol'] as String? ?? '';
          final category = data['category'] as String? ?? '';

          if (symbol.isNotEmpty) {
            analytics['symbolUsage'][symbol] = (analytics['symbolUsage'][symbol] ?? 0) + 1;
          }
          if (category.isNotEmpty) {
            analytics['categoryUsage'][category] = (analytics['categoryUsage'][category] ?? 0) + 1;
          }
        } else if (type == 'sentence_usage') {
          analytics['totalSentences']++;
          final sentence = data['sentence'] as String? ?? '';
          final wordCount = data['word_count'] as int? ?? 0;

          if (wordCount > 0) {
            analytics['sentenceLengths'].add(wordCount);
            analytics['totalWords'] += wordCount;
          }

          // Check if it's a quick phrase
          final quickPhrases = [
            'I want water', 'I need help', 'I am hungry', 'I am tired',
            'I want to play', 'I need bathroom', 'I am happy', 'I am sad',
            'Thank you', 'I want more'
          ];
          if (quickPhrases.contains(sentence)) {
            analytics['quickPhrasesUsed'][sentence] = (analytics['quickPhrasesUsed'][sentence] ?? 0) + 1;
          }
        }
      }

      // Calculate most used symbols
      final symbolUsageMap = analytics['symbolUsage'] as Map<String, int>;
      final symbolEntries = symbolUsageMap.entries.toList()
        ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
      
      analytics['mostUsedSymbols'] = symbolEntries.take(10).map((entry) {
        return {
          'symbol': entry.key,
          'count': entry.value,
        };
      }).toList();

      // Calculate average words per sentence
      if (analytics['totalSentences'] > 0) {
        analytics['averageWordsPerSentence'] = 
            analytics['totalWords'] / analytics['totalSentences'];
      }

      print('📊 AAC Progress: Processed analytics - Symbols: ${analytics['totalSymbols']}, Sentences: ${analytics['totalSentences']}');
      
      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading AAC analytics: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isParentView && widget.childName != null
              ? '${widget.childName}\'s AAC Progress'
              : 'AAC Communication Progress',
        ),
        backgroundColor: const Color(0xFFFF6B9D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? const Center(child: Text('No data available'))
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6B9D), Color(0xFFFFB6B9)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Period selector
                      _buildPeriodSelector(),
                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Overview Cards
                              _buildOverviewCards(),
                              const SizedBox(height: 20),
                              // Most Used Symbols
                              _buildMostUsedSymbols(),
                              const SizedBox(height: 20),
                              // Category Usage
                              _buildCategoryUsage(),
                              const SizedBox(height: 20),
                              // Sentence Stats
                              _buildSentenceStats(),
                              const SizedBox(height: 20),
                              // Daily Usage Chart
                              _buildDailyUsageChart(),
                              const SizedBox(height: 20),
                              // Quick Phrases Usage
                              _buildQuickPhrasesUsage(),
                              const SizedBox(height: 20),
                              // Communication Timeline
                              _buildCommunicationTimeline(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white.withOpacity(0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPeriodButton('All Time', 'all'),
          const SizedBox(width: 12),
          _buildPeriodButton('Last Week', 'week'),
          const SizedBox(width: 12),
          _buildPeriodButton('Last Month', 'month'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
        _loadAnalytics();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFFFF6B9D) : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final totalSymbols = _analytics!['totalSymbols'] as int;
    final totalSentences = _analytics!['totalSentences'] as int;
    final avgWords = _analytics!['averageWordsPerSentence'] as double;
    final daysActive = _analytics!['firstUsage'] != null && _analytics!['lastUsage'] != null
        ? _analytics!['lastUsage'].difference(_analytics!['firstUsage']).inDays + 1
        : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Symbols',
            totalSymbols.toString(),
            Icons.touch_app,
            const Color(0xFF4ECDC4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Sentences Built',
            totalSentences.toString(),
            Icons.chat_bubble,
            const Color(0xFF6B73FF),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMostUsedSymbols() {
    final mostUsed = _analytics!['mostUsedSymbols'] as List<dynamic>;
    
    if (mostUsed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFFFE66D), size: 28),
              SizedBox(width: 8),
              Text(
                'Most Used Symbols',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...mostUsed.asMap().entries.map((entry) {
            final index = entry.key;
            final symbol = entry.value as Map<String, dynamic>;
            final symbolName = symbol['symbol'] as String;
            final count = symbol['count'] as int;
            final maxCount = mostUsed.isNotEmpty 
                ? (mostUsed.first as Map<String, dynamic>)['count'] as int
                : 1;
            final percentage = (count / maxCount * 100).clamp(0.0, 100.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _getColorForIndex(index),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
                          symbolName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getColorForIndex(index),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getColorForIndex(index),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryUsage() {
    final categoryUsage = _analytics!['categoryUsage'] as Map<String, int>;
    
    if (categoryUsage.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = categoryUsage.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    final maxCount = entries.isNotEmpty ? entries.first.value : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.category, color: Color(0xFF4ECDC4), size: 28),
              SizedBox(width: 8),
              Text(
                'Category Usage',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            final category = entry.key;
            final count = entry.value;
            final percentage = (count / maxCount * 100).clamp(0.0, 100.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getCategoryColor(category),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getCategoryColor(category),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSentenceStats() {
    final avgWords = _analytics!['averageWordsPerSentence'] as double;
    final sentenceLengths = _analytics!['sentenceLengths'] as List<int>;
    
    if (sentenceLengths.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxLength = sentenceLengths.isNotEmpty ? sentenceLengths.reduce(math.max) : 0;
    final minLength = sentenceLengths.isNotEmpty ? sentenceLengths.reduce(math.min) : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFF6B73FF), size: 28),
              SizedBox(width: 8),
              Text(
                'Sentence Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  'Average Words',
                  avgWords.toStringAsFixed(1),
                  Icons.trending_up,
                  const Color(0xFF4ECDC4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStatCard(
                  'Longest',
                  '$maxLength words',
                  Icons.arrow_upward,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStatCard(
                  'Shortest',
                  '$minLength words',
                  Icons.arrow_downward,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyUsageChart() {
    final dailyUsage = _analytics!['dailyUsage'] as Map<String, int>;
    
    if (dailyUsage.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = dailyUsage.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => a.key.compareTo(b.key));
    final maxUsage = entries.isNotEmpty 
        ? entries.map((e) => e.value).reduce(math.max)
        : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: Color(0xFFFF6B9D), size: 28),
              SizedBox(width: 8),
              Text(
                'Daily Usage',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140, // Reduced height to prevent overflow
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: entries.take(7).map((entry) {
                final date = DateTime.parse(entry.key);
                final dayLabel = DateFormat('E').format(date);
                final height = (entry.value / maxUsage * 100).clamp(10.0, 100.0); // Reduced max height
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Flexible(
                          child: Container(
                            height: height,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B9D), Color(0xFFFFB6B9)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dayLabel,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPhrasesUsage() {
    final quickPhrases = _analytics!['quickPhrasesUsed'] as Map<String, int>;
    
    if (quickPhrases.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = quickPhrases.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, color: Color(0xFFFFE66D), size: 28),
              SizedBox(width: 8),
              Text(
                'Quick Phrases Used',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFFFFE66D), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE66D).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '${entry.value}x',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFE66D),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommunicationTimeline() {
    final firstUsage = _analytics!['firstUsage'] as DateTime?;
    final lastUsage = _analytics!['lastUsage'] as DateTime?;
    final totalSymbols = _analytics!['totalSymbols'] as int;
    final totalSentences = _analytics!['totalSentences'] as int;

    if (firstUsage == null || lastUsage == null) {
      return const SizedBox.shrink();
    }

    final daysActive = lastUsage.difference(firstUsage).inDays + 1;
    final avgPerDay = daysActive > 0 ? (totalSymbols / daysActive).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, color: Color(0xFF6B73FF), size: 28),
              SizedBox(width: 8),
              Text(
                'Communication Timeline',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTimelineItem(
            'First Communication',
            DateFormat('MMM dd, yyyy').format(firstUsage),
            Icons.play_arrow,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildTimelineItem(
            'Last Communication',
            DateFormat('MMM dd, yyyy').format(lastUsage),
            Icons.update,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildTimelineItem(
            'Days Active',
            '$daysActive days',
            Icons.calendar_today,
            const Color(0xFFFF6B9D),
          ),
          const SizedBox(height: 12),
          _buildTimelineItem(
            'Average per Day',
            '$avgPerDay symbols',
            Icons.trending_up,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      const Color(0xFFFF6B9D),
      const Color(0xFF4ECDC4),
      const Color(0xFF6B73FF),
      const Color(0xFFFFE66D),
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.blue,
    ];
    return colors[index % colors.length];
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'common': const Color(0xFFFF6B9D),
      'food': Colors.orange,
      'actions': const Color(0xFF4ECDC4),
      'emotions': Colors.yellow,
      'places': Colors.green,
      'people': Colors.purple,
    };
    return colors[category] ?? Colors.grey;
  }
}

