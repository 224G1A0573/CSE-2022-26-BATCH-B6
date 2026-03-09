import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';

class ParentChatScreen extends StatefulWidget {
  final VoidCallback? onUnreadCountChanged;
  
  const ParentChatScreen({super.key, this.onUnreadCountChanged});

  @override
  State<ParentChatScreen> createState() => _ParentChatScreenState();
}

class _ParentChatScreenState extends State<ParentChatScreen> {
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
      print('🔍 DEBUG: Parent loading chat rooms...');
      final chatRooms = await _chatService.getChatRoomsForUser();
      print('🔍 DEBUG: Parent found ${chatRooms.length} chat rooms');
      setState(() {
        _chatRooms = chatRooms;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ DEBUG: Error loading chat rooms for parent: $e');
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
      // Notify parent dashboard if callback is provided
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
        title: const Text('Chat with Therapist'),
        backgroundColor: Colors.green[700],
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
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
            'Your therapist will start a conversation with you',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshChatRooms,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                backgroundColor: Colors.green[100],
                child: Icon(
                  Icons.psychology,
                  color: Colors.green[700],
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
                            chatRoom.therapistName,
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    if (chatRoom.lastMessage != null)
                      Text(
                        chatRoom.lastMessage!,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(chatRoom.lastMessageAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
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
        builder: (context) => ParentChatRoomScreen(
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

class ParentChatRoomScreen extends StatefulWidget {
  final ChatRoom chatRoom;
  final VoidCallback onMessagesRead;

  const ParentChatRoomScreen({
    super.key,
    required this.chatRoom,
    required this.onMessagesRead,
  });

  @override
  State<ParentChatRoomScreen> createState() => _ParentChatRoomScreenState();
}

class _ParentChatRoomScreenState extends State<ParentChatRoomScreen> {
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
            Text(widget.chatRoom.therapistName),
            Text(
              'Child: ${widget.chatRoom.childName}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
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
                  return Center(child: Text('Error: ${snapshot.error}'));
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
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
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
                  backgroundColor: Colors.green[700],
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
    final isMe = message.senderRole == 'parent';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[700] : Colors.grey[300],
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
