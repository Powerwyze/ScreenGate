import 'package:flutter_test/flutter_test.dart';
import 'package:screengate/models/user.dart';

void main() {
  group('User account role', () {
    final now = DateTime.utc(2026, 7, 20);

    Map<String, dynamic> userJson({String? role, String? usageMode}) => {
          'id': 'user-1',
          'codename': 'Maya',
          'email': 'maya@example.com',
          'selected_handler_id': 'handler-1',
          'life_goals': 'Finish homework',
          if (role != null) 'account_role': role,
          if (usageMode != null) 'usage_mode': usageMode,
          'total_stars': 0,
          'level': 1,
          'current_streak': 0,
          'longest_streak': 0,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

    test('reads child role from Supabase', () {
      expect(User.fromJson(userJson(role: 'child')).accountRole,
          AccountRole.child);
    });

    test('keeps existing profiles compatible as parent', () {
      expect(User.fromJson(userJson()).accountRole, AccountRole.parent);
    });

    test('writes role back to Supabase', () {
      final child = User.fromJson(userJson(role: 'child'));
      expect(child.toJson()['account_role'], 'child');
    });

    test('keeps existing profiles compatible as family accounts', () {
      expect(User.fromJson(userJson()).usageMode, UsageMode.family);
    });

    test('round-trips solo mode', () {
      final solo = User.fromJson(userJson(usageMode: 'solo'));
      expect(solo.usageMode, UsageMode.solo);
      expect(solo.toJson()['usage_mode'], 'solo');
    });
  });
}
