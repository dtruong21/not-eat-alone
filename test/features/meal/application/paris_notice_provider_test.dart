import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/application/paris_notice_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Only the failing-store test double needs this transitive package.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A store whose writes always fail (full disk, locked storage).
class _FailingWriteStore extends InMemorySharedPreferencesStore {
  _FailingWriteStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      throw StateError('disk full');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to not dismissed', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(parisNoticeControllerProvider), isFalse);
  });

  test(
    'dismiss hides now and persists; a seeded container starts dismissed',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final done = c.read(parisNoticeControllerProvider.notifier).dismiss();
      expect(c.read(parisNoticeControllerProvider), isTrue);
      await done;

      final saved = await readParisNoticeDismissed();
      expect(saved, isTrue);
      final fresh = ProviderContainer(
        overrides: [parisNoticeSeedProvider.overrideWithValue(saved)],
      );
      addTearDown(fresh.dispose);
      expect(fresh.read(parisNoticeControllerProvider), isTrue);
    },
  );

  test('reads a pre-stored flag', () async {
    SharedPreferences.setMockInitialValues({parisNoticeDismissedKey: true});
    expect(await readParisNoticeDismissed(), isTrue);
  });

  test('a failing write does not throw and the choice still applies', () async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = _FailingWriteStore();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(parisNoticeControllerProvider.notifier).dismiss();
    expect(c.read(parisNoticeControllerProvider), isTrue);
  });
}
