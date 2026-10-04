import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/config/emulator_config.dart';

void main() {
  test('EmulatorConfig.local has expected defaults', () {
    const c = EmulatorConfig.local();
    expect(c.host, '127.0.0.1');
    expect(c.authPort, 9099);
    expect(c.firestorePort, 8080);
    expect(c.functionsPort, 5001);
    expect(c.storagePort, 9199);
  });

  test('host override is honoured (Android loopback)', () {
    const c = EmulatorConfig(host: '10.0.2.2');
    expect(c.host, '10.0.2.2');
    expect(c.firestorePort, 8080);
  });
}
