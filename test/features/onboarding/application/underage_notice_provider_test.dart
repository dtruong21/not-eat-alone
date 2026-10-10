import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/onboarding/application/underage_notice_provider.dart';

void main() {
  test('defaults to false, can be set and cleared, survives no listeners', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(underageNoticeProvider), isFalse);
    container.read(underageNoticeProvider.notifier).set(value: true);
    expect(container.read(underageNoticeProvider), isTrue);
    container.read(underageNoticeProvider.notifier).set(value: false);
    expect(container.read(underageNoticeProvider), isFalse);
  });
}
