import 'package:screengate/services/solo_reward_policy.dart';
import 'package:screengate/supabase/supabase_config.dart';
import 'package:screengate/services/user_service.dart';

class RewardService {
  Future<bool> _isSolo(String userId) async {
    final row = await SupabaseConfig.client
        .from('users')
        .select('usage_mode')
        .eq('id', userId)
        .maybeSingle();
    return row?['usage_mode'] == 'solo';
  }

  String _dayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
  }

  Future<int> getAvailableMinutes() async {
    final userId = UserService.activeProfileId;
    if (userId == null) return 0;

    if (await _isSolo(userId)) {
      final rows = await SupabaseConfig.client
          .from('solo_reward_requests')
          .select('requested_minutes,status')
          .eq('user_id', userId)
          .eq('status', 'approved')
          .gte('created_at', _dayStart());
      final total = (rows as List).fold<int>(
        0,
        (sum, row) => sum + ((row['requested_minutes'] as num?)?.toInt() ?? 0),
      );
      return SoloRewardPolicy.clampDailyMinutes(total);
    }

    final rows = await SupabaseConfig.client
        .from('reward_requests')
        .select('requested_minutes,status')
        .eq('child_user_id', userId)
        .eq('status', 'approved');
    return (rows as List).fold<int>(
      0,
      (total, row) =>
          total + ((row['requested_minutes'] as num?)?.toInt() ?? 0),
    );
  }

  Stream<int> watchAvailableMinutes() {
    final userId = UserService.activeProfileId;
    if (userId == null) return const Stream<int>.empty();
    return Stream.periodic(const Duration(seconds: 4))
        .asyncMap((_) => getAvailableMinutes())
        .startWith(getAvailableMinutes());
  }
}

extension on Stream<int> {
  Stream<int> startWith(Future<int> first) async* {
    yield await first;
    yield* this;
  }
}
