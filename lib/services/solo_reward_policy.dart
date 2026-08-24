/// Rules for Solo earned app time.
class SoloRewardPolicy {
  static const int dailyLimitMinutes = 60;

  static int clampDailyMinutes(int minutes) =>
      minutes.clamp(0, dailyLimitMinutes).toInt();

  static int increment(int currentMinutes, int earnedMinutes) =>
      clampDailyMinutes(currentMinutes + earnedMinutes);
}
