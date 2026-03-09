import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDataMigration {
  static final UserDataMigration _instance = UserDataMigration._internal();
  factory UserDataMigration() => _instance;
  UserDataMigration._internal();

  // Migrate all existing child users to include required fields
  Future<void> migrateAllChildUsers() async {
    try {
      print('Starting migration of child users...');

      // Get all child users
      final childUsersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'kid')
          .get();

      print('Found ${childUsersQuery.docs.length} child users to migrate');

      for (final doc in childUsersQuery.docs) {
        await _migrateChildUser(doc);
      }

      print('Migration completed successfully!');
    } catch (e) {
      print('Error during migration: $e');
    }
  }

  // Migrate a single child user
  Future<void> _migrateChildUser(DocumentSnapshot childDoc) async {
    try {
      final childData = childDoc.data() as Map<String, dynamic>?;
      if (childData == null) return;

      final updates = <String, dynamic>{};

      // Check if parentEmail is missing
      if (childData['parentEmail'] == null ||
          childData['parentEmail'].toString().isEmpty) {
        final parentEmail = await _findParentEmail(childData);
        updates['parentEmail'] = parentEmail;
        print(
            'Added parentEmail: $parentEmail for child: ${childData['displayName']}');
      }

      // Check if emotion detection fields are missing
      if (childData['emotionDetectionActive'] == null) {
        updates['emotionDetectionActive'] = false;
      }

      if (childData['emotionDetectionStartedAt'] == null) {
        updates['emotionDetectionStartedAt'] = null;
      }

      if (childData['emotionDetectionStoppedAt'] == null) {
        updates['emotionDetectionStoppedAt'] = null;
      }

      // Update the document if any fields are missing
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(childDoc.id)
            .update(updates);

        print(
            'Migrated child user: ${childData['displayName']} - Added fields: ${updates.keys.join(', ')}');
      } else {
        print(
            'Child user already has all required fields: ${childData['displayName']}');
      }
    } catch (e) {
      print('Error migrating child user ${childDoc.id}: $e');
    }
  }

  // Find parent email for a child
  Future<String> _findParentEmail(Map<String, dynamic> childData) async {
    try {
      // First, try to find any parent user in the system
      final parentQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();

      if (parentQuery.docs.isNotEmpty) {
        final parentData = parentQuery.docs.first.data();
        final parentEmail = parentData['email'] as String?;
        if (parentEmail != null && parentEmail.isNotEmpty) {
          return parentEmail;
        }
      }

      // If no parent found, create a default parent email based on child's email
      final childEmail = childData['email'] as String? ?? '';
      if (childEmail.isNotEmpty) {
        final emailParts = childEmail.split('@');
        if (emailParts.length == 2) {
          return 'parent.${emailParts[0]}@${emailParts[1]}';
        }
      }

      // Final fallback
      return 'parent@bloombuddy.com';
    } catch (e) {
      print('Error finding parent email: $e');
      return 'parent@bloombuddy.com';
    }
  }

  // Migrate current user (for testing)
  Future<void> migrateCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        await _migrateChildUser(userDoc);
      } else {
        print('User document not found');
      }
    } catch (e) {
      print('Error migrating current user: $e');
    }
  }

  // Check if user needs migration
  Future<bool> needsMigration(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) return false;

      // Check if any required fields are missing
      return userData['parentEmail'] == null ||
          userData['parentEmail'].toString().isEmpty ||
          userData['emotionDetectionActive'] == null ||
          userData['emotionDetectionStartedAt'] == null ||
          userData['emotionDetectionStoppedAt'] == null;
    } catch (e) {
      print('Error checking migration status: $e');
      return false;
    }
  }
}
