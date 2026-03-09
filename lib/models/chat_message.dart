import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'therapist' or 'parent'
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? childId;
  final String? childName;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.childId,
    this.childName,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      childId: data['childId'],
      childName: data['childName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'childId': childId,
      'childName': childName,
    };
  }
}

class ChatRoom {
  final String id;
  final String therapistId;
  final String therapistName;
  final String parentId;
  final String parentName;
  final String childId;
  final String childName;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int unreadCount;
  final String? lastMessage;
  final String? lastMessageSender;

  ChatRoom({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.parentId,
    required this.parentName,
    required this.childId,
    required this.childName,
    required this.createdAt,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageSender,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      therapistId: data['therapistId'] ?? '',
      therapistName: data['therapistName'] ?? '',
      parentId: data['parentId'] ?? '',
      parentName: data['parentName'] ?? '',
      childId: data['childId'] ?? '',
      childName: data['childName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp).toDate(),
      unreadCount: (data['unreadCount'] ?? 0).toInt(),
      lastMessage: data['lastMessage'],
      lastMessageSender: data['lastMessageSender'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'therapistId': therapistId,
      'therapistName': therapistName,
      'parentId': parentId,
      'parentName': parentName,
      'childId': childId,
      'childName': childName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'unreadCount': unreadCount,
      'lastMessage': lastMessage,
      'lastMessageSender': lastMessageSender,
    };
  }
}
