import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'background_emotion_service.dart';
import 'background_eye_tracking_service.dart';
import 'user_data_migration.dart';
import 'games_screen.dart';
import 'emergency_alert_service.dart';
import 'screens/canvas_session_launcher.dart';
import 'aac_builder.dart';
import 'social_skills_game.dart';

class ChildDashboard extends StatefulWidget {
  const ChildDashboard({super.key});

  @override
  State<ChildDashboard> createState() => _ChildDashboardState();
}

class _ChildDashboardState extends State<ChildDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  final BackgroundEmotionService _backgroundService =
      BackgroundEmotionService();
  final BackgroundEyeTrackingService _eyeTrackingService =
      BackgroundEyeTrackingService();
  final UserDataMigration _migration = UserDataMigration();
  final EmergencyAlertService _emergencyService = EmergencyAlertService();
  Map<String, dynamic>? childData;
  bool isLoading = true;
  bool _backgroundDetectionActive = false;

  @override
  void initState() {
    super.initState();
    fetchChildData();
    _migrateUserData();
    _initializeBackgroundEmotionDetection();
    // _initializeBackgroundEyeTracking(); // DISABLED - camera conflict with emotion detection
    _initializeEmergencyMonitoring();
  }

  // Migrate user data to include required fields
  Future<void> _migrateUserData() async {
    if (user == null) return;

    try {
      // Check if user needs migration
      final needsMigration = await _migration.needsMigration(user!.uid);
      if (needsMigration) {
        print('User needs migration, running automatic migration...');
        await _migration.migrateCurrentUser();
        print('User migration completed');
      } else {
        print('User already has all required fields');
      }
    } catch (e) {
      print('Error during user migration: $e');
    }
  }

  // Initialize background emotion detection
  Future<void> _initializeBackgroundEmotionDetection() async {
    if (user == null) return;

    try {
      // Initialize background emotion detection
      final success = await _backgroundService.initializeForChild(user!.uid);

      if (success) {
        // Start background detection
        await _backgroundService.startBackgroundDetection();

        setState(() {
          _backgroundDetectionActive = true;
        });

        print('Background emotion detection started for child: ${user!.uid}');
      } else {
        print('Failed to initialize background emotion detection');
      }
    } catch (e) {
      print('Error initializing background emotion detection: $e');
    }
  }

  // Initialize background eye tracking
  Future<void> _initializeBackgroundEyeTracking() async {
    if (user == null) return;

    try {
      // Initialize background eye tracking
      final success = await _eyeTrackingService.initializeForChild(user!.uid);

      if (success) {
        // Start background eye tracking
        await _eyeTrackingService.startBackgroundTracking();

        print('Background eye tracking started for child: ${user!.uid}');
      } else {
        print('Failed to initialize background eye tracking');
      }
    } catch (e) {
      print('Error initializing background eye tracking: $e');
    }
  }

  // Initialize emergency monitoring
  Future<void> _initializeEmergencyMonitoring() async {
    if (user == null) return;

    try {
      // Start emergency monitoring for this child
      await _emergencyService.startMonitoring(user!.uid);
      print('Emergency monitoring started for child: ${user!.uid}');
    } catch (e) {
      print('Error initializing emergency monitoring: $e');
    }
  }

  @override
  void dispose() {
    // Clean up services
    _backgroundService.stopBackgroundDetection();
    // _eyeTrackingService.stopBackgroundTracking(); // DISABLED - camera conflict
    _emergencyService.stopMonitoring(user?.uid ?? '');
    super.dispose();
  }

  Future<void> fetchChildData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    var data = doc.data();
    // Generate username if not present
    if (data != null &&
        (data['username'] == null || data['username'].toString().isEmpty)) {
      final name = (data['displayName'] ?? '')
          .toString()
          .split(' ')
          .first
          .toLowerCase();
      final random = Random();
      final randomDigits = random.nextInt(900) + 100; // 100-999
      final username = '$name$randomDigits';
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'username': username,
      }, SetOptions(merge: true));
      data['username'] = username;
    }
    setState(() {
      childData = data;
      isLoading = false;
    });
  }

  void showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.child_care, color: Colors.pink[700], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Child Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink[700],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Profile Picture Section
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.pink[100],
                          child: Icon(
                            Icons.child_care,
                            size: 60,
                            color: Colors.pink[700],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Child Information (Read-only)
                      _buildSection('Child Information', [
                        _buildReadOnlyField(
                          'Full Name',
                          childData?['name'] ??
                              childData?['displayName'] ??
                              'Not set',
                          Icons.person,
                        ),
                        _buildReadOnlyField(
                          'Username',
                          childData?['username'] ?? 'Not set',
                          Icons.alternate_email,
                        ),
                        _buildReadOnlyField(
                          'Email',
                          childData?['email'] ?? 'Not set',
                          Icons.email,
                        ),
                        _buildReadOnlyField(
                          'Age',
                          childData?['age']?.toString() ?? 'Not set',
                          Icons.cake,
                        ),
                        _buildReadOnlyField(
                          'Gender',
                          childData?['gender'] ?? 'Not set',
                          Icons.wc,
                        ),
                        _buildReadOnlyField(
                          'Height',
                          childData?['height'] != null
                              ? '${childData!['height']} cm'
                              : 'Not set',
                          Icons.height,
                        ),
                        _buildReadOnlyField(
                          'Weight',
                          childData?['weight'] != null
                              ? '${childData!['weight']} kg'
                              : 'Not set',
                          Icons.monitor_weight,
                        ),
                        _buildReadOnlyField(
                          'Blood Group',
                          childData?['bloodGroup'] ?? 'Not set',
                          Icons.bloodtype,
                        ),
                      ]),

                      // Parent Information (Read-only)
                      _buildSection('Parent Information', [
                        _buildReadOnlyField(
                          'Parent/Guardian',
                          childData?['guardianEmail'] ??
                              childData?['parentEmail'] ??
                              'Not linked',
                          Icons.family_restroom,
                        ),
                        _buildReadOnlyField(
                          'Mentor',
                          childData?['mentorName'] ?? 'Not assigned',
                          Icons.school,
                        ),
                      ]),

                      // Account Information (Read-only)
                      _buildSection('Account Information', [
                        _buildReadOnlyField('Role', 'Child', Icons.child_care),
                        _buildReadOnlyField(
                          'Account Created',
                          childData?['createdAt'] != null
                              ? '${DateTime.fromMillisecondsSinceEpoch(childData!['createdAt'].millisecondsSinceEpoch).day}/${DateTime.fromMillisecondsSinceEpoch(childData!['createdAt'].millisecondsSinceEpoch).month}/${DateTime.fromMillisecondsSinceEpoch(childData!['createdAt'].millisecondsSinceEpoch).year}'
                              : 'Unknown',
                          Icons.calendar_today,
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    // Stop background emotion detection before logout
    await _backgroundService.stopBackgroundDetection();

    // Stop emergency monitoring before logout
    if (user != null) {
      await _emergencyService.stopMonitoring(user!.uid);
    }

    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // Test emotion simulation (for development/testing)
  Future<void> _testEmotionSimulation() async {
    if (user == null) return;

    try {
      print('🧪 TEST EMOTION: Starting emotion simulation test...');

      // Simulate angry emotion with high confidence
      await _emergencyService.simulateEmotionDetection(user!.uid, 'angry', 0.8);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🧪 Simulated angry emotion! Check console for monitoring logs.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ TEST EMOTION ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Emotion simulation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Test emergency alert (for development/testing)
  Future<void> _testEmergencyAlert() async {
    if (user == null) return;

    try {
      print('🚨 TEST ALERT: Starting emergency alert test...');

      // Get child data
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (!childDoc.exists) {
        print('❌ TEST ALERT: Child document not found');
        return;
      }

      final childData = childDoc.data()!;
      final childName =
          childData['name'] ?? childData['displayName'] ?? 'Test Child';
      final parentEmail =
          childData['guardianEmail'] ??
          childData['parentEmail'] ??
          'test@example.com';
      final therapistId = childData['therapistId'];

      print(
        '🚨 TEST ALERT: Child - $childName, Parent - $parentEmail, Therapist - $therapistId',
      );

      // Directly trigger emergency alert
      await _emergencyService.triggerEmergencyAlert(user!.uid);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🚨 Test emergency alert triggered! Check parent/therapist notifications!',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ TEST ALERT ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Test alert failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.pink[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.pink[200]!),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.pink[700],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Welcome Card
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
                const Icon(
                  Icons.psychology,
                  size: 48,
                  color: Color(0xFFFF6B9D),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome back, ${childData?['username'] ?? 'Buddy'}!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'How are you feeling today?',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Background Monitoring Status Card
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
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _backgroundDetectionActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _backgroundDetectionActive ? Icons.security : Icons.info,
                    size: 30,
                    color: _backgroundDetectionActive
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _backgroundDetectionActive
                            ? 'Safety Monitoring Active'
                            : 'Initializing Safety Monitoring',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _backgroundDetectionActive
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _backgroundDetectionActive
                            ? 'Your emotions are being monitored for safety. Emergency alerts will be sent if you show signs of distress (angry/fear/sad) for more than 1 minute.'
                            : 'Setting up automatic emotion monitoring...',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      _backgroundDetectionActive
                          ? Icons.check_circle
                          : Icons.hourglass_empty,
                      color: _backgroundDetectionActive
                          ? Colors.green[700]
                          : Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    // Test Buttons (for development)
                    if (_backgroundDetectionActive) ...[
                      ElevatedButton(
                        onPressed: _testEmotionSimulation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[100],
                          foregroundColor: Colors.orange[700],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                        ),
                        child: const Text(
                          'Test Emotion',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: _testEmergencyAlert,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red[700],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                        ),
                        child: const Text(
                          'Test Alert',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Fun Action Cards - Bigger and More Engaging!
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              _buildFunActionCard(
                icon: Icons.games,
                title: 'Games',
                subtitle: 'Play & Learn!',
                emoji: '🎮',
                color: const Color(0xFF4ECDC4),
                gradientColors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GamesScreen(),
                    ),
                  );
                },
              ),
              _buildFunActionCard(
                icon: Icons.palette,
                title: 'Draw Together',
                subtitle: 'With Your Therapist!',
                emoji: '🎨',
                color: const Color(0xFF6B73FF),
                gradientColors: [Color(0xFF6B73FF), Color(0xFF8E94FF)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CanvasSessionLauncher(isTherapist: false),
                    ),
                  );
                },
              ),
              _buildFunActionCard(
                icon: Icons.chat_bubble,
                title: 'Talk Builder',
                subtitle: 'Build & Speak!',
                emoji: '💬',
                color: const Color(0xFFFF6B9D),
                gradientColors: [Color(0xFFFF6B9D), Color(0xFFFFB6B9)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AACBuilder(),
                    ),
                  );
                },
              ),
              _buildFunActionCard(
                icon: Icons.people,
                title: 'Social Skills',
                subtitle: 'Practice & Learn!',
                emoji: '🤝',
                color: const Color(0xFFFFE66D),
                gradientColors: [Color(0xFFFFE66D), Color(0xFFFFB347)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SocialSkillsGame(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Super Fun Action Card with Animations and Emojis!
  Widget _buildFunActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String emoji,
    required Color color,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Big Emoji
              Text(emoji, style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 12),
              // Title with fun font
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // Subtitle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fun Classes Dialog with Colorful Options!
  void _showClassesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE66D), Color(0xFFFFB347)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Text('🎓', style: TextStyle(fontSize: 40)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Choose Your Class!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Class Cards
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildClassCard(
                        emoji: '🎨',
                        title: 'Art & Drawing',
                        description: 'Learn to draw and paint!',
                        color: const Color(0xFFFF6B9D),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎨 Art class coming soon!'),
                              backgroundColor: Color(0xFFFF6B9D),
                            ),
                          );
                        },
                      ),
                      _buildClassCard(
                        emoji: '🎵',
                        title: 'Music & Singing',
                        description: 'Make beautiful music!',
                        color: const Color(0xFF9C27B0),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎵 Music class coming soon!'),
                              backgroundColor: Color(0xFF9C27B0),
                            ),
                          );
                        },
                      ),
                      _buildClassCard(
                        emoji: '🧮',
                        title: 'Math Fun',
                        description: 'Numbers are exciting!',
                        color: const Color(0xFF4ECDC4),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🧮 Math class coming soon!'),
                              backgroundColor: Color(0xFF4ECDC4),
                            ),
                          );
                        },
                      ),
                      _buildClassCard(
                        emoji: '📖',
                        title: 'Story Time',
                        description: 'Amazing stories await!',
                        color: const Color(0xFF44A08D),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📖 Story time coming soon!'),
                              backgroundColor: Color(0xFF44A08D),
                            ),
                          );
                        },
                      ),
                      _buildClassCard(
                        emoji: '🌍',
                        title: 'World Explorer',
                        description: 'Discover new places!',
                        color: const Color(0xFF2196F3),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🌍 Explorer class coming soon!'),
                              backgroundColor: Color(0xFF2196F3),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Individual Class Card
  Widget _buildClassCard({
    required String emoji,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                'Welcome, ${childData?['username'] ?? ''}!',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.account_circle, color: Colors.pink),
                onPressed: showProfileDialog,
                tooltip: 'Profile',
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B9D), Color(0xFFFFB6B9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildDashboardContent(),
      ),
    );
  }
}
