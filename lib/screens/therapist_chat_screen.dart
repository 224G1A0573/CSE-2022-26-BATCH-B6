import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';

class TherapistChatScreen extends StatefulWidget {
  final VoidCallback? onUnreadCountChanged;
  
  const TherapistChatScreen({super.key, this.onUnreadCountChanged});

  @override
  State<TherapistChatScreen> createState() => _TherapistChatScreenState();
}

class _TherapistChatScreenState extends State<TherapistChatScreen> {
  final ChatService _chatService = ChatService();

  List<ChatRoom> _chatRooms = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
    _loadUnreadCount();
  }

  Future<void> _loadChatRooms() async {
    try {
      final chatRooms = await _chatService.getChatRoomsForUser();
      setState(() {
        _chatRooms = chatRooms;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chat rooms: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _chatService.getUnreadMessageCount();
      setState(() {
        _unreadCount = count;
      });
      // Notify therapist dashboard if callback is provided
      if (widget.onUnreadCountChanged != null) {
        widget.onUnreadCountChanged!();
      }
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  Future<void> _refreshChatRooms() async {
    await _loadChatRooms();
    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Parents'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (_unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatRooms.isEmpty
              ? _buildEmptyState()
              : _buildChatRoomsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No chat conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with a parent',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showNewChatDialog,
            icon: const Icon(Icons.add),
            label: const Text('Start New Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomsList() {
    return RefreshIndicator(
      onRefresh: _refreshChatRooms,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _chatRooms.length,
        itemBuilder: (context, index) {
          final chatRoom = _chatRooms[index];
          return _buildChatRoomCard(chatRoom);
        },
      ),
    );
  }

  Widget _buildChatRoomCard(ChatRoom chatRoom) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openChatRoom(chatRoom),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.blue[100],
                child: Icon(
                  Icons.person,
                  color: Colors.blue[700],
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),

              // Chat info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chatRoom.parentName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (chatRoom.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${chatRoom.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Child: ${chatRoom.childName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (chatRoom.lastMessage != null)
                      Text(
                        chatRoom.lastMessage!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(chatRoom.lastMessageAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChatRoom(ChatRoom chatRoom) async {
    // Open chat room and wait for it to close
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatRoom: chatRoom,
          onMessagesRead: () {
            _loadUnreadCount();
          },
        ),
      ),
    );
    // Refresh unread count when returning from chat room
    _loadUnreadCount();
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => NewChatDialog(
        onChatCreated: () {
          _refreshChatRooms();
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class NewChatDialog extends StatefulWidget {
  final VoidCallback onChatCreated;

  const NewChatDialog({
    super.key,
    required this.onChatCreated,
  });

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get children assigned to current therapist
      final childrenQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'kid')
          .where('therapistId', isEqualTo: user.uid)
          .get();

      final children = <Map<String, dynamic>>[];

      for (var doc in childrenQuery.docs) {
        final data = doc.data();
        final childId = doc.id;

        // Get parent info
        final parentEmail = data['guardianEmail'] ?? data['parentEmail'];
        if (parentEmail != null) {
          final parentQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: parentEmail)
              .where('role', isEqualTo: 'parent')
              .limit(1)
              .get();

          if (parentQuery.docs.isNotEmpty) {
            final parentData = parentQuery.docs.first.data();
            children.add({
              'childId': childId,
              'childName': data['name'] ?? data['displayName'] ?? 'Child',
              'parentId': parentQuery.docs.first.id,
              'parentName':
                  parentData['name'] ?? parentData['displayName'] ?? 'Parent',
              'parentEmail': parentEmail,
            });
          }
        }
      }

      setState(() {
        _children = children;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading children: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start New Chat'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _children.isEmpty
                ? const Center(
                    child: Text('No children assigned to you yet'),
                  )
                : ListView.builder(
                    itemCount: _children.length,
                    itemBuilder: (context, index) {
                      final child = _children[index];
                      final isSelected = _selectedChildId == child['childId'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isSelected ? Colors.blue[700] : Colors.grey[300],
                          child: Icon(
                            Icons.child_care,
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                        ),
                        title: Text(child['childName']),
                        subtitle: Text('Parent: ${child['parentName']}'),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedChildId = child['childId'];
                          });
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
        ElevatedButton(
          onPressed: _selectedChildId != null ? _createChat : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
          child: const Text('Start Chat'),
        ),
      ],
    );
  }

  Future<void> _createChat() async {
    try {
      final selectedChild = _children.firstWhere(
        (child) => child['childId'] == _selectedChildId,
      );

      final chatId = await _chatService.createOrGetChatRoom(
        therapistId: _auth.currentUser!.uid,
        parentId: selectedChild['parentId'],
        childId: selectedChild['childId'],
      );

      Navigator.pop(context);
      widget.onChatCreated();

      // Open the chat room
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            chatRoom: ChatRoom(
              id: chatId,
              therapistId: _auth.currentUser!.uid,
              therapistName: 'You',
              parentId: selectedChild['parentId'],
              parentName: selectedChild['parentName'],
              childId: selectedChild['childId'],
              childName: selectedChild['childName'],
              createdAt: DateTime.now(),
              lastMessageAt: DateTime.now(),
            ),
            onMessagesRead: () {},
          ),
        ),
      );
    } catch (e) {
      print('Error creating chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class ChatRoomScreen extends StatefulWidget {
  final ChatRoom chatRoom;
  final VoidCallback onMessagesRead;

  const ChatRoomScreen({
    super.key,
    required this.chatRoom,
    required this.onMessagesRead,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _chatService.markMessagesAsRead(widget.chatRoom.id);
      widget.onMessagesRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await _chatService.sendMessage(
        chatId: widget.chatRoom.id,
        message: message,
        childId: widget.chatRoom.childId,
        childName: widget.chatRoom.childName,
      );

      _messageController.clear();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatRoom.parentName),
            Text(
              'Child: ${widget.chatRoom.childName}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(widget.chatRoom.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blue[700],
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderRole == 'therapist';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[700] : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
