import 'package:taskassassin/supabase/supabase_config.dart';

class RewardService {
  Future<int> getAvailableMinutes() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return 0;
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
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return const Stream<int>.empty();
    return SupabaseConfig.client
        .from('reward_requests')
        .stream(primaryKey: ['id'])
        .eq('child_user_id', userId)
        .map((rows) => rows
            .where((row) => row['status'] == 'approved')
            .fold<int>(
                0,
                (total, row) =>
                    total +
                    ((row['requested_minutes'] as num?)?.toInt() ?? 0)));
  }
}
