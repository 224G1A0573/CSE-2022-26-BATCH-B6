import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create or get existing chat room between therapist and parent for a specific child
  Future<String> createOrGetChatRoom({
    required String therapistId,
    required String parentId,
    required String childId,
  }) async {
    try {
      print(
        '🔍 DEBUG: Creating chat room - Therapist: $therapistId, Parent: $parentId, Child: $childId',
      );

      // Check if chat room already exists
      final existingChatQuery = await _firestore
          .collection('chatRooms')
          .where('therapistId', isEqualTo: therapistId)
          .where('parentId', isEqualTo: parentId)
          .where('childId', isEqualTo: childId)
          .limit(1)
          .get();

      print(
        '🔍 DEBUG: Found ${existingChatQuery.docs.length} existing chat rooms',
      );

      if (existingChatQuery.docs.isNotEmpty) {
        final existingId = existingChatQuery.docs.first.id;
        print('✅ DEBUG: Using existing chat room: $existingId');
        return existingId;
      }

      // Get therapist and parent names
      print('🔍 DEBUG: Fetching user data...');
      final therapistDoc = await _firestore
          .collection('users')
          .doc(therapistId)
          .get();
      final parentDoc = await _firestore
          .collection('users')
          .doc(parentId)
          .get();
      final childDoc = await _firestore.collection('users').doc(childId).get();

      if (!therapistDoc.exists || !parentDoc.exists || !childDoc.exists) {
        print(
          '❌ DEBUG: User documents not found - Therapist: ${therapistDoc.exists}, Parent: ${parentDoc.exists}, Child: ${childDoc.exists}',
        );
        throw Exception('User documents not found');
      }

      final therapistData = therapistDoc.data()!;
      final parentData = parentDoc.data()!;
      final childData = childDoc.data()!;

      print('🔍 DEBUG: User data fetched successfully');

      // Create new chat room
      final chatRoomData = {
        'therapistId': therapistId,
        'therapistName':
            therapistData['name'] ??
            therapistData['displayName'] ??
            'Therapist',
        'parentId': parentId,
        'parentName':
            parentData['name'] ?? parentData['displayName'] ?? 'Parent',
        'childId': childId,
        'childName': childData['name'] ?? childData['displayName'] ?? 'Child',
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
        'lastMessage': null,
        'lastMessageSender': null,
      };

      print('🔍 DEBUG: Creating chat room with data: $chatRoomData');
      final docRef = await _firestore.collection('chatRooms').add(chatRoomData);

      print('✅ DEBUG: Chat room created successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ DEBUG: Error creating chat room: $e');
      rethrow;
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String message,
    String? childId,
    String? childName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('🔍 DEBUG: Sending message to chat: $chatId');
      print('🔍 DEBUG: Message: $message');
      print('🔍 DEBUG: Sender: ${user.uid}');

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw Exception('User document not found');

      final userData = userDoc.data()!;
      final senderName = userData['name'] ?? userData['displayName'] ?? 'User';
      final senderRole = userData['role'] ?? 'unknown';

      print('🔍 DEBUG: Sender name: $senderName, role: $senderRole');

      // Create message
      final messageData = {
        'chatId': chatId,
        'senderId': user.uid,
        'senderName': senderName,
        'senderRole': senderRole,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'childId': childId,
        'childName': childName,
      };

      print('🔍 DEBUG: Creating message with data: $messageData');

      // Add message to messages subcollection
      await _firestore
          .collection('chatRooms')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      print('🔍 DEBUG: Message added to subcollection');

      // Update chat room with last message info
      // Note: unreadCount is not used anymore - we calculate from actual unread messages
      // But we keep it for backward compatibility with existing code that might reference it
      await _firestore.collection('chatRooms').doc(chatId).update({
        'lastMessage': message,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSender': senderName,
        // Don't increment unreadCount here - we calculate it from actual unread messages
      });

      print('✅ DEBUG: Message sent successfully to chat: $chatId');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  // Get chat room for current user
  Future<List<ChatRoom>> getChatRoomsForUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('🔍 DEBUG: Getting chat rooms for user: ${user.uid}');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw Exception('User document not found');

      final userData = userDoc.data()!;
      final userRole = userData['role'] ?? 'unknown';

      print('🔍 DEBUG: User role: $userRole');

      Query query;

      if (userRole == 'therapist') {
        // Get all chat rooms where current user is the therapist
        print('🔍 DEBUG: Querying chat rooms for therapist: ${user.uid}');
        query = _firestore
            .collection('chatRooms')
            .where('therapistId', isEqualTo: user.uid);
      } else if (userRole == 'parent') {
        // Get all chat rooms where current user is the parent
        print('🔍 DEBUG: Querying chat rooms for parent: ${user.uid}');
        query = _firestore
            .collection('chatRooms')
            .where('parentId', isEqualTo: user.uid);
      } else {
        throw Exception('Invalid user role for chat');
      }

      print('🔍 DEBUG: Executing query...');
      final snapshot = await query.get();
      print('🔍 DEBUG: Query returned ${snapshot.docs.length} documents');

      final chatRooms = snapshot.docs
          .map((doc) => ChatRoom.fromFirestore(doc))
          .toList();

      // Sort by lastMessageAt in descending order (most recent first)
      chatRooms.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      print('🔍 DEBUG: Returning ${chatRooms.length} sorted chat rooms');
      return chatRooms;
    } catch (e) {
      print('❌ Error getting chat rooms: $e');
      return [];
    }
  }

  // Get messages for a chat room
  Stream<List<ChatMessage>> getMessages(String chatId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
        });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get all unread messages (avoiding composite index requirement)
      final allUnreadMessages = await _firestore
          .collection('chatRooms')
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      // Filter in memory for messages from other users (not current user)
      final otherUserUnreadMessages = allUnreadMessages.docs
          .where((doc) {
            final data = doc.data();
            return data['senderId'] != user.uid;
          })
          .toList();

      // Mark each unread message from other users as read
      if (otherUserUnreadMessages.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in otherUserUnreadMessages) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }

      // Reset unread count (for backward compatibility)
      await _firestore.collection('chatRooms').doc(chatId).update({
        'unreadCount': 0,
      });

      print('✅ Messages marked as read for chat: $chatId');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  // Get unread message count for a user
  // This calculates based on actual unread messages (not the stored unreadCount field)
  Future<int> getUnreadMessageCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return 0;

      final userData = userDoc.data()!;
      final userRole = userData['role'] ?? 'unknown';

      Query query;

      if (userRole == 'therapist') {
        query = _firestore
            .collection('chatRooms')
            .where('therapistId', isEqualTo: user.uid);
      } else if (userRole == 'parent') {
        query = _firestore
            .collection('chatRooms')
            .where('parentId', isEqualTo: user.uid);
      } else {
        return 0;
      }

      final snapshot = await query.get();
      int totalUnread = 0;

      // Count actual unread messages (messages from the other user that are not read)
      for (var doc in snapshot.docs) {
        final chatId = doc.id;
        
        // Get all unread messages (avoiding composite index requirement)
        // Then filter in memory for messages from other users
        final unreadMessages = await _firestore
            .collection('chatRooms')
            .doc(chatId)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .get();
        
        // Filter in memory for messages from other users (not current user)
        final otherUserUnreadMessages = unreadMessages.docs
            .where((doc) {
              final data = doc.data();
              return data['senderId'] != user.uid;
            })
            .length;
        
        totalUnread += otherUserUnreadMessages;
      }

      return totalUnread;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // Delete chat room (admin function)
  Future<void> deleteChatRoom(String chatId) async {
    try {
      // Delete all messages first
      final messagesSnapshot = await _firestore
          .collection('chatRooms')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete chat room
      await _firestore.collection('chatRooms').doc(chatId).delete();

      print('✅ Chat room deleted: $chatId');
    } catch (e) {
      print('❌ Error deleting chat room: $e');
      rethrow;
    }
  }
}
