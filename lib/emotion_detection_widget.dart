import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'emotion_detection_service.dart';

class EmotionDetectionWidget extends StatefulWidget {
  const EmotionDetectionWidget({super.key});

  @override
  State<EmotionDetectionWidget> createState() => _EmotionDetectionWidgetState();
}

class _EmotionDetectionWidgetState extends State<EmotionDetectionWidget> {
  final EmotionDetectionService _emotionService = EmotionDetectionService();
  bool _isInitialized = false;
  bool _isDetecting = false;
  String _currentEmotion = 'neutral';
  double _confidence = 0.0;
  List<Map<String, dynamic>> _recentEmotions = [];
  Map<String, int> _emotionStats = {};

  @override
  void initState() {
    super.initState();
    _initializeEmotionDetection();
    _loadRecentEmotions();
    _loadEmotionStats();
  }

  Future<void> _initializeEmotionDetection() async {
    final success = await _emotionService.initialize();
    if (success) {
      setState(() {
        _isInitialized = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Failed to initialize camera. Please check permissions.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadRecentEmotions() async {
    final emotions = await _emotionService.getRecentEmotions(limit: 5);
    setState(() {
      _recentEmotions = emotions;
    });
  }

  Future<void> _loadEmotionStats() async {
    final stats = await _emotionService.getEmotionStats();
    setState(() {
      _emotionStats = stats;
    });
  }

  Future<void> _toggleEmotionDetection() async {
    if (!_isInitialized) return;

    if (_isDetecting) {
      await _emotionService.stopEmotionDetection();
      setState(() {
        _isDetecting = false;
      });
    } else {
      await _emotionService.startEmotionDetection();
      setState(() {
        _isDetecting = true;
      });

      // Start periodic updates
      _startPeriodicUpdates();
    }
  }

  // Manual emotion detection for testing
  Future<void> _detectEmotionOnce() async {
    if (!_isInitialized) return;

    try {
      // This will trigger one emotion detection and show debug info
      await _emotionService.detectAndLogEmotion();
      // Refresh the UI
      _loadRecentEmotions();
      _loadEmotionStats();
    } catch (e) {
      print('Error in manual detection: $e');
    }
  }

  void _startPeriodicUpdates() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_isDetecting && mounted) {
        _loadRecentEmotions();
        _loadEmotionStats();
        _startPeriodicUpdates();
      }
    });
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'fear':
        return '😨';
      case 'surprise':
        return '😲';
      case 'disgust':
        return '🤢';
      case 'neutral':
      default:
        return '😐';
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.green;
      case 'sad':
        return Colors.blue;
      case 'angry':
        return Colors.red;
      case 'fear':
        return Colors.purple;
      case 'surprise':
        return Colors.orange;
      case 'disgust':
        return Colors.brown;
      case 'neutral':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotion Detection'),
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
        child: _isInitialized ? _buildEmotionDetectionUI() : _buildLoadingUI(),
      ),
    );
  }

  Widget _buildLoadingUI() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionDetectionUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Camera Preview
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _emotionService.cameraController != null
                  ? CameraPreview(_emotionService.cameraController!)
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: Text(
                          'Camera not available',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Current Emotion Display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
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
                  _getEmotionEmoji(_currentEmotion),
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentEmotion.toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getEmotionColor(_currentEmotion),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Control Buttons
          Row(
            children: [
              // Main Control Button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _toggleEmotionDetection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDetecting ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
                        const SizedBox(width: 8),
                        Text(
                          _isDetecting ? 'Stop' : 'Start',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Manual Detection Button
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _detectEmotionOnce,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent Emotions
          _buildRecentEmotionsCard(),
          const SizedBox(height: 20),

          // Emotion Statistics
          _buildEmotionStatsCard(),
        ],
      ),
    );
  }

  Widget _buildRecentEmotionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
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
          const Text(
            'Recent Emotions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_recentEmotions.isEmpty)
            const Text(
              'No emotions detected yet',
              style: TextStyle(color: Colors.grey),
            )
          else
            Column(
              children: _recentEmotions.map((emotion) {
                final timestamp = emotion['timestamp'] as Timestamp?;
                final timeAgo = timestamp != null
                    ? _getTimeAgo(timestamp.toDate())
                    : 'Unknown';

                return ListTile(
                  leading: Text(
                    _getEmotionEmoji(emotion['emotion']),
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    emotion['emotion'].toString().toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getEmotionColor(emotion['emotion']),
                    ),
                  ),
                  subtitle: Text(timeAgo),
                  trailing: Text(
                    '${(emotion['confidence'] * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmotionStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
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
          const Text(
            'Emotion Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_emotionStats.isEmpty)
            const Text(
              'No emotion data available',
              style: TextStyle(color: Colors.grey),
            )
          else
            Column(
              children: _emotionStats.entries.map((entry) {
                final total = _emotionStats.values.reduce((a, b) => a + b);
                final percentage =
                    (entry.value / total * 100).toStringAsFixed(1);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        _getEmotionEmoji(entry.key),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _getEmotionColor(entry.key),
                          ),
                        ),
                      ),
                      Text(
                        '$percentage% (${entry.value})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _emotionService.dispose();
    super.dispose();
  }
}
