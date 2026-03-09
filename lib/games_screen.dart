import 'package:flutter/material.dart';
import 'eyes_game.dart';
import 'repeat_game.dart';
import 'tetris_game.dart';
import 'emotion_character_game.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        backgroundColor: const Color(0xFFFF6B9D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B9D), Color(0xFFFFB6B9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Your Game!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Have fun and learn while playing!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildGameCard(
                        context: context,
                        title: 'Eyes Game',
                        subtitle: 'Calm & Focus',
                        icon: Icons.visibility,
                        color: const Color(0xFF4ECDC4),
                        description:
                            'Meditation and breathing exercises to help you relax and focus.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EyesGame(),
                            ),
                          );
                        },
                      ),
                      _buildGameCard(
                        context: context,
                        title: 'Repeat Game',
                        subtitle: 'Memory Challenge',
                        icon: Icons.memory,
                        color: const Color(0xFFFFE66D),
                        description:
                            'Test your memory by repeating the color patterns!',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RepeatGame(),
                            ),
                          );
                        },
                      ),
                      _buildGameCard(
                        context: context,
                        title: 'Tetris',
                        subtitle: 'Puzzle Fun',
                        icon: Icons.grid_4x4,
                        color: const Color(0xFF95E1D3),
                        description: 'Classic block-stacking puzzle game.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TetrisGame(),
                            ),
                          );
                        },
                      ),
                      _buildGameCard(
                        context: context,
                        title: 'Emotion Friend',
                        subtitle: 'Learn Emotions',
                        icon: Icons.sentiment_satisfied,
                        color: const Color(0xFF9B59B6),
                        description:
                            'Meet your emotion friend! Learn about feelings in a fun way.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmotionCharacterGame(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
