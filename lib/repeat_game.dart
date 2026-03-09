import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RepeatGame extends StatefulWidget {
  const RepeatGame({super.key});

  @override
  State<RepeatGame> createState() => _RepeatGameState();
}

class _RepeatGameState extends State<RepeatGame> with TickerProviderStateMixin {
  late AnimationController _flashController;
  late AnimationController _feedbackController;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingMusic = false;
  
  List<int> _sequence = [];
  int _currentIndex = 0;
  bool _isFlashing = false;
  bool _isShowingSequence = false;
  String _gameState = 'menu'; // menu, playing, gameOver
  String _feedback = '';
  int _score = 0;
  int _round = 1;
  int _chances = 3;
  int _bestScore = 0;
  
  final List<Color> _colors = [
    const Color(0xFFFF5050), // Red
    const Color(0xFF64FF64), // Green
    const Color(0xFF78B4FF), // Blue
    const Color(0xFFFFE666), // Yellow
  ];
  
  final List<Color> _flashColors = [
    const Color(0xFFFF0000), // Bright Red
    const Color(0xFF00FF00), // Bright Green
    const Color(0xFF0080FF), // Bright Blue
    const Color(0xFFFFFF00), // Bright Yellow
  ];
  
  Timer? _flashTimer;
  Timer? _feedbackTimer;
  int _lastFlashTime = 0;
  int _flashInterval = 1000;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _playBackgroundMusic();
  }

  void _playBackgroundMusic() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/And Just Like That.mp3'));
      setState(() {
        _isPlayingMusic = true;
      });
    } catch (e) {
      print('Error playing background music: $e');
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    _feedbackController.dispose();
    _flashTimer?.cancel();
    _feedbackTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _gameState = 'playing';
      _sequence = [];
      _currentIndex = 0;
      _score = 0;
      _round = 1;
      _chances = 3;
      _feedback = '';
    });
    _addToSequence();
    _showSequence();
  }

  void _addToSequence() {
    setState(() {
      _sequence.add(Random().nextInt(4));
    });
  }

  void _showSequence() {
    setState(() {
      _isShowingSequence = true;
      _currentIndex = 0;
    });
    _flashNextInSequence();
  }

  void _flashNextInSequence() {
    if (_currentIndex >= _sequence.length) {
      setState(() {
        _isShowingSequence = false;
        _currentIndex = 0;
      });
      return;
    }

    final colorIndex = _sequence[_currentIndex];
    _flashColor(colorIndex, () {
      _currentIndex++;
      if (_currentIndex < _sequence.length) {
        Timer(const Duration(milliseconds: 500), () { // Increased delay between flashes
          _flashNextInSequence();
        });
      } else {
        setState(() {
          _isShowingSequence = false;
          _currentIndex = 0;
        });
      }
    });
  }

  void _flashColor(int colorIndex, VoidCallback onComplete) {
    setState(() {
      _isFlashing = true;
    });
    
    // Play a sound effect when flashing
    _playFlashSound();
    
    _flashController.forward().then((_) {
      Timer(const Duration(milliseconds: 1000), () { // Increased to 1 second for better visibility
        _flashController.reverse().then((_) {
          setState(() {
            _isFlashing = false;
          });
          onComplete();
        });
      });
    });
  }

  void _playFlashSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/ding.mp3'));
    } catch (e) {
      print('Error playing flash sound: $e');
    }
  }

  void _onColorTap(int colorIndex) {
    if (_isShowingSequence || _gameState != 'playing') return;

    if (_sequence[_currentIndex] == colorIndex) {
      _currentIndex++;
      _showFeedback('Correct!', Colors.green);
      
      if (_currentIndex >= _sequence.length) {
        // Round completed
        setState(() {
          _score += _sequence.length * 10;
          _round++;
        });
        
        Timer(const Duration(milliseconds: 1000), () {
          _addToSequence();
          _showSequence();
        });
      }
    } else {
      // Wrong color
      setState(() {
        _chances--;
      });
      
      if (_chances <= 0) {
        _gameOver();
      } else {
        _showFeedback('Wrong! Try again. Chances left: $_chances', Colors.red);
        setState(() {
          _currentIndex = 0;
        });
      }
    }
  }

  void _showFeedback(String message, Color color) {
    setState(() {
      _feedback = message;
    });
    
    _feedbackController.forward().then((_) {
      Timer(const Duration(milliseconds: 1500), () {
        _feedbackController.reverse().then((_) {
          setState(() {
            _feedback = '';
          });
        });
      });
    });
  }

  Future<void> _saveGameReport() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final reportData = {
        'gameType': 'repeat_game',
        'score': _score,
        'round': _round,
        'bestScore': _bestScore,
        'completedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gameReports')
          .add(reportData);
      
      print('✅ Repeat game report saved successfully!');
    } catch (e) {
      print('❌ Error saving repeat game report: $e');
    }
  }

  void _gameOver() {
    setState(() {
      _gameState = 'gameOver';
      if (_score > _bestScore) {
        _bestScore = _score;
      }
    });
    _saveGameReport();
  }

  void _resetGame() {
    setState(() {
      _gameState = 'menu';
      _sequence = [];
      _currentIndex = 0;
      _score = 0;
      _round = 1;
      _chances = 3;
      _feedback = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B9D), Color(0xFFFFB6B9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _gameState == 'menu' ? _buildMenu() : _buildGame(),
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.memory,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 20),
          const Text(
            'Repeat Game',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Memory Challenge',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Watch the colors flash and repeat the sequence!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Best Score: $_bestScore',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFF6B9D),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Start Game',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Back to Games',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _gameState == 'gameOver' ? _resetGame : () => Navigator.pop(context),
              ),
              const Text(
                'Repeat Game',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                'Score: $_score',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Game Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (_isShowingSequence)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('💃', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 8),
                      Text(
                        'Watch the dancing emoji!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('💃', style: TextStyle(fontSize: 24)),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'Round: $_round',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'Chances: $_chances',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Game Grid
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _onColorTap(index),
                      child: AnimatedBuilder(
                        animation: _flashController,
                        builder: (context, child) {
                          final isFlashing = _isFlashing && 
                              _isShowingSequence && 
                              _currentIndex < _sequence.length &&
                              _sequence[_currentIndex] == index;
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: isFlashing 
                                  ? _flashColors[index]
                                  : _colors[index],
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isFlashing
                                  ? AnimatedBuilder(
                                      animation: _flashController,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: 1.0 + (_flashController.value * 0.3),
                                          child: const Text(
                                            '💃', // Dancing emoji when flashing
                                            style: TextStyle(fontSize: 50),
                                          ),
                                        );
                                      },
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        
        // Feedback
        AnimatedBuilder(
          animation: _feedbackController,
          builder: (context, child) {
            return AnimatedOpacity(
              opacity: _feedback.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _feedback,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
        
        // Game Over Screen
        if (_gameState == 'gameOver')
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Game Over!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Final Score: $_score',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_score > _bestScore)
                  const Text(
                    'New Best Score!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Play Again'),
                    ),
                    ElevatedButton(
                      onPressed: _resetGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Menu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
