import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});

  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? mentorData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMentorData();
  }

  Future<void> fetchMentorData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    setState(() {
      mentorData = doc.data();
      isLoading = false;
    });
  }

  void showProfileDialog() {
    final nameController =
        TextEditingController(text: mentorData?['displayName'] ?? '');
    final bioController = TextEditingController(text: mentorData?['bio'] ?? '');
    final username = mentorData?['username'] ?? '';
    final email = mentorData?['email'] ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.person, size: 40, color: Colors.blue[700]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text('Username: $username'),
              Text('Email: $email'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .set({
                'displayName': nameController.text,
                'bio': bioController.text,
              }, SetOptions(merge: true));
              Navigator.pop(context);
              fetchMentorData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated!')),
              );
            },
            child: const Text('Save'),
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
              Text(
                'Welcome, ${mentorData?['displayName'] ?? ''}!',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.account_circle, color: Colors.blue),
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
            colors: [Color(0xFF6B73FF), Color(0xFF000DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Container(),
      ),
    );
  }
}
