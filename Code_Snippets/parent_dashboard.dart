import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'email_notification_service.dart';
import 'widgets/monthly_therapy_calendar.dart';
import 'screens/parent_chat_screen.dart';
import 'screens/emotion_game_reports_screen.dart';
import 'screens/all_games_reports_screen.dart';
import 'screens/aac_progress_report_screen.dart';
import 'screens/parent_chatbot_screen.dart';
import 'services/chat_service.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard>
    with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? parentData;
  bool isLoading = true;
  List<Map<String, dynamic>> therapists = [];
  String? selectedTherapistId;
  String? selectedTherapistName;
  List<Map<String, dynamic>> linkedChildren = [];
  List<Map<String, dynamic>> notifications = [];
  int selectedTabIndex = 0;
  int chatUnreadCount = 0;
  List<QueryDocumentSnapshot>? _artworkList;
  bool _isLoadingArtwork = false;
  String? _artworkError;

  // Notification settings state
  bool emailNotifications = true;
  bool pushNotifications = true;
  bool emotionAlerts = true;
  bool progressUpdates = true;
  bool therapyReminders = true;
  bool emergencyAlerts = true;

  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    fetchParentData();
    fetchTherapists();
    fetchLinkedChildren();
    fetchNotifications();
    _loadChatUnreadCount();
  }

  Future<void> _loadArtwork() async {
    if (user == null) return;
    
    setState(() {
      _isLoadingArtwork = true;
      _artworkError = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('childArtwork')
          .orderBy('savedAt', descending: true)
          .get();

      setState(() {
        _artworkList = snapshot.docs;
        _isLoadingArtwork = false;
      });
    } catch (e) {
      print('❌ Error loading artwork: $e');
      setState(() {
        _artworkError = e.toString();
        _isLoadingArtwork = false;
      });
    }
  }

  Future<void> _loadChatUnreadCount() async {
    try {
      final count = await _chatService.getUnreadMessageCount();
      setState(() {
        chatUnreadCount = count;
      });
    } catch (e) {
      print('Error loading chat unread count: $e');
    }
  }

  Future<void> fetchParentData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    setState(() {
      parentData = doc.data();
      selectedTherapistId = parentData?['therapistId'];
      selectedTherapistName = parentData?['therapistName'];
      isLoading = false;
    });
    // Load notification settings
    _loadNotificationSettings();
  }

  void _loadNotificationSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          setState(() {
            emailNotifications = data?['emailNotifications'] ?? true;
            pushNotifications = data?['pushNotifications'] ?? true;
            emotionAlerts = data?['emotionAlerts'] ?? true;
            progressUpdates = data?['progressUpdates'] ?? true;
            therapyReminders = data?['therapyReminders'] ?? true;
            emergencyAlerts = data?['emergencyAlerts'] ?? true;
          });
        }
      } catch (e) {
        print('Error loading notification settings: $e');
      }
    }
  }

  Future<void> fetchTherapists() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'therapist')
        .get();
    setState(() {
      therapists = query.docs.map((doc) {
        final data = doc.data();
        return {'uid': doc.id, 'name': data['displayName'] ?? ''};
      }).toList();
    });
  }

  Future<void> fetchLinkedChildren() async {
    if (user == null) return;
    final parentEmail = parentData?['email'] ?? user!.email;
    if (parentEmail == null) return;

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'kid')
        .where('guardianEmail', isEqualTo: parentEmail)
        .get();

    setState(() {
      linkedChildren = query.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['name'] ?? data['displayName'] ?? '',
          'email': data['email'] ?? '',
          'age': data['age'] ?? '',
          'username': data['username'] ?? '',
          ...data,
        };
      }).toList();
    });
  }

  Future<void> fetchNotifications() async {
    if (user == null) return;

    print('DEBUG: Fetching notifications for user: ${user!.uid}');

    final notificationsQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .get();

    print('DEBUG: Found ${notificationsQuery.docs.length} notifications');

    setState(() {
      notifications = notificationsQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    });

    print('DEBUG: Notifications updated: ${notifications.length}');
  }

  Future<void> _clearNotification(String notificationId) async {
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      setState(() {
        notifications.removeWhere(
          (notification) => notification['id'] == notificationId,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showProfileDialog() {
    final nameController = TextEditingController(
      text: parentData?['name'] ?? parentData?['displayName'] ?? '',
    );
    final phoneController = TextEditingController(
      text: parentData?['phone'] ?? '',
    );
    final addressController = TextEditingController(
      text: parentData?['address'] ?? '',
    );
    final occupationController = TextEditingController(
      text: parentData?['occupation'] ?? '',
    );
    final emergencyContactController = TextEditingController(
      text: parentData?['emergencyContact'] ?? '',
    );
    final email = parentData?['email'] ?? '';

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
                  Icon(Icons.person, color: Colors.blue[700], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Parent Profile Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
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
                          backgroundColor: Colors.blue[100],
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Basic Information
                      _buildSection('Basic Information', [
                        _buildTextField(
                          nameController,
                          'Full Name',
                          Icons.person,
                        ),
                        _buildTextField(
                          phoneController,
                          'Phone Number',
                          Icons.phone,
                        ),
                        _buildTextField(
                          addressController,
                          'Address',
                          Icons.location_on,
                        ),
                        _buildTextField(
                          occupationController,
                          'Occupation',
                          Icons.work,
                        ),
                        _buildTextField(
                          emergencyContactController,
                          'Emergency Contact',
                          Icons.emergency,
                        ),
                      ]),

                      // Account Information (Read-only)
                      _buildSection('Account Information', [
                        _buildReadOnlyField('Email', email, Icons.email),
                        _buildReadOnlyField(
                          'Role',
                          'Parent',
                          Icons.family_restroom,
                        ),
                        _buildReadOnlyField(
                          'Account Created',
                          parentData?['createdAt'] != null
                              ? '${DateTime.fromMillisecondsSinceEpoch(parentData!['createdAt'].millisecondsSinceEpoch).day}/${DateTime.fromMillisecondsSinceEpoch(parentData!['createdAt'].millisecondsSinceEpoch).month}/${DateTime.fromMillisecondsSinceEpoch(parentData!['createdAt'].millisecondsSinceEpoch).year}'
                              : 'Unknown',
                          Icons.calendar_today,
                        ),
                      ]),

                      // Linked Children Section
                      _buildSection('Linked Children', [
                        if (linkedChildren.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.child_care,
                                  size: 32,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No children linked yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Use the "Link Child" button to connect your child\'s account',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ...linkedChildren.map(
                            (child) => _buildChildInfoCard(child),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user!.uid)
                            .set({
                          'name': nameController.text,
                          'phone': phoneController.text,
                          'address': addressController.text,
                          'occupation': occupationController.text,
                          'emergencyContact': emergencyContactController.text,
                          'lastUpdated': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                        Navigator.pop(context);
                        fetchParentData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkChildDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Child Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your child\'s email to link their account to you. This will set your email as the guardian in their profile so notifications are sent correctly.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Child\'s email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final childEmail = emailController.text.trim();
              if (childEmail.isEmpty || user == null) return;
              try {
                final childQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'kid')
                    .where('email', isEqualTo: childEmail)
                    .limit(1)
                    .get();
                if (childQuery.docs.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No child account found with that email.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                final childDoc = childQuery.docs.first;
                final parentEmail = parentData?['email'] ?? user!.email;
                // Write guardianEmail to child; also store parentEmail for compatibility
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(childDoc.id)
                    .set({
                  'guardianEmail': parentEmail,
                  'parentEmail': parentEmail,
                }, SetOptions(merge: true));
                // Optionally record linkage on parent side
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .set({
                  'linkedChildren': FieldValue.arrayUnion([childDoc.id]),
                }, SetOptions(merge: true));
                // Immediately notify parent via EmailJS so they get the consent email now
                try {
                  final childData = childDoc.data();
                  final childName =
                      childData['name'] ?? childData['displayName'] ?? '';
                  await EmailNotificationService()
                      .sendEmotionDetectionNotification(
                    parentEmail: parentEmail ?? '',
                    childName: childName,
                    childId: childDoc.id,
                  );
                } catch (e) {
                  // ignore, diagnostics will be printed by the service
                }
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Linked to child: ${childEmail}')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Link failed: $e')));
                }
              }
            },
            child: const Text('Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
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
              Expanded(
                child: Text(
                  'Welcome, ${parentData?['displayName'] ?? ''}!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.link,
                  color: Colors.blueAccent,
                  size: 22,
                ),
                onPressed: _showLinkChildDialog,
                tooltip: 'Link Child',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red, size: 22),
                onPressed: _logout,
                tooltip: 'Logout',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final selectedChildId = linkedChildren.isNotEmpty 
              ? (linkedChildren[0]['uid'] ?? linkedChildren[0]['id'])
              : null;
          print('🔍 Opening chatbot with child ID: $selectedChildId');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParentChatbotScreen(
                selectedChildId: selectedChildId,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF4ECDC4),
        icon: const Icon(Icons.smart_toy, color: Colors.white),
        label: const Text(
          'AI Assistant',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 8,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4ECDC4), Color(0xFF11998E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Responsive Tab Bar
                  Container(
                    margin: const EdgeInsets.all(16),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DefaultTabController(
                        length: 6,
                        initialIndex: selectedTabIndex,
                        child: TabBar(
                          controller: TabController(
                            length: 6,
                            vsync: this,
                            initialIndex: selectedTabIndex,
                          ),
                          onTap: (index) {
                            setState(() {
                              selectedTabIndex = index;
                            });
                            // Refresh notifications when switching to notifications tab
                            if (index == 4) {
                              fetchNotifications();
                            }
                            // Refresh chat unread count when switching to chat tab
                            if (index == 2) {
                              _loadChatUnreadCount();
                            }
                            // Load artwork when switching to progress tab (only if not loaded)
                            if (index == 1 && _artworkList == null && !_isLoadingArtwork) {
                              _loadArtwork();
                            }
                          },
                          isScrollable: true, // Make tabs scrollable
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4ECDC4), Color(0xFF11998E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          indicatorPadding: const EdgeInsets.all(4),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey[600],
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          tabs: [
                            Tab(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.child_care, size: 16),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Child',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.analytics, size: 16),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Progress',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.chat, size: 16),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Chat',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    if (chatUnreadCount > 0) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$chatUnreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 16),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Calendar',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.notifications, size: 16),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Alerts',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.settings, size: 16),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Settings',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tab Content
                  Expanded(
                    child: IndexedStack(
                      index: selectedTabIndex,
                      children: [
                        _buildChildInfoTab(),
                        _buildProgressTab(),
                        _buildChatTab(),
                        _buildCalendarTab(),
                        _buildNotificationsTab(),
                        _buildSettingsTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildChildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF11998E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.family_restroom, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Child Information Management',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage comprehensive information about your children for better therapy outcomes',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // AI Assistant Card
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4ECDC4).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  final selectedChildId = linkedChildren.isNotEmpty 
                      ? (linkedChildren[0]['uid'] ?? linkedChildren[0]['id'])
                      : null;
                  print('🔍 Opening chatbot from card with child ID: $selectedChildId');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParentChatbotScreen(
                        selectedChildId: selectedChildId,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.smart_toy,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Assistant',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Get instant answers about the app and your child\'s progress',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Linked Children Overview
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.child_care,
                        color: Colors.blue[700],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Linked Children',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          Text(
                            '${linkedChildren.length} child${linkedChildren.length != 1 ? 'ren' : ''} connected',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (linkedChildren.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.child_care,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No children linked yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Link your child\'s account to start managing their comprehensive information for therapy',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showLinkChildDialog,
                          icon: const Icon(Icons.link),
                          label: const Text('Link Child Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...linkedChildren.map((child) => _buildChildCard(child)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ECDC4), Color(0xFF11998E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.child_care, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${child['username'] ?? 'unknown'}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue[700]),
                  onPressed: () => _showChildInfoForm(child),
                  tooltip: 'Edit Child Info',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  'Age: ${child['age'] ?? 'N/A'}',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip(
                  'Gender: ${child['gender'] ?? 'N/A'}',
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap edit to manage comprehensive information for therapy',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Emotion Game Reports Section
          _buildEmotionGameReportsSection(),
          const SizedBox(height: 16),
          // AAC Communication Progress Section
          _buildAACProgressSection(),
          const SizedBox(height: 16),
          // Canvas Artwork Section
          _buildCanvasArtworkSection(),
          const SizedBox(height: 16),
          // Future progress tracking sections can go here
        ],
      ),
    );
  }

  Widget _buildEmotionGameReportsSection() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_emotions, color: const Color(0xFFFF6B9D), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Game Reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF6B9D),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  if (linkedChildren.isNotEmpty) {
                    final firstChild = linkedChildren.first;
                    final childId = firstChild['uid'] as String? ?? firstChild['id'] as String?;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllGamesReportsScreen(
                          childId: childId,
                          childName: firstChild['name'] as String? ?? 'Child',
                          isParentView: true,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B9D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (linkedChildren.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Link a child account to view emotion game reports',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...linkedChildren.map((child) {
              final childId = child['uid'] as String? ?? child['id'] as String?;
              final childName = child['name'] as String? ?? 'Child';
              if (childId == null) return const SizedBox.shrink();
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(childId)
                    .collection('gameReports')
                    .orderBy('completedAt', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  final hasReports = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                  final latestReport = hasReports
                      ? snapshot.data!.docs.first.data() as Map<String, dynamic>
                      : null;
                  final gameType = latestReport?['gameType'] as String? ?? '';
                  String latestText = 'No reports yet';
                  if (hasReports && latestReport != null) {
                    if (gameType == 'emotion_character_quiz') {
                      final score = latestReport['score'] as int? ?? 0;
                      final total = latestReport['totalQuestions'] as int? ?? 10;
                      final accuracy = latestReport['accuracy'] as double? ?? 0.0;
                      latestText = 'Latest: $score/$total (${(accuracy * 100).toStringAsFixed(0)}%)';
                    } else if (gameType == 'eyes_game') {
                      final focus = latestReport['focusCounter'] as int? ?? 0;
                      latestText = 'Latest: Focus $focus';
                    } else {
                      final score = latestReport['score'] as int? ?? 0;
                      latestText = 'Latest: Score $score';
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF6B9D).withOpacity(0.1),
                          const Color(0xFFFFB6B9).withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF6B9D).withOpacity(0.3),
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        final finalChildId = child['uid'] as String? ?? child['id'] as String?;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllGamesReportsScreen(
                              childId: finalChildId,
                              childName: childName,
                              isParentView: true,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B9D).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.emoji_emotions,
                                color: Color(0xFFFF6B9D),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    childName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    latestText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasReports ? Colors.grey[700] : Colors.grey[600],
                                      fontStyle: hasReports ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFFF6B9D),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildAACProgressSection() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble, color: Color(0xFF4ECDC4), size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AAC Communication Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4ECDC4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (linkedChildren.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No children linked yet',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...linkedChildren.map((child) {
              final childId = child['uid'] as String? ?? child['id'] as String?;
              final childName = child['name'] as String? ?? 'Child';
              if (childId == null) return const SizedBox.shrink();
              
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(childId)
                    .collection('aac_analytics')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  final hasData = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                  String latestText = 'No AAC usage yet';
                  
                  if (hasData) {
                    final totalDocs = snapshot.data!.docs.length;
                    final symbolCount = snapshot.data!.docs
                        .where((doc) {
                          final data = doc.data() as Map<String, dynamic>?;
                          return data?['type'] == 'symbol_usage';
                        })
                        .length;
                    final sentenceCount = snapshot.data!.docs
                        .where((doc) {
                          final data = doc.data() as Map<String, dynamic>?;
                          return data?['type'] == 'sentence_usage';
                        })
                        .length;
                    latestText = '$symbolCount symbols, $sentenceCount sentences used';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4ECDC4).withOpacity(0.1),
                          const Color(0xFF6B73FF).withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4ECDC4).withOpacity(0.3),
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        final finalChildId = child['uid'] as String? ?? child['id'] as String?;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AACProgressReportScreen(
                              childId: finalChildId,
                              childName: childName,
                              isParentView: true,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ECDC4).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.chat_bubble,
                                color: Color(0xFF4ECDC4),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    childName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    latestText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasData ? Colors.grey[700] : Colors.grey[600],
                                      fontStyle: hasData ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF4ECDC4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildCanvasArtworkSection() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, color: Colors.purple[700], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Canvas Artwork Sessions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                color: Colors.purple[700],
                onPressed: _loadArtwork,
                tooltip: 'Refresh artwork',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Builder(
            builder: (context) {
              // Load artwork on first build if not loaded
              if (_artworkList == null && !_isLoadingArtwork) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadArtwork();
                });
              }

              if (_isLoadingArtwork) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (_artworkError != null) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Error loading artwork',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _artworkError!,
                        style: TextStyle(fontSize: 12, color: Colors.red[500]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadArtwork,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (_artworkList == null || _artworkList!.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.folder_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No artwork yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Canvas artwork from therapy sessions will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: _artworkList!.length,
                itemBuilder: (context, index) {
                  final artwork = _artworkList![index];
                  final data = artwork.data() as Map<String, dynamic>;
                  return _buildArtworkFolder(data, artwork.id);
                },
                key: const ValueKey('artwork_grid'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkFolder(Map<String, dynamic> data, String artworkId) {
    final name = data['name'] as String? ?? 'Untitled';
    final timestamp = (data['savedAt'] as Timestamp?)?.toDate();
    final childName = data['childName'] as String? ?? 'Child';

    return GestureDetector(
      key: ValueKey(artworkId),
      onTap: () {
        print('🖱️ Artwork tapped: $name (ID: $artworkId)');
        _showArtworkDetails(data);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[300]!, Colors.blue[300]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_special, size: 40, color: Colors.white),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timestamp != null
                    ? '${timestamp.day}/${timestamp.month}/${timestamp.year}'
                    : '',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              const SizedBox(height: 2),
              Text(
                childName,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showArtworkDetails(Map<String, dynamic> data) {
    print('🎨 Showing artwork details: ${data.toString()}');
    final name = data['name'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final aiInsights = data['aiInsights'] as String? ?? '';
    final base64Image = data['imageBase64'] as String?;
    final timestamp = (data['savedAt'] as Timestamp?)?.toDate();
    final childName = data['childName'] as String? ?? 'Child';
    
    print('📸 Image present: ${base64Image != null && base64Image.isNotEmpty}');
    print('📝 Description: ${description.isNotEmpty}');
    print('🤖 AI Insights: ${aiInsights.isNotEmpty}');
    
    // Decode image once to prevent flickering
    Uint8List? imageBytes;
    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        imageBytes = base64Decode(base64Image);
        print('✅ Image decoded successfully: ${imageBytes.length} bytes');
      } catch (e) {
        print('❌ Error decoding image: $e');
      }
    } else {
      print('⚠️ No image data found');
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple[400]!, Colors.blue[400]!],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.palette, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'By $childName • ${timestamp != null ? '${timestamp.day}/${timestamp.month}/${timestamp.year}' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Image - use cached bytes to prevent flickering
                  if (imageBytes != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          imageBytes,
                          fit: BoxFit.contain,
                          cacheWidth: 600,
                          cacheHeight: 600,
                        ),
                      ),
                    ),
                // Therapist Description
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📝 Therapist\'s Insights',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(description),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                // AI Insights
                if (aiInsights.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🤖 AI-Generated Session Insights',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            aiInsights,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildChatTab() {
    // Refresh unread count when chat tab is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatUnreadCount();
    });
    return ParentChatScreen(
      onUnreadCountChanged: () {
        _loadChatUnreadCount();
      },
    );
  }

  Widget _buildCalendarTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Text(
                'Therapy Calendar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (linkedChildren.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {
                    _showChildSelectionDialog();
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Select Child'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: linkedChildren.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No children linked',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Link children to view their therapy calendar',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a child to view their calendar',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click "Select Child" to choose a child\'s therapy calendar',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _showChildSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Child'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: linkedChildren.length,
            itemBuilder: (context, index) {
              final child = linkedChildren[index];

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4ECDC4).withOpacity(0.1),
                  child: const Icon(Icons.child_care, color: Color(0xFF4ECDC4)),
                ),
                title: Text(child['name'] ?? 'Unknown Child'),
                subtitle: Text(child['email'] ?? 'No email'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonthlyTherapyCalendar(
                        childId: child['uid'] ?? '',
                        childName: child['name'] ?? 'Unknown Child',
                        userRole: 'parent',
                        therapistId: child['therapistId'],
                        therapistName: child['therapistName'],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                Row(
                  children: [
                    Icon(
                      Icons.notifications,
                      color: Colors.orange[700],
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: fetchNotifications,
                      icon: Icon(Icons.refresh, color: Colors.grey[600]),
                      tooltip: 'Refresh',
                    ),
                    IconButton(
                      onPressed: _createTestNotification,
                      icon: Icon(Icons.bug_report, color: Colors.orange[600]),
                      tooltip: 'Test Notification',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (notifications.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll receive notifications about therapist assignments and updates here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['read'] == true;
    final type = notification['type'] ?? 'general';

    Color cardColor;
    IconData iconData;

    switch (type) {
      case 'therapist_assignment':
        cardColor = Colors.blue[50]!;
        iconData = Icons.psychology;
        break;
      case 'emotion_alert':
        cardColor = Colors.orange[50]!;
        iconData = Icons.mood;
        break;
      case 'progress_update':
        cardColor = Colors.green[50]!;
        iconData = Icons.trending_up;
        break;
      default:
        cardColor = Colors.grey[50]!;
        iconData = Icons.notifications;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isRead ? Colors.grey[300]! : cardColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, color: Colors.grey[700], size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'] ?? 'Notification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isRead ? FontWeight.normal : FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(notification['timestamp']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _clearNotification(notification['id']),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear notification',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            notification['message'] ?? '',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          if (type == 'therapist_assignment' &&
              notification['status'] == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleTherapistAssignment(notification, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleTherapistAssignment(notification, 'rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleTherapistAssignment(
    Map<String, dynamic> notification,
    String action,
  ) async {
    try {
      final childId = notification['childId'];
      final therapistId = notification['therapistId'];
      final childName = notification['childName'];

      if (childId == null || therapistId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Missing assignment information'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update child's assignment status
      if (action == 'accepted') {
        // Only update child document when parent accepts
        await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .update({
          'therapistId': therapistId,
          'therapistName': notification['therapistName'],
          'assignmentStatus': 'accepted',
          'assignedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // For rejected assignments, just update the status
        await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .update({
          'assignmentStatus': 'rejected',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Mark notification as read
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('notifications')
          .doc(notification['id'])
          .update({
        'read': true,
        'status': action,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Create notification for therapist
      await FirebaseFirestore.instance
          .collection('users')
          .doc(therapistId)
          .collection('notifications')
          .add({
        'type': 'assignment_response',
        'title': 'Assignment $action',
        'message':
            'Your assignment request for $childName has been $action by the parent.',
        'childName': childName,
        'childId': childId,
        'status': action,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Refresh notifications
      fetchNotifications();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Therapist assignment $action successfully'),
          backgroundColor: action == 'accepted' ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createTestNotification() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('notifications')
          .add({
        'type': 'test',
        'title': 'Test Notification',
        'message':
            'This is a test notification to verify the system is working.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      fetchNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification created!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating test notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';

    try {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                Row(
                  children: [
                    Icon(Icons.settings, color: Colors.purple[700], size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Settings & Preferences',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSettingsOption(
                  icon: Icons.account_circle,
                  title: 'Profile Settings',
                  subtitle: 'Manage your account information',
                  onTap: showProfileDialog,
                ),
                _buildSettingsOption(
                  icon: Icons.notifications,
                  title: 'Notification Settings',
                  subtitle: 'Configure email and push notifications',
                  onTap: () => _showNotificationSettingsDialog(),
                ),
                _buildSettingsOption(
                  icon: Icons.privacy_tip,
                  title: 'Privacy & Security',
                  subtitle: 'Manage data privacy and security settings',
                  onTap: () => _showPrivacySecurityDialog(),
                ),
                _buildSettingsOption(
                  icon: Icons.help,
                  title: 'Help & Support',
                  subtitle: 'Get help and contact support',
                  onTap: () => _showHelpSupportDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.purple[700], size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showChildInfoForm(Map<String, dynamic> child) {
    showDialog(
      context: context,
      builder: (context) => ChildInfoForm(
        child: child,
        onSave: () {
          fetchLinkedChildren();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showPrivacySecurityDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.privacy_tip, color: Colors.purple[700], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy & Security Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
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
                      // Data Privacy Section
                      _buildPrivacySection('Data Privacy', [
                        _buildPrivacyOption(
                          icon: Icons.data_usage,
                          title: 'Data Collection',
                          subtitle:
                              'Control what data is collected about your child',
                          onTap: () => _showDataCollectionDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.share,
                          title: 'Data Sharing',
                          subtitle:
                              'Manage who can access your child\'s information',
                          onTap: () => _showDataSharingDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.storage,
                          title: 'Data Storage',
                          subtitle: 'Control where and how data is stored',
                          onTap: () => _showDataStorageDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.delete_forever,
                          title: 'Data Deletion',
                          subtitle: 'Request deletion of your child\'s data',
                          onTap: () => _showDataDeletionDialog(),
                        ),
                      ]),

                      // Security Section
                      _buildPrivacySection('Account Security', [
                        _buildPrivacyOption(
                          icon: Icons.password,
                          title: 'Password Security',
                          subtitle:
                              'Manage account password and authentication',
                          onTap: () => _showPasswordSecurityDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.devices,
                          title: 'Device Management',
                          subtitle:
                              'Manage devices that can access your account',
                          onTap: () => _showDeviceManagementDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.login,
                          title: 'Login Activity',
                          subtitle: 'View recent login activity and sessions',
                          onTap: () => _showLoginActivityDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.security,
                          title: 'Two-Factor Authentication',
                          subtitle: 'Add extra security to your account',
                          onTap: () => _showTwoFactorDialog(),
                        ),
                      ]),

                      // Child Privacy Section
                      _buildPrivacySection('Child Privacy Protection', [
                        _buildPrivacyOption(
                          icon: Icons.visibility_off,
                          title: 'Profile Visibility',
                          subtitle: 'Control who can see your child\'s profile',
                          onTap: () => _showProfileVisibilityDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.block,
                          title: 'Content Filtering',
                          subtitle: 'Set up content filters for your child',
                          onTap: () => _showContentFilteringDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.location_off,
                          title: 'Location Privacy',
                          subtitle: 'Control location tracking and sharing',
                          onTap: () => _showLocationPrivacyDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.camera_alt,
                          title: 'Camera & Microphone',
                          subtitle: 'Manage camera and microphone permissions',
                          onTap: () => _showCameraMicrophoneDialog(),
                        ),
                      ]),

                      // Important Information Section
                      _buildPrivacySection('Important Information', [
                        _buildPrivacyOption(
                          icon: Icons.videocam,
                          title: 'Video & Audio Recording',
                          subtitle: 'Learn about emotion detection recording',
                          onTap: () => _showRecordingInfoDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.description,
                          title: 'Privacy Policy',
                          subtitle: 'Read our privacy policy and terms',
                          onTap: () => _showPrivacyPolicyDialog(),
                        ),
                        _buildPrivacyOption(
                          icon: Icons.info,
                          title: 'Data Rights',
                          subtitle: 'Your rights regarding your child\'s data',
                          onTap: () => _showDataRightsDialog(),
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
                    backgroundColor: Colors.purple[700],
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

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
          ),
        ),
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

  Widget _buildChildInfoCard(Map<String, dynamic> child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue[100],
            child: Icon(Icons.child_care, color: Colors.blue[700], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@${child['username'] ?? 'unknown'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (child['age'] != null || child['gender'] != null)
                  Text(
                    '${child['age'] ?? 'N/A'} years old • ${child['gender'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue[700]),
            onPressed: () => _showChildInfoForm(child),
            tooltip: 'Edit Child Info',
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple[200]!),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPrivacyOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.purple[700], size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: onTap,
      ),
    );
  }

  // Privacy Dialog Methods
  void _showDataCollectionDialog() {
    _showInfoDialog(
      'Data Collection',
      'We collect essential data for therapy:\n\n• Basic profile info (name, age, gender)\n• Emotional and behavioral data\n• Medical information\n• Progress tracking\n• Therapist communication\n\nControl data collection in profile settings.',
      Icons.data_usage,
    );
  }

  void _showDataSharingDialog() {
    _showInfoDialog(
      'Data Sharing',
      'Data shared only with:\n\n• Assigned therapists\n• Medical professionals\n• Legal authorities (if required)\n\nNEVER shared with:\n• Advertisers\n• Social media\n• Unauthorized users\n\nRevoke permissions anytime.',
      Icons.share,
    );
  }

  void _showDataStorageDialog() {
    _showInfoDialog(
      'Data Storage',
      'Data stored securely:\n\n• Encrypted in transit and at rest\n• Secure cloud servers\n• Regular security audits\n• Backup systems\n• Industry standards\n\nRetention:\n• Active data: 7 years\n• Inactive: 3 years\n• Deleted: 30 days',
      Icons.storage,
    );
  }

  void _showDataDeletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Request Data Deletion',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: const Text(
            'Delete your child\'s data? This cannot be undone and will permanently remove all information.\n\nNote: Some data may be retained for legal compliance.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Data deletion request submitted. Confirmation within 48 hours.',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text('Request Deletion'),
          ),
        ],
      ),
    );
  }

  void _showPasswordSecurityDialog() {
    _showInfoDialog(
      'Password Security',
      'Account security features:\n\n• Strong password requirements\n• Regular security updates\n• Secure authentication\n• Account lockout protection\n• Password recommendations\n\nBest practices:\n• Use unique, strong passwords\n• Enable two-factor auth\n• Don\'t share credentials\n• Log out from shared devices',
      Icons.password,
    );
  }

  void _showDeviceManagementDialog() {
    _showInfoDialog(
      'Device Management',
      'Manage account devices:\n\n• View connected devices\n• Remove unauthorized devices\n• Set device permissions\n• Monitor login locations\n• Remote logout\n\nSecurity features:\n• Device fingerprinting\n• Location-based access\n• Activity alerts\n• Auto logout',
      Icons.devices,
    );
  }

  void _showLoginActivityDialog() {
    _showInfoDialog(
      'Login Activity',
      'Recent activity:\n\n• Last login: Today 2:30 PM\n• Device: iPhone 13 Pro\n• Location: New York, NY\n• Status: Active\n\nSecurity alerts:\n• No suspicious activity\n• Recognized devices only\n• No unauthorized access\n\nUnusual activity notifications enabled.',
      Icons.login,
    );
  }

  void _showTwoFactorDialog() {
    _showInfoDialog(
      'Two-Factor Authentication',
      'Extra account security:\n\n• SMS verification codes\n• Authenticator app support\n• Backup recovery codes\n• Biometric authentication\n• Email verification\n\nBenefits:\n• Password theft protection\n• Secure device access\n• Data protection\n• Industry security',
      Icons.security,
    );
  }

  void _showProfileVisibilityDialog() {
    _showInfoDialog(
      'Profile Visibility',
      'Control profile access:\n\n• Private: Only assigned therapists\n• Restricted: Therapists and staff\n• Public: All platform users\n\nRecommended:\n• Keep profile private\n• Share with trusted therapists\n• Review settings regularly\n• Monitor access',
      Icons.visibility_off,
    );
  }

  void _showContentFilteringDialog() {
    _showInfoDialog(
      'Content Filtering',
      'Content filters for your child:\n\n• Age-appropriate content\n• Educational material\n• Block inappropriate content\n• Safe search\n• Communication monitoring\n\nOptions:\n• Strict: Maximum protection\n• Moderate: Balanced\n• Custom: Personalized\n• Disabled: No filtering',
      Icons.block,
    );
  }

  void _showLocationPrivacyDialog() {
    _showInfoDialog(
      'Location Privacy',
      'Control location tracking:\n\n• Disable location services\n• Limit location sharing\n• Approximate location only\n• Delete location history\n• Emergency location sharing\n\nPrivacy levels:\n• No sharing\n• Approximate only\n• Precise for emergencies\n• Full tracking',
      Icons.location_off,
    );
  }

  void _showCameraMicrophoneDialog() {
    _showInfoDialog(
      'Camera & Microphone',
      'REQUIRED for emotion detection:\n\n• Video for facial analysis\n• Audio for voice detection\n• Real-time monitoring\n• Shared with therapist\n• Therapy only\n\nIMPORTANT: Without access, emotion detection won\'t work.',
      Icons.camera_alt,
    );
  }

  void _showRecordingInfoDialog() {
    _showInfoDialog(
      'Video & Audio Recording',
      'IMPORTANT: Emotion Detection\n\nWe record video and audio for:\n\n• Facial emotion analysis\n• Voice emotion detection\n• Real-time monitoring\n• Therapy progress\n• Safety monitoring\n\nData Sharing:\n• Shared with therapist\n• Therapy and safety only\n• Stored securely\n• Request deletion anytime\n\nEssential for emotion detection.',
      Icons.videocam,
    );
  }

  void _showPrivacyPolicyDialog() {
    _showInfoDialog(
      'Privacy Policy',
      'Our privacy commitment:\n\n• Protect your child\'s information\n• Data for therapy only\n• Never sell personal data\n• You control your data\n• Secure storage\n\nWhat we collect:\n• Basic profile info\n• Emotional data\n• Video/audio for detection\n• Therapy progress\n• Therapist communication',
      Icons.description,
    );
  }

  void _showDataRightsDialog() {
    _showInfoDialog(
      'Your Data Rights',
      'You have the right to:\n\n• View collected data\n• Request corrections\n• Delete child\'s data\n• Control data access\n• Opt-out of collection\n• Request data portability\n\nHow to exercise rights:\n• Contact support team\n• Use request form\n• Email meghajbhat@gmail.com\n• Response within 48 hours',
      Icons.info,
    );
  }

  void _showHelpSupportDialog() {
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
                  Icon(Icons.help, color: Colors.blue[700], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Help & Support',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
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
                      // Getting Started Section
                      _buildHelpSection('Getting Started', [
                        _buildHelpOption(
                          icon: Icons.play_circle,
                          title: 'How to Use the App',
                          subtitle: 'Learn the basics of using BloomBuddy',
                          onTap: () => _showGettingStartedDialog(),
                        ),
                        _buildHelpOption(
                          icon: Icons.person_add,
                          title: 'Link Your Child',
                          subtitle: 'Connect your child\'s account',
                          onTap: () => _showLinkChildHelpDialog(),
                        ),
                        _buildHelpOption(
                          icon: Icons.edit,
                          title: 'Update Child Info',
                          subtitle: 'How to add and edit child information',
                          onTap: () => _showUpdateInfoHelpDialog(),
                        ),
                      ]),

                      // Common Issues Section
                      _buildHelpSection('Common Issues', [
                        _buildHelpOption(
                          icon: Icons.bug_report,
                          title: 'App Not Working',
                          subtitle: 'Troubleshoot app problems',
                          onTap: () => _showTroubleshootingDialog(),
                        ),
                        _buildHelpOption(
                          icon: Icons.login,
                          title: 'Login Problems',
                          subtitle: 'Can\'t sign in to your account',
                          onTap: () => _showLoginHelpDialog(),
                        ),
                        _buildHelpOption(
                          icon: Icons.sync,
                          title: 'Data Not Syncing',
                          subtitle: 'Information not updating properly',
                          onTap: () => _showSyncHelpDialog(),
                        ),
                      ]),

                      // Contact Support Section
                      _buildHelpSection('Contact Support', [
                        _buildHelpOption(
                          icon: Icons.email,
                          title: 'Email Support',
                          subtitle: 'Send us an email for help',
                          onTap: () => _showEmailSupportDialog(),
                        ),
                        _buildHelpOption(
                          icon: Icons.phone,
                          title: 'Emergency Contact',
                          subtitle: 'For urgent issues and emergencies',
                          onTap: () => _showEmergencyContactDialog(),
                        ),
                        _buildHelpOption(
                          icon: Icons.feedback,
                          title: 'Send Feedback',
                          subtitle: 'Share your thoughts and suggestions',
                          onTap: () => _showFeedbackDialog(),
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
                    backgroundColor: Colors.blue[700],
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

  // Help Support Helper Methods
  Widget _buildHelpSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHelpOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue[600]),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: onTap,
      ),
    );
  }

  // Help Dialog Methods
  void _showGettingStartedDialog() {
    _showInfoDialog(
      'How to Use the App',
      'Welcome to BloomBuddy! Here\'s how to get started:\n\n• Link your child\'s account using their email\n• Add detailed information about your child\n• Monitor their progress and emotions\n• Chat with assigned therapists\n• Update settings and privacy preferences\n\nTips:\n• Keep child information up to date\n• Check progress regularly\n• Contact therapist for questions',
      Icons.play_circle,
    );
  }

  void _showLinkChildHelpDialog() {
    _showInfoDialog(
      'Link Your Child',
      'To connect your child\'s account:\n\n• Go to Child Info tab\n• Tap "Link Child" button\n• Enter your child\'s email address\n• Child will receive notification\n• Once accepted, child appears in your dashboard\n\nRequirements:\n• Child must have existing account\n• Email must match exactly\n• Child needs to accept the link',
      Icons.person_add,
    );
  }

  void _showUpdateInfoHelpDialog() {
    _showInfoDialog(
      'Update Child Info',
      'To add or edit child information:\n\n• Go to Child Info tab\n• Tap on child\'s card\n• Fill out the detailed form\n• Include medical info, triggers, likes/dislikes\n• Save changes to update therapist\n\nImportant:\n• Be thorough and accurate\n• Include all relevant details\n• Update when things change\n• This helps therapists provide better care',
      Icons.edit,
    );
  }

  void _showTroubleshootingDialog() {
    _showInfoDialog(
      'App Not Working',
      'If the app isn\'t working properly:\n\n• Check your internet connection\n• Restart the app completely\n• Update to latest version\n• Clear app cache/data\n• Restart your device\n\nStill having issues?\n• Contact support team\n• Email meghajbhat@gmail.com\n• Include device details\n• Describe the problem',
      Icons.bug_report,
    );
  }

  void _showLoginHelpDialog() {
    _showInfoDialog(
      'Login Problems',
      'Can\'t sign in? Try these steps:\n\n• Check email and password\n• Use "Forgot Password" if needed\n• Ensure internet connection\n• Try different network\n• Clear browser cache\n\nAccount Issues:\n• Verify email address\n• Check spam folder\n• Contact support if locked out\n• Email meghajbhat@gmail.com',
      Icons.login,
    );
  }

  void _showSyncHelpDialog() {
    _showInfoDialog(
      'Data Not Syncing',
      'If information isn\'t updating:\n\n• Check internet connection\n• Wait a few minutes\n• Refresh the app\n• Log out and back in\n• Restart the app\n\nData Issues:\n• Changes save automatically\n• Check all required fields\n• Verify child is linked\n• Contact therapist if needed',
      Icons.sync,
    );
  }

  void _showEmailSupportDialog() {
    _showInfoDialog(
      'Email Support',
      'Need help? Send us an email:\n\nEmail: meghajbhat@gmail.com\n\nInclude in your message:\n• Your name and email\n• Child\'s name\n• Description of the problem\n• Device type and app version\n• Screenshots if helpful\n\nResponse time: Within 24 hours',
      Icons.email,
    );
  }

  void _showEmergencyContactDialog() {
    _showInfoDialog(
      'Emergency Contact',
      'For urgent issues:\n\nEmergency Email: meghajbhat@gmail.com\n\nUse for:\n• App security issues\n• Child safety concerns\n• Data privacy violations\n• Account hacking attempts\n• Critical technical problems\n\nResponse time: Within 2 hours',
      Icons.phone,
    );
  }

  void _showFeedbackDialog() {
    _showInfoDialog(
      'Send Feedback',
      'We value your input! Share:\n\n• App improvement suggestions\n• New feature requests\n• User experience feedback\n• Bug reports\n• General comments\n\nEmail: meghajbhat@gmail.com\n\nYour feedback helps us make BloomBuddy better for families!',
      Icons.feedback,
    );
  }

  void _showNotificationSettingsDialog() {
    // Load current settings before showing dialog
    _loadNotificationSettings();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications,
                      color: Colors.orange[700],
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notification Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
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
                        // Email Notifications Section
                        _buildNotificationSection('Email Notifications', [
                          _buildNotificationOption(
                            icon: Icons.email,
                            title: 'Email Notifications',
                            subtitle: 'Receive notifications via email',
                            value: emailNotifications,
                            onChanged: (value) {
                              setDialogState(() {
                                emailNotifications = value;
                              });
                              _saveNotificationSettings();
                            },
                          ),
                          _buildNotificationOption(
                            icon: Icons.mood,
                            title: 'Emotion Alerts',
                            subtitle: 'Get notified about emotional changes',
                            value: emotionAlerts,
                            onChanged: (value) {
                              setDialogState(() {
                                emotionAlerts = value;
                              });
                              _saveNotificationSettings();
                            },
                          ),
                          _buildNotificationOption(
                            icon: Icons.trending_up,
                            title: 'Progress Updates',
                            subtitle: 'Weekly progress reports',
                            value: progressUpdates,
                            onChanged: (value) {
                              setDialogState(() {
                                progressUpdates = value;
                              });
                              _saveNotificationSettings();
                            },
                          ),
                          _buildNotificationOption(
                            icon: Icons.schedule,
                            title: 'Therapy Reminders',
                            subtitle: 'Reminders for therapy sessions',
                            value: therapyReminders,
                            onChanged: (value) {
                              setDialogState(() {
                                therapyReminders = value;
                              });
                              _saveNotificationSettings();
                            },
                          ),
                        ]),

                        // Push Notifications Section
                        _buildNotificationSection('Push Notifications', [
                          _buildNotificationOption(
                            icon: Icons.notifications_active,
                            title: 'Push Notifications',
                            subtitle: 'Receive notifications on your device',
                            value: pushNotifications,
                            onChanged: (value) {
                              setDialogState(() {
                                pushNotifications = value;
                              });
                              _saveNotificationSettings();
                            },
                          ),
                          _buildNotificationOption(
                            icon: Icons.warning,
                            title: 'Emergency Alerts',
                            subtitle: 'Critical safety notifications',
                            value: emergencyAlerts,
                            onChanged: (value) {
                              setDialogState(() {
                                emergencyAlerts = value;
                              });
                              _saveNotificationSettings();
                            },
                          ),
                        ]),

                        // Notification Frequency Section
                        _buildNotificationSection('Notification Frequency', [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email Frequency',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Daily summaries • Weekly reports • Emergency alerts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Push Notification Times',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '9:00 AM - 8:00 PM (respects quiet hours)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
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
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Notification Settings Helper Methods
  Widget _buildNotificationSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange[700],
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNotificationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange[600]),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.orange[700],
        ),
      ),
    );
  }

  Future<void> _saveNotificationSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'emailNotifications': emailNotifications,
          'pushNotifications': pushNotifications,
          'emotionAlerts': emotionAlerts,
          'progressUpdates': progressUpdates,
          'therapyReminders': therapyReminders,
          'emergencyAlerts': emergencyAlerts,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Settings saved successfully - no need to show message as changes are visible immediately
      } catch (e) {
        print('Error saving notification settings: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save notification settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInfoDialog(String title, String content, IconData icon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: Colors.purple[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Text(
              content,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ChildInfoForm extends StatefulWidget {
  final Map<String, dynamic> child;
  final VoidCallback onSave;

  const ChildInfoForm({super.key, required this.child, required this.onSave});

  @override
  State<ChildInfoForm> createState() => _ChildInfoFormState();
}

class _ChildInfoFormState extends State<ChildInfoForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _genderController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _bloodGroupController;
  late TextEditingController _medicalConditionsController;
  late TextEditingController _medicationsController;
  late TextEditingController _allergiesController;
  late TextEditingController _triggerPointsController;
  late TextEditingController _likesController;
  late TextEditingController _dislikesController;
  late TextEditingController _behavioralPatternsController;
  late TextEditingController _communicationStyleController;
  late TextEditingController _learningStyleController;
  late TextEditingController _socialPreferencesController;
  late TextEditingController _familyHistoryController;
  late TextEditingController _therapyGoalsController;
  late TextEditingController _emergencyContactsController;
  late TextEditingController _schoolInfoController;
  late TextEditingController _additionalNotesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child['name'] ?? '');
    _ageController = TextEditingController(
      text: widget.child['age']?.toString() ?? '',
    );
    _genderController = TextEditingController(
      text: widget.child['gender'] ?? '',
    );
    _heightController = TextEditingController(
      text: widget.child['height']?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: widget.child['weight']?.toString() ?? '',
    );
    _bloodGroupController = TextEditingController(
      text: widget.child['bloodGroup'] ?? '',
    );
    _medicalConditionsController = TextEditingController(
      text: widget.child['medicalConditions'] ?? '',
    );
    _medicationsController = TextEditingController(
      text: widget.child['medications'] ?? '',
    );
    _allergiesController = TextEditingController(
      text: widget.child['allergies'] ?? '',
    );
    _triggerPointsController = TextEditingController(
      text: widget.child['triggerPoints'] ?? '',
    );
    _likesController = TextEditingController(text: widget.child['likes'] ?? '');
    _dislikesController = TextEditingController(
      text: widget.child['dislikes'] ?? '',
    );
    _behavioralPatternsController = TextEditingController(
      text: widget.child['behavioralPatterns'] ?? '',
    );
    _communicationStyleController = TextEditingController(
      text: widget.child['communicationStyle'] ?? '',
    );
    _learningStyleController = TextEditingController(
      text: widget.child['learningStyle'] ?? '',
    );
    _socialPreferencesController = TextEditingController(
      text: widget.child['socialPreferences'] ?? '',
    );
    _familyHistoryController = TextEditingController(
      text: widget.child['familyHistory'] ?? '',
    );
    _therapyGoalsController = TextEditingController(
      text: widget.child['therapyGoals'] ?? '',
    );
    _emergencyContactsController = TextEditingController(
      text: widget.child['emergencyContacts'] ?? '',
    );
    _schoolInfoController = TextEditingController(
      text: widget.child['schoolInfo'] ?? '',
    );
    _additionalNotesController = TextEditingController(
      text: widget.child['additionalNotes'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bloodGroupController.dispose();
    _medicalConditionsController.dispose();
    _medicationsController.dispose();
    _allergiesController.dispose();
    _triggerPointsController.dispose();
    _likesController.dispose();
    _dislikesController.dispose();
    _behavioralPatternsController.dispose();
    _communicationStyleController.dispose();
    _learningStyleController.dispose();
    _socialPreferencesController.dispose();
    _familyHistoryController.dispose();
    _therapyGoalsController.dispose();
    _emergencyContactsController.dispose();
    _schoolInfoController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.child_care, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Child Information Form',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
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
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSection('Basic Information', [
                        _buildTextField(
                          _nameController,
                          'Full Name',
                          Icons.person,
                        ),
                        _buildTextField(
                          _ageController,
                          'Age',
                          Icons.cake,
                          TextInputType.number,
                        ),
                        _buildTextField(_genderController, 'Gender', Icons.wc),
                        _buildTextField(
                          _heightController,
                          'Height (cm)',
                          Icons.height,
                          TextInputType.number,
                        ),
                        _buildTextField(
                          _weightController,
                          'Weight (kg)',
                          Icons.monitor_weight,
                          TextInputType.number,
                        ),
                        _buildTextField(
                          _bloodGroupController,
                          'Blood Group',
                          Icons.bloodtype,
                        ),
                      ]),
                      _buildSection('Medical Information', [
                        _buildTextField(
                          _medicalConditionsController,
                          'Medical Conditions',
                          Icons.medical_services,
                          TextInputType.multiline,
                        ),
                        _buildTextField(
                          _medicationsController,
                          'Current Medications',
                          Icons.medication,
                          TextInputType.multiline,
                        ),
                        _buildTextField(
                          _allergiesController,
                          'Allergies',
                          Icons.warning,
                          TextInputType.multiline,
                        ),
                      ]),
                      _buildSection('Emotional & Behavioral Information', [
                        _buildTextField(
                          _triggerPointsController,
                          'Trigger Points (What causes stress/anxiety)',
                          Icons.warning_amber,
                          TextInputType.multiline,
                        ),
                        _buildTextField(
                          _behavioralPatternsController,
                          'Behavioral Patterns',
                          Icons.psychology,
                          TextInputType.multiline,
                        ),
                        _buildTextField(
                          _communicationStyleController,
                          'Communication Style & Preferences',
                          Icons.chat,
                          TextInputType.multiline,
                        ),
                      ]),
                      _buildSection('Preferences & Interests', [
                        _buildTextField(
                          _likesController,
                          'Likes & Interests',
                          Icons.favorite,
                          TextInputType.multiline,
                        ),
                        _buildTextField(
                          _dislikesController,
                          'Dislikes & Avoidances',
                          Icons.block,
                          TextInputType.multiline,
                        ),
                        _buildTextField(
                          _learningStyleController,
                          'Learning Style & Preferences',
                          Icons.school,
                          TextInputType.multiline,
                        ),
                        _buildTextField(
                          _socialPreferencesController,
                          'Social Preferences & Comfort Level',
                          Icons.group,
                          TextInputType.multiline,
                        ),
                      ]),
                      _buildSection('Family & Background', [
                        _buildTextField(
                          _familyHistoryController,
                          'Family History (Mental health, relevant background)',
                          Icons.family_restroom,
                          TextInputType.multiline,
                        ),
                        _buildTextField(
                          _schoolInfoController,
                          'School Information & Performance',
                          Icons.school,
                          TextInputType.multiline,
                        ),
                      ]),
                      _buildSection('Therapy & Goals', [
                        _buildTextField(
                          _therapyGoalsController,
                          'Therapy Goals & Objectives',
                          Icons.flag,
                          TextInputType.multiline,
                        ),
                        _buildTextField(
                          _emergencyContactsController,
                          'Emergency Contacts',
                          Icons.emergency,
                          TextInputType.multiline,
                        ),
                      ]),
                      _buildSection('Additional Information', [
                        _buildTextField(
                          _additionalNotesController,
                          'Additional Notes for Therapist',
                          Icons.note_add,
                          TextInputType.multiline,
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveChildInfo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Information'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, [
    TextInputType? keyboardType,
  ]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: keyboardType == TextInputType.multiline ? 3 : 1,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
          ),
        ),
      ),
    );
  }

  Future<void> _saveChildInfo() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.child['uid'])
          .set({
        'name': _nameController.text,
        'age': _ageController.text,
        'gender': _genderController.text,
        'height': _heightController.text,
        'weight': _weightController.text,
        'bloodGroup': _bloodGroupController.text,
        'medicalConditions': _medicalConditionsController.text,
        'medications': _medicationsController.text,
        'allergies': _allergiesController.text,
        'triggerPoints': _triggerPointsController.text,
        'likes': _likesController.text,
        'dislikes': _dislikesController.text,
        'behavioralPatterns': _behavioralPatternsController.text,
        'communicationStyle': _communicationStyleController.text,
        'learningStyle': _learningStyleController.text,
        'socialPreferences': _socialPreferencesController.text,
        'familyHistory': _familyHistoryController.text,
        'therapyGoals': _therapyGoalsController.text,
        'emergencyContacts': _emergencyContactsController.text,
        'schoolInfo': _schoolInfoController.text,
        'additionalNotes': _additionalNotesController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      widget.onSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Child information saved successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving information: $e')));
      }
    }
  }
}
