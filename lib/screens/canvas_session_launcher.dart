import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/collaborative_canvas_service.dart';
import 'collaborative_canvas_screen.dart';

class CanvasSessionLauncher extends StatefulWidget {
  final bool isTherapist;

  const CanvasSessionLauncher({
    super.key,
    required this.isTherapist,
  });

  @override
  State<CanvasSessionLauncher> createState() => _CanvasSessionLauncherState();
}

class _CanvasSessionLauncherState extends State<CanvasSessionLauncher> {
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _availablePartners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailablePartners();
  }

  Future<void> _loadAvailablePartners() async {
    if (user == null) return;

    try {
      if (widget.isTherapist) {
        // Load assigned children
        final childrenSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'kid')
            .where('therapistId', isEqualTo: user!.uid)
            .get();

        setState(() {
          _availablePartners = childrenSnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          _isLoading = false;
        });
      } else {
        // Load assigned therapist
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        final therapistId = userDoc.data()?['therapistId'];
        if (therapistId != null) {
          final therapistDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(therapistId)
              .get();

          setState(() {
            _availablePartners = [
              {'id': therapistDoc.id, ...therapistDoc.data()!}
            ];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading partners: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startSession(Map<String, dynamic> partner) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      print('Creating canvas session...');
      final sessionId = await CollaborativeCanvasService.createCanvasSession(
        therapistId: widget.isTherapist ? user!.uid : partner['id'],
        childId: widget.isTherapist ? partner['id'] : user!.uid,
      );
      print('Session created: $sessionId');

      // Send notification to partner
      await FirebaseFirestore.instance
          .collection('users')
          .doc(partner['id'])
          .collection('notifications')
          .add({
        'type': 'canvas_session',
        'title': '🎨 Canvas Session Started!',
        'message':
            '${widget.isTherapist ? 'Your therapist' : partner['name']} wants to draw with you!',
        'sessionId': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Close loading dialog
      Navigator.pop(context);

      // Navigate to canvas
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollaborativeCanvasScreen(
            sessionId: sessionId,
            partnerName: partner['name'] ?? partner['displayName'] ?? 'Partner',
            isTherapist: widget.isTherapist,
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      print('Error starting canvas session: $e');

      // Show helpful error message
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Cannot Start Session'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Firebase Realtime Database not set up!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Please follow these steps:'),
              const SizedBox(height: 8),
              const Text('1. Open Firebase Console'),
              const Text('2. Click "Realtime Database"'),
              const Text('3. Click "Create Database"'),
              const Text('4. Choose "Start in test mode"'),
              const Text('5. Click "Enable"'),
              const SizedBox(height: 12),
              Text(
                'Error: $e',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('🎨 Start Canvas Session',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6B73FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availablePartners.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        widget.isTherapist
                            ? 'No children assigned yet'
                            : 'No therapist assigned yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _availablePartners.length,
                  itemBuilder: (context, index) {
                    final partner = _availablePartners[index];
                    return _buildPartnerCard(partner);
                  },
                ),
    );
  }

  Widget _buildPartnerCard(Map<String, dynamic> partner) {
    final name = partner['name'] ?? partner['displayName'] ?? 'Unknown';
    final age = partner['age']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      child: InkWell(
        onTap: () => _startSession(partner),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6B73FF).withOpacity(0.1),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B73FF), Color(0xFF8E94FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B73FF).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🎨',
                    style: TextStyle(fontSize: 35),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (age.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Age: $age',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B73FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🖌️ Start Drawing Together',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B73FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 24,
                color: Color(0xFF6B73FF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
