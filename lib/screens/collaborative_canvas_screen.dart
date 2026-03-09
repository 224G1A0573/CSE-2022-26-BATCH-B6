import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/collaborative_canvas_service.dart';
import '../widgets/collaborative_canvas_painter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CollaborativeCanvasScreen extends StatefulWidget {
  final String sessionId;
  final String partnerName;
  final bool isTherapist;

  const CollaborativeCanvasScreen({
    super.key,
    required this.sessionId,
    required this.partnerName,
    required this.isTherapist,
  });

  @override
  State<CollaborativeCanvasScreen> createState() =>
      _CollaborativeCanvasScreenState();
}

class _CollaborativeCanvasScreenState extends State<CollaborativeCanvasScreen> {
  final user = FirebaseAuth.instance.currentUser;
  List<DrawingPoint> _points = [];
  Color _selectedColor = Colors.blue;
  double _strokeWidth = 5.0;
  bool _isEraser = false;

  // Emotion detection (read from Firestore instead of camera)
  String _currentEmotion = 'neutral';
  Color _emotionColor = Colors.blue;
  bool _emotionDetectionEnabled = false;
  Timer? _emotionTimer;
  StreamSubscription? _canvasSubscription;

  // Session tracking for insights
  DateTime? _sessionStartTime;
  final Map<String, int> _emotionCounts = {};
  bool _hasAutoSaved = false; // Track if auto-save has been triggered

  final GlobalKey _canvasKey = GlobalKey();

