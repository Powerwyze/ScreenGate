import 'package:flutter_test/flutter_test.dart';
import 'package:screengate/services/solo_reward_policy.dart';

void main() {
  test('Solo reward totals are capped at 60 minutes per day', () {
    expect(SoloRewardPolicy.clampDailyMinutes(0), 0);
    expect(SoloRewardPolicy.clampDailyMinutes(45), 45);
    expect(SoloRewardPolicy.clampDailyMinutes(90), 60);
  });

  test('Solo reward increments never exceed the daily cap', () {
    expect(SoloRewardPolicy.increment(20, 15), 35);
    expect(SoloRewardPolicy.increment(50, 20), 60);
  });
}
