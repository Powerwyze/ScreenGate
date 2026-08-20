import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:screengate/models/friend.dart';
import 'package:screengate/models/notification.dart';
import 'package:screengate/services/notification_service.dart';
import 'package:screengate/supabase/supabase_config.dart';

class FriendService {
  late final NotificationService _notificationService;

  FriendService() {
    _notificationService = NotificationService();
  }

  Future<Friend> sendFriendRequest(String userId, String friendUserId) async {
    try {
      final friend = Friend(
        id: const Uuid().v4(),
        userId: userId,
        friendUserId: friendUserId,
        status: FriendStatus.pending,
        createdAt: DateTime.now(),
      );

      await SupabaseService.insert('friends', friend.toJson());

      final senderData =
          await SupabaseService.selectSingle('users', filters: {'id': userId});
      final senderName = senderData?['codename'] ?? 'Someone';

      await _notificationService.createNotification(
        userId: friendUserId,
        type: NotificationType.friendRequest,
        title: 'New Friend Request',
        message: '$senderName wants to be your friend!',
        data: {'friend_id': friend.id, 'sender_id': userId},
      );

      return friend;
    } catch (e) {
      debugPrint('[FriendService] Error sending friend request: $e');
      rethrow;
    }
  }

  Future<void> acceptFriendRequest(String friendId) async {
    try {
      final friendData = await SupabaseService.selectSingle('friends',
          filters: {'id': friendId});
      if (friendData == null) return;

      final friend = Friend.fromJson(friendData);

      await SupabaseService.update(
        'friends',
        {'status': FriendStatus.accepted.name},
        filters: {'id': friendId},
      );

      final accepterData = await SupabaseService.selectSingle('users',
          filters: {'id': friend.friendUserId});
      final accepterName = accepterData?['codename'] ?? 'Someone';

      await _notificationService.createNotification(
        userId: friend.userId,
        type: NotificationType.friendAccepted,
        title: 'Friend Request Accepted',
        message: '$accepterName accepted your friend request!',
        data: {'friend_id': friendId, 'accepter_id': friend.friendUserId},
      );
    } catch (e) {
      debugPrint('[FriendService] Error accepting friend request: $e');
      rethrow;
    }
  }

  Future<void> declineFriendRequest(String friendId) async {
    await deleteFriend(friendId);
  }

  Future<void> deleteFriend(String friendId) async {
    try {
      await SupabaseService.delete('friends', filters: {'id': friendId});
    } catch (e) {
      debugPrint('[FriendService] Error deleting friend: $e');
      rethrow;
    }
  }

  Future<Friend?> getFriendById(String friendId) async {
    try {
      final data = await SupabaseService.selectSingle('friends',
          filters: {'id': friendId});
      if (data == null) return null;
      return Friend.fromJson(data);
    } catch (e) {
      debugPrint('[FriendService] Error getting friend by id: $e');
      return null;
    }
  }

  Future<List<Friend>> getFriendsByUserId(String userId) async {
    try {
      final results = await SupabaseConfig.client
          .from('friends')
          .select()
          .or('user_id.eq.$userId,friend_user_id.eq.$userId')
          .eq('status', FriendStatus.accepted.name);

      return results.map<Friend>((json) => Friend.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[FriendService] Error getting friends: $e');
      return [];
    }
  }

  Future<List<Friend>> getPendingRequests(String userId) async {
    try {
      final results = await SupabaseService.select(
        'friends',
        filters: {
          'friend_user_id': userId,
          'status': FriendStatus.pending.name
        },
      );
      return results.map((json) => Friend.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[FriendService] Error getting pending requests: $e');
      return [];
    }
  }

  Future<List<Friend>> getPendingRequestsSentBy(String userId) async {
    try {
      final results = await SupabaseService.select(
        'friends',
        filters: {'user_id': userId, 'status': FriendStatus.pending.name},
      );
      return results.map((json) => Friend.fromJson(json)).toList();
    } catch (e) {
      debugPrint(
          '[FriendService] Error getting pending requests sent by user: $e');
      return [];
    }
  }

  Future<List<String>> getAcceptedFriendUserIds(String userId) async {
    try {
      final friends = await getFriendsByUserId(userId);
      return friends
          .map((f) => f.userId == userId ? f.friendUserId : f.userId)
          .toList();
    } catch (e) {
      debugPrint('[FriendService] Error getting accepted friend user ids: $e');
      return [];
    }
  }
}
