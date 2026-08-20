import 'package:flutter/foundation.dart';
import 'package:screengate/models/achievement.dart';
import 'package:screengate/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

class AchievementService {
  AchievementService();

  /// Get all achievements from Supabase.
  /// Returns empty list if none exist (achievements should be seeded in Supabase).
  Future<List<Achievement>> getAllAchievements() async {
    try {
      final results = await SupabaseService.select('achievements');
      return results.map((json) => Achievement.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[AchievementService] Error getting all achievements: $e');
      return [];
    }
  }

  Future<List<UserAchievement>> getUserAchievements(String userId) async {
    try {
      final results = await SupabaseService.select(
        'user_achievements',
        filters: {'user_id': userId},
        orderBy: 'unlocked_at',
        ascending: false,
      );
      return results.map((json) => UserAchievement.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[AchievementService] Error getting user achievements: $e');
      return [];
    }
  }

  Future<void> unlockAchievement(String userId, String achievementId) async {
    try {
      final existing = await SupabaseService.selectSingle(
        'user_achievements',
        filters: {'user_id': userId, 'achievement_id': achievementId},
      );

      if (existing != null) {
        debugPrint('[AchievementService] Achievement already unlocked');
        return;
      }

      final userAchievement = UserAchievement(
        id: const Uuid().v4(),
        userId: userId,
        achievementId: achievementId,
        unlockedAt: DateTime.now(),
      );

      await SupabaseService.insert(
          'user_achievements', userAchievement.toJson());
      debugPrint('[AchievementService] Achievement unlocked: $achievementId');
    } catch (e) {
      debugPrint('[AchievementService] Error unlocking achievement: $e');
      rethrow;
    }
  }

  Future<bool> hasAchievement(String userId, String achievementId) async {
    try {
      final result = await SupabaseService.selectSingle(
        'user_achievements',
        filters: {'user_id': userId, 'achievement_id': achievementId},
      );
      return result != null;
    } catch (e) {
      debugPrint('[AchievementService] Error checking achievement: $e');
      return false;
    }
  }
}
