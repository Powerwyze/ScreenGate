import 'package:flutter/foundation.dart';
import 'package:screengate/models/mission.dart';
import 'package:screengate/models/notification.dart';
import 'package:screengate/models/social_post.dart';
import 'package:screengate/services/friend_service.dart';
import 'package:screengate/services/notification_service.dart';
import 'package:screengate/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

enum FeedScope { public, friends }

class SocialService {
  final FriendService _friendService;
  final NotificationService _notificationService;

  SocialService({
    FriendService? friendService,
    NotificationService? notificationService,
  })  : _friendService = friendService ?? FriendService(),
        _notificationService = notificationService ?? NotificationService();

  Future<List<SocialPost>> getFeed({
    required String viewerId,
    required FeedScope scope,
    int limit = 50,
  }) async {
    try {
      dynamic query = SupabaseConfig.client
          .from('social_posts')
          .select()
          .not('mission_id', 'is', null);
      if (scope == FeedScope.public) {
        query = query.eq('visibility', PostVisibility.public.name);
      } else {
        final friendIds =
            await _friendService.getAcceptedFriendUserIds(viewerId);
        query = query
            .inFilter('user_id', {...friendIds, viewerId}.toList())
            .inFilter('visibility', const ['public', 'friends']);
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit);
      return _hydratePosts(rows, viewerId);
    } catch (error) {
      debugPrint('[SocialService] Error loading feed: $error');
      rethrow;
    }
  }

  Future<List<SocialPost>> _hydratePosts(
    List<dynamic> rows,
    String viewerId,
  ) async {
    if (rows.isEmpty) return [];
    final postIds = rows.map((row) => row['id'] as String).toList();
    final authorIds = rows.map((row) => row['user_id'] as String).toSet();

    final results = await Future.wait([
      SupabaseConfig.client
          .from('users')
          .select()
          .inFilter('id', authorIds.toList()),
      SupabaseConfig.client
          .from('post_likes')
          .select()
          .inFilter('post_id', postIds),
      SupabaseConfig.client
          .from('post_comments')
          .select('id, post_id')
          .inFilter('post_id', postIds),
    ]);

    final authors = <String, Map<String, dynamic>>{
      for (final row in results[0]) row['id'] as String: row,
    };
    final likes = results[1];
    final comments = results[2];

    return rows.map<SocialPost>((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final postId = row['id'] as String;
      final author = authors[row['user_id']] ?? const <String, dynamic>{};
      final postLikes = likes.where((like) => like['post_id'] == postId);
      return SocialPost.fromJson(
        row,
        authorName: author['codename'] as String? ?? 'ScreenGate user',
        authorAvatarUrl: author['avatar_url'] as String?,
        likeCount: postLikes.length,
        commentCount:
            comments.where((comment) => comment['post_id'] == postId).length,
        isLikedByMe: postLikes.any((like) => like['user_id'] == viewerId),
      );
    }).toList();
  }

  Future<SocialPost> shareCompletedTask({
    required Mission mission,
    required String userId,
    required PostVisibility visibility,
  }) async {
    if (mission.status != MissionStatus.completed &&
        mission.status != MissionStatus.verified) {
      throw Exception('Finish the task before sharing it.');
    }
    final result = await SupabaseConfig.client.rpc(
      'share_completed_task',
      params: {
        'p_mission_id': mission.id,
        'p_visibility': visibility.name,
      },
    );
    final rows = await _hydratePosts(
      [Map<String, dynamic>.from(result as Map)],
      userId,
    );
    return rows.single;
  }

  Future<SocialPost?> getSharedTask({
    required String missionId,
    required String viewerId,
  }) async {
    final row = await SupabaseConfig.client
        .from('social_posts')
        .select()
        .eq('mission_id', missionId)
        .maybeSingle();
    if (row == null) return null;
    final posts = await _hydratePosts([row], viewerId);
    return posts.single;
  }

  Future<bool> toggleLike({
    required SocialPost post,
    required String userId,
    required String userName,
  }) async {
    if (post.isLikedByMe) {
      await SupabaseConfig.client
          .from('post_likes')
          .delete()
          .eq('post_id', post.id)
          .eq('user_id', userId);
      return false;
    }

    await SupabaseService.insert('post_likes', {
      'id': const Uuid().v4(),
      'post_id': post.id,
      'user_id': userId,
    });
    if (post.userId != userId) {
      try {
        await _notificationService.createNotification(
          userId: post.userId,
          type: NotificationType.postLike,
          title: 'Someone liked your task',
          message: '$userName liked your finished task.',
          data: {'post_id': post.id, 'sender_id': userId},
        );
      } catch (error) {
        debugPrint('[SocialService] Like notification failed: $error');
      }
    }
    return true;
  }

  Future<List<SocialComment>> getComments(String postId) async {
    final rows = await SupabaseConfig.client
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at');
    if (rows.isEmpty) return [];
    final userIds =
        rows.map((row) => row['user_id'] as String).toSet().toList();
    final userRows = await SupabaseConfig.client
        .from('users')
        .select()
        .inFilter('id', userIds);
    final users = <String, Map<String, dynamic>>{
      for (final row in userRows) row['id'] as String: row,
    };
    return rows.map<SocialComment>((row) {
      final author = users[row['user_id']] ?? const <String, dynamic>{};
      return SocialComment.fromJson(
        row,
        authorName: author['codename'] as String? ?? 'ScreenGate user',
        authorAvatarUrl: author['avatar_url'] as String?,
      );
    }).toList();
  }

  Future<void> addComment({
    required SocialPost post,
    required String userId,
    required String userName,
    required String content,
  }) async {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) return;
    await SupabaseService.insert('post_comments', {
      'id': const Uuid().v4(),
      'post_id': post.id,
      'user_id': userId,
      'content': cleanContent,
    });
    if (post.userId != userId) {
      try {
        await _notificationService.createNotification(
          userId: post.userId,
          type: NotificationType.postComment,
          title: 'New comment',
          message: '$userName commented on your finished task.',
          data: {'post_id': post.id, 'sender_id': userId},
        );
      } catch (error) {
        debugPrint('[SocialService] Comment notification failed: $error');
      }
    }
  }

  Future<void> deletePost(String postId) =>
      SupabaseService.delete('social_posts', filters: {'id': postId});
}
