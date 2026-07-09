import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skipit/core/config/app_config.dart';
import 'package:skipit/core/services/supabase_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref);
});

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final String? bookingId;
  final bool isRead;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;
  final String? receiverName;
  final String? receiverAvatar;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.bookingId,
    required this.isRead,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
    this.receiverName,
    this.receiverAvatar,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['content'] as String,
      bookingId: json['booking_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: json['sender']?['full_name'] as String?,
      senderAvatar: json['sender']?['avatar_url'] as String?,
      receiverName: json['receiver']?['full_name'] as String?,
      receiverAvatar: json['receiver']?['avatar_url'] as String?,
    );
  }
}

class ChatConversation {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String lastMessage;
  final DateTime createdAt;
  final int unreadCount;

  ChatConversation({
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.lastMessage,
    required this.createdAt,
    required this.unreadCount,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final other = json['otherUser'];
    return ChatConversation(
      otherUserId: other['id'] as String,
      otherUserName: other['full_name'] as String? ?? 'User',
      otherUserAvatar: other['avatar_url'] as String?,
      lastMessage: json['lastMessage'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}

class ChatRepository {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'bypass-tunnel-reminder': 'true'},
  ));

  ChatRepository(this._ref);

  Future<List<ChatConversation>> getConversations() async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.get(
        '/messages/conversations',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final List list = response.data;
      return list.map((item) => ChatConversation.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to fetch conversations: $e');
    }
  }

  Future<List<ChatMessage>> getChatHistory(String chatUserId) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.get(
        '/messages/history/$chatUserId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final List list = response.data;
      return list.map((item) => ChatMessage.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to fetch chat history: $e');
    }
  }

  Future<ChatMessage> sendMessage({
    required String receiverId,
    required String content,
    String? bookingId,
  }) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;

      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.post(
        '/messages',
        data: {
          'receiverId': receiverId,
          'content': content,
          if (bookingId != null) 'bookingId': bookingId,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return ChatMessage.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }
}
