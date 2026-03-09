import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'emotion_landmarks.dart';
import 'services/ai_conversation_service.dart';
import 'services/eye_contact_detector.dart';
import 'services/adaptive_difficulty_service.dart';
import 'services/emotion_mirroring_service.dart';
import 'services/predictive_analytics_service.dart';
import 'services/personalized_ai_peer.dart';

class SocialSkillsGame extends StatefulWidget {
  const SocialSkillsGame({super.key});

  @override
  State<SocialSkillsGame> createState() => _SocialSkillsGameState();
}

class _SocialSkillsGameState extends State<SocialSkillsGame>
    with TickerProviderStateMixin {
  // Game State
  String _gameMode = 'menu'; // menu, conversation, turnTaking, emotionRecognition, eyeContact
  String? _selectedPeer;
  int _score = 0;
  int _conversationRound = 0;
  int _turnTakingScore = 0;
  int _emotionRecognitionScore = 0;
  int _eyeContactScore = 0;
  
  // Virtual Peers
  final List<Map<String, dynamic>> _virtualPeers = [
    {
      'name': 'Alex',
      'avatar': '👦',
      'color': const Color(0xFF4ECDC4),
      'personality': 'Friendly and helpful',
      'age': '8 years old',
    },
    {
      'name': 'Maya',
      'avatar': '👧',
      'color': const Color(0xFFFF6B9D),
      'personality': 'Kind and patient',
      'age': '9 years old',
    },
    {
      'name': 'Sam',
      'avatar': '🧒',
      'color': const Color(0xFFFFE66D),
      'personality': 'Funny and energetic',
      'age': '7 years old',
    },
  ];

  // Conversation Scenarios (will be populated with selected peer name)
  List<Map<String, dynamic>> get _conversationScenarios {
    final peerName = _selectedPeer ?? 'Alex';
    return [
      {
        'id': 'greeting',
        'title': 'Saying Hello',
        'peerMessage': 'Hi! My name is $peerName. What\'s your name?',
        'options': ['Hi $peerName! I\'m [Your Name]', 'Hello', 'Nice to meet you!', 'Hi there!'],
        'correctIndex': 0,
        'hint': 'Try introducing yourself!',
      },
      {
        'id': 'sharing',
        'title': 'Sharing Interests',
        'peerMessage': 'I love playing with blocks! What do you like to do?',
        'options': ['I like drawing!', 'That\'s cool', 'I don\'t know', 'Me too!'],
        'correctIndex': 0,
        'hint': 'Share something you enjoy!',
      },
      {
        'id': 'asking',
        'title': 'Asking Questions',
        'peerMessage': 'I had pizza for lunch today!',
        'options': ['That sounds yummy!', 'Okay', 'I don\'t like pizza', 'What did you have?'],
        'correctIndex': 0,
        'hint': 'Show interest in what they said!',
      },
      {
        'id': 'compliment',
        'title': 'Giving Compliments',
        'peerMessage': 'I drew this picture of a rainbow!',
        'options': ['That\'s beautiful!', 'Nice', 'I can draw better', 'Cool'],
        'correctIndex': 0,
        'hint': 'Say something positive!',
      },
      {
        'id': 'helping',
        'title': 'Offering Help',
        'peerMessage': 'I can\'t find my pencil. I need it for my drawing.',
        'options': ['I can help you look!', 'That\'s too bad', 'I don\'t have one', 'Maybe it\'s lost'],
        'correctIndex': 0,
        'hint': 'Offer to help!',
      },
    ];
  }

  // Turn-Taking Game
  int _turnTakingRound = 0;
  List<String> _turnSequence = [];
  int _currentTurnIndex = 0;
  bool _isPlayerTurn = true;
  Timer? _turnTimer;

  // Emotion Recognition
  int _emotionRound = 0;
  String? _currentEmotion;
  List<String> _emotionOptions = [];
  bool _emotionAnswered = false;

  // Eye Contact Practice
  int _eyeContactRound = 0;
  bool _eyeContactActive = false;
  Timer? _eyeContactTimer;
  double _eyeContactDuration = 0.0;
  int _eyeContactTarget = 3; // seconds
  DateTime? _lastTapTime;
  bool _isHolding = false;
  
  // Emotion Character for Eye Contact
  ui.Image? _baseImage;
  String _currentExpression = 'happy';
  Offset _characterPosition = const Offset(0, 0);
  Timer? _characterMovementTimer;
  final Map<String, Map<String, List<Offset>>> _emotionLandmarks = {
    'happy': {
      'left_eyebrow': EmotionLandmarks.happyLeftEyebrow,
      'right_eyebrow': EmotionLandmarks.happyRightEyebrow,
      'lip': EmotionLandmarks.happyLip,
    },
    'angry': {
      'left_eyebrow': EmotionLandmarks.angryLeftEyebrow,
      'right_eyebrow': EmotionLandmarks.angryRightEyebrow,
      'lip': EmotionLandmarks.angryLip,
    },
    'sad': {
      'left_eyebrow': EmotionLandmarks.sadLeftEyebrow,
      'right_eyebrow': EmotionLandmarks.sadRightEyebrow,
      'lip': EmotionLandmarks.sadLip,
    },
    'confused': {
      'left_eyebrow': EmotionLandmarks.confusedLeftEyebrow,
      'right_eyebrow': EmotionLandmarks.confusedRightEyebrow,
      'lip': EmotionLandmarks.confusedLip,
    },
  };

  // Animation Controllers
  late AnimationController _peerAnimationController;
  late AnimationController _pulseController;
  late AnimationController _celebrationController;
  late AnimationController _characterMoveController;
  late Animation<double> _peerBounceAnimation;
  late Animation<double> _pulseAnimation;

  // Progress Tracking
  DateTime? _sessionStartTime;
  List<Map<String, dynamic>> _sessionData = [];

  // AI/ML Services
  final AIConversationService _aiConversation = AIConversationService();
  final EyeContactDetector _eyeContactDetector = EyeContactDetector();
  final AdaptiveDifficultyService _adaptiveDifficulty = AdaptiveDifficultyService();
  final EmotionMirroringService _emotionMirroring = EmotionMirroringService();
  final PredictiveAnalyticsService _predictiveAnalytics = PredictiveAnalyticsService();
  final PersonalizedAIPeer _aiPeer = PersonalizedAIPeer();
  
  // AI Features State
  bool _useAIConversations = false;
  bool _useRealEyeContact = false;
  bool _useEmotionMirroring = false;
  bool _useAdaptiveDifficulty = true; // Enabled by default
  Map<String, dynamic>? _currentDifficulty;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _loadImage();
    
    // Initialize animations
    _peerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _characterMoveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _peerBounceAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _peerAnimationController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  Future<void> _loadImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/base.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      setState(() {
        _baseImage = frameInfo.image;
      });
    } catch (e) {
      print('Error loading image: $e');
    }
  }

  /// Initialize AI/ML services
  Future<void> _initializeAIServices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Initialize AI conversation service (will use fallback if no API key)
      await _aiConversation.initialize();
      _useAIConversations = _aiConversation.isAIEnabled;

      // Initialize personalized AI peer
      if (_selectedPeer != null) {
        await _aiPeer.initializePeer(
          peerName: _selectedPeer!,
          childId: user.uid,
        );
      }

      // Initialize adaptive difficulty (always enabled)
      _useAdaptiveDifficulty = true;

      print('✅ AI Services initialized. AI Conversations: $_useAIConversations');
    } catch (e) {
      print('Error initializing AI services: $e');
    }
  }

  @override
  void dispose() {
    _peerAnimationController.dispose();
    _pulseController.dispose();
    _celebrationController.dispose();
    _characterMoveController.dispose();
    _turnTimer?.cancel();
    _eyeContactTimer?.cancel();
    _characterMovementTimer?.cancel();
    _eyeContactDetector.dispose();
    _emotionMirroring.dispose();
    super.dispose();
  }

  void _startConversationMode() {
    setState(() {
      _gameMode = 'conversation';
      _conversationRound = 0;
      _score = 0;
    });
    _loadNextConversation();
  }

  void _loadNextConversation() {
    final scenarios = _conversationScenarios;
    if (_conversationRound >= scenarios.length) {
      _endConversationMode();
      return;
    }

    setState(() {
      _conversationRound++;
    });
    _peerAnimationController.forward().then((_) {
      _peerAnimationController.reverse();
    });
  }

  void _onConversationAnswer(int index) async {
    final scenarios = _conversationScenarios;
    final scenario = scenarios[_conversationRound - 1];
    final isCorrect = index == scenario['correctIndex'];
    final selectedResponse = scenario['options'][index] as String;
    
    HapticFeedback.mediumImpact();
    
    // If AI conversations enabled, generate dynamic peer response
    if (_useAIConversations && _selectedPeer != null) {
      try {
        final peerResponse = await _aiPeer.generatePersonalizedResponse(
          childResponse: selectedResponse,
          context: 'Conversation practice round $_conversationRound',
          scenario: scenario['title'] as String? ?? 'General conversation',
        );
        
        // Show AI-generated response (optional - can be shown in a dialog)
        if (mounted) {
          _showAIPeerResponse(peerResponse);
        }
      } catch (e) {
        print('Error generating AI response: $e');
      }
    }
    
    if (isCorrect) {
      setState(() {
        _score++;
      });
      _startCelebration();
      HapticFeedback.heavyImpact();
      
      _sessionData.add({
        'type': 'conversation',
        'round': _conversationRound,
        'correct': true,
        'selectedResponse': selectedResponse,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      HapticFeedback.lightImpact();
      _sessionData.add({
        'type': 'conversation',
        'round': _conversationRound,
        'correct': false,
        'selectedResponse': selectedResponse,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _loadNextConversation();
      }
    });
  }

  void _showAIPeerResponse(String response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.smart_toy, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(response)),
          ],
        ),
        backgroundColor: const Color(0xFF6B73FF),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _startTurnTakingGame() {
    setState(() {
      _gameMode = 'turnTaking';
      _turnTakingRound = 0;
      _turnTakingScore = 0;
      _currentTurnIndex = 0;
      _isPlayerTurn = true;
    });
    _loadNextTurnSequence();
  }

  void _loadNextTurnSequence() {
    if (_turnTakingRound >= 5) {
      _endTurnTakingGame();
      return;
    }

    setState(() {
      _turnTakingRound++;
      
      // Use adaptive difficulty if available
      int sequenceLength = 3 + _turnTakingRound;
      double turnSpeed = 1.0;
      
      if (_currentDifficulty != null && _useAdaptiveDifficulty) {
        sequenceLength = (_currentDifficulty!['sequenceLength'] as int? ?? sequenceLength)
            .clamp(3, 10);
        turnSpeed = (_currentDifficulty!['turnSpeed'] as double? ?? 1.0);
      }
      
      // Create alternating sequence: You, Peer, You, Peer, etc.
      _turnSequence = List.generate(sequenceLength, (i) => i % 2 == 0 ? 'You' : 'Peer');
      _currentTurnIndex = 0;
      _isPlayerTurn = _turnSequence[0] == 'You';
    });

    // If it's peer's turn first, wait a moment then start
    if (!_isPlayerTurn) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _peerTakeTurn();
        }
      });
    }
  }

  void _peerTakeTurn() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _currentTurnIndex < _turnSequence.length) {
        setState(() {
          _currentTurnIndex++;
          if (_currentTurnIndex < _turnSequence.length) {
            _isPlayerTurn = _turnSequence[_currentTurnIndex] == 'You';
          } else {
            // Sequence completed
            _turnTakingScore++;
            _startCelebration();
            _sessionData.add({
              'type': 'turnTaking',
              'round': _turnTakingRound,
              'correct': true,
              'timestamp': DateTime.now().toIso8601String(),
            });
            // Move to next sequence after a delay
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                _loadNextTurnSequence();
              }
            });
            return;
          }
        });
        _peerAnimationController.forward().then((_) {
          _peerAnimationController.reverse();
        });
        
        if (!_isPlayerTurn && _currentTurnIndex < _turnSequence.length) {
          _peerTakeTurn();
        }
      }
    });
  }

  void _playerTakeTurn() {
    if (_currentTurnIndex >= _turnSequence.length) {
      _loadNextTurnSequence();
      return;
    }

    if (_turnSequence[_currentTurnIndex] != 'You') {
      // Wrong turn!
      HapticFeedback.lightImpact();
      _showFeedback('Wait for your turn!', false);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentTurnIndex++;
      if (_currentTurnIndex < _turnSequence.length) {
        _isPlayerTurn = _turnSequence[_currentTurnIndex] == 'You';
      } else {
        // Sequence completed by player
        _turnTakingScore++;
        _startCelebration();
        _sessionData.add({
          'type': 'turnTaking',
          'round': _turnTakingRound,
          'correct': true,
          'timestamp': DateTime.now().toIso8601String(),
        });
        // Move to next sequence after a delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _loadNextTurnSequence();
          }
        });
        return;
      }
    });

    // If there are more turns and it's peer's turn, let peer take it
    if (_currentTurnIndex < _turnSequence.length && !_isPlayerTurn) {
      _peerTakeTurn();
    }
  }

  void _startEmotionRecognition() {
    setState(() {
      _gameMode = 'emotionRecognition';
      _emotionRound = 0;
      _emotionRecognitionScore = 0;
    });
    _loadNextEmotion();
  }

  void _loadNextEmotion() {
    if (_emotionRound >= 8) {
      _endEmotionRecognition();
      return;
    }

    final emotions = ['happy', 'sad', 'angry', 'surprised', 'scared', 'excited', 'calm', 'confused'];
    final random = math.Random();
    _currentEmotion = emotions[random.nextInt(emotions.length)];
    
    final allEmotions = List<String>.from(emotions);
    allEmotions.shuffle();
    _emotionOptions = allEmotions.take(4).toList();
    
    if (!_emotionOptions.contains(_currentEmotion)) {
      _emotionOptions[0] = _currentEmotion!;
    }
    _emotionOptions.shuffle();

    setState(() {
      _emotionRound++;
      _emotionAnswered = false;
    });
  }

  void _onEmotionAnswer(String selectedEmotion) {
    if (_emotionAnswered) return;
    
    final isCorrect = selectedEmotion == _currentEmotion;
    _emotionAnswered = true;
    
    HapticFeedback.mediumImpact();
    
    if (isCorrect) {
      setState(() {
        _emotionRecognitionScore++;
      });
      _startCelebration();
      HapticFeedback.heavyImpact();
      
      _sessionData.add({
        'type': 'emotionRecognition',
        'round': _emotionRound,
        'correct': true,
        'emotion': _currentEmotion,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      HapticFeedback.lightImpact();
      _sessionData.add({
        'type': 'emotionRecognition',
        'round': _emotionRound,
        'correct': false,
        'emotion': _currentEmotion,
        'selected': selectedEmotion,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _loadNextEmotion();
      }
    });
  }

  void _startEyeContactPractice() {
    setState(() {
      _gameMode = 'eyeContact';
      _eyeContactRound = 0;
      _eyeContactScore = 0;
      _eyeContactActive = false;
      _eyeContactDuration = 0;
      _currentExpression = 'happy';
      _characterPosition = const Offset(0, 0);
    });
    _loadNextEyeContact();
    _startCharacterMovement();
  }
  
  void _startCharacterMovement() {
    _characterMovementTimer?.cancel();
    final random = math.Random();
    
    // Get movement speed from adaptive difficulty
    double movementSpeed = 1.0;
    if (_currentDifficulty != null && _useAdaptiveDifficulty) {
      movementSpeed = _currentDifficulty!['movementSpeed'] as double? ?? 1.0;
    }
    
    _characterMovementTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && _gameMode == 'eyeContact') {
        setState(() {
          // Move character in a smooth circular/random pattern
          // Speed adjusted by adaptive difficulty
          final time = DateTime.now().millisecondsSinceEpoch / 1000.0 * movementSpeed;
          _characterPosition = Offset(
            math.sin(time * 0.5) * 100,
            math.cos(time * 0.7) * 80,
          );
          
          // Update eye contact detector with new position
          if (_useRealEyeContact) {
            _eyeContactDetector.setCharacterPosition(_characterPosition);
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _loadNextEyeContact() {
    if (_eyeContactRound >= 5) {
      _endEyeContactPractice();
      return;
    }

    setState(() {
      _eyeContactRound++;
      _eyeContactActive = false;
      _eyeContactDuration = 0.0;
    });
  }

  void _startEyeContactTimer() {
    setState(() {
      _eyeContactActive = true;
      _eyeContactDuration = 0.0;
      _isHolding = true;
      _lastTapTime = DateTime.now();
    });

    _eyeContactTimer?.cancel();
    _eyeContactTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && _eyeContactActive) {
        // Check if user is still holding (tapped within last 0.5 seconds)
        final now = DateTime.now();
        if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds > 500) {
          // User stopped holding - pause/reset
          setState(() {
            _isHolding = false;
            _eyeContactActive = false;
            _eyeContactDuration = 0.0;
          });
          timer.cancel();
          _showFeedback('Keep following your friend!', false);
          return;
        }

        // Only count time if holding
        if (_isHolding) {
          setState(() {
            _eyeContactDuration += 0.1;
          });

          if (_eyeContactDuration >= _eyeContactTarget) {
            timer.cancel();
            _completeEyeContact();
          }
        }
      } else {
        timer.cancel();
      }
    });
  }
  
  void _onCharacterTap() {
    if (!_eyeContactActive) {
      _startEyeContactTimer();
    } else {
      // Update last tap time to keep the timer going
      setState(() {
        _lastTapTime = DateTime.now();
        _isHolding = true;
      });
    }
  }

  void _completeEyeContact() {
    _eyeContactTimer?.cancel();
    HapticFeedback.heavyImpact();
    _startCelebration();
    
    setState(() {
      _eyeContactScore++;
      _eyeContactActive = false;
    });

    _sessionData.add({
      'type': 'eyeContact',
      'round': _eyeContactRound,
      'duration': _eyeContactDuration,
      'target': _eyeContactTarget,
      'success': true,
      'timestamp': DateTime.now().toIso8601String(),
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _loadNextEyeContact();
      }
    });
  }

  void _startCelebration() {
    _celebrationController.forward().then((_) {
      _celebrationController.reverse();
    });
  }

  void _showFeedback(String message, bool isPositive) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isPositive ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _endConversationMode() {
    _saveSessionReport();
    _showCompletionDialog('Conversation Practice', _score, _conversationScenarios.length);
  }

  void _endTurnTakingGame() {
    _saveSessionReport();
    _showCompletionDialog('Turn-Taking Game', _turnTakingScore, 5);
  }

  void _endEmotionRecognition() {
    _saveSessionReport();
    _showCompletionDialog('Emotion Recognition', _emotionRecognitionScore, 8);
  }

  void _endEyeContactPractice() {
    _saveSessionReport();
    _showCompletionDialog('Eye Contact Practice', _eyeContactScore, 5);
  }

  Future<void> _saveSessionReport() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _sessionStartTime == null) return;

      final sessionDuration = DateTime.now().difference(_sessionStartTime!).inSeconds;
      final totalScore = _score + _turnTakingScore + _emotionRecognitionScore + _eyeContactScore;
      final totalRounds = _conversationRound + _turnTakingRound + _emotionRound + _eyeContactRound;
      final accuracy = totalRounds > 0 ? (totalScore / totalRounds) : 0.0;

      // Determine which modules were played
      final List<String> modulesPlayed = [];
      if (_conversationRound > 0) modulesPlayed.add('Conversation Practice');
      if (_turnTakingRound > 0) modulesPlayed.add('Turn-Taking Game');
      if (_emotionRound > 0) modulesPlayed.add('Emotion Recognition');
      if (_eyeContactRound > 0) modulesPlayed.add('Eye Contact Practice');
      
      // Determine primary module (the one with most rounds)
      String primaryModule = 'Mixed Session';
      if (modulesPlayed.length == 1) {
        primaryModule = modulesPlayed[0];
      } else if (modulesPlayed.isNotEmpty) {
        // Find module with most rounds
        final moduleRounds = {
          'Conversation Practice': _conversationRound,
          'Turn-Taking Game': _turnTakingRound,
          'Emotion Recognition': _emotionRound,
          'Eye Contact Practice': _eyeContactRound,
        };
        primaryModule = moduleRounds.entries
            .where((e) => e.value > 0)
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      final reportData = {
        'gameType': 'social_skills_training',
        'primaryModule': primaryModule,
        'modulesPlayed': modulesPlayed,
        'sessionDurationSeconds': sessionDuration,
        'totalScore': totalScore,
        'totalRounds': totalRounds,
        'accuracy': accuracy,
        'conversationScore': _score,
        'conversationRounds': _conversationRound,
        'turnTakingScore': _turnTakingScore,
        'turnTakingRounds': _turnTakingRound,
        'emotionRecognitionScore': _emotionRecognitionScore,
        'emotionRecognitionRounds': _emotionRound,
        'eyeContactScore': _eyeContactScore,
        'eyeContactRounds': _eyeContactRound,
        'sessionData': _sessionData,
        'completedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gameReports')
          .add(reportData);

      print('✅ Social skills training report saved successfully!');
    } catch (e) {
      print('❌ Error saving social skills report: $e');
    }
  }

  void _showCompletionDialog(String mode, int score, int total) async {
    final percentage = ((score / total) * 100).round();
    String message;
    String emoji;

    if (percentage >= 90) {
      message = 'Amazing! You\'re a social skills superstar! 🌟';
      emoji = '🌟';
    } else if (percentage >= 70) {
      message = 'Great job! You\'re learning so well! 🎉';
      emoji = '🎉';
    } else if (percentage >= 50) {
      message = 'Good try! Keep practicing! 💪';
      emoji = '💪';
    } else {
      message = 'Nice effort! Let\'s try again! 😊';
      emoji = '😊';
    }

    // Get predictive analytics if available
    Map<String, dynamic>? predictions;
    try {
      predictions = await _predictiveAnalytics.getProgressPredictions();
    } catch (e) {
      print('Error getting predictions: $e');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Great Job! $emoji'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 8),
              Text(
                'You scored $score out of $total! ($percentage%)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B9D),
                ),
              ),
              if (predictions != null && predictions['overall'] != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Progress Prediction',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B73FF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Predicted accuracy in 7 days: ${((predictions['overall']['predictedAccuracy7Days'] as double? ?? 0.5) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _gameMode = 'menu';
              });
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B73FF), Color(0xFF9B59B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _buildCurrentScreen(),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_gameMode) {
      case 'menu':
        return _buildMenuScreen();
      case 'conversation':
        return _buildConversationScreen();
      case 'turnTaking':
        return _buildTurnTakingScreen();
      case 'emotionRecognition':
        return _buildEmotionRecognitionScreen();
      case 'eyeContact':
        return _buildEyeContactScreen();
      default:
        return _buildMenuScreen();
    }
  }

  Widget _buildMenuScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Social Skills Training',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Practice social skills with friendly virtual peers!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Virtual Peer Selection
          const Text(
            'Choose Your Friend',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: _virtualPeers.map((peer) {
              final isSelected = _selectedPeer == peer['name'];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPeer = peer['name'];
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          peer['avatar'],
                          style: const TextStyle(fontSize: 40),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          peer['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Training Modules
          const Text(
            'Training Modules',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildModuleCard(
            title: 'Conversation Practice',
            subtitle: 'Learn to have conversations',
            icon: Icons.chat_bubble_outline,
            color: const Color(0xFF4ECDC4),
            onTap: _startConversationMode,
          ),
          const SizedBox(height: 12),
          _buildModuleCard(
            title: 'Turn-Taking Game',
            subtitle: 'Practice taking turns',
            icon: Icons.swap_horiz,
            color: const Color(0xFFFF6B9D),
            onTap: _startTurnTakingGame,
          ),
          const SizedBox(height: 12),
          _buildModuleCard(
            title: 'Emotion Recognition',
            subtitle: 'Recognize emotions in others',
            icon: Icons.emoji_emotions,
            color: const Color(0xFFFFE66D),
            onTap: _startEmotionRecognition,
          ),
          const SizedBox(height: 12),
          _buildModuleCard(
            title: 'Eye Contact Practice',
            subtitle: 'Comfortable eye contact practice',
            icon: Icons.visibility,
            color: const Color(0xFF95E1D3),
            onTap: _startEyeContactPractice,
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationScreen() {
    final scenarios = _conversationScenarios;
    if (_conversationRound == 0 || _conversationRound > scenarios.length) {
      return const Center(child: CircularProgressIndicator());
    }

    final scenario = scenarios[_conversationRound - 1];
    final peer = _virtualPeers.firstWhere(
      (p) => p['name'] == _selectedPeer,
      orElse: () => _virtualPeers[0],
    );

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _gameMode = 'menu';
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Conversation Practice - Round $_conversationRound/${_conversationScenarios.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: $_score',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Virtual Peer
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _peerBounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _peerBounceAnimation.value),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            peer['avatar'],
                            style: const TextStyle(fontSize: 60),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  peer['name'] + ' says:',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    scenario['peerMessage'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Response Options
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How would you respond?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...scenarios[_conversationRound - 1]['options'].asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: () => _onConversationAnswer(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: peer['color'],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        option,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTurnTakingScreen() {
    final peer = _virtualPeers.firstWhere(
      (p) => p['name'] == _selectedPeer,
      orElse: () => _virtualPeers[0],
    );

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _gameMode = 'menu';
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Turn-Taking - Round $_turnTakingRound/5',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: $_turnTakingScore',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Game Area
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Turn Sequence Display
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Follow the turn sequence:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _turnSequence.asMap().entries.map((entry) {
                          final index = entry.key;
                          final turn = entry.value;
                          final isCurrent = index == _currentTurnIndex;
                          final isCompleted = index < _currentTurnIndex;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? peer['color']
                                  : isCompleted
                                      ? Colors.green
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              turn,
                              style: TextStyle(
                                color: isCurrent || isCompleted ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Virtual Peer
                AnimatedBuilder(
                  animation: _peerBounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _peerBounceAnimation.value),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            peer['avatar'],
                            style: const TextStyle(fontSize: 50),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  _isPlayerTurn ? 'Your turn!' : '${peer['name']}\'s turn',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action Button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isPlayerTurn ? _playerTakeTurn : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPlayerTurn ? peer['color'] : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isPlayerTurn ? 'Take Your Turn!' : 'Wait for your turn...',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionRecognitionScreen() {
    final emotionIcons = {
      'happy': '😊',
      'sad': '😢',
      'angry': '😠',
      'surprised': '😲',
      'scared': '😨',
      'excited': '🤩',
      'calm': '😌',
      'confused': '😕',
    };

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _gameMode = 'menu';
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Emotion Recognition - Round $_emotionRound/8',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: $_emotionRecognitionScore',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Emotion Display
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            emotionIcons[_currentEmotion] ?? '😊',
                            style: const TextStyle(fontSize: 80),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                const Text(
                  'What emotion is this?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Options
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _emotionOptions.length,
            itemBuilder: (context, index) {
              final emotion = _emotionOptions[index];
              final isCorrect = emotion == _currentEmotion;
              
              return ElevatedButton(
                onPressed: _emotionAnswered
                    ? null
                    : () => _onEmotionAnswer(emotion),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emotionAnswered && isCorrect
                      ? Colors.green
                      : _emotionAnswered && !isCorrect
                          ? Colors.red
                          : const Color(0xFF6B73FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  emotion.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEyeContactScreen() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  _characterMovementTimer?.cancel();
                  setState(() {
                    _gameMode = 'menu';
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Eye Contact Practice - Round $_eyeContactRound/5',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: $_eyeContactScore',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Instructions
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Follow your friend with your eyes for 3 seconds. This is a safe, comfortable way to practice!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Moving Emotion Character
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([_characterMoveController, _pulseAnimation]),
            builder: (context, child) {
              final characterLeft = MediaQuery.of(context).size.width / 2 + _characterPosition.dx - 150;
              final characterTop = MediaQuery.of(context).size.height / 2 + _characterPosition.dy - 200;
              
              return Stack(
                children: [
                  // Moving character - make it tappable
                  Positioned(
                    left: characterLeft,
                    top: characterTop,
                    child: GestureDetector(
                      onTap: _onCharacterTap,
                      child: Transform.scale(
                        scale: _eyeContactActive && _isHolding ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 300,
                          height: 424,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _isHolding 
                                    ? Colors.green.withOpacity(0.5)
                                    : Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: EmotionCharacterPainter(
                              baseImage: _baseImage,
                              currentExpression: _currentExpression,
                              morphProgress: 0.0,
                              emotionLandmarks: _emotionLandmarks,
                              displayWidth: 300,
                              displayHeight: 424,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                    // Progress indicator
                    if (_eyeContactActive)
                      Positioned(
                        bottom: 100,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Text(
                              '${_eyeContactDuration.toStringAsFixed(1)} / $_eyeContactTarget seconds',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: LinearProgressIndicator(
                                value: _eyeContactDuration / _eyeContactTarget,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Positioned(
                        bottom: 100,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            const Text(
                              'Tap your friend as they move!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Keep tapping to maintain eye contact',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_eyeContactActive && !_isHolding)
                      Positioned(
                        bottom: 200,
                        left: 0,
                        right: 0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Tap your friend to continue!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

// Emotion Character Painter for Eye Contact Practice
class EmotionCharacterPainter extends CustomPainter {
  final ui.Image? baseImage;
  final String currentExpression;
  final String? targetExpression;
  final double morphProgress;
  final Map<String, Map<String, List<Offset>>> emotionLandmarks;
  final double displayWidth;
  final double displayHeight;

  EmotionCharacterPainter({
    required this.baseImage,
    required this.currentExpression,
    this.targetExpression,
    required this.morphProgress,
    required this.emotionLandmarks,
    this.displayWidth = 362.0,
    this.displayHeight = 512.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (baseImage == null) return;

    // Calculate scale factors
    final scaleX = size.width / 362.0;
    final scaleY = size.height / 512.0;

    // Draw base image
    canvas.drawImageRect(
      baseImage!,
      Rect.fromLTWH(0, 0, baseImage!.width.toDouble(), baseImage!.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // Draw current expression features
    final landmarks = emotionLandmarks[currentExpression] ?? {};
    for (final feature in ['left_eyebrow', 'right_eyebrow', 'lip']) {
      final points = landmarks[feature] ?? [];
      if (points.isEmpty) continue;

      final path = Path();
      final firstPoint = Offset(points[0].dx * scaleX, points[0].dy * scaleY);
      path.moveTo(firstPoint.dx, firstPoint.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx * scaleX, points[i].dy * scaleY);
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(EmotionCharacterPainter oldDelegate) {
    return oldDelegate.baseImage != baseImage ||
        oldDelegate.currentExpression != currentExpression ||
        oldDelegate.morphProgress != morphProgress;
  }
}

