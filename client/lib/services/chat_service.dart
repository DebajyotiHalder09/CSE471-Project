import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final bool read;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.read,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? '',
      senderId: json['senderId']?.toString() ?? '',
      text: json['text'] ?? '',
      read: json['read'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class Chat {
  final String id;
  final List<Map<String, dynamic>> participants;
  final List<ChatMessage> messages;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  Chat({
    required this.id,
    required this.participants,
    required this.messages,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    // Handle response structure: { success: true, chat: { ... } }
    final chatData = json['chat'] ?? json;
    
    return Chat(
      id: chatData['_id']?.toString() ?? '',
      participants: chatData['participants'] != null
          ? List<Map<String, dynamic>>.from(chatData['participants'])
          : [],
      messages: chatData['messages'] != null
          ? (chatData['messages'] as List)
              .map((m) => ChatMessage.fromJson(m))
              .toList()
          : [],
      lastMessageAt: chatData['lastMessageAt'] != null
          ? DateTime.parse(chatData['lastMessageAt'])
          : null,
      createdAt: chatData['createdAt'] != null
          ? DateTime.parse(chatData['createdAt'])
          : DateTime.now(),
    );
  }
}

class ChatService {
  static const String baseUrl = AuthService.baseUrl;

  // Get or create a chat with another user
  static Future<Chat> getChat(String otherUserId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/$otherUserId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return Chat.fromJson(responseData);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to get chat');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get chat');
      }
    } catch (e) {
      print('Error getting chat: $e');
      rethrow;
    }
  }

  // Send a message
  static Future<ChatMessage> sendMessage(String chatId, String text) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat/send'),
        headers: headers,
        body: jsonEncode({
          'chatId': chatId,
          'text': text,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return ChatMessage.fromJson(responseData['message']);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to send message');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages for a chat
  static Future<List<ChatMessage>> getMessages(String chatId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/messages/$chatId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return (responseData['messages'] as List)
              .map((m) => ChatMessage.fromJson(m))
              .toList();
        } else {
          throw Exception(responseData['message'] ?? 'Failed to get messages');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get messages');
      }
    } catch (e) {
      print('Error getting messages: $e');
      rethrow;
    }
  }

  // Get unread message counts for all friends
  static Future<Map<String, int>> getUnreadCounts() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/unread-counts'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final unreadCounts = responseData['unreadCounts'] as Map<String, dynamic>;
          return unreadCounts.map((key, value) => MapEntry(key, value as int));
        } else {
          throw Exception(responseData['message'] ?? 'Failed to get unread counts');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get unread counts');
      }
    } catch (e) {
      print('Error getting unread counts: $e');
      rethrow;
    }
  }
}

