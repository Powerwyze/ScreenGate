import 'package:flutter_test/flutter_test.dart';
import 'package:screengate/models/mission.dart';

void main() {
  group('Mission', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final updatedAt = DateTime.utc(2026, 1, 2);
    final completedAt = DateTime.utc(2026, 1, 3);

    Mission buildMission() => Mission(
          id: 'mission-1',
          userId: 'user-1',
          title: 'Clear desk',
          description: 'Remove all clutter from the desk.',
          completedState: 'Desk is clear and ready to use.',
          type: MissionType.selfAssigned,
          status: MissionStatus.failed,
          deadline: DateTime.utc(2026, 1, 4),
          recurrencePattern: 'daily',
          beforePhotoUrl: 'https://example.com/before.jpg',
          afterPhotoUrl: 'https://example.com/after.jpg',
          starsEarned: 2,
          aiFeedback: 'Try again with a clearer after photo.',
          createdAt: createdAt,
          updatedAt: updatedAt,
          completedAt: completedAt,
        );

    test('round-trips JSON fields', () {
      final mission = buildMission();
      final decoded = Mission.fromJson(mission.toJson());

      expect(decoded.id, mission.id);
      expect(decoded.userId, mission.userId);
      expect(decoded.type, mission.type);
      expect(decoded.status, mission.status);
      expect(decoded.beforePhotoUrl, mission.beforePhotoUrl);
      expect(decoded.afterPhotoUrl, mission.afterPhotoUrl);
      expect(decoded.starsEarned, mission.starsEarned);
      expect(decoded.completedAt, mission.completedAt);
    });

    test('copyWith can clear nullable verification fields', () {
      final reset = buildMission().copyWith(
        status: MissionStatus.pending,
        afterPhotoUrl: null,
        aiFeedback: null,
        completedAt: null,
        starsEarned: 0,
      );

      expect(reset.status, MissionStatus.pending);
      expect(reset.beforePhotoUrl, 'https://example.com/before.jpg');
      expect(reset.afterPhotoUrl, isNull);
      expect(reset.aiFeedback, isNull);
      expect(reset.completedAt, isNull);
      expect(reset.starsEarned, 0);
    });
  });
}