  // Emotion to color mapping
  final Map<String, Color> _emotionColors = {
    'happy': const Color(0xFFFFD700), // Gold
    'sad': const Color(0xFF4A90E2), // Blue
    'angry': const Color(0xFFE74C3C), // Red
    'surprised': const Color(0xFFFF69B4), // Pink
    'fear': const Color(0xFF9B59B6), // Purple
    'neutral': const Color(0xFF95A5A6), // Gray
  };

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _listenToCanvas();
    _initializeEmotionDetection();
  }

  @override
  void dispose() {
    _emotionTimer?.cancel();
    _canvasSubscription?.cancel();
    super.dispose();
  }

  void _listenToCanvas() {
    _canvasSubscription =
        CollaborativeCanvasService.getDrawingPoints(widget.sessionId).listen(
            (points) {
      if (mounted) {
        setState(() {
          _points = points;
        });
        
        // Auto-save for children when they draw alone and exceed 100 strokes
        if (!widget.isTherapist && !_hasAutoSaved && points.length >= 100) {
          _checkAndAutoSave();
        }
      }
    }, onError: (error) {
      if (mounted) {
        print('❌ Stream error: $error');
      }
    });
  }

  Future<void> _checkAndAutoSave() async {
    // Only auto-save once
    if (_hasAutoSaved) return;
    
    // Get session info to check if child is drawing alone
    try {
      final sessionSnapshot = await FirebaseDatabase.instance
          .ref('canvasSessions/${widget.sessionId}')
          .get();
      
      final childId = sessionSnapshot.child('childId').value as String?;
      final therapistId = sessionSnapshot.child('therapistId').value as String?;
      
      // Check if current user is the child
      final isCurrentUserChild = childId != null && user!.uid == childId;
      
      if (!isCurrentUserChild) return; // Not the child, don't auto-save
      
      // Count strokes by user to see if child is drawing alone
      int childStrokes = 0;
      int therapistStrokes = 0;
      
      for (var point in _points) {
        if (point.userId == childId) {
          childStrokes++;
        } else if (therapistId != null && point.userId == therapistId) {
          therapistStrokes++;
        }
      }
      
      // Only auto-save if child has drawn significantly more than therapist (drawing alone)
      // Or if therapist hasn't drawn at all
      if (childStrokes >= 100 && (therapistStrokes == 0 || childStrokes > therapistStrokes * 2)) {
        _hasAutoSaved = true;
        await _autoSaveChildArtwork(childId, therapistId);
      }
    } catch (e) {
      print('❌ Error checking for auto-save: $e');
    }
  }

  Future<void> _autoSaveChildArtwork(String? childId, String? therapistId) async {
    if (childId == null || user == null) return;
    
    try {
      // Generate a simple name based on timestamp
      final timestamp = DateTime.now();
      final artworkName = 'My Drawing - ${timestamp.day}/${timestamp.month}/${timestamp.year}';
      
      // Generate simple AI insights
      final aiInsights = _generateAutoSaveInsights();
      
      // Save artwork (similar to manual save but without dialog)
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final base64Image = base64Encode(pngBytes);

      // Get therapist ID (from session or child's profile)
      String? finalTherapistId = therapistId;
      
      // If no therapist in session, try to get from child's profile
      if (finalTherapistId == null) {
        try {
          final childDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(childId)
              .get();
          finalTherapistId = childDoc.data()?['therapistId'] as String?;
        } catch (e) {
          print('⚠️ Could not get therapistId from child profile: $e');
        }
      }

      final artworkData = {
        'name': artworkName,
        'description': '', // Empty - therapist can add report later
        'aiInsights': aiInsights,
        'sessionId': widget.sessionId,
        'partnerName': widget.isTherapist ? widget.partnerName : 'Solo Drawing',
        'savedAt': FieldValue.serverTimestamp(),
        'imageBase64': base64Image,
        'emotionCounts': _emotionCounts,
        'sessionDurationMinutes':
            DateTime.now().difference(_sessionStartTime!).inMinutes,
        'totalStrokes': _points.length,
        'therapistId': finalTherapistId, // Use the final therapist ID
        'childId': childId,
        'sentToParent': false,
        'autoSaved': true, // Mark as auto-saved
      };

      // Save to child's collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('canvasArtwork')
          .add(artworkData);
      print('✅ Auto-saved artwork to child ($childId) canvasArtwork collection');

      // Also save to therapist's collection if therapist exists
      if (finalTherapistId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(finalTherapistId)
            .collection('canvasArtwork')
            .add(artworkData);
        print('✅ Auto-saved artwork to therapist ($finalTherapistId) canvasArtwork collection');
      } else {
        print('⚠️ No therapist found - artwork saved only to child collection');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎨 Your drawing was automatically saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error auto-saving artwork: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error auto-saving: $e')),
        );
      }
    }
  }

  String _generateAutoSaveInsights() {
    final insights = <String>[];
    
    if (_points.length > 100) {
      insights.add('High engagement with ${_points.length} strokes');
    }
    
    final sessionDuration = DateTime.now().difference(_sessionStartTime!).inMinutes;
    if (sessionDuration > 10) {
      insights.add('Extended drawing session (${sessionDuration} minutes)');
    }
    
    if (_emotionCounts.isNotEmpty) {
      final dominantEmotion = _emotionCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      insights.add('Dominant emotion: ${dominantEmotion.key}');
    }
    
    insights.add('Solo drawing activity - child engaged independently');
    
    return insights.join('. ') + '.';
  }

  Future<void> _initializeEmotionDetection() async {
    // Read emotions from Firestore (background service already tracking)
    setState(() {
      _emotionDetectionEnabled = true;
    });

    _startEmotionDetection();
  }

  void _startEmotionDetection() {
    // Listen to the emotion data that background service is already writing
    _emotionTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_emotionDetectionEnabled || user == null) return;

      try {
        // Get the latest emotion from Firestore
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('emotions')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final emotionData = snapshot.docs.first.data();
          final emotion = emotionData['emotion'] as String? ?? 'neutral';

          // Track emotion counts
          _emotionCounts[emotion] = (_emotionCounts[emotion] ?? 0) + 1;

          setState(() {
            _currentEmotion = emotion;
            _emotionColor = _emotionColors[emotion] ?? Colors.blue;
            if (!_isEraser) {
              _selectedColor = _emotionColor;
            }
          });
        }
      } catch (e) {
        print('Error reading emotion: $e');
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final point = DrawingPoint(
      id: CollaborativeCanvasService.generatePointId(),
      x: details.localPosition.dx,
      y: details.localPosition.dy,
      color: CollaborativeCanvasService.colorToHex(
        _isEraser ? Colors.white : _selectedColor,
      ),
      strokeWidth: _isEraser ? 20.0 : _strokeWidth,
      userId: user!.uid,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Add point locally first for instant feedback
    setState(() {
      _points.add(point);
    });

    // Then sync to Firebase (don't wait for it)
    CollaborativeCanvasService.addDrawingPoint(
      sessionId: widget.sessionId,
      point: point,
    ).catchError((e) {
      print('❌ Error sending point: $e');
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final point = DrawingPoint(
      id: CollaborativeCanvasService.generatePointId(),
      x: details.localPosition.dx,
      y: details.localPosition.dy,
      color: CollaborativeCanvasService.colorToHex(
        _isEraser ? Colors.white : _selectedColor,
      ),
      strokeWidth: _isEraser ? 20.0 : _strokeWidth,
      userId: user!.uid,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Add point locally first for instant feedback
    setState(() {
      _points.add(point);
    });

    // Then sync to Firebase (don't wait for it)
    CollaborativeCanvasService.addDrawingPoint(
      sessionId: widget.sessionId,
      point: point,
    ).catchError((e) {
      print('❌ Error in pan update: $e');
    });
  }

  void _showSaveArtworkDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final insightsController = TextEditingController();
    bool sendToParent = true; // Track checkbox state

    // Calculate insights
    final duration = DateTime.now().difference(_sessionStartTime!);
    final minutes = duration.inMinutes;
    final mostCommonEmotion = _emotionCounts.isNotEmpty
        ? _emotionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'neutral';

    // Generate AI insights
    final aiInsights = '''
📊 Session Duration: $minutes minutes
🎨 Total Strokes: ${_points.length}
😊 Emotions Detected:
${_emotionCounts.entries.map((e) => '   ${_getEmotionEmoji(e.key)} ${e.key}: ${e.value} times').join('\n')}

🎯 Most Common Emotion: ${_getEmotionEmoji(mostCommonEmotion)} $mostCommonEmotion

💡 Behavioral Insights:
- Drawing engagement: ${_points.length > 100 ? 'High' : _points.length > 50 ? 'Medium' : 'Low'}
- Emotional stability: ${_emotionCounts.length <= 2 ? 'Stable' : 'Varied'}
- Session focus: ${minutes > 5 ? 'Extended' : 'Brief'}
''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💾 Save Artwork',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '🎨 Artwork Name',
                  hintText: 'e.g., Happy Trees',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '📝 Your Insights & Description',
                  hintText: 'Add your observations about the session...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('🤖 AI-Generated Insights:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(aiInsights, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setDialogState) => Row(
                  children: [
                    Checkbox(
                      value: sendToParent,
                      onChanged: (value) {
                        setDialogState(() {
                          sendToParent = value ?? true;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text('Send to Parent Dashboard',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }
              Navigator.pop(context);
              _saveCanvasWithInsights(
                nameController.text,
                descriptionController.text,
                aiInsights,
                sendToParent,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B73FF)),
            child: const Text('Save & Send'),
          ),
        ],
      ),
    );
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'surprised':
        return '😲';
      case 'fear':
        return '😨';
      default:
        return '😐';
    }
  }

  Future<void> _saveCanvasWithInsights(String name, String description,
      String aiInsights, bool sendToParent) async {
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/canvas_$timestamp.png');
      await file.writeAsBytes(pngBytes);

      // Convert image to base64 for Firestore storage
      final base64Image = base64Encode(pngBytes);

      // Get child ID from session
      final sessionSnapshot = await FirebaseDatabase.instance
          .ref('canvasSessions/${widget.sessionId}')
          .get();
      final childId = sessionSnapshot.child('childId').value as String?;
      final therapistId = sessionSnapshot.child('therapistId').value as String?;

      final artworkData = {
        'name': name,
        'description': description,
        'aiInsights': aiInsights,
        'sessionId': widget.sessionId,
        'partnerName': widget.partnerName,
        'savedAt': FieldValue.serverTimestamp(),
        'imageBase64': base64Image,
        'emotionCounts': _emotionCounts,
        'sessionDurationMinutes':
            DateTime.now().difference(_sessionStartTime!).inMinutes,
        'totalStrokes': _points.length,
        'therapistId': therapistId,
        'childId': childId,
        'sentToParent': sendToParent,
      };

      // Determine if current user is the child or therapist
      final isCurrentUserChild = childId != null && user!.uid == childId;
      final isCurrentUserTherapist = therapistId != null && user!.uid == therapistId;

      // Save to child's collection (ALWAYS - this is the source of truth)
      // This ensures therapist can see all child artwork
      if (childId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .collection('canvasArtwork')
            .add(artworkData);
        print('✅ Artwork saved to child ($childId) canvasArtwork collection');
      } else if (isCurrentUserChild) {
        // Fallback: if childId not in session but user is child
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('canvasArtwork')
            .add({
          ...artworkData,
          'childId': user!.uid,
        });
        print('✅ Artwork saved to child ($user!.uid) canvasArtwork collection (fallback)');
      }

      // Save to therapist's collection (if therapist is saving OR if child is saving and therapistId exists)
      if (isCurrentUserTherapist) {
        // Therapist saving - save to their own collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('canvasArtwork')
            .add(artworkData);
        print('✅ Artwork saved to therapist ($user!.uid) canvasArtwork collection');
      } else if (isCurrentUserChild && therapistId != null) {
        // Child saving - also save to therapist's collection so they can see it
        await FirebaseFirestore.instance
            .collection('users')
            .doc(therapistId)
            .collection('canvasArtwork')
            .add(artworkData);
        print('✅ Artwork saved to therapist ($therapistId) canvasArtwork collection (from child)');
      }

      // Get parent ID from child's data and save to parent if requested
      if (childId != null) {
        final childDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .get();

        if (childDoc.exists && sendToParent) {
          final guardianEmail = childDoc.data()?['guardianEmail'] as String?;

          // Save to parent's collection ONLY if sendToParent is true
          if (guardianEmail != null) {
            // Find parent by guardianEmail
            final parentQuery = await FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'parent')
                .where('email', isEqualTo: guardianEmail)
                .limit(1)
                .get();

            if (parentQuery.docs.isNotEmpty) {
              final parentId = parentQuery.docs.first.id;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(parentId)
                  .collection('childArtwork')
                  .add({
                ...artworkData,
                'childName': childDoc.data()?['name'] ??
                    childDoc.data()?['displayName'] ??
                    'Child',
              });
              print('✅ Artwork saved to parent ($parentId) childArtwork');
            } else {
              print('⚠️ Parent not found for guardianEmail: $guardianEmail');
            }
          } else {
            print('⚠️ Child has no guardianEmail set');
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sendToParent
              ? '🎨 Artwork saved & sent to parent successfully!'
              : '🎨 Artwork saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎨 Collaborative Canvas',
                style: TextStyle(fontSize: 18)),
            Text(
              'Drawing with ${widget.partnerName}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6B73FF),
        foregroundColor: Colors.white,
        actions: [
          if (_emotionDetectionEnabled)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _emotionColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _emotionColor, width: 2),
              ),
              child: Row(
                children: [
                  Text(
                    _getEmotionEmoji(_currentEmotion),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentEmotion.toUpperCase(),
                    style: TextStyle(
                      color: _emotionColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          // Only show Save button for therapists
          if (widget.isTherapist)
            IconButton(
              onPressed: _showSaveArtworkDialog,
              icon: const Icon(Icons.save),
              tooltip: 'Save Artwork',
            ),
          // Only show Clear button for therapists
          if (widget.isTherapist)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Canvas?'),
                    content: const Text(
                        'This will erase everything for both of you!'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          CollaborativeCanvasService.clearCanvas(
                              widget.sessionId);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Canvas',
            ),
        ],
      ),
      body: Column(
        children: [
          // Drawing tools
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Brush/Eraser toggle
                Row(
                  children: [
                    ChoiceChip(
                      label: const Row(
                        children: [
                          Icon(Icons.brush, size: 18),
                          SizedBox(width: 6),
                          Text('Brush'),
                        ],
                      ),
                      selected: !_isEraser,
                      onSelected: (selected) {
                        setState(() {
                          _isEraser = false;
                          if (_emotionDetectionEnabled) {
                            _selectedColor = _emotionColor;
                          }
                        });
                      },
                      selectedColor: const Color(0xFF6B73FF).withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Row(
                        children: [
                          Icon(Icons.auto_fix_high, size: 18),
                          SizedBox(width: 6),
                          Text('Eraser'),
                        ],
                      ),
                      selected: _isEraser,
                      onSelected: (selected) {
                        setState(() => _isEraser = true);
                      },
                      selectedColor: Colors.red.withOpacity(0.3),
                    ),
                    const Spacer(),
                    if (!_isEraser)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.grey[300]!, width: 2),
                        ),
                        width: 40,
                        height: 40,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Color palette (only if not eraser)
                if (!_isEraser) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildColorButton(Colors.red),
                      _buildColorButton(Colors.orange),
                      _buildColorButton(Colors.yellow),
                      _buildColorButton(Colors.green),
                      _buildColorButton(Colors.blue),
                      _buildColorButton(Colors.purple),
                      _buildColorButton(Colors.pink),
                      _buildColorButton(Colors.brown),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Stroke width slider
                Row(
                  children: [
                    const Icon(Icons.line_weight, size: 20),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 2,
                        max: 20,
                        divisions: 18,
                        label: _strokeWidth.round().toString(),
                        onChanged: (value) {
                          setState(() => _strokeWidth = value);
                        },
                        activeColor: const Color(0xFF6B73FF),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: _strokeWidth,
                          height: _strokeWidth,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    child: CustomPaint(
                      painter: CollaborativeCanvasPainter(
                        points: _points,
                        currentUserId: user?.uid,
                        highlightColor: _emotionColor,
                      ),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _isEraser = false;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
