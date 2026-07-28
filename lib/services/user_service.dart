import 'package:flutter/foundation.dart';
import 'package:taskassassin/models/user.dart';
import 'package:taskassassin/supabase/supabase_config.dart';
import 'package:taskassassin/services/mission_service.dart';

class UserService {
  UserService();

  Future<User> createUser({
    required String codename,
    required String email,
    required String selectedHandlerId,
    required String lifeGoals,
    required AccountRole accountRole,
  }) async {
    try {
      final current = SupabaseConfig.auth.currentUser;
      if (current == null) {
        throw Exception(
            'No authenticated user. Please sign in before creating a profile.');
      }
      final userId = current.id;

      // Build the user payload and upsert in one go to avoid a pre-select
      final now = DateTime.now();
      final payload = User(
        id: userId,
        codename: codename,
        email: email,
        selectedHandlerId: selectedHandlerId,
        lifeGoals: lifeGoals,
        accountRole: accountRole,
        totalStars: 0,
        level: 1,
        currentStreak: 0,
        longestStreak: 0,
        createdAt: now,
        updatedAt: now,
      ).toJson();

      final res = await SupabaseService.upsert(
        'users',
        payload,
        onConflict: 'id',
        ignoreDuplicates: false,
      );

      // Supabase returns the row(s) after upsert; use the first
      if (res.isNotEmpty) {
        final saved = User.fromJson(res.first);
        debugPrint(
            '[UserService] Upserted user during onboarding: ${saved.id}');

        // Create welcome mission for new user
        await _createWelcomeMissionForUser(saved.id);

        return saved;
      }

      // If nothing returned, fetch once to confirm
      final fetched =
          await SupabaseService.selectSingle('users', filters: {'id': userId});
      if (fetched != null) {
        final saved = User.fromJson(fetched);
        debugPrint(
            '[UserService] Fetched user post-upsert during onboarding: ${saved.id}');

        // Create welcome mission for new user
        await _createWelcomeMissionForUser(saved.id);

        return saved;
      }

      throw Exception('User upsert returned no data.');
    } catch (e) {
      debugPrint('[UserService] Error creating user: $e');
      rethrow;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return null;
      return getUserById(userId);
    } catch (e) {
      debugPrint('[UserService] Error getting current user: $e');
      return null;
    }
  }

  Future<User?> getUserById(String id) async {
    try {
      final data =
          await SupabaseService.selectSingle('users', filters: {'id': id});
      if (data == null) return null;
      return User.fromJson(data);
    } catch (e) {
      debugPrint('[UserService] Error getting user by id: $e');
      return null;
    }
  }

  Stream<User?> getCurrentUserStream() {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);

    return SupabaseConfig.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isEmpty) return null;
          return User.fromJson(data.first);
        });
  }

  Future<void> updateUser(User user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      await SupabaseService.update(
        'users',
        updatedUser.toJson(),
        filters: {'id': user.id},
      );
    } catch (e) {
      debugPrint('[UserService] Error updating user: $e');
      rethrow;
    }
  }

  Future<void> addStars(String userId, int stars) async {
    try {
      final user = await getUserById(userId);
      if (user == null) return;

      final newTotalStars = user.totalStars + stars;
      final newLevel = (newTotalStars / 100).floor() + 1;

      await updateUser(user.copyWith(
        totalStars: newTotalStars,
        level: newLevel,
      ));
    } catch (e) {
      debugPrint('[UserService] Error adding stars: $e');
      rethrow;
    }
  }

  Future<void> updateStreak(String userId, int newStreak) async {
    try {
      final user = await getUserById(userId);
      if (user == null) return;

      final longestStreak =
          newStreak > user.longestStreak ? newStreak : user.longestStreak;

      await updateUser(user.copyWith(
        currentStreak: newStreak,
        longestStreak: longestStreak,
      ));
    } catch (e) {
      debugPrint('[UserService] Error updating streak: $e');
      rethrow;
    }
  }

  Future<List<User>> searchUsersByCodename(String codename) async {
    try {
      final results = await SupabaseConfig.client
          .from('users')
          .select()
          .ilike('codename', '%$codename%')
          .limit(20);

      return results.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[UserService] Error searching users: $e');
      return [];
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await SupabaseService.delete('users', filters: {'id': userId});
    } catch (e) {
      debugPrint('[UserService] Error deleting user: $e');
      rethrow;
    }
  }

  /// Creates a welcome mission for a new user
  Future<void> _createWelcomeMissionForUser(String userId) async {
    try {
      final missionService = MissionService();
      await missionService.createWelcomeMission(userId);
      debugPrint('[UserService] Welcome mission created for user: $userId');
    } catch (e) {
      // Don't fail user creation if welcome mission fails
      debugPrint('[UserService] Failed to create welcome mission: $e');
    }
  }

  Future<List<User>> getUsersByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];
      final results = await SupabaseConfig.client
          .from('users')
          .select()
          .inFilter('id', userIds);
      return results.map<User>((json) => User.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[UserService] Error getting users by ids: $e');
      return [];
    }
  }

  Future<List<User>> getAllUsers({int limit = 100}) async {
    try {
      final results = await SupabaseService.select('users', limit: limit);
      return results.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[UserService] Error getting all users: $e');
      return [];
    }
  }

  Future<List<User>> getLeaderboard({int limit = 10}) async {
    try {
      final results = await SupabaseConfig.client
          .from('users')
          .select()
          .order('total_stars', ascending: false)
          .limit(limit);
      return results.map<User>((json) => User.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[UserService] Error getting leaderboard: $e');
      return [];
    }
  }
}
