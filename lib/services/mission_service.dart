import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:taskassassin/models/mission.dart';
import 'package:taskassassin/models/notification.dart';
import 'package:taskassassin/services/notification_service.dart';
import 'package:taskassassin/supabase/supabase_config.dart';

class MissionService {
  late final NotificationService _notificationService;

  MissionService() {
    _notificationService = NotificationService();
  }

  Future<Mission> createMission({
    required String userId,
    required String title,
    required String description,
    required String completedState,
    required MissionType type,
    DateTime? deadline,
    String? recurrencePattern,
    String? assignedByUserId,
    String? assignedToUserId,
    int rewardMinutes = 15,
  }) async {
    try {
      final missionId = const Uuid().v4();

      final mission = Mission(
        id: missionId,
        userId: userId,
        title: title,
        description: description,
        completedState: completedState,
        type: type,
        status: MissionStatus.pending,
        deadline: deadline,
        recurrencePattern: recurrencePattern,
        assignedByUserId: assignedByUserId,
        assignedToUserId: assignedToUserId,
        rewardMinutes: rewardMinutes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await SupabaseService.insert('missions', mission.toJson());

      // Send notification if mission is assigned to someone
      if (assignedToUserId != null && assignedByUserId != null) {
        try {
          final assignerData = await SupabaseService.selectSingle(
            'users',
            filters: {'id': assignedByUserId},
          );
          final assignerName = assignerData?['codename'] ?? 'Your parent';
          await _notificationService.createNotification(
            userId: assignedToUserId,
            type: NotificationType.missionAssigned,
            title: 'New Quest',
            message: '$assignerName sent you a quest: $title',
            data: {'mission_id': mission.id},
          );
        } catch (error) {
          debugPrint('[MissionService] Notification skipped: $error');
        }
      }

      return mission;
    } catch (e) {
      debugPrint('[MissionService] Error creating mission: $e');
      rethrow;
    }
  }

  Future<List<Mission>> getMissionsByUserId(String userId) async {
    try {
      final results = await SupabaseService.select(
        'missions',
        filters: {'user_id': userId},
        orderBy: 'created_at',
        ascending: false,
      );

      return results.map((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[MissionService] Error getting missions by user id: $e');
      return [];
    }
  }

  Future<List<Mission>> getVisibleMissions() async {
    final results = await SupabaseConfig.client
        .from('missions')
        .select()
        .order('created_at', ascending: false);
    return (results as List)
        .map((json) => Mission.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<Mission> approveFamilyQuest(String missionId) async {
    final result = await SupabaseConfig.client.rpc(
      'approve_family_quest',
      params: {'p_mission_id': missionId},
    );
    return Mission.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Stream<List<Mission>> getMissionsStreamByUserId(String userId) {
    return SupabaseConfig.client
        .from('missions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Mission.fromJson(json)).toList());
  }

  Stream<List<Mission>> getVisibleMissionsStream() {
    return SupabaseConfig.client
        .from('missions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Mission.fromJson(json)).toList());
  }

  Future<List<Mission>> getMissionsByStatus(
      String userId, MissionStatus status) async {
    try {
      dynamic query = SupabaseConfig.client
          .from('missions')
          .select()
          .eq('user_id', userId)
          .eq('status', status.name)
          .order('created_at', ascending: false);

      final results = await query;
      return results.map<Mission>((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[MissionService] Error getting missions by status: $e');
      return [];
    }
  }

  Future<List<Mission>> getMissionsByType(
      String userId, MissionType type) async {
    try {
      dynamic query = SupabaseConfig.client
          .from('missions')
          .select()
          .eq('user_id', userId)
          .eq('type', type.name)
          .order('created_at', ascending: false);

      final results = await query;
      return results.map<Mission>((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[MissionService] Error getting missions by type: $e');
      return [];
    }
  }

  Future<Mission?> getMissionById(String id) async {
    try {
      final data =
          await SupabaseService.selectSingle('missions', filters: {'id': id});
      if (data == null) return null;
      return Mission.fromJson(data);
    } catch (e) {
      debugPrint('[MissionService] Error getting mission by id: $e');
      return null;
    }
  }

  Future<void> updateMission(Mission mission) async {
    try {
      final updatedMission = mission.copyWith(updatedAt: DateTime.now());
      await SupabaseService.update(
        'missions',
        updatedMission.toJson(),
        filters: {'id': mission.id},
      );
    } catch (e) {
      debugPrint('[MissionService] Error updating mission: $e');
      rethrow;
    }
  }

  Future<void> updateMissionStatus(
      String missionId, MissionStatus status) async {
    try {
      final mission = await getMissionById(missionId);
      if (mission == null) return;

      final updatedMission = mission.copyWith(
        status: status,
        completedAt: status == MissionStatus.completed ||
                status == MissionStatus.verified
            ? DateTime.now()
            : mission.completedAt,
      );

      await updateMission(updatedMission);
    } catch (e) {
      debugPrint('[MissionService] Error updating mission status: $e');
      rethrow;
    }
  }

  Future<void> deleteMission(String missionId) async {
    try {
      await SupabaseService.delete('missions', filters: {'id': missionId});
    } catch (e) {
      debugPrint('[MissionService] Error deleting mission: $e');
      rethrow;
    }
  }

  Future<List<Mission>> getOverdueMissions(String userId) async {
    try {
      final now = DateTime.now().toIso8601String();
      dynamic query = SupabaseConfig.client
          .from('missions')
          .select()
          .eq('user_id', userId)
          .lt('deadline', now)
          .neq('status', MissionStatus.completed.name)
          .neq('status', MissionStatus.verified.name)
          .order('deadline', ascending: true);

      final results = await query;
      return results.map<Mission>((json) => Mission.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[MissionService] Error getting overdue missions: $e');
      return [];
    }
  }

  Future<int> getCompletedMissionsCount(String userId) async {
    try {
      final results = await SupabaseConfig.client
          .from('missions')
          .select()
          .eq('user_id', userId)
          .or('status.eq.${MissionStatus.completed.name},status.eq.${MissionStatus.verified.name}');

      return results.length;
    } catch (e) {
      debugPrint('[MissionService] Error getting completed missions count: $e');
      return 0;
    }
  }

  Future<void> updateMissionPhotos({
    required String missionId,
    String? beforePhotoUrl,
    String? afterPhotoUrl,
  }) async {
    final changes = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (beforePhotoUrl != null) 'before_photo_url': beforePhotoUrl,
      if (afterPhotoUrl != null) 'after_photo_url': afterPhotoUrl,
    };
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await SupabaseConfig.client
            .from('missions')
            .update(changes)
            .eq('id', missionId);
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt));
        }
      }
    }
    debugPrint('[MissionService] Error updating mission photos: $lastError');
    throw lastError ?? StateError('Could not save the mission photo.');
  }

  Future<void> updateMissionVerification({
    required String missionId,
    required String aiFeedback,
    required int starsEarned,
    required MissionStatus status,
  }) async {
    try {
      final mission = await getMissionById(missionId);
      if (mission == null) return;

      final updatedMission = mission.copyWith(
        aiFeedback: aiFeedback,
        starsEarned: starsEarned,
        status: status,
        completedAt: status == MissionStatus.verified
            ? DateTime.now()
            : mission.completedAt,
      );

      await updateMission(updatedMission);
    } catch (e) {
      debugPrint('[MissionService] Error updating mission verification: $e');
      rethrow;
    }
  }

  /// Admin user email for welcome missions
  static const String adminEmail = 'spc.bstewart@gmail.com';

  /// Creates the welcome mission for a new user.
  /// This mission is assigned by the admin account (spc.bstewart@gmail.com).
  Future<Mission?> createWelcomeMission(String newUserId) async {
    try {
      // Look up the admin user by email
      final adminData = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('email', adminEmail)
          .maybeSingle();

      final String? adminUserId = adminData?['id'];

      final welcomeMission = await createMission(
        userId: newUserId,
        title: 'Welcome Mission: Tie Your Shoes! 👟',
        description: '''Welcome to the app, Agent! 🎉

Here's how this works: You'll receive missions from friends, your coach, or create your own. Social missions are how we keep each other accountable – friends can assign you tasks and you can challenge them right back!

This is your FIRST example mission. Your objective: Tie your shoes and prove you can complete a mission.

But wait... to take the "before" photo, you'll need to untie ONE of your shoes first. I know, I know – the sacrifices we make for accountability! 😂

Go ahead, loosen those laces, snap a "before" photo of your untied shoe, then work your magic and tie it back up for the "after" shot.

Let's see what you've got, Agent!''',
        completedState:
            '''Your "after" photo should show a BEAUTIFULLY tied shoe – we're talking a proper knot, not that bunny-ears-gone-wrong situation.

Your coach will analyze both photos to verify:
✅ The "before" shows an untied shoe (yes, we can tell if you faked it!)
✅ The "after" shows the same shoe, now properly tied
✅ Bonus points for style – double knots, fancy loops, or just pure functional excellence

Once verified, you'll earn your first stars and be ready for real missions!''',
        type: MissionType.friendAssigned,
        assignedByUserId: adminUserId,
        assignedToUserId: newUserId,
      );

      debugPrint(
          '[MissionService] Created welcome mission for user: $newUserId');
      return welcomeMission;
    } catch (e) {
      debugPrint('[MissionService] Error creating welcome mission: $e');
      return null;
    }
  }

  /// Reset a failed mission so the user can redo it.
  /// This moves the mission back to inProgress, clears stars/feedback,
  /// clears the AFTER photo (user must upload a new result), and clears completedAt.
  Future<void> redoMission(String missionId) async {
    try {
      final mission = await getMissionById(missionId);
      if (mission == null) return;

      final updated = mission.copyWith(
        status: MissionStatus.inProgress,
        starsEarned: 0,
        aiFeedback: null,
        // Keep BEFORE photo for continuity, require new AFTER proof
        afterPhotoUrl: null,
        completedAt: null,
      );

      await updateMission(updated);
    } catch (e) {
      debugPrint('[MissionService] Error redoing mission: $e');
      rethrow;
    }
  }
}
