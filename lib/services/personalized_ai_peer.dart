import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ai_conversation_service.dart';
import 'adaptive_difficulty_service.dart';

/// Personalized AI Virtual Peer that learns and adapts
class PersonalizedAIPeer {
  static final PersonalizedAIPeer _instance = PersonalizedAIPeer._internal();
  factory PersonalizedAIPeer() => _instance;
  PersonalizedAIPeer._internal();

  final AIConversationService _conversationService = AIConversationService();
  final AdaptiveDifficultyService _difficultyService = AdaptiveDifficultyService();

  // Peer personality and memory
  Map<String, dynamic>? _peerProfile;
  List<Map<String, dynamic>> _conversationMemory = [];
  Map<String, dynamic> _childPreferences = {};
  Map<String, double> _modulePerformance = {};

  /// Initialize personalized peer for a child
  Future<void> initializePeer({
    required String peerName,
    required String childId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load child's profile and preferences
      await _loadChildProfile(childId);
      
      // Load conversation history
      await _loadConversationHistory(childId);
      
      // Load performance data
      await _loadPerformanceData(childId);

      // Create personalized peer profile
      _peerProfile = {
        'name': peerName,
        'personality': _generatePersonality(),
        'communicationStyle': _determineCommunicationStyle(),
        'encouragementStyle': _determineEncouragementStyle(),
        'difficultyPreference': _determineDifficultyPreference(),
      };

      // Initialize AI conversation service
      await _conversationService.initialize();
    } catch (e) {
      print('Error initializing personalized peer: $e');
    }
  }

