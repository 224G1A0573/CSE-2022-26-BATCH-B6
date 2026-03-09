import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'emotion_landmarks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmotionCharacterGame extends StatefulWidget {
  const EmotionCharacterGame({super.key});

  @override
  State<EmotionCharacterGame> createState() => _EmotionCharacterGameState();
}

class _EmotionCharacterGameState extends State<EmotionCharacterGame>
    with TickerProviderStateMixin {
  String _currentExpression = 'happy';
  bool _isMorphing = false;
  ui.Image? _baseImage;
  double _morphProgress = 0.0;
  String? _targetExpression;
  Timer? _morphTimer;
  
  // Game mode: 'learn', 'identify', 'mirror'
  String _gameMode = 'learn';
  String? _questionEmotion;
  List<String> _options = [];
  int? _selectedAnswer;
  int _score = 0;
  int _round = 0;
  bool _showResult = false;
  bool _isCorrect = false;
  
  // Quiz tracking for better randomization
  List<String> _recentQuestions = []; // Track last 3 questions to avoid repetition
  List<Map<String, dynamic>> _quizAnswers = []; // Track all answers for reporting
  DateTime? _quizStartTime;
  int _totalQuestions = 10; // Increased from 5 to 10 for more variety
  
  // Animation controllers
  late AnimationController _characterAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _celebrationController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _celebrationAnimation;
  late Animation<double> _bounceAnimation;
  
  // Celebration particles
  List<Particle> _particles = [];
  Timer? _particleTimer;
  
  // Emotion data with landmarks (scaled for display size 362x512)
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
  
  final Map<String, String> _emotionDescriptions = {
    'happy': 'Happy means feeling good and joyful! 😊',
    'angry': 'Angry means feeling upset or mad. It\'s okay to feel this way sometimes. 😠',
    'sad': 'Sad means feeling down or blue. It\'s normal to feel sad sometimes. 😢',
    'confused': 'Confused means not understanding something. It\'s okay to ask for help! 🤔',
  };
  
  final Map<String, Color> _emotionColors = {
    'happy': const Color(0xFFFFD700),
    'angry': const Color(0xFFE74C3C),
    'sad': const Color(0xFF3498DB),
    'confused': const Color(0xFF9B59B6),
  };

  @override
  void initState() {
    super.initState();
    _loadImage();
    _characterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _startLearnMode();
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

  void _startLearnMode() {
    _gameMode = 'learn';
    _round = 0;
    _score = 0;
    _showNextEmotion();
  }

  void _startIdentifyMode() {
    _gameMode = 'identify';
    _round = 0;
    _score = 0;
    _recentQuestions.clear();
    _quizAnswers.clear();
    _quizStartTime = DateTime.now();
    _showNextQuestion();
  }

  void _showNextEmotion() {
    if (_round >= 4) {
      _showCompletionDialog();
      return;
    }
    
    final emotions = ['happy', 'angry', 'sad', 'confused'];
    final emotion = emotions[_round % emotions.length];
    _morphToExpression(emotion);
    _round++;
  }

  void _showNextQuestion() {
    if (_round >= _totalQuestions) {
      _saveQuizReport();
      _showCompletionDialog();
      return;
    }
    
    final emotions = ['happy', 'angry', 'sad', 'confused'];
    final random = math.Random();
    
    // Smart randomization: avoid showing same emotion too frequently
    List<String> availableEmotions = List.from(emotions);
    
    // Remove emotions that were shown in the last 2 questions
    if (_recentQuestions.length >= 2) {
      availableEmotions.removeWhere((e) => _recentQuestions.contains(e));
    }
    
    // If we filtered out too many, allow some repetition but not the last one
    if (availableEmotions.isEmpty) {
      availableEmotions = List.from(emotions);
      if (_recentQuestions.isNotEmpty) {
        availableEmotions.remove(_recentQuestions.last);
      }
    }
    
    // Select random emotion from available ones
    _questionEmotion = availableEmotions[random.nextInt(availableEmotions.length)];
    
    // Update recent questions (keep only last 2)
    _recentQuestions.add(_questionEmotion!);
    if (_recentQuestions.length > 2) {
      _recentQuestions.removeAt(0);
    }
    
    _morphToExpression(_questionEmotion!);
    
    // Create options - ensure all 4 emotions are shown
    _options = List.from(emotions);
    _options.shuffle();
    
    // Make sure correct answer is in options
    if (!_options.contains(_questionEmotion)) {
      _options[0] = _questionEmotion!;
      _options.shuffle();
    }
    
    _selectedAnswer = null;
    _showResult = false;
    _round++;
  }

  void _morphToExpression(String target) {
    if (_isMorphing || target == _currentExpression) return;
    
    _targetExpression = target;
    _isMorphing = true;
    _morphProgress = 0.0;
    
    _morphTimer?.cancel();
    _morphTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        _morphProgress += 0.033; // ~30fps
        if (_morphProgress >= 1.0) {
          _morphProgress = 1.0;
          _currentExpression = target;
          _isMorphing = false;
          _targetExpression = null;
          timer.cancel();
        }
      });
    });
  }

  void _onAnswerSelected(int index) {
    if (_showResult) return;
    
    HapticFeedback.mediumImpact();
    
    final selectedEmotion = _options[index];
    final isCorrect = selectedEmotion == _questionEmotion;
    final questionTime = DateTime.now();
    
    // Track this answer for reporting
    _quizAnswers.add({
      'questionNumber': _round,
      'correctEmotion': _questionEmotion,
      'selectedEmotion': selectedEmotion,
      'isCorrect': isCorrect,
      'timestamp': questionTime.toIso8601String(),
      'options': List.from(_options),
    });
    
    setState(() {
      _selectedAnswer = index;
      _isCorrect = isCorrect;
      _showResult = true;
      if (_isCorrect) {
        _score++;
        _startCelebration();
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showNextQuestion();
      }
    });
  }
  
  void _startCelebration() {
    _celebrationController.forward(from: 0.0);
    _bounceController.forward(from: 0.0);
    
    // Create particles
    _particles.clear();
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      _particles.add(Particle(
        x: 150, // Center of character (300/2)
        y: 212, // Center of character (424/2)
        vx: (random.nextDouble() - 0.5) * 8,
        vy: (random.nextDouble() - 0.5) * 8 - 2,
        color: [
          Colors.yellow,
          Colors.orange,
          Colors.pink,
          Colors.purple,
          Colors.blue,
        ][random.nextInt(5)],
        size: random.nextDouble() * 8 + 4,
      ));
    }
    
    _particleTimer?.cancel();
    _particleTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        _particles.removeWhere((p) {
          p.update();
          return p.y > 600 || p.alpha <= 0;
        });
        if (_particles.isEmpty) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _saveQuizReport() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _quizStartTime == null) return;
      
      final quizDuration = DateTime.now().difference(_quizStartTime!).inSeconds;
      
      // Calculate emotion-specific stats
      final emotionStats = <String, Map<String, dynamic>>{};
      for (final emotion in ['happy', 'angry', 'sad', 'confused']) {
        final emotionQuestions = _quizAnswers.where((a) => a['correctEmotion'] == emotion).toList();
        final correctCount = emotionQuestions.where((a) => a['isCorrect'] == true).length;
        emotionStats[emotion] = {
          'totalQuestions': emotionQuestions.length,
          'correctAnswers': correctCount,
          'accuracy': emotionQuestions.isEmpty ? 0.0 : (correctCount / emotionQuestions.length),
        };
      }
      
      final reportData = {
        'gameType': 'emotion_character_quiz',
        'score': _score,
        'totalQuestions': _totalQuestions,
        'accuracy': _score / _totalQuestions,
        'quizDurationSeconds': quizDuration,
        'completedAt': FieldValue.serverTimestamp(),
        'answers': _quizAnswers,
        'emotionStats': emotionStats,
        'userId': user.uid,
      };
      
      // Save to user's emotionGameReports subcollection (for detailed view)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('emotionGameReports')
          .add(reportData);
      
      // Also save to unified gameReports collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gameReports')
          .add({
        'gameType': 'emotion_character_quiz',
        'score': _score,
        'totalQuestions': _totalQuestions,
        'accuracy': _score / _totalQuestions,
        'quizDurationSeconds': quizDuration,
        'completedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });
      
      print('✅ Quiz report saved successfully!');
    } catch (e) {
      print('❌ Error saving quiz report: $e');
      // Don't show error to user, just log it
    }
  }

  void _showCompletionDialog() {
    final percentage = ((_score / _totalQuestions) * 100).round();
    String message;
    String emoji;
    
    if (percentage >= 90) {
      message = 'Amazing! You\'re an emotion expert! 🌟';
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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Great Job! $emoji'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _gameMode == 'learn'
                  ? 'You learned about all the emotions!'
                  : message,
            ),
            const SizedBox(height: 8),
            Text(
              _gameMode == 'identify'
                  ? 'You scored $_score out of $_totalQuestions! ($percentage%)'
                  : '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B9D),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_gameMode == 'learn') {
                _startIdentifyMode();
              } else {
                _startLearnMode();
              }
            },
            child: Text(_gameMode == 'learn' ? 'Play Quiz' : 'Play Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _morphTimer?.cancel();
    _particleTimer?.cancel();
    _characterAnimationController.dispose();
    _pulseAnimationController.dispose();
    _celebrationController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotion Friend'),
        backgroundColor: const Color(0xFFFF6B9D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _emotionColors[_currentExpression] ?? const Color(0xFFFF6B9D),
              (_emotionColors[_currentExpression] ?? const Color(0xFFFF6B9D)).withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main scrollable content
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Score display for quiz mode
                    if (_gameMode == 'identify')
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...List.generate(5, (index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  index < _score ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 30,
                                ),
                              );
                            }),
                            const SizedBox(width: 16),
                            Text(
                              'Score: $_score/$_totalQuestions',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B9D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Mode selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildModeButton('Learn', 'learn', Icons.school),
                          const SizedBox(width: 16),
                          _buildModeButton('Quiz', 'identify', Icons.quiz),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Character display
                    AnimatedBuilder(
                      animation: Listenable.merge([_pulseAnimation, _bounceAnimation, _celebrationAnimation]),
                      builder: (context, child) {
                        double scale = _pulseAnimation.value;
                        if (_isCorrect && _showResult) {
                          scale *= (1.0 + _celebrationAnimation.value * 0.2);
                        }
                        return Transform.scale(
                          scale: scale,
                          child: Transform.translate(
                            offset: Offset(0, -_bounceAnimation.value * 20),
                            child: Container(
                              width: 300,
                              height: 424,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_emotionColors[_currentExpression] ?? Colors.pink).withOpacity(0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      painter: EmotionCharacterPainter(
                                        baseImage: _baseImage,
                                        currentExpression: _currentExpression,
                                        targetExpression: _targetExpression,
                                        morphProgress: _morphProgress,
                                        emotionLandmarks: _emotionLandmarks,
                                        displayWidth: 300,
                                        displayHeight: 424,
                                      ),
                                      size: const Size(300, 424),
                                    ),
                                    // Celebration overlay
                                    if (_isCorrect && _showResult)
                                      AnimatedBuilder(
                                        animation: _celebrationAnimation,
                                        builder: (context, child) {
                                          return CustomPaint(
                                            painter: ParticlePainter(_particles),
                                            size: const Size(300, 424),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Emotion name and description (only show in learn mode)
                    if (_gameMode == 'learn')
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
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
                        child: Column(
                          children: [
                            Text(
                              _currentExpression.toUpperCase(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _emotionColors[_currentExpression],
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _emotionDescriptions[_currentExpression] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Game controls
                    if (_gameMode == 'learn') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _showNextEmotion();
                            },
                            icon: const Icon(Icons.arrow_forward, size: 28),
                            label: const Text(
                              'Next Emotion',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _emotionColors[_currentExpression] ?? const Color(0xFFFF6B9D),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 8,
                            ),
                          ),
                        ),
                      ),
                    ] else if (_gameMode == 'identify') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            Text(
                              'What emotion is this?',
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
                            const SizedBox(height: 16),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 2.2,
                              ),
                              itemCount: _options.length,
                              itemBuilder: (context, index) => _buildEmotionButton(index),
                            ),
                            const SizedBox(height: 16),
                            if (_showResult)
                              AnimatedBuilder(
                                animation: _celebrationAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _isCorrect ? (1.0 + _celebrationAnimation.value * 0.3) : 1.0,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _isCorrect ? Colors.green : Colors.red,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (_isCorrect ? Colors.green : Colors.red).withOpacity(0.5),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _isCorrect ? '🎉 Awesome! 🎉' : '💪 Try Again! 💪',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, String mode, IconData icon) {
    final isSelected = _gameMode == mode;
    return GestureDetector(
      onTap: () {
        if (mode == 'learn') {
          _startLearnMode();
        } else {
          _startIdentifyMode();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFF6B9D) : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFF6B9D) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionButton(int index) {
    final emotion = _options[index];
    final isSelected = _selectedAnswer == index;
    final isCorrect = emotion == _questionEmotion && _showResult;
    final isWrong = isSelected && !_isCorrect && _showResult;
    
    Color backgroundColor;
    if (isCorrect && _showResult) {
      backgroundColor = Colors.green;
    } else if (isWrong) {
      backgroundColor = Colors.red;
    } else if (isSelected) {
      backgroundColor = Colors.blue.shade300;
    } else {
      backgroundColor = Colors.white;
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: () => _onAnswerSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isCorrect || isWrong || isSelected)
                    ? backgroundColor.withOpacity(0.6)
                    : Colors.black.withOpacity(0.2),
                blurRadius: isCorrect || isWrong ? 15 : 8,
                spreadRadius: isCorrect || isWrong ? 2 : 0,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isSelected ? Colors.blue.shade700 : Colors.transparent,
              width: 3,
            ),
          ),
          child: Center(
            child: Text(
              emotion.toUpperCase(),
              style: TextStyle(
                color: isSelected || isCorrect || isWrong
                    ? Colors.white
                    : _emotionColors[emotion],
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// Custom painter for drawing the character with morphing expressions
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

    // Calculate scale factors (landmarks are scaled for 362x512, but we may display at different size)
    final scaleX = size.width / 362.0;
    final scaleY = size.height / 512.0;

    // Draw base image
    canvas.drawImageRect(
      baseImage!,
      Rect.fromLTWH(0, 0, baseImage!.width.toDouble(), baseImage!.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // Draw morphed features if morphing
    if (targetExpression != null && morphProgress > 0) {
      final currentLandmarks = emotionLandmarks[currentExpression] ?? {};
      final targetLandmarks = emotionLandmarks[targetExpression!] ?? {};

      for (final feature in ['left_eyebrow', 'right_eyebrow', 'lip']) {
        final currentPoints = currentLandmarks[feature] ?? [];
        final targetPoints = targetLandmarks[feature] ?? [];

        if (currentPoints.isEmpty || targetPoints.isEmpty) continue;

        // Interpolate between current and target
        final morphedPoints = <Offset>[];
        final maxLen = math.max(currentPoints.length, targetPoints.length);

        for (int i = 0; i < maxLen; i++) {
          final currentPoint = currentPoints[math.min(i, currentPoints.length - 1)];
          final targetPoint = targetPoints[math.min(i, targetPoints.length - 1)];

          final x = (currentPoint.dx + (targetPoint.dx - currentPoint.dx) * morphProgress) * scaleX;
          final y = (currentPoint.dy + (targetPoint.dy - currentPoint.dy) * morphProgress) * scaleY;
          morphedPoints.add(Offset(x, y));
        }

        // Draw morphed feature
        final path = Path();
        if (morphedPoints.isNotEmpty) {
          path.moveTo(morphedPoints[0].dx, morphedPoints[0].dy);
          for (int i = 1; i < morphedPoints.length; i++) {
            path.lineTo(morphedPoints[i].dx, morphedPoints[i].dy);
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
    } else {
      // Draw current expression features
      final landmarks = emotionLandmarks[currentExpression] ?? {};
      for (final feature in ['left_eyebrow', 'right_eyebrow', 'lip']) {
        final points = landmarks[feature] ?? [];
        if (points.isEmpty) continue;

        final path = Path();
        // Scale the first point
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
  }

  @override
  bool shouldRepaint(EmotionCharacterPainter oldDelegate) {
    return oldDelegate.currentExpression != currentExpression ||
        oldDelegate.targetExpression != targetExpression ||
        oldDelegate.morphProgress != morphProgress ||
        oldDelegate.baseImage != baseImage ||
        oldDelegate.displayWidth != displayWidth ||
        oldDelegate.displayHeight != displayHeight;
  }
}

// Particle class for celebrations
class Particle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double alpha = 1.0;
  
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });
  
  void update() {
    x += vx;
    y += vy;
    vy += 0.3; // gravity
    alpha -= 0.02;
    if (alpha < 0) alpha = 0;
  }
}

// Particle painter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  
  ParticlePainter(this.particles);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

