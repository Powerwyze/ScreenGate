import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:screengate/models/chat_message.dart';
import 'package:screengate/supabase/supabase_config.dart';

class ChatService {
  ChatService();

  Future<ChatMessage> addMessage({
    required String userId,
    required ChatRole role,
    required String content,
  }) async {
    try {
      final message = ChatMessage(
        id: const Uuid().v4(),
        userId: userId,
        role: role,
        content: content,
        createdAt: DateTime.now(),
      );

      await SupabaseService.insert('chat_messages', message.toJson());
      return message;
    } catch (e) {
      debugPrint('[ChatService] Error adding message: $e');
      rethrow;
    }
  }

  Future<List<ChatMessage>> getMessagesByUserId(String userId) async {
    try {
      final results = await SupabaseService.select(
        'chat_messages',
        filters: {'user_id': userId},
        orderBy: 'created_at',
        ascending: true,
      );
      return results.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[ChatService] Error getting messages by user id: $e');
      return [];
    }
  }

  Stream<List<ChatMessage>> getMessagesStreamByUserId(String userId) {
    return SupabaseConfig.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: true)
        .map((data) => data.map((json) => ChatMessage.fromJson(json)).toList());
  }

  Future<void> clearUserMessages(String userId) async {
    try {
      await SupabaseConfig.client
          .from('chat_messages')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[ChatService] Error clearing user messages: $e');
      rethrow;
    }
  }
}
