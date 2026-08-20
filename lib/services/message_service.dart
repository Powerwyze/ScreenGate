import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:screengate/models/message.dart';
import 'package:screengate/supabase/supabase_config.dart';

class MessageService {
  MessageService();

  Future<Message> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    try {
      final friends = await _areFriends(senderId, receiverId);
      if (!friends) {
        throw Exception('You can only message accepted friends.');
      }

      final message = Message(
        id: const Uuid().v4(),
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await SupabaseService.insert('messages', message.toJson());
      return message;
    } catch (e) {
      debugPrint('[MessageService] Error sending message: $e');
      rethrow;
    }
  }

  Future<List<Message>> getConversation(String userId1, String userId2) async {
    try {
      final results = await SupabaseConfig.client
          .from('messages')
          .select()
          .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
          .order('created_at', ascending: true);

      return results.map<Message>((json) => Message.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[MessageService] Error getting conversation: $e');
      return [];
    }
  }

  Future<List<Message>> getUnreadMessages(String userId) async {
    try {
      dynamic query = SupabaseConfig.client
          .from('messages')
          .select()
          .eq('receiver_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      final results = await query;
      return results.map<Message>((json) => Message.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[MessageService] Error getting unread messages: $e');
      return [];
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await SupabaseService.update(
        'messages',
        {'is_read': true},
        filters: {'id': messageId},
      );
    } catch (e) {
      debugPrint('[MessageService] Error marking message as read: $e');
      rethrow;
    }
  }

  Future<bool> _areFriends(String userId1, String userId2) async {
    try {
      final results = await SupabaseConfig.client
          .from('friends')
          .select()
          .or('and(user_id.eq.$userId1,friend_user_id.eq.$userId2),and(user_id.eq.$userId2,friend_user_id.eq.$userId1)')
          .eq('status', 'accepted');

      return results.isNotEmpty;
    } catch (e) {
      debugPrint('[MessageService] Error checking friendship: $e');
      return false;
    }
  }

  Stream<List<Message>> getConversationStream(String userId1, String userId2) {
    final controller = StreamController<List<Message>>();
    final messagesById = <String, Message>{};

    void emit(List<Message> msgs) {
      for (final m in msgs) {
        messagesById[m.id] = m;
      }
      final sorted = messagesById.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!controller.isClosed) {
        controller.add(sorted);
      }
    }

    // Load the latest snapshot right away so the UI has an initial list
    getConversation(userId1, userId2).then(emit).catchError((e) {
      debugPrint('[MessageService] Initial conversation fetch failed: $e');
    });

    // Live updates for this pair; we filter client-side to keep the two-way thread only
    final realtimeSub = SupabaseConfig.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen((data) {
          final updates = data
              .where((msg) {
                final senderId = msg['sender_id'] as String;
                final receiverId = msg['receiver_id'] as String;
                return (senderId == userId1 && receiverId == userId2) ||
                    (senderId == userId2 && receiverId == userId1);
              })
              .map((json) => Message.fromJson(json))
              .toList();
          if (updates.isNotEmpty) {
            emit(updates);
          }
        }, onError: (e) {
          debugPrint('[MessageService] Realtime conversation stream error: $e');
        });

    // Fallback polling to handle any missed realtime events (e.g., dropped websocket)
    final pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final latest = await getConversation(userId1, userId2);
        emit(latest);
      } catch (e) {
        debugPrint('[MessageService] Poll refresh failed: $e');
      }
    });

    controller.onCancel = () {
      realtimeSub.cancel();
      pollTimer.cancel();
      controller.close();
    };

    return controller.stream;
  }
}
