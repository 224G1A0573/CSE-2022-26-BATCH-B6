import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/session_notes.dart';

class SessionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new session note
  static Future<String> createSessionNote(SessionNotes sessionNote) async {
    try {
      print(
        'DEBUG: Creating session note for child ${sessionNote.childId} on ${sessionNote.sessionDate}',
      );

      final docRef = await _firestore
          .collection('sessionNotes')
          .add(sessionNote.toMap());

      // Update the document with its own ID
      await docRef.update({'id': docRef.id});

      print('DEBUG: Session note created successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('DEBUG: Error creating session note: $e');
      throw Exception('Failed to create session note: $e');
    }
  }

  // Update an existing session note
  static Future<void> updateSessionNote(
    String noteId,
    SessionNotes sessionNote,
  ) async {
    try {
      await _firestore
          .collection('sessionNotes')
          .doc(noteId)
          .update(sessionNote.toMap());
    } catch (e) {
      throw Exception('Failed to update session note: $e');
    }
  }

  // Get session notes for a specific child
  static Future<List<SessionNotes>> getSessionNotesForChild(
    String childId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('sessionNotes')
          .where('childId', isEqualTo: childId)
          .orderBy('sessionDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SessionNotes.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get session notes: $e');
    }
  }

  // Get session notes for a specific therapist
  static Future<List<SessionNotes>> getSessionNotesForTherapist(
    String therapistId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('sessionNotes')
          .where('therapistId', isEqualTo: therapistId)
          .orderBy('sessionDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SessionNotes.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get session notes: $e');
    }
  }

  // Get session notes for a specific parent
  static Future<List<SessionNotes>> getSessionNotesForParent(
    String parentId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('sessionNotes')
          .where('parentId', isEqualTo: parentId)
          .orderBy('sessionDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SessionNotes.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get session notes: $e');
    }
  }

  // Get session note for a specific date and child
  static Future<SessionNotes?> getSessionNoteForDate(
    String childId,
    DateTime date,
  ) async {
    try {
      print('DEBUG: Getting session note for child $childId on date $date');

      // Get the start and end of the day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection('sessionNotes')
          .where('childId', isEqualTo: childId)
          .where(
            'sessionDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'sessionDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .get();

      print(
        'DEBUG: Found ${querySnapshot.docs.length} session notes for date $date',
      );

      if (querySnapshot.docs.isNotEmpty) {
        final sessionNote = SessionNotes.fromMap(
          querySnapshot.docs.first.data(),
        );
        print('DEBUG: Returning session note: ${sessionNote.id}');
        return sessionNote;
      }
      return null;
    } catch (e) {
      print('DEBUG: Error getting session note for date: $e');
      throw Exception('Failed to get session note for date: $e');
    }
  }

  // Upload session note (mark as uploaded and notify parent)
  static Future<void> uploadSessionNote(String noteId) async {
    try {
      print('DEBUG: Uploading session note $noteId');
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Update the session note as uploaded
      await _firestore.collection('sessionNotes').doc(noteId).update({
        'isUploaded': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('DEBUG: Session note $noteId marked as uploaded');

      // Get the session note to create notification
      final sessionDoc = await _firestore
          .collection('sessionNotes')
          .doc(noteId)
          .get();

      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data()!;

        // Create notification for parent
        await _firestore
            .collection('users')
            .doc(sessionData['parentId'])
            .collection('notifications')
            .add({
              'type': 'session_notes_uploaded',
              'title': 'New Session Notes Available',
              'message':
                  'Session notes for ${sessionData['childName']} on ${_formatDate(sessionData['sessionDate'])} have been uploaded by ${sessionData['therapistName']}.',
              'childName': sessionData['childName'],
              'therapistName': sessionData['therapistName'],
              'sessionDate': sessionData['sessionDate'],
              'noteId': noteId,
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
            });
      }
    } catch (e) {
      throw Exception('Failed to upload session note: $e');
    }
  }

  // Delete session note
  static Future<void> deleteSessionNote(String noteId) async {
    try {
      await _firestore.collection('sessionNotes').doc(noteId).delete();
    } catch (e) {
      throw Exception('Failed to delete session note: $e');
    }
  }

  // Get weekly session schedule for a child (Monday-Friday)
  static Future<Map<DateTime, SessionNotes?>> getWeeklySchedule(
    String childId,
    DateTime weekStart,
  ) async {
    try {
      final schedule = <DateTime, SessionNotes?>{};

      // Get Monday of the week
      final monday = weekStart.subtract(Duration(days: weekStart.weekday - 1));

      // Check each day from Monday to Friday
      for (int i = 0; i < 5; i++) {
        final date = monday.add(Duration(days: i));
        final sessionNote = await getSessionNoteForDate(childId, date);
        schedule[date] = sessionNote;
      }

      return schedule;
    } catch (e) {
      throw Exception('Failed to get weekly schedule: $e');
    }
  }

  // Helper method to format date
  static String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown date';
  }

  // Get child information for session notes
  static Future<Map<String, dynamic>?> getChildInfo(String childId) async {
    try {
      final doc = await _firestore.collection('users').doc(childId).get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get child info: $e');
    }
  }

  // Get parent information for session notes
  static Future<Map<String, dynamic>?> getParentInfo(String parentId) async {
    try {
      final doc = await _firestore.collection('users').doc(parentId).get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get parent info: $e');
    }
  }

  // Debug method to test reading session notes
  static Future<void> debugSessionNotes(String childId) async {
    try {
      print('DEBUG: Testing session notes read for child $childId');

      final querySnapshot = await _firestore
          .collection('sessionNotes')
          .where('childId', isEqualTo: childId)
          .get();

      print('DEBUG: Found ${querySnapshot.docs.length} session notes');

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        print('DEBUG: Session note ${doc.id}:');
        print('  - therapistId: ${data['therapistId']}');
        print('  - parentId: ${data['parentId']}');
        print('  - isUploaded: ${data['isUploaded']}');
        print('  - sessionDate: ${data['sessionDate']}');
      }
    } catch (e) {
      print('DEBUG: Error reading session notes: $e');
    }
  }

  // Debug method to test reading session notes for current parent
  static Future<void> debugParentSessionNotes() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('DEBUG: No authenticated user');
        return;
      }

      print('DEBUG: Testing session notes read for parent ${user.uid}');

      final querySnapshot = await _firestore
          .collection('sessionNotes')
          .where('parentId', isEqualTo: user.uid)
          .get();

      print(
        'DEBUG: Found ${querySnapshot.docs.length} session notes for parent',
      );

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        print('DEBUG: Session note ${doc.id}:');
        print('  - childId: ${data['childId']}');
        print('  - therapistId: ${data['therapistId']}');
        print('  - parentId: ${data['parentId']}');
        print('  - isUploaded: ${data['isUploaded']}');
        print('  - sessionDate: ${data['sessionDate']}');
      }
    } catch (e) {
      print('DEBUG: Error reading parent session notes: $e');
    }
  }

  // Debug method to check all session notes
  static Future<void> debugAllSessionNotes() async {
    try {
      print('DEBUG: Testing all session notes');

      final querySnapshot = await _firestore.collection('sessionNotes').get();

      print('DEBUG: Found ${querySnapshot.docs.length} total session notes');

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        print('DEBUG: Session note ${doc.id}:');
        print('  - childId: ${data['childId']}');
        print('  - therapistId: ${data['therapistId']}');
        print('  - parentId: ${data['parentId']}');
        print('  - isUploaded: ${data['isUploaded']}');
        print('  - sessionDate: ${data['sessionDate']}');
      }
    } catch (e) {
      print('DEBUG: Error reading all session notes: $e');
    }
  }
}
