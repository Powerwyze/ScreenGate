import 'package:flutter/foundation.dart';
import 'package:screengate/models/notification.dart';
import 'package:screengate/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';
import 'package:screengate/services/user_service.dart';

class NotificationService {
  final _uuid = const Uuid();

  NotificationService();

  Stream<List<AppNotification>> getNotificationsStream() {
    final userId = UserService.activeProfileId;
    if (userId == null) return Stream.value([]);

    return SupabaseConfig.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((data) =>
            data.map((json) => AppNotification.fromJson(json)).toList());
  }

  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    try {
      final userId = UserService.activeProfileId;
      if (userId == null) return [];

      final results = await SupabaseService.select(
        'notifications',
        filters: {'user_id': userId},
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
      );

      return results.map((json) => AppNotification.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[NotificationService] Error getting notifications: $e');
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final userId = UserService.activeProfileId;
      if (userId == null) return 0;

      dynamic query = SupabaseConfig.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false);

      final results = await query;
      return results.length;
    } catch (e) {
      debugPrint('[NotificationService] Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = AppNotification(
        id: _uuid.v4(),
        userId: userId,
        type: type,
        title: title,
        message: message,
        data: data,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await SupabaseService.insert('notifications', notification.toJson());
    } catch (e) {
      debugPrint('[NotificationService] Error creating notification: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService.update(
        'notifications',
        {'is_read': true},
        filters: {'id': notificationId},
      );
    } catch (e) {
      debugPrint(
          '[NotificationService] Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = UserService.activeProfileId;
      if (userId == null) return;

      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[NotificationService] Error marking all as read: $e');
      rethrow;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await SupabaseService.delete('notifications',
          filters: {'id': notificationId});
    } catch (e) {
      debugPrint('[NotificationService] Error deleting notification: $e');
      rethrow;
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final userId = UserService.activeProfileId;
      if (userId == null) return;

      await SupabaseConfig.client
          .from('notifications')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[NotificationService] Error deleting all notifications: $e');
      rethrow;
    }
  }
}
