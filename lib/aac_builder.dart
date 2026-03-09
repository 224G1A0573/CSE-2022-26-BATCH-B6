import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;

class AACBuilder extends StatefulWidget {
  const AACBuilder({super.key});

  @override
  State<AACBuilder> createState() => _AACBuilderState();
}

class _AACBuilderState extends State<AACBuilder> with TickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<SymbolItem> _sentence = [];
  final List<SymbolItem> _recentlyUsed = [];
  String _selectedCategory = 'common';
  bool _isSpeaking = false;
  bool _autoSpeak = false; // Speak each word as added
  
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late AnimationController _successController;

  // Quick Phrases - Pre-made common sentences
  final List<QuickPhrase> _quickPhrases = [
    QuickPhrase('I want water', [Icons.water_drop], Colors.blue),
    QuickPhrase('I need help', [Icons.help], Colors.orange),
    QuickPhrase('I am hungry', [Icons.restaurant], Colors.orange),
    QuickPhrase('I am tired', [Icons.bedtime], Colors.purple),
    QuickPhrase('I want to play', [Icons.play_circle], Colors.green),
    QuickPhrase('I need bathroom', [Icons.wc], Colors.teal),
    QuickPhrase('I am happy', [Icons.sentiment_very_satisfied], Colors.yellow),
    QuickPhrase('I am sad', [Icons.sentiment_very_dissatisfied], Colors.blue),
    QuickPhrase('Thank you', [Icons.celebration], Colors.pink),
    QuickPhrase('I want more', [Icons.add_circle], Colors.cyan),
  ];

  // Expanded symbol library with more practical symbols
  final Map<String, List<SymbolItem>> _symbols = {
    'common': [
      SymbolItem('I', 'I', Icons.person, const Color(0xFFFF6B9D)),
      SymbolItem('want', 'want', Icons.favorite, const Color(0xFFFF6B9D)),
      SymbolItem('need', 'need', Icons.help, const Color(0xFFFF6B9D)),
      SymbolItem('am', 'am', Icons.check, const Color(0xFFFF6B9D)),
      SymbolItem('is', 'is', Icons.check, const Color(0xFFFF6B9D)),
      SymbolItem('yes', 'yes', Icons.check_circle, Colors.green),
      SymbolItem('no', 'no', Icons.cancel, Colors.red),
      SymbolItem('please', 'please', Icons.volunteer_activism, const Color(0xFF6B73FF)),
      SymbolItem('thank you', 'thank you', Icons.celebration, const Color(0xFFFFE66D)),
      SymbolItem('more', 'more', Icons.add_circle, const Color(0xFF4ECDC4)),
      SymbolItem('done', 'done', Icons.done_all, Colors.green),
      SymbolItem('help', 'help', Icons.help_outline, Colors.orange),
      SymbolItem('stop', 'stop', Icons.stop_circle, Colors.red),
      SymbolItem('wait', 'wait', Icons.hourglass_empty, Colors.orange),
      SymbolItem('sorry', 'sorry', Icons.favorite_border, Colors.pink),
    ],
    'food': [
      SymbolItem('apple', 'apple', Icons.apple, Colors.red),
      SymbolItem('banana', 'banana', Icons.eco, const Color(0xFFFFE66D)),
      SymbolItem('water', 'water', Icons.water_drop, Colors.blue),
      SymbolItem('milk', 'milk', Icons.local_drink, Colors.white),
      SymbolItem('bread', 'bread', Icons.bakery_dining, const Color(0xFFD4A574)),
      SymbolItem('cookie', 'cookie', Icons.cookie, const Color(0xFF8B4513)),
      SymbolItem('pizza', 'pizza', Icons.local_pizza, Colors.orange),
      SymbolItem('ice cream', 'ice cream', Icons.icecream, const Color(0xFFFFB6C1)),
      SymbolItem('juice', 'juice', Icons.local_bar, const Color(0xFFFF6B9D)),
      SymbolItem('cereal', 'cereal', Icons.breakfast_dining, const Color(0xFFFFD700)),
      SymbolItem('chicken', 'chicken', Icons.set_meal, Colors.brown),
      SymbolItem('rice', 'rice', Icons.rice_bowl, Colors.white),
      SymbolItem('hungry', 'hungry', Icons.restaurant_menu, Colors.orange),
      SymbolItem('thirsty', 'thirsty', Icons.local_drink, Colors.blue),
    ],
    'actions': [
      SymbolItem('play', 'play', Icons.play_circle, const Color(0xFF4ECDC4)),
      SymbolItem('stop', 'stop', Icons.stop_circle, Colors.red),
      SymbolItem('go', 'go', Icons.arrow_forward, Colors.green),
      SymbolItem('come', 'come', Icons.arrow_back, Colors.blue),
      SymbolItem('eat', 'eat', Icons.restaurant, Colors.orange),
      SymbolItem('drink', 'drink', Icons.local_drink, Colors.blue),
      SymbolItem('sleep', 'sleep', Icons.bedtime, const Color(0xFF6B73FF)),
      SymbolItem('bathroom', 'bathroom', Icons.wc, Colors.teal),
      SymbolItem('wash', 'wash', Icons.wash, Colors.cyan),
      SymbolItem('brush', 'brush', Icons.brush, Colors.purple),
      SymbolItem('read', 'read', Icons.menu_book, Colors.brown),
      SymbolItem('draw', 'draw', Icons.brush, Colors.purple),
      SymbolItem('watch', 'watch', Icons.tv, Colors.blue),
      SymbolItem('listen', 'listen', Icons.headphones, Colors.purple),
    ],
    'emotions': [
      SymbolItem('happy', 'happy', Icons.sentiment_very_satisfied, Colors.yellow),
      SymbolItem('sad', 'sad', Icons.sentiment_very_dissatisfied, Colors.blue),
      SymbolItem('angry', 'angry', Icons.sentiment_very_dissatisfied, Colors.red),
      SymbolItem('tired', 'tired', Icons.sentiment_dissatisfied, Colors.grey),
      SymbolItem('excited', 'excited', Icons.celebration, Colors.orange),
      SymbolItem('scared', 'scared', Icons.warning, Colors.deepOrange),
      SymbolItem('calm', 'calm', Icons.spa, Colors.green),
      SymbolItem('love', 'love', Icons.favorite, Colors.pink),
      SymbolItem('okay', 'okay', Icons.thumb_up, Colors.green),
      SymbolItem('not good', 'not good', Icons.thumb_down, Colors.red),
    ],
    'places': [
      SymbolItem('home', 'home', Icons.home, const Color(0xFF6B73FF)),
      SymbolItem('school', 'school', Icons.school, Colors.orange),
      SymbolItem('park', 'park', Icons.park, Colors.green),
      SymbolItem('store', 'store', Icons.store, Colors.blue),
      SymbolItem('car', 'car', Icons.directions_car, Colors.red),
      SymbolItem('bedroom', 'bedroom', Icons.bed, Colors.purple),
      SymbolItem('kitchen', 'kitchen', Icons.kitchen, Colors.orange),
      SymbolItem('bathroom', 'bathroom', Icons.bathroom, Colors.teal),
      SymbolItem('outside', 'outside', Icons.nature, Colors.green),
    ],
    'people': [
      SymbolItem('mom', 'mom', Icons.face, Colors.pink),
      SymbolItem('dad', 'dad', Icons.face, Colors.blue),
      SymbolItem('teacher', 'teacher', Icons.person, Colors.purple),
      SymbolItem('friend', 'friend', Icons.people, Colors.green),
      SymbolItem('me', 'me', Icons.person_outline, const Color(0xFFFF6B9D)),
      SymbolItem('baby', 'baby', Icons.child_care, Colors.yellow),
      SymbolItem('doctor', 'doctor', Icons.medical_services, Colors.red),
      SymbolItem('you', 'you', Icons.person, Colors.blue),
    ],
  };

  final Map<String, Color> _categoryColors = {
    'common': const Color(0xFFFF6B9D),
    'food': Colors.orange,
    'actions': const Color(0xFF4ECDC4),
    'emotions': Colors.yellow,
    'places': Colors.green,
    'people': Colors.purple,
  };

  final Map<String, IconData> _categoryIcons = {
    'common': Icons.star,
    'food': Icons.restaurant,
    'actions': Icons.directions_run,
    'emotions': Icons.emoji_emotions,
    'places': Icons.place,
    'people': Icons.people,
  };

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Slower for clarity
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _playTapSound() async {
    try {
      // Play a gentle tap sound - you can add audio file later
      // For now, we'll use haptic feedback
    } catch (e) {
      print('Error playing tap sound: $e');
    }
  }

  void _addToSentence(SymbolItem symbol) {
    setState(() {
      _sentence.add(symbol);
      // Add to recently used (keep last 10)
      if (!_recentlyUsed.contains(symbol)) {
        _recentlyUsed.insert(0, symbol);
        if (_recentlyUsed.length > 10) {
          _recentlyUsed.removeLast();
        }
      } else {
        _recentlyUsed.remove(symbol);
        _recentlyUsed.insert(0, symbol);
      }
    });
    
    _bounceController.forward().then((_) => _bounceController.reverse());
    _playTapSound();
    _logSymbolUsage(symbol);
    
    // Auto-speak if enabled
    if (_autoSpeak) {
      _speakWord(symbol.text);
    }
  }

  Future<void> _speakWord(String word) async {
    await _flutterTts.speak(word);
  }

  void _removeFromSentence(int index) {
    setState(() {
      _sentence.removeAt(index);
    });
    _playTapSound();
  }

  void _clearSentence() {
    setState(() {
      _sentence.clear();
    });
    _playTapSound();
  }

  void _addQuickPhrase(QuickPhrase phrase) {
    setState(() {
      _sentence.clear();
      // Parse phrase and add symbols
      final words = phrase.text.toLowerCase().split(' ');
      for (final word in words) {
        // Find matching symbol across all categories
        SymbolItem? foundSymbol;
        for (final category in _symbols.values) {
          try {
            foundSymbol = category.firstWhere(
              (s) => s.text.toLowerCase() == word,
            );
            break; // Found it, stop searching
          } catch (e) {
            // Not found in this category, continue
            continue;
          }
        }
        // If found, add it; otherwise create a simple symbol
        if (foundSymbol != null) {
          _sentence.add(foundSymbol);
        } else {
          // Create a simple symbol for words not in library
          _sentence.add(SymbolItem(
            word,
            word,
            Icons.circle,
            Colors.grey,
          ));
        }
      }
    });
    _successController.forward().then((_) => _successController.reverse());
    _playTapSound();
    _logSentenceUsage(phrase.text);
  }

  Future<void> _speakSentence() async {
    if (_sentence.isEmpty || _isSpeaking) return;

    setState(() {
      _isSpeaking = true;
    });

    final sentence = _sentence.map((s) => s.text).join(' ');
    
    await _flutterTts.speak(sentence);
    
    // Log sentence usage
    _logSentenceUsage(sentence);
    
    // Show success animation
    _successController.forward().then((_) => _successController.reverse());
    
    // Wait for speech to complete
    await Future.delayed(Duration(milliseconds: sentence.length * 150));
    
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _logSymbolUsage(SymbolItem symbol) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ AAC: No user logged in, cannot log symbol usage');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('aac_analytics')
          .add({
        'type': 'symbol_usage',
        'symbol': symbol.text,
        'category': _selectedCategory,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ AAC: Logged symbol usage - ${symbol.text}');
    } catch (e) {
      print('❌ Error logging symbol usage: $e');
    }
  }

  Future<void> _logSentenceUsage(String sentence) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ AAC: No user logged in, cannot log sentence usage');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('aac_analytics')
          .add({
        'type': 'sentence_usage',
        'sentence': sentence,
        'word_count': sentence.split(' ').length,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ AAC: Logged sentence usage - $sentence');
    } catch (e) {
      print('❌ Error logging sentence usage: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B9D), Color(0xFFFFB6B9), Color(0xFFFFE66D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Quick Phrases Section
              _buildQuickPhrases(),
              
              // Sentence Builder Area
              _buildSentenceBuilder(),
              
              // Recently Used Symbols (if any)
              if (_recentlyUsed.isNotEmpty) _buildRecentlyUsed(),
              
              // Category Tabs
              _buildCategoryTabs(),
              
              // Symbol Grid
              Expanded(
                child: _buildSymbolGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              '💬 Talk Builder',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Auto-speak toggle
          Tooltip(
            message: _autoSpeak ? 'Auto-speak ON' : 'Auto-speak OFF',
            child: IconButton(
              icon: Icon(
                _autoSpeak ? Icons.volume_up : Icons.volume_off,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                setState(() {
                  _autoSpeak = !_autoSpeak;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPhrases() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '⚡ Quick Phrases',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickPhrases.length,
              itemBuilder: (context, index) {
                final phrase = _quickPhrases[index];
                return _buildQuickPhraseCard(phrase);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPhraseCard(QuickPhrase phrase) {
    return GestureDetector(
      onTap: () => _addQuickPhrase(phrase),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: phrase.color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(phrase.icons[0], color: phrase.color, size: 24),
            const SizedBox(width: 8),
            Text(
              phrase.text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: phrase.color,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(duration: 200.ms);
  }

  Widget _buildSentenceBuilder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble, color: Color(0xFFFF6B9D), size: 24), // Smaller icon
              const SizedBox(width: 8),
              const Text(
                'Your Sentence:',
                style: TextStyle(
                  fontSize: 18, // Smaller font
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_sentence.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red, size: 24), // Smaller icon
                  onPressed: _clearSentence,
                  tooltip: 'Clear',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12), // Reduced spacing
          // Sentence display - More compact
          if (_sentence.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Reduced padding
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
              ),
              child: const Center(
                child: Text(
                  'Tap symbols or quick phrases\nto build your sentence! ✨',
                  style: TextStyle(
                    fontSize: 16, // Smaller font
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 100, // Max height to prevent overflow
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Reduced padding
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4ECDC4), width: 2), // Thinner border
                  ),
                  child: Wrap(
                    spacing: 8, // Reduced spacing
                    runSpacing: 8, // Reduced spacing
                    alignment: WrapAlignment.start,
                    children: List.generate(_sentence.length, (index) {
                      final symbol = _sentence[index];
                      return _buildSentenceSymbol(symbol, index);
                    }),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12), // Reduced spacing
          // Speak button - BIGGER
          AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _successController]),
            builder: (context, child) {
              return Transform.scale(
                scale: _isSpeaking 
                    ? 1.0 + (_pulseController.value * 0.15)
                    : 1.0 + (_successController.value * 0.1),
                child: ElevatedButton.icon(
                  onPressed: _isSpeaking || _sentence.isEmpty ? null : _speakSentence,
                  icon: Icon(
                    _isSpeaking ? Icons.volume_up : Icons.record_voice_over,
                    size: 28, // Smaller icon
                  ),
                  label: Text(
                    _isSpeaking ? 'Speaking...' : 'SPEAK',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2), // Smaller font
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sentence.isEmpty
                        ? Colors.grey
                        : const Color(0xFF4ECDC4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32, // Reduced padding
                      vertical: 16, // Reduced padding
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: _sentence.isEmpty ? 2 : 12,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceSymbol(SymbolItem symbol, int index) {
    return GestureDetector(
      onTap: () => _removeFromSentence(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Smaller padding
        decoration: BoxDecoration(
          color: symbol.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: symbol.color, width: 2), // Thinner border
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbol.icon, color: symbol.color, size: 18), // Smaller icon
            const SizedBox(width: 6),
            Text(
              symbol.text,
              style: TextStyle(
                fontSize: 14, // Smaller font
                fontWeight: FontWeight.bold,
                color: symbol.color,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.close, size: 14, color: Colors.grey), // Smaller close icon
          ],
        ),
      ),
    ).animate().scale(duration: 200.ms);
  }

  Widget _buildRecentlyUsed() {
    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '⭐ Recently Used',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentlyUsed.length,
              itemBuilder: (context, index) {
                final symbol = _recentlyUsed[index];
                return GestureDetector(
                  onTap: () => _addToSentence(symbol),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          symbol.color,
                          symbol.color.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: symbol.color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(symbol.icon, color: Colors.white, size: 30),
                        const SizedBox(height: 4),
                        Text(
                          symbol.text,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ).animate().scale(duration: 200.ms);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 65,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _symbols.keys.map((category) {
          final isSelected = _selectedCategory == category;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? _categoryColors[category] ?? Colors.grey
                    : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: (_categoryColors[category] ?? Colors.grey)
                              .withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _categoryIcons[category] ?? Icons.category,
                    color: isSelected ? Colors.white : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().scale(duration: 200.ms);
        }).toList(),
      ),
    );
  }

  Widget _buildSymbolGrid() {
    final symbols = _symbols[_selectedCategory] ?? [];
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // More columns = smaller symbols
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        return _buildSymbolCard(symbol);
      },
    );
  }

  Widget _buildSymbolCard(SymbolItem symbol) {
    return GestureDetector(
      onTap: () => _addToSentence(symbol),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              symbol.color,
              symbol.color.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: symbol.color.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              symbol.icon,
              size: 32, // Much smaller icons
              color: Colors.white,
            ),
            const SizedBox(height: 6),
            Text(
              symbol.text,
              style: const TextStyle(
                fontSize: 11, // Much smaller text
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ).animate()
        .scale(delay: (math.Random().nextInt(200)).ms, duration: 300.ms)
        .shimmer(delay: 500.ms, duration: 1000.ms),
    );
  }
}

class SymbolItem {
  final String id;
  final String text;
  final IconData icon;
  final Color color;

  SymbolItem(this.id, this.text, this.icon, this.color);
}

class QuickPhrase {
  final String text;
  final List<IconData> icons;
  final Color color;

  QuickPhrase(this.text, this.icons, this.color);
}
