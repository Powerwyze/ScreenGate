import 'package:flutter_test/flutter_test.dart';
import 'package:taskassassin/services/family_service.dart';

void main() {
  test('RememberedChild round-trips local account data', () {
    const child = RememberedChild(
      id: '7d173659-6a18-41f7-84ac-e73bf9822451',
      name: 'Jimmy',
    );

    final restored = RememberedChild.fromJson(child.toJson());

    expect(restored.id, child.id);
    expect(restored.name, child.name);
  });

  test('QuestimeDevice keeps the installation identity used for deduping', () {
    final device = QuestimeDevice.fromJson({
      'id': 'device-id',
      'installation_id': 'ios-7d173659-6a18-41f7-84ac-e73bf9822451',
      'platform': 'ios',
      'device_name': 'Child phone',
      'screen_time_authorized': false,
      'remaining_seconds': 0,
    });

    expect(
      device.installationId,
      'ios-7d173659-6a18-41f7-84ac-e73bf9822451',
    );
  });
}
