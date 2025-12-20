import 'package:flutter/material.dart';
import 'dart:async';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../utils/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final User friend;

  const ChatScreen({super.key, required this.friend});

  static const routeName = '/chat';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  String? _chatId;
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _refreshTimer;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserAndChat();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserAndChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      _currentUser = await AuthService.getUser();
      if (_currentUser == null) {
        throw Exception('User not logged in');
      }

      // Get or create chat
      final chat = await ChatService.getChat(widget.friend.id);
      setState(() {
        _chatId = chat.id;
        _messages = chat.messages;
        _isLoading = false;
      });

      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      // Load messages
      await _loadMessages();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chat: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_chatId == null) return;

    try {
      final messages = await ChatService.getMessages(_chatId!);
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  void _startRefreshTimer() {
    // Refresh messages every 3 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_chatId != null && mounted) {
        _loadMessages();
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final newMessage = await ChatService.sendMessage(_chatId!, text);
      _messageController.clear();
      
      setState(() {
        _messages.add(newMessage);
        _isSending = false;
      });

      _scrollToBottom();
      
      // Refresh messages to get latest state
      await _loadMessages();
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isCurrentUser(String? senderId) {
    if (senderId == null || _currentUser == null) return false;
    return senderId == _currentUser!.id || senderId.toString() == _currentUser!.id;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                child: Text(
                  widget.friend.firstNameInitial,
                  style: AppTheme.heading4.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friend.name,
                    style: AppTheme.heading4Dark(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.friend.email,
                    style: AppTheme.bodySmallDark(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            )
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? AppTheme.darkSurface 
                                      : AppTheme.backgroundLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 64,
                                  color: isDark 
                                      ? AppTheme.darkTextTertiary 
                                      : AppTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No messages yet',
                                style: AppTheme.heading4Dark(context).copyWith(
                                  color: isDark 
                                      ? AppTheme.darkTextSecondary 
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start a conversation!',
                                style: AppTheme.bodyMediumDark(context).copyWith(
                                  color: isDark 
                                      ? AppTheme.darkTextTertiary 
                                      : AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = _isCurrentUser(message.senderId);
                            return _buildMessageBubble(message, isMe, isDark);
                          },
                        ),
                ),
                // Message input
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? AppTheme.darkSurfaceElevated 
                                    : AppTheme.backgroundLight,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: isDark 
                                      ? AppTheme.darkBorder 
                                      : AppTheme.borderLight,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _messageController,
                                style: AppTheme.bodyLargeDark(context),
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: AppTheme.bodyMediumDark(context).copyWith(
                                    color: isDark 
                                        ? AppTheme.darkTextTertiary 
                                        : AppTheme.textTertiary,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                                maxLines: null,
                                textCapitalization: TextCapitalization.sentences,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isSending ? null : _sendMessage,
                                borderRadius: BorderRadius.circular(28),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  alignment: Alignment.center,
                                  child: _isSending
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                child: Text(
                  widget.friend.firstNameInitial,
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe 
                    ? AppTheme.primaryGradient
                    : null,
                color: isMe 
                    ? null 
                    : (isDark ? AppTheme.darkSurfaceElevated : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? AppTheme.primaryBlue.withOpacity(0.2)
                        : (isDark
                            ? Colors.black.withOpacity(0.2)
                            : Colors.black.withOpacity(0.05)),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: AppTheme.bodyLarge.copyWith(
                  fontSize: 15,
                  color: isMe 
                      ? Colors.white 
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                child: Text(
                  _currentUser?.firstNameInitial ?? 'U',
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
