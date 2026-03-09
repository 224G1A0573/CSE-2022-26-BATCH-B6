import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EyesGame extends StatefulWidget {
  const EyesGame({super.key});

  @override
  State<EyesGame> createState() => _EyesGameState();
}

class _EyesGameState extends State<EyesGame> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _breathController;
  late AnimationController _pulseController;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingMusic = false;
  
  bool _isBlinking = false;
  bool _breathingMode = false;
  bool _focusTriggered = false;
  int _focusCounter = 0;
  String _currentMessage = "";
  double _messageAlpha = 0.0;
  
  // Reporting
  DateTime? _sessionStartTime;
  int _breathingSessions = 0;
  int _totalBreathingDuration = 0; // in seconds
  Timer? _breathingDurationTimer;
  
  final List<Map<String, String>> _feelings = [
    {"emoji": "😊", "name": "happy", "message": "Yay! You're happy!"},
    {"emoji": "😢", "name": "sad", "message": "It's okay to feel sad. I'm here."},
    {"emoji": "😡", "name": "angry", "message": "Take a breath. It'll be okay."},
    {"emoji": "😴", "name": "tired", "message": "You can rest. You're doing great."},
  ];
  
  Map<String, String>? _selectedFeeling;
  Timer? _messageTimer;
  Timer? _breathTimer;
  
  final List<Color> _bgColors = [
    const Color(0xFFC8DCFF),
    const Color(0xFFE6FFE6),
    const Color(0xFFFFF0DC),
    const Color(0xFFFFFFF0),
    const Color(0xFFF5E6FF),
  ];
  int _bgIndex = 0;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _breathController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _breathController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
    
    _startRandomBlinking();
    _startMessageCycle();
    _playBackgroundMusic();
  }

  void _startRandomBlinking() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_breathingMode) {
        _triggerBlink();
      }
    });
  }

  void _triggerBlink() {
    setState(() {
      _isBlinking = true;
    });
    _blinkController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _blinkController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isBlinking = false;
              });
            }
          });
        }
      });
    });
  }

  void _startMessageCycle() {
    _messageTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _showRandomMessage();
      }
    });
  }

  void _showRandomMessage() {
    final messages = [
      "Take a deep breath...",
      "You're doing great!",
      "Focus on your breathing...",
      "Relax and be present...",
      "You are safe and calm...",
    ];
    
    setState(() {
      _currentMessage = messages[Random().nextInt(messages.length)];
      _messageAlpha = 1.0;
    });
    
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _messageAlpha = 0.0;
        });
      }
    });
  }

  void _toggleBreathingMode() {
    setState(() {
      _breathingMode = !_breathingMode;
    });
    
    if (_breathingMode) {
      _breathingSessions++;
      _breathingDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _totalBreathingDuration++;
      });
      _breathTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted) {
          setState(() {
            _bgIndex = (_bgIndex + 1) % _bgColors.length;
          });
        }
      });
    } else {
      _breathTimer?.cancel();
      _breathingDurationTimer?.cancel();
    }
  }

  void _selectFeeling(Map<String, String> feeling) {
    setState(() {
      _selectedFeeling = feeling;
      _currentMessage = feeling['message']!;
      _messageAlpha = 1.0;
    });
    
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _messageAlpha = 0.0;
        });
      }
    });
  }

  void _playBackgroundMusic() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/calm_music.mp3'));
      setState(() {
        _isPlayingMusic = true;
      });
    } catch (e) {
      print('Error playing background music: $e');
    }
  }

  void _playDingSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/ding.mp3'));
    } catch (e) {
      print('Error playing ding sound: $e');
    }
  }

  void _focusOnBreathing() {
    setState(() {
      _focusCounter++;
      if (_focusCounter >= 3) {
        _focusTriggered = true;
        _currentMessage = "Excellent focus! You're doing amazing!";
        _messageAlpha = 1.0;
        _playDingSound();
      }
    });
    
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _messageAlpha = 0.0;
        });
      }
    });
  }

  Future<void> _saveGameReport() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _sessionStartTime == null) return;
      
      final sessionDuration = DateTime.now().difference(_sessionStartTime!).inSeconds;
      
      final reportData = {
        'gameType': 'eyes_game',
        'sessionDurationSeconds': sessionDuration,
        'focusCounter': _focusCounter,
        'breathingSessions': _breathingSessions,
        'totalBreathingDurationSeconds': _totalBreathingDuration,
        'completedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gameReports')
          .add(reportData);
      
      print('✅ Eyes game report saved successfully!');
    } catch (e) {
      print('❌ Error saving eyes game report: $e');
    }
  }

  @override
  void dispose() {
    _saveGameReport();
    _breathingDurationTimer?.cancel();
    _blinkController.dispose();
    _breathController.dispose();
    _pulseController.dispose();
    _messageTimer?.cancel();
    _breathTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgColors[_bgIndex], _bgColors[_bgIndex].withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Eyes Game - Calm & Focus',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main Eye
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _focusOnBreathing,
                    child: AnimatedBuilder(
                      animation: _breathController,
                      builder: (context, child) {
                        return AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final breathScale = _breathingMode 
                                ? 1.0 + (_breathController.value * 0.3)
                                : 1.0;
                            final pulseScale = 1.0 + (_pulseController.value * 0.1);
                            
                            return Transform.scale(
                              scale: breathScale * pulseScale,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: _isBlinking
                                    ? Center(
                                        child: Text(
                                          _selectedFeeling?['emoji'] ?? '😴',
                                          style: const TextStyle(fontSize: 80),
                                        ),
                                      )
                                    : Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildEye(),
                                            _buildEye(),
                                          ],
                                        ),
                                      ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              // Message Display
              AnimatedOpacity(
                opacity: _messageAlpha,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    _currentMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Controls
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Breathing Mode Toggle
                    ElevatedButton.icon(
                      onPressed: _toggleBreathingMode,
                      icon: Icon(_breathingMode ? Icons.pause : Icons.play_arrow),
                      label: Text(_breathingMode ? 'Stop Breathing' : 'Start Breathing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _breathingMode ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Feelings Selection
                    const Text(
                      'How are you feeling?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _feelings.map((feeling) {
                        return GestureDetector(
                          onTap: () => _selectFeeling(feeling),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                              border: _selectedFeeling == feeling
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            child: Text(
                              feeling['emoji']!,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEye() {
    return Container(
      width: 60,
      height: 60,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
      ),
      child: const Center(
        child: CircleAvatar(
          radius: 15,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
