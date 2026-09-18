import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/config/flavor.dart';

void main() {
  test('stage config', () {
    final c = FlavorConfig(flavor: Flavor.stage);
    expect(c.isStage, true);
    expect(c.appTitle, 'not-eat-alone (stage)');
    expect(c.firestoreDatabaseId, 'stage');
  });
  test('prod config', () {
    final c = FlavorConfig(flavor: Flavor.prod);
    expect(c.isStage, false);
    expect(c.appTitle, 'not-eat-alone');
    expect(c.firestoreDatabaseId, '(default)');
  });
}
