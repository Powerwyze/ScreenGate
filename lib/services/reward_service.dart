import 'package:taskassassin/supabase/supabase_config.dart';

class RewardService {
  Future<int> getAvailableMinutes() async {
    final rows = await SupabaseConfig.client
        .from('reward_requests')
        .select('requested_minutes,status')
        .eq('status', 'approved');
    return (rows as List).fold<int>(
      0,
      (total, row) =>
          total + ((row['requested_minutes'] as num?)?.toInt() ?? 0),
    );
  }

  Stream<int> watchAvailableMinutes() {
    return SupabaseConfig.client.from('reward_requests').stream(primaryKey: [
      'id'
    ]).map((rows) => rows.where((row) => row['status'] == 'approved').fold<int>(
        0,
        (total, row) =>
            total + ((row['requested_minutes'] as num?)?.toInt() ?? 0)));
  }
}
