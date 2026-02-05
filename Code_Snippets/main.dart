import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'parent_dashboard.dart';
import 'child_dashboard.dart';
import 'therapist_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BloomBuddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B73FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          if (user.email != null && user.email!.isNotEmpty) {
            // Fetch user role from Firestore
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }
                if (userSnapshot.hasData && userSnapshot.data != null) {
                  final role = userSnapshot.data!.data()?['role'];
                  if (role == 'parent') {
                    return const ParentDashboard();
                  } else if (role == 'kid') {
                    return const ChildDashboard();
                  } else if (role == 'therapist') {
                    return const TherapistDashboard();
                  } else {
                    return const HomeScreen();
                  }
                }
                return const HomeScreen();
              },
            );
          } else {
            FirebaseAuth.instance.signOut();
            return const WelcomeScreen();
          }
        }
        return const WelcomeScreen();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6B73FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology,
                size: 60,
                color: Color(0xFF6B73FF),
              ),
            ).animate().scale(duration: 600.ms).then().shake(),
            const SizedBox(height: 30),
            const Text(
              'BloomBuddy',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 10),
            const Text(
              'Your Mental Health Companion',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              color: Colors.white,
            ).animate().fadeIn(delay: 900.ms),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B73FF), Color(0xFF000DFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                // Logo and Title
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology,
                    size: 60,
                    color: Color(0xFF6B73FF),
                  ),
                ).animate().scale(duration: 600.ms).then().shake(),
                const SizedBox(height: 30),
                const Text(
                  'Welcome to BloomBuddy',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 10),
                const Text(
                  'Your journey to better mental health starts here',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 600.ms),
                const Spacer(),
                // Role Selection
                const Text(
                  'I am a...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ).animate().fadeIn(delay: 900.ms),
                const SizedBox(height: 20),
                // Role Cards
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.child_care,
                        title: 'Kid',
                        subtitle: 'Ages 5-12',
                        color: const Color(0xFFFF6B9D),
                        onTap: () => _showAuthScreen(context, 'kid'),
                      ).animate().slideX(delay: 1200.ms, begin: -1),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.family_restroom,
                        title: 'Parent',
                        subtitle: 'Guardian',
                        color: const Color(0xFF4ECDC4),
                        onTap: () => _showAuthScreen(context, 'parent'),
                      ).animate().slideX(delay: 1400.ms, begin: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.psychology,
                  title: 'Therapist',
                  subtitle: 'Mental Health Professional',
                  color: const Color(0xFF9C27B0),
                  onTap: () => _showAuthScreen(context, 'therapist'),
                ).animate().slideY(delay: 1600.ms, begin: 1),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAuthScreen(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen(role: role)),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final String role;

  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      if (userCredential.user != null) {
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid);
        final userSnapshot = await userDoc.get();

        if (userSnapshot.exists) {
          final existingRole = userSnapshot.data()?['role'];
          if (existingRole != null) {
            if (existingRole != widget.role) {
              // Role mismatch: show error and sign out
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'You are already registered as a $existingRole. You cannot register as a ${widget.role}.',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
              return;
            }
            // If role matches, just update lastLogin and displayName/email if needed, but NOT role
            await userDoc.set({
              'email': userCredential.user!.email,
              'displayName': userCredential.user!.displayName,
              'lastLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } else {
            // If for some reason role is missing, set it now
            await userDoc.set({
              'email': userCredential.user!.email,
              'displayName': userCredential.user!.displayName,
              'role': widget.role,
              'createdAt': FieldValue.serverTimestamp(),
              'lastLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } else {
          // First time sign-in, set everything
          await userDoc.set({
            'email': userCredential.user!.email,
            'displayName': userCredential.user!.displayName,
            'role': widget.role,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Pop the AuthScreen so AuthWrapper can update
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      print('Google Sign-In Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B73FF), Color(0xFF000DFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Back Button and Title
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Sign in to BloomBuddy',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ).animate().slideX(delay: 200.ms, begin: -1),
                const SizedBox(height: 20),
                Text(
                  'Join as a ${widget.role}',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ).animate().fadeIn(delay: 400.ms),
                const Spacer(),
                // Google Sign In Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _signInWithGoogle,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Image.network(
                                'https://developers.google.com/identity/images/g-logo.png',
                                height: 24,
                              ),
                            const SizedBox(width: 12),
                            Text(
                              _isLoading
                                  ? 'Signing in...'
                                  : 'Continue with Google',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().slideY(delay: 600.ms, begin: 1),
                const SizedBox(height: 20),
                const Text(
                  'Sign in with your Google account to get started',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 800.ms),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BloomBuddy'),
        backgroundColor: const Color(0xFF6B73FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Welcome to BloomBuddy! 🎉',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
