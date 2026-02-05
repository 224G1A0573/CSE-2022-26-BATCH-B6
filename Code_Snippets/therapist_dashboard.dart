import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'widgets/monthly_therapy_calendar.dart';
import 'screens/therapist_chat_screen.dart';
import 'screens/canvas_session_launcher.dart';
import 'screens/emotion_game_reports_screen.dart';
import 'screens/all_games_reports_screen.dart';
import 'screens/aac_progress_report_screen.dart';
import 'services/chat_service.dart';

class TherapistDashboard extends StatefulWidget {
  const TherapistDashboard({super.key});

  @override
  State<TherapistDashboard> createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends State<TherapistDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? therapistData;
  List<Map<String, dynamic>> assignedChildren = [];
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  int selectedTabIndex = 0;
  Set<String> expandedChildren = {}; // Track which children are expanded
  int chatUnreadCount = 0;
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _loadChatUnreadCount();
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

  Future<void> _loadAllData() async {
    await Future.wait([
      fetchTherapistData(),
      fetchAssignedChildren(),
      fetchNotifications(),
    ]);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchTherapistData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    setState(() {
      therapistData = doc.data();
    });
  }

  Future<void> fetchAssignedChildren() async {
    if (user == null) return;

    // Fetch children assigned to this therapist (including pending assignments)
    final childrenQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'kid')
        .where('therapistId', isEqualTo: user!.uid)
        .get();

    // Also fetch pending assignments from notifications
    final pendingQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('notifications')
        .where('type', isEqualTo: 'assignment_response')
        .where('status', isEqualTo: 'pending')
        .get();