  /// Load child's profile
  Future<void> _loadChildProfile(String childId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        _childPreferences = {
          'age': data?['age'] ?? 8,
          'interests': data?['interests'] ?? [],
          'communicationLevel': data?['communicationLevel'] ?? 'moderate',
        };
      }
    } catch (e) {
      print('Error loading child profile: $e');
    }
  }

  /// Load conversation history
  Future<void> _loadConversationHistory(String childId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('socialSkillsConversations')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      _conversationMemory = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'childResponse': data['childResponse'],
          'peerResponse': data['peerResponse'],
          'timestamp': data['timestamp'],
        };
      }).toList();
    } catch (e) {
      print('Error loading conversation history: $e');
    }
  }

  /// Load performance data
  Future<void> _loadPerformanceData(String childId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('gameReports')
          .where('gameType', isEqualTo: 'social_skills_training')
          .orderBy('completedAt', descending: true)
          .limit(10)
          .get();

      final reports = snapshot.docs.map((doc) => doc.data()).toList();
      
      // Calculate average performance per module
      _modulePerformance = {
        'conversation': _calculateModuleAvg(reports, 'conversation'),
        'turnTaking': _calculateModuleAvg(reports, 'turnTaking'),
        'emotionRecognition': _calculateModuleAvg(reports, 'emotionRecognition'),
        'eyeContact': _calculateModuleAvg(reports, 'eyeContact'),
      };
    } catch (e) {
      print('Error loading performance data: $e');
    }
  }

  /// Calculate average performance for a module
  double _calculateModuleAvg(List<Map<String, dynamic>> reports, String module) {
    if (reports.isEmpty) return 0.5;

    double total = 0.0;
    int count = 0;

    for (final report in reports) {
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
        total += score;
        count++;
      }
    }

    return count > 0 ? total / count : 0.5;
  }

  /// Generate personalized personality
  Map<String, dynamic> _generatePersonality() {
    final age = _childPreferences['age'] as int? ?? 8;
    final communicationLevel = _childPreferences['communicationLevel'] as String? ?? 'moderate';

    // Adapt personality based on child's needs
    if (communicationLevel == 'low') {
      return {
        'patience': 'very_high',
        'simplicity': 'high',
        'encouragement': 'frequent',
        'pace': 'slow',
      };
    } else if (communicationLevel == 'high') {
      return {
        'patience': 'moderate',
        'simplicity': 'moderate',
        'encouragement': 'moderate',
        'pace': 'normal',
      };
    } else {
      return {
        'patience': 'high',
        'simplicity': 'moderate',
        'encouragement': 'frequent',
        'pace': 'moderate',
      };
    }
  }

  /// Determine communication style
  String _determineCommunicationStyle() {
    final avgPerformance = _modulePerformance.values.isEmpty
        ? 0.5
        : _modulePerformance.values.reduce((a, b) => a + b) / _modulePerformance.length;

    if (avgPerformance < 0.5) {
      return 'simple_and_clear';
    } else if (avgPerformance < 0.7) {
      return 'supportive_and_guided';
    } else {
      return 'engaging_and_challenging';
    }
  }

  /// Determine encouragement style
  String _determineEncouragementStyle() {
    // Analyze performance trends
    final weakModules = _modulePerformance.entries
        .where((e) => e.value < 0.6)
        .map((e) => e.key)
        .toList();

    if (weakModules.length > 2) {
      return 'very_supportive';
    } else if (weakModules.isNotEmpty) {
      return 'balanced';
    } else {
      return 'celebratory';
    }
  }

  /// Determine difficulty preference
  String _determineDifficultyPreference() {
    final avgPerformance = _modulePerformance.values.isEmpty
        ? 0.5
        : _modulePerformance.values.reduce((a, b) => a + b) / _modulePerformance.length;

    if (avgPerformance < 0.5) {
      return 'easy';
    } else if (avgPerformance < 0.7) {
      return 'moderate';
    } else {
      return 'challenging';
    }
  }

  /// Generate personalized conversation response
  Future<String> generatePersonalizedResponse({
    required String childResponse,
    required String context,
    required String scenario,
  }) async {
    if (_peerProfile == null) {
      return _conversationService.generatePeerResponse(
        peerName: 'Friend',
        childResponse: childResponse,
        context: context,
        scenario: scenario,
        age: _childPreferences['age'] as int? ?? 8,
      );
    }

    final peerName = _peerProfile!['name'] as String;
    final personality = _peerProfile!['personality'] as Map<String, dynamic>;
    final communicationStyle = _peerProfile!['communicationStyle'] as String;

    // Build personalized context
    final personalizedContext = '''
Child Age: ${_childPreferences['age']}
Communication Level: ${_childPreferences['communicationLevel']}
Personality: ${personality.toString()}
Communication Style: $communicationStyle
Previous Conversations: ${_conversationMemory.length} conversations
Performance: ${_modulePerformance.toString()}
''';

    // Generate AI response
    final response = await _conversationService.generatePeerResponse(
      peerName: peerName,
      childResponse: childResponse,
      context: personalizedContext,
      scenario: scenario,
      age: _childPreferences['age'] as int? ?? 8,
    );

    // Save to memory
    _saveConversationToMemory(childResponse, response);

    return response;
  }

  /// Save conversation to memory
  Future<void> _saveConversationToMemory(String childResponse, String peerResponse) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _conversationMemory.add({
        'childResponse': childResponse,
        'peerResponse': peerResponse,
        'timestamp': DateTime.now(),
      });

      // Keep only last 20 conversations in memory
      if (_conversationMemory.length > 20) {
        _conversationMemory.removeAt(0);
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('socialSkillsConversations')
          .add({
        'childResponse': childResponse,
        'peerResponse': peerResponse,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving conversation to memory: $e');
    }
  }

  /// Get personalized difficulty for a module
  Future<Map<String, dynamic>> getPersonalizedDifficulty(String module) async {
    return await _difficultyService.calculateOptimalDifficulty(module: module);
  }

  /// Get peer profile
  Map<String, dynamic>? get peerProfile => _peerProfile;

  /// Update preferences based on interaction
  void updatePreferences(Map<String, dynamic> newPreferences) {
    _childPreferences.addAll(newPreferences);
    // Regenerate personality if needed
    if (_peerProfile != null) {
      _peerProfile!['personality'] = _generatePersonality();
      _peerProfile!['communicationStyle'] = _determineCommunicationStyle();
    }
  }
}

