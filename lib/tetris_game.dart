import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TetrisGame extends StatefulWidget {
  const TetrisGame({super.key});

  @override
  State<TetrisGame> createState() => _TetrisGameState();
}

class _TetrisGameState extends State<TetrisGame> {
  static const int gridWidth = 10;
  static const int gridHeight = 18;
  static const int blockSize = 30;

  List<List<String>> _grid = [];
  List<List<String>> _currentPiece = [];
  int _pieceX = 0;
  int _pieceY = 0;
  int _pieceType = 0;
  int _pieceRotation = 0;
  int _score = 0;
  int _level = 0;
  int _linesCleared = 0;
  int _dropTimer = 0;
  int _dropDelay = 700;
  bool _gameOver = false;
  bool _isPaused = false;
  int _bestScore = 0;

  Timer? _gameTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingMusic = false;

  final List<List<List<String>>> _pieces = [
    // I piece
    [
      ['    ', 'iiii', '    ', '    '],
      [' i  ', ' i  ', ' i  ', ' i  '],
    ],
    // O piece
    [
      ['    ', ' oo ', ' oo ', '    '],
    ],
    // J piece
    [
      ['    ', 'jjj ', '  j ', '    '],
      [' j  ', ' j  ', 'jj  ', '    '],
      ['j   ', 'jjj ', '    ', '    '],
      ['jj  ', ' j  ', ' j  ', '    '],
    ],
    // L piece
    [
      ['    ', 'lll ', 'l   ', '    '],
      [' l  ', ' l  ', ' ll ', '    '],
      ['  l ', 'lll ', '    ', '    '],
      ['ll  ', ' l  ', ' l  ', '    '],
    ],
    // T piece
    [
      ['    ', 'ttt ', ' t  ', '    '],
      [' t  ', ' tt ', ' t  ', '    '],
      [' t  ', 'ttt ', '    ', '    '],
      [' t  ', 'tt  ', ' t  ', '    '],
    ],
    // S piece
    [
      ['    ', ' ss ', 'ss  ', '    '],
      ['s   ', 'ss  ', ' s  ', '    '],
    ],
    // Z piece
    [
      ['    ', 'zz  ', ' zz ', '    '],
      [' z  ', 'zz  ', 'z   ', '    '],
    ],
  ];