    setState(() {
      assignedChildren = childrenQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Add pending assignments to the list
      for (var notification in pendingQuery.docs) {
        final data = notification.data();
        assignedChildren.add({
          'id': data['childId'],
          'name': data['childName'],
          'assignmentStatus': 'pending',
          'isPending': true,
        });
      }
    });
  }

  Future<void> fetchNotifications() async {
    if (user == null) return;

    final notificationsQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      notifications = notificationsQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    });
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
      text: therapistData?['displayName'] ?? '',
    );
    final ageController = TextEditingController(
      text: therapistData?['age']?.toString() ?? '',
    );
    final experienceController = TextEditingController(
      text: therapistData?['experience']?.toString() ?? '',
    );
    final genderController = TextEditingController(
      text: therapistData?['gender'] ?? '',
    );
    final specializationController = TextEditingController(
      text: therapistData?['specialization'] ?? '',
    );
    final bioController = TextEditingController(
      text: therapistData?['bio'] ?? '',
    );
    final qualificationsController = TextEditingController(
      text: therapistData?['qualifications'] ?? '',
    );
    final licenseController = TextEditingController(
      text: therapistData?['license'] ?? '',
    );
    final phoneController = TextEditingController(
      text: therapistData?['phone'] ?? '',
    );
    final addressController = TextEditingController(
      text: therapistData?['address'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Therapist Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue[100],
                  child: Icon(
                    Icons.psychology,
                    size: 50,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: genderController.text.isNotEmpty
                          ? genderController.text
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Gender *',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Male', 'Female', 'Other', 'Prefer not to say']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          genderController.text = newValue;
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: experienceController,
                decoration: const InputDecoration(
                  labelText: 'Years of Experience *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: specializationController,
                decoration: const InputDecoration(
                  labelText: 'Specialization *',
                  hintText: 'e.g., Child Psychology, Behavioral Therapy',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qualificationsController,
                decoration: const InputDecoration(
                  labelText: 'Qualifications *',
                  hintText:
                      'e.g., PhD in Psychology, Licensed Clinical Psychologist',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: licenseController,
                decoration: const InputDecoration(
                  labelText: 'License Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(
                  labelText: 'Professional Bio',
                  hintText: 'Tell us about your approach and experience...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Text(
                'Email: ${therapistData?['email'] ?? ''}',
                style: TextStyle(color: Colors.grey[600]),
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
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  ageController.text.isEmpty ||
                  experienceController.text.isEmpty ||
                  genderController.text.isEmpty ||
                  specializationController.text.isEmpty ||
                  qualificationsController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .set({
                'displayName': nameController.text,
                'age': int.tryParse(ageController.text) ?? 0,
                'experience': int.tryParse(experienceController.text) ?? 0,
                'gender': genderController.text,
                'specialization': specializationController.text,
                'qualifications': qualificationsController.text,
                'license': licenseController.text,
                'phone': phoneController.text,
                'address': addressController.text,
                'bio': bioController.text,
                'profileComplete': true,
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              Navigator.pop(context);
              fetchTherapistData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated successfully!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void showAssignChildDialog() {
    final childEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Child'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the child\'s email address to assign them to you:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: childEmailController,
              decoration: const InputDecoration(
                labelText: 'Child Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
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
              if (childEmailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email address'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Find child by email
              final childQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'kid')
                  .where('email', isEqualTo: childEmailController.text)
                  .get();

              if (childQuery.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No child found with this email address'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final childDoc = childQuery.docs.first;
              final childData = childDoc.data();

              // Check if child already has a therapist
              if (childData['therapistId'] != null &&
                  childData['therapistId'] != user!.uid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This child is already assigned to another therapist',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // DON'T update child document yet - wait for parent acceptance
              // Just create notification for parent to review
              print(
                'DEBUG: Creating assignment request notification (not updating child yet)',
              );

              // Create notification for parent
              print('DEBUG: Child data: $childData');
              print('DEBUG: Guardian email: ${childData['guardianEmail']}');
              print('DEBUG: Parent email: ${childData['parentEmail']}');

              if (childData['guardianEmail'] != null ||
                  childData['parentEmail'] != null) {
                final parentEmail =
                    childData['guardianEmail'] ?? childData['parentEmail'];
                print('DEBUG: Looking for parent with email: $parentEmail');

                // Find parent by email
                final parentQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'parent')
                    .where('email', isEqualTo: parentEmail)
                    .get();

                print('DEBUG: Found ${parentQuery.docs.length} parents');

                if (parentQuery.docs.isNotEmpty) {
                  final parentId = parentQuery.docs.first.id;
                  print('DEBUG: Creating notification for parent: $parentId');

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(parentId)
                      .collection('notifications')
                      .add({
                    'type': 'therapist_assignment',
                    'title': 'New Therapist Assignment',
                    'message':
                        '${therapistData?['displayName']} has requested to be assigned as your child\'s therapist. Please review and accept or reject this assignment.',
                    'childName': childData['name'] ?? 'Unknown Child',
                    'therapistName':
                        therapistData?['displayName'] ?? 'Unknown Therapist',
                    'therapistId': user!.uid,
                    'childId': childDoc.id,
                    'status': 'pending',
                    'timestamp': FieldValue.serverTimestamp(),
                    'read': false,
                  });
                  print('DEBUG: Notification created successfully');
                } else {
                  print('DEBUG: No parent found with email: $parentEmail');
                }
              } else {
                print('DEBUG: Child has no guardian or parent email set');
              }

              Navigator.pop(context);
              fetchAssignedChildren();

              // Check if notification was created
              if (childData['guardianEmail'] != null ||
                  childData['parentEmail'] != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Child assignment request sent to parent'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Child assigned but no parent email found. Please ensure the child is linked to a parent first.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showRemoveChildDialog(Map<String, dynamic> child) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Child Assignment'),
        content: Text(
          'Are you sure you want to remove ${child['name'] ?? 'this child'} from your assigned children? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Remove therapist assignment from child
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(child['id'])
                    .update({
                  'therapistId': FieldValue.delete(),
                  'therapistName': FieldValue.delete(),
                  'assignmentStatus': FieldValue.delete(),
                  'assignedAt': FieldValue.delete(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                // Create notification for parent
                if (child['guardianEmail'] != null ||
                    child['parentEmail'] != null) {
                  final parentEmail =
                      child['guardianEmail'] ?? child['parentEmail'];
                  final parentQuery = await FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'parent')
                      .where('email', isEqualTo: parentEmail)
                      .get();

                  if (parentQuery.docs.isNotEmpty) {
                    final parentId = parentQuery.docs.first.id;
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(parentId)
                        .collection('notifications')
                        .add({
                      'type': 'therapist_removal',
                      'title': 'Therapist Assignment Removed',
                      'message':
                          '${therapistData?['displayName']} has removed themselves as your child\'s therapist.',
                      'childName': child['name'] ?? 'Unknown Child',
                      'therapistName':
                          therapistData?['displayName'] ?? 'Unknown Therapist',
                      'timestamp': FieldValue.serverTimestamp(),
                      'read': false,
                    });
                  }
                }

                Navigator.pop(context);
                fetchAssignedChildren();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Child assignment removed successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error removing assignment: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B73FF), Color(0xFF000DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${therapistData?['displayName'] ?? 'Therapist'}!',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            therapistData?['specialization'] ??
                                'Mental Health Professional',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.account_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: showProfileDialog,
                      tooltip: 'Profile',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _logout,
                      tooltip: 'Logout',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ),

              // Responsive Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton('Profile', 0, Icons.person),
                      _buildTabButton('Children', 1, Icons.child_care),
                      _buildTabButton('Calendar', 2, Icons.calendar_today),
                      _buildTabButton('Chat', 3, Icons.chat),
                      _buildTabButton('Notifications', 4, Icons.notifications),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: selectedTabIndex == 0
                      ? _buildProfileTab()
                      : selectedTabIndex == 1
                          ? _buildChildrenTab()
                          : selectedTabIndex == 2
                              ? _buildCalendarTab()
                              : selectedTabIndex == 3
                                  ? _buildChatTab()
                                  : _buildNotificationsTab(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isSelected = selectedTabIndex == index;
    final showBadge = title == 'Chat' && chatUnreadCount > 0;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTabIndex = index;
        });
        // Refresh chat unread count when switching to chat tab
        if (index == 3) {
          _loadChatUnreadCount();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF6B73FF) : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF6B73FF) : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showBadge) ...[
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
    );
  }

  Widget _buildProfileTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Professional Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoCard('Name', therapistData?['displayName'] ?? 'Not set'),
          _buildInfoCard('Age', '${therapistData?['age'] ?? 'Not set'} years'),
          _buildInfoCard('Gender', therapistData?['gender'] ?? 'Not set'),
          _buildInfoCard(
            'Experience',
            '${therapistData?['experience'] ?? 'Not set'} years',
          ),
          _buildInfoCard(
            'Specialization',
            therapistData?['specialization'] ?? 'Not set',
          ),
          _buildInfoCard(
            'Qualifications',
            therapistData?['qualifications'] ?? 'Not set',
          ),
          _buildInfoCard(
            'License',
            therapistData?['license'] ?? 'Not provided',
          ),
          _buildInfoCard('Phone', therapistData?['phone'] ?? 'Not provided'),
          _buildInfoCard(
            'Address',
            therapistData?['address'] ?? 'Not provided',
          ),
          if (therapistData?['bio'] != null &&
              therapistData!['bio'].isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Professional Bio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                therapistData!['bio'],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ],
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: showProfileDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B73FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Text(
                'Assigned Children',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: showAssignChildDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Assign Child',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B73FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: assignedChildren.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.child_care_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No children assigned yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Assign children to start providing therapy',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: assignedChildren.length,
                  itemBuilder: (context, index) {
                    final child = assignedChildren[index];
                    return _buildChildCard(child);
                  },
                ),
        ),
      ],
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
              if (assignedChildren.isNotEmpty)
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showChildSelectionDialog();
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text(
                      'Select Child',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B73FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: assignedChildren.isEmpty
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
                        'No children assigned',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Assign children to access their therapy calendar',
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
            itemCount: assignedChildren.length,
            itemBuilder: (context, index) {
              final child = assignedChildren[index];
              final status = child['assignmentStatus'] ?? 'pending';

              if (status != 'accepted') return const SizedBox.shrink();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6B73FF).withOpacity(0.1),
                  child: const Icon(Icons.child_care, color: Color(0xFF6B73FF)),
                ),
                title: Text(child['name'] ?? 'Unknown Child'),
                subtitle: Text(child['email'] ?? 'No email'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonthlyTherapyCalendar(
                        childId: child['id'],
                        childName: child['name'] ?? 'Unknown Child',
                        userRole: 'therapist',
                        therapistId: user!.uid,
                        therapistName: therapistData?['displayName'] ??
                            'Unknown Therapist',
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

  Widget _buildChatTab() {
    // Refresh unread count when chat tab is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatUnreadCount();
    });
    return TherapistChatScreen(
      onUnreadCountChanged: () {
        _loadChatUnreadCount();
      },
    );
  }

  Widget _buildNotificationsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationCard(notification);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final status = child['assignmentStatus'] ?? 'pending';
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main row with name and remove button
          InkWell(
            onTap: status == 'accepted' ? () {
              setState(() {
                final childId = child['id'] as String? ?? '';
                if (expandedChildren.contains(childId)) {
                  expandedChildren.remove(childId);
                } else {
                  expandedChildren.add(childId);
                }
              });
            } : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF6B73FF).withOpacity(0.1),
                    child: const Icon(
                      Icons.child_care,
                      color: Color(0xFF6B73FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      child['name'] ?? 'Unknown Child',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (status == 'accepted')
                    Icon(
                      expandedChildren.contains(child['id'] as String? ?? '')
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                  if (status != 'pending') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => _showRemoveChildDialog(child),
                      tooltip: 'Remove',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Expandable buttons section (only for accepted children)
          if (status == 'accepted' && expandedChildren.contains(child['id'] as String? ?? '')) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MonthlyTherapyCalendar(
                                  childId: child['id'],
                                  childName: child['name'] ?? 'Unknown Child',
                                  userRole: 'therapist',
                                  therapistId: user!.uid,
                                  therapistName: therapistData?['displayName'] ??
                                      'Unknown Therapist',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text('Calendar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B73FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CanvasSessionLauncher(
                                  isTherapist: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.palette, size: 18),
                          label: const Text('Draw'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B73FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AllGamesReportsScreen(
                                  childId: child['id'],
                                  childName: child['name'] ?? 'Unknown Child',
                                  isParentView: false,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.sports_esports, size: 18),
                          label: const Text('Reports'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B9D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AACProgressReportScreen(
                                  childId: child['id'],
                                  childName: child['name'] ?? 'Unknown Child',
                                  isParentView: false,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble, size: 18),
                          label: const Text('AAC'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ECDC4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showCanvasArtworkReports(child['id'], child['name'] ?? 'Unknown Child');
                      },
                      icon: const Icon(Icons.palette, size: 18),
                      label: const Text('Canvas Artwork Reports'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: const Text(
                      'Waiting for parent response',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification['read'] == false ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification['read'] == false
              ? Colors.blue[200]!
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications,
            color:
                notification['read'] == false ? Colors.blue : Colors.grey[600],
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
                    fontWeight: notification['read'] == false
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification['message'] ?? '',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTimestamp(notification['timestamp']),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _clearNotification(notification['id']),
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Clear notification',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
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

  // Fun Classes Dialog - Shows available classes for the child
  void _showClassesDialog(Map<String, dynamic> child) {
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available Classes',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'For ${child['name'] ?? 'Student'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
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
                        description: 'Creative expression through art',
                        color: const Color(0xFFFF6B9D),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎨 Art class available'),
                              backgroundColor: Color(0xFFFF6B9D),
                            ),
                          );
                        },
                      ),
                      _buildClassCard(
                        emoji: '🎵',
                        title: 'Music & Singing',
                        description: 'Musical therapy and expression',
                        color: const Color(0xFF9C27B0),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎵 Music class available'),
                              backgroundColor: Color(0xFF9C27B0),
                            ),
                          );
                        },
                      ),
                      _buildClassCard(
                        emoji: '🧮',
                        title: 'Math Fun',
                        description: 'Cognitive development through numbers',
                        color: const Color(0xFF4ECDC4),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🧮 Math class available'),
                              backgroundColor: Color(0xFF4ECDC4),
                            ),
                          );
                        },
                      ),
                      _buildClassCard(
                        emoji: '📖',
                        title: 'Story Time',
                        description: 'Language and imagination building',
                        color: const Color(0xFF44A08D),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📖 Story time available'),
                              backgroundColor: Color(0xFF44A08D),
                            ),
                          );
                        },
                      ),
                      _buildClassCard(
                        emoji: '🌍',
                        title: 'World Explorer',
                        description: 'Learning about the world',
                        color: const Color(0xFF2196F3),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🌍 Explorer class available'),
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

  // Individual Class Card for Therapist View
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

  Future<void> _showCanvasArtworkReports(String childId, String childName) async {
    if (user == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Load artwork from BOTH therapist's collection AND child's collection
      // This ensures therapist sees all artwork: collaborative sessions + child's own drawings
      final therapistArtworkFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('canvasArtwork')
          .where('childId', isEqualTo: childId)
          .get();
      
      final childArtworkFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('canvasArtwork')
          .get();
      
      // Wait for both queries
      final results = await Future.wait([therapistArtworkFuture, childArtworkFuture]);
      final therapistArtwork = results[0] as QuerySnapshot;
      final childArtwork = results[1] as QuerySnapshot;
      
      print('🔍 Therapist artwork count: ${therapistArtwork.docs.length}');
      print('🔍 Child artwork count: ${childArtwork.docs.length}');
      
      // Combine both collections and remove duplicates (by sessionId if available, or by image hash)
      final allDocs = <QueryDocumentSnapshot>[];
      final seenSessionIds = <String>{};
      
      // Add therapist's artwork first
      for (var doc in therapistArtwork.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final sessionId = data['sessionId'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) {
          if (!seenSessionIds.contains(sessionId)) {
            seenSessionIds.add(sessionId);
            allDocs.add(doc);
          }
        } else {
          // If no sessionId, add it (might be from old data)
          allDocs.add(doc);
        }
      }
      
      // Add child's artwork (excluding duplicates)
      for (var doc in childArtwork.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final sessionId = data['sessionId'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) {
          if (!seenSessionIds.contains(sessionId)) {
            seenSessionIds.add(sessionId);
            allDocs.add(doc);
          }
        } else {
          // If no sessionId, check by timestamp and image similarity
          final docTime = (data['savedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          bool isDuplicate = false;
          for (var existingDoc in allDocs) {
            final existingData = existingDoc.data() as Map<String, dynamic>;
            final existingTime = (existingData['savedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            // If same timestamp (within 1 second), likely duplicate
            if ((docTime - existingTime).abs() < 1000) {
              isDuplicate = true;
              break;
            }
          }
          if (!isDuplicate) {
            allDocs.add(doc);
          }
        }
      }
      
      // Sort by savedAt descending in memory
      final sortedDocs = allDocs
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['savedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (bData['savedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime); // Descending order
        });

      print('✅ Total unique artwork after deduplication: ${sortedDocs.length}');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      if (sortedDocs.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Artwork Found'),
            content: Text('No canvas artwork reports found for $childName yet.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Show artwork list dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            child: Column(
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
                            const Text(
                              'Canvas Artwork Reports',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '$childName • All artwork (collaborative + child\'s drawings)',
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
                // Artwork list
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Create a map to track which docs are from child collection
                      final childDocIds = childArtwork.docs.map((doc) => doc.id).toSet();
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedDocs.length,
                        itemBuilder: (context, index) {
                          final artwork = sortedDocs[index];
                          final data = artwork.data() as Map<String, dynamic>;
                          // Store document reference and collection info for updating
                          final artworkInfo = {
                            'data': data,
                            'docId': artwork.id,
                            'isFromChildCollection': childDocIds.contains(artwork.id),
                          };
                          return _buildArtworkReportCard(data, artwork.id, artworkInfo);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error loading artwork: $e'),
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

  Widget _buildArtworkReportCard(Map<String, dynamic> data, String artworkId, [Map<String, dynamic>? artworkInfo]) {
    final name = data['name'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final aiInsights = data['aiInsights'] as String? ?? '';
    final base64Image = data['imageBase64'] as String?;
    final timestamp = (data['savedAt'] as Timestamp?)?.toDate();
    final sessionDuration = data['sessionDurationMinutes'] as int? ?? 0;
    final totalStrokes = data['totalStrokes'] as int? ?? 0;
    final hasTherapistReport = description.isNotEmpty;
    final isRecent = timestamp != null && 
        DateTime.now().difference(timestamp).inDays <= 7; // Within last 7 days

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isRecent ? Colors.blue[50] : null,
      child: InkWell(
        onTap: () => _showArtworkDetails(data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isRecent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (hasTherapistReport) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.note, size: 16, color: Colors.blue[700]),
                        ],
                      ],
                    ),
                  ),
                  if (timestamp != null)
                    Text(
                      '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (description.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your Report: $description',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              if (aiInsights.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Insights: $aiInsights',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Duration: ${sessionDuration}min',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.edit, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Strokes: $totalStrokes',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tap to view full details',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (!hasTherapistReport)
                    TextButton.icon(
                      onPressed: () => _addReportToArtwork(artworkId, data, artworkInfo),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Add Report', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  void _showArtworkDetails(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final aiInsights = data['aiInsights'] as String? ?? '';
    final base64Image = data['imageBase64'] as String?;
    final timestamp = (data['savedAt'] as Timestamp?)?.toDate();
    final sessionDuration = data['sessionDurationMinutes'] as int? ?? 0;
    final totalStrokes = data['totalStrokes'] as int? ?? 0;
    final emotionCounts = data['emotionCounts'] as Map<String, dynamic>? ?? {};

    // Decode image once to prevent flickering
    Uint8List? imageBytes;
    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        imageBytes = base64Decode(base64Image);
      } catch (e) {
        print('Error decoding image: $e');
      }
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
                              if (timestamp != null)
                                Text(
                                  '${timestamp.day}/${timestamp.month}/${timestamp.year}',
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
                  // Image
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
                  // Session Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.timer, color: Colors.blue),
                                const SizedBox(height: 4),
                                Text(
                                  '$sessionDuration min',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Text(
                                  'Duration',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.edit, color: Colors.purple),
                                const SizedBox(height: 4),
                                Text(
                                  '$totalStrokes',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Text(
                                  'Strokes',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Therapist's Report
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.note, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Your Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                        ],
                      ),
                    ),
                  // AI Insights
                  if (aiInsights.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'AI-Generated Insights',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                        ],
                      ),
                    ),
                  // Emotion Counts (if available)
                  if (emotionCounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Emotion Analysis',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: emotionCounts.entries.map((entry) {
                              return Chip(
                                label: Text('${entry.key}: ${entry.value}'),
                                backgroundColor: Colors.grey[100],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addReportToArtwork(String artworkId, Map<String, dynamic> artworkData, [Map<String, dynamic>? artworkInfo]) async {
    if (user == null) return;

    final nameController = TextEditingController(text: artworkData['name'] as String? ?? 'Untitled');
    final descriptionController = TextEditingController();
    final aiInsightsController = TextEditingController();

    // Check if we need to find the artwork in child's collection or therapist's collection
    final childId = artworkData['childId'] as String?;
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add report: Child ID not found')),
      );
      return;
    }

    final isFromChildCollection = artworkInfo?['isFromChildCollection'] as bool? ?? true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Progress Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Artwork Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Your Report / Insights',
                  hintText: 'Enter your observations and progress notes...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: aiInsightsController,
                decoration: const InputDecoration(
                  labelText: 'AI-Generated Insights (Optional)',
                  hintText: 'Leave empty to auto-generate, or enter custom insights...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();
              var aiInsights = aiInsightsController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an artwork name')),
                );
                return;
              }

              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your report')),
                );
                return;
              }

              // Auto-generate AI insights if not provided
              if (aiInsights.isEmpty) {
                aiInsights = _generateAIInsights(artworkData, description);
              }

              Navigator.pop(context); // Close dialog

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                // Update artwork in child's collection (this is the source of truth)
                final childArtworkRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(childId)
                    .collection('canvasArtwork')
                    .doc(artworkId);
                
                await childArtworkRef.update({
                  'name': name,
                  'description': description,
                  'aiInsights': aiInsights,
                  'therapistId': user!.uid,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Also update in therapist's collection if it exists
                final therapistArtworkQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('canvasArtwork')
                    .where('childId', isEqualTo: childId)
                    .get();

                bool foundInTherapistCollection = false;
                for (var doc in therapistArtworkQuery.docs) {
                  final data = doc.data();
                  final sessionId = data['sessionId'] as String?;
                  final artworkSessionId = artworkData['sessionId'] as String?;
                  
                  // Match by sessionId or by similar timestamp
                  if (sessionId != null && artworkSessionId != null && sessionId == artworkSessionId) {
                    await doc.reference.update({
                      'name': name,
                      'description': description,
                      'aiInsights': aiInsights,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    foundInTherapistCollection = true;
                    break;
                  }
                }

                // If not found in therapist's collection, add it
                if (!foundInTherapistCollection) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('canvasArtwork')
                      .add({
                    ...artworkData,
                    'name': name,
                    'description': description,
                    'aiInsights': aiInsights,
                    'therapistId': user!.uid,
                    'childId': childId,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }

                if (mounted) Navigator.pop(context); // Close loading

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Report added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Refresh the artwork list
                  Navigator.pop(context); // Close artwork list dialog
                  _showCanvasArtworkReports(childId, artworkData['childName'] as String? ?? 'Child');
                }
              } catch (e) {
                if (mounted) Navigator.pop(context); // Close loading
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding report: $e')),
                  );
                }
              }
            },
            child: const Text('Save Report'),
          ),
        ],
      ),
    );
  }

  String _generateAIInsights(Map<String, dynamic> artworkData, String therapistReport) {
    // Simple AI insights generation based on artwork data and therapist's report
    final totalStrokes = artworkData['totalStrokes'] as int? ?? 0;
    final sessionDuration = artworkData['sessionDurationMinutes'] as int? ?? 0;
    final emotionCounts = artworkData['emotionCounts'] as Map<String, dynamic>? ?? {};

    final insights = <String>[];

    // Analyze engagement
    if (totalStrokes > 100) {
      insights.add('High engagement level with ${totalStrokes} strokes');
    } else if (totalStrokes > 50) {
      insights.add('Moderate engagement with ${totalStrokes} strokes');
    } else {
      insights.add('Lower engagement with ${totalStrokes} strokes');
    }

    // Analyze session duration
    if (sessionDuration > 20) {
      insights.add('Extended session duration (${sessionDuration} minutes) indicates sustained focus');
    } else if (sessionDuration > 10) {
      insights.add('Good session duration (${sessionDuration} minutes)');
    }

    // Analyze emotions
    if (emotionCounts.isNotEmpty) {
      final dominantEmotion = emotionCounts.entries
          .reduce((a, b) => (a.value as int) > (b.value as int) ? a : b);
      insights.add('Dominant emotion during session: ${dominantEmotion.key}');
    }

    // Add therapist report summary
    if (therapistReport.isNotEmpty) {
      insights.add('Therapist observations noted in report');
    }

    return insights.isEmpty 
        ? 'Artwork session completed. Review therapist notes for detailed insights.'
        : insights.join('. ') + '.';
  }
}
