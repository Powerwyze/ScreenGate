import 'package:taskassassin/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyChild {
  final String id;
  final String name;
  final List<QuestimeDevice> devices;

  const FamilyChild(
      {required this.id, required this.name, required this.devices});
}

class QuestimeDevice {
  final String id;
  final String platform;
  final String name;
  final bool screenTimeAuthorized;
  final int remainingSeconds;
  final DateTime? lastSeenAt;

  const QuestimeDevice({
    required this.id,
    required this.platform,
    required this.name,
    required this.screenTimeAuthorized,
    required this.remainingSeconds,
    this.lastSeenAt,
  });

  factory QuestimeDevice.fromJson(Map<String, dynamic> json) => QuestimeDevice(
        id: json['id'] as String? ?? '',
        platform: json['platform'] as String? ?? 'unknown',
        name: json['device_name'] as String? ?? 'Child phone',
        screenTimeAuthorized: json['screen_time_authorized'] as bool? ?? false,
        remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 0,
        lastSeenAt: json['last_seen_at'] == null
            ? null
            : DateTime.tryParse(json['last_seen_at'] as String),
      );
}

class FamilyPairingCode {
  final String code;
  final DateTime expiresAt;

  const FamilyPairingCode({required this.code, required this.expiresAt});

  factory FamilyPairingCode.fromJson(Map<String, dynamic> json) {
    return FamilyPairingCode(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

class ChildRecoveryCode {
  final String code;
  final String childUserId;

  const ChildRecoveryCode({required this.code, required this.childUserId});
}

class FamilyService {
  Future<void> saveScreenTimeRule({
    required String childUserId,
    required int dailyLimitMinutes,
    required int rewardMinutes,
  }) async {
    final membership = await SupabaseConfig.client
        .from('family_members')
        .select('family_id')
        .eq('user_id', SupabaseConfig.auth.currentUser!.id)
        .eq('role', 'parent')
        .eq('status', 'active')
        .limit(1)
        .single();
    await SupabaseConfig.client.from('screen_time_rules').upsert({
      'family_id': membership['family_id'],
      'child_user_id': childUserId,
      'created_by': SupabaseConfig.auth.currentUser!.id,
      'daily_limit_minutes': dailyLimitMinutes,
      'reward_minutes': rewardMinutes,
      'enabled': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'family_id,child_user_id');
  }

  Future<List<FamilyChild>> getChildren() async {
    final memberships = await SupabaseConfig.client
        .from('family_members')
        .select('user_id, users!family_members_user_id_fkey(codename)')
        .eq('role', 'child')
        .eq('status', 'active');

    final children = <FamilyChild>[];
    for (final row in memberships as List) {
      final data = Map<String, dynamic>.from(row);
      final userId = data['user_id'] as String;
      final deviceRows = await SupabaseConfig.client
          .from('questime_devices')
          .select()
          .eq('user_id', userId)
          .order('last_seen_at', ascending: false);
      final user = Map<String, dynamic>.from(data['users'] as Map);
      children.add(FamilyChild(
        id: userId,
        name: user['codename'] as String? ?? 'Child',
        devices: (deviceRows as List)
            .map((item) =>
                QuestimeDevice.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      ));
    }
    return children;
  }

  Future<FamilyPairingCode> createPairingCode() async {
    final result = await SupabaseConfig.client.rpc(
      'create_family_pairing_code',
    );
    return FamilyPairingCode.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<void> joinAsChild({
    required String code,
    required String childName,
  }) async {
    var createdAnonymousSession = false;
    if (SupabaseConfig.auth.currentUser == null) {
      final response = await SupabaseConfig.auth.signInAnonymously();
      if (response.user == null) {
        throw Exception('Could not start the child device.');
      }
      createdAnonymousSession = true;
    }

    try {
      await SupabaseConfig.client.rpc(
        'join_family_with_code',
        params: {
          'pairing_code': code.trim().toUpperCase(),
          'child_name': childName.trim(),
        },
      );
    } catch (_) {
      if (createdAnonymousSession) await SupabaseConfig.auth.signOut();
      rethrow;
    }
  }

  Future<ChildRecoveryCode> createChildRecoveryCode(
    String childUserId, {
    bool rotate = false,
  }) async {
    final result = await SupabaseConfig.client.rpc(
      rotate ? 'rotate_child_recovery_code' : 'preview_child_recovery_code',
      params: {'p_child_user_id': childUserId},
    );
    final data = Map<String, dynamic>.from(result as Map);
    return ChildRecoveryCode(
      code: data['code'] as String,
      childUserId: data['child_user_id'] as String,
    );
  }

  Future<void> recoverChild(String code) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'recover-child',
      body: {'code': code.trim().toUpperCase()},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) throw Exception(data['error']);
    await SupabaseConfig.auth.verifyOTP(
      tokenHash: data['tokenHash'] as String,
      type: OtpType.magiclink,
    );
  }
}