  final Map<String, Color> _colors = {
    ' ': const Color(0xFF1E1E1E),
    'i': const Color(0xFF78C3F3),
    'j': const Color(0xFFECF7A8),
    'l': const Color(0xFF7CDAB9),
    'o': const Color(0xFFEAB175),
    's': const Color(0xFFD388EC),
    't': const Color(0xFFF893C4),
    'z': const Color(0xFFA9DD76),
  };

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _playBackgroundMusic();
  }

  void _initializeGame() {
    _grid = List.generate(gridHeight, (i) => List.filled(gridWidth, ' '));
    _spawnNewPiece();
    _startGameTimer();
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_gameOver && !_isPaused) {
        setState(() {
          _dropTimer += 50;
          if (_dropTimer >= _dropDelay) {
            _dropTimer = 0;
            _movePieceDown();
          }
        });
      }
    });
  }

  void _spawnNewPiece() {
    _pieceType = Random().nextInt(_pieces.length);
    _pieceRotation = 0;
    _currentPiece = _pieces[_pieceType][_pieceRotation]
        .map((row) => row.split(''))
        .toList();
    _pieceX = gridWidth ~/ 2 - _currentPiece[0].length ~/ 2;
    _pieceY = 0;

    if (_checkCollision()) {
      _gameOver = true;
      _saveGameReport();
      _gameTimer?.cancel();
    }
  }

  bool _checkCollision() {
    for (int y = 0; y < _currentPiece.length; y++) {
      for (int x = 0; x < _currentPiece[y].length; x++) {
        if (_currentPiece[y][x] != ' ') {
          int newX = _pieceX + x;
          int newY = _pieceY + y;

          if (newX < 0 ||
              newX >= gridWidth ||
              newY >= gridHeight ||
              (newY >= 0 && _grid[newY][newX] != ' ')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _placePiece() {
    for (int y = 0; y < _currentPiece.length; y++) {
      for (int x = 0; x < _currentPiece[y].length; x++) {
        if (_currentPiece[y][x] != ' ') {
          int newX = _pieceX + x;
          int newY = _pieceY + y;
          if (newY >= 0) {
            _grid[newY][newX] = _currentPiece[y][x];
          }
        }
      }
    }
    _clearLines();
    _spawnNewPiece();
  }

  void _clearLines() {
    int linesClearedThisRound = 0;

    for (int y = gridHeight - 1; y >= 0; y--) {
      if (_grid[y].every((cell) => cell != ' ')) {
        _grid.removeAt(y);
        _grid.insert(0, List.filled(gridWidth, ' '));
        linesClearedThisRound++;
        y++; // Check the same line again
      }
    }

    if (linesClearedThisRound > 0) {
      _linesCleared += linesClearedThisRound;
      _score += linesClearedThisRound * 100 * (_level + 1);
      _level = _linesCleared ~/ 10;
      _dropDelay = max(100, 700 - (_level * 50));
    }
  }

  void _movePieceDown() {
    _pieceY++;
    if (_checkCollision()) {
      _pieceY--;
      _placePiece();
    }
  }

  void _movePieceLeft() {
    _pieceX--;
    if (_checkCollision()) {
      _pieceX++;
    }
  }

  void _movePieceRight() {
    _pieceX++;
    if (_checkCollision()) {
      _pieceX--;
    }
  }

  void _rotatePiece() {
    int newRotation = (_pieceRotation + 1) % _pieces[_pieceType].length;
    List<List<String>> newPiece = _pieces[_pieceType][newRotation]
        .map((row) => row.split(''))
        .toList();

    List<List<String>> oldPiece = _currentPiece;
    int oldRotation = _pieceRotation;

    _currentPiece = newPiece;
    _pieceRotation = newRotation;

    if (_checkCollision()) {
      _currentPiece = oldPiece;
      _pieceRotation = oldRotation;
    }
  }

  void _dropPiece() {
    while (!_checkCollision()) {
      _pieceY++;
    }
    _pieceY--;
    _placePiece();
  }

  void _pauseGame() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _saveGameReport() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final reportData = {
        'gameType': 'tetris_game',
        'score': _score,
        'level': _level,
        'linesCleared': _linesCleared,
        'bestScore': _bestScore,
        'completedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gameReports')
          .add(reportData);
      
      print('✅ Tetris game report saved successfully!');
    } catch (e) {
      print('❌ Error saving tetris game report: $e');
    }
  }

  void _resetGame() {
    _gameTimer?.cancel();
    setState(() {
      _gameOver = false;
      _isPaused = false;
      _score = 0;
      _level = 0;
      _linesCleared = 0;
      _dropDelay = 700;
      _dropTimer = 0;
    });
    _initializeGame();
  }

  void _playBackgroundMusic() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/background.mp3'));
      setState(() {
        _isPlayingMusic = true;
      });
    } catch (e) {
      print('Error playing background music: $e');
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _gameOver ? _buildGameOverScreen() : _buildGameScreen(),
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    return Column(
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
                'Tetris',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                onPressed: _pauseGame,
                color: Colors.white,
              ),
            ],
          ),
        ),

        // Game Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text('Score', style: TextStyle(color: Colors.white70)),
                  Text(
                    '$_score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text('Level', style: TextStyle(color: Colors.white70)),
                  Text(
                    '$_level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text('Lines', style: TextStyle(color: Colors.white70)),
                  Text(
                    '$_linesCleared',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AspectRatio(
                aspectRatio: gridWidth / gridHeight,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridWidth,
                  ),
                  itemCount: gridWidth * gridHeight,
                  itemBuilder: (context, index) {
                    int x = index % gridWidth;
                    int y = index ~/ gridWidth;

                    String cell = _grid[y][x];

                    // Check if this cell is part of the current piece
                    int pieceX = x - _pieceX;
                    int pieceY = y - _pieceY;
                    if (pieceX >= 0 &&
                        pieceX < _currentPiece[0].length &&
                        pieceY >= 0 &&
                        pieceY < _currentPiece.length &&
                        _currentPiece[pieceY][pieceX] != ' ') {
                      cell = _currentPiece[pieceY][pieceX];
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: _colors[cell] ?? Colors.grey[800],
                        border: Border.all(
                          color: Colors.black.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isPaused ? null : _movePieceLeft,
                    child: const Icon(Icons.arrow_back),
                  ),
                  ElevatedButton(
                    onPressed: _isPaused ? null : _rotatePiece,
                    child: const Icon(Icons.rotate_right),
                  ),
                  ElevatedButton(
                    onPressed: _isPaused ? null : _movePieceRight,
                    child: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isPaused ? null : _dropPiece,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('DROP'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gamepad, size: 60, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Game Over!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Final Score: $_score',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Lines Cleared: $_linesCleared',
              style: const TextStyle(fontSize: 16),
            ),
            if (_bestScore > 0)
              Text(
                'Best Score: $_bestScore',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _resetGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Play Again'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Back to Games'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
