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
}
