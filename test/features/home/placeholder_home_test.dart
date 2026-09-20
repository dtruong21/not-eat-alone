import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/home/placeholder_home.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
    when(() => authRepository.signOut()).thenAnswer((_) async {});
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
        child: const MaterialApp(home: PlaceholderHome()),
      ),
    );
  }

  testWidgets('shows the flavor-aware app title', (tester) async {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);

    await pumpHome(tester);

    expect(find.text('not-eat-alone'), findsOneWidget);
  });

  testWidgets('tapping sign out calls AuthRepository.signOut', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('placeholder_home_sign_out_button')));
    await tester.pump();

    verify(() => authRepository.signOut()).called(1);
  });
}
