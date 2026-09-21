import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/matching/application/meal_request_state_provider.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/meal_detail_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

const _restaurant = Restaurant(
  placeId: 'p1',
  name: 'Cafe Central',
  address: '1 Rue de Rivoli, 75001 Paris',
  lat: 48.8566,
  lng: 2.3522,
);

final _meal = Meal(
  id: 'm1',
  hostId: 'host1',
  restaurant: _restaurant,
  dateTime: DateTime(2027, 1, 5, 19, 30),
  geohash: 'u09tvw',
  note: 'Bring your appetite!',
);

final _hostDob = DateTime(1990, 3, 15);

final _host = AppUser(
  uid: 'host1',
  dob: _hostDob,
  displayName: 'Alex',
  bio: 'Loves ramen.',
);

/// Same birthday-adjusted age math as the screen's private `_ageFromDob`,
/// duplicated here (rather than importing a private symbol) so the expected
/// age is computed relative to whenever the test actually runs, instead of
/// hardcoding a value that would drift with real wall-clock time.
int _expectedAge(DateTime dob) {
  final today = DateTime.now();
  var age = today.year - dob.year;
  final hadBirthday = (today.month > dob.month) ||
      (today.month == dob.month && today.day >= dob.day);
  if (!hadBirthday) age -= 1;
  return age;
}

void main() {
  late MockUserRepository userRepository;

  setUp(() {
    userRepository = MockUserRepository();
    when(() => userRepository.watch('host1'))
        .thenAnswer((_) => Stream.value(_host));
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'guest1')),
          ),
          mealRequestStateProvider(_meal.id)
              .overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: MealDetailScreen(meal: _meal),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders restaurant name and address', (tester) async {
    await pumpDetail(tester);

    expect(find.text(_restaurant.name), findsOneWidget);
    expect(find.text(_restaurant.address), findsOneWidget);
  });

  testWidgets('renders host display name and derived age', (tester) async {
    await pumpDetail(tester);

    expect(find.text('Alex, ${_expectedAge(_hostDob)}'), findsOneWidget);
    expect(find.text(_host.bio!), findsOneWidget);
  });

  testWidgets('"Request to join" is present and enabled for a guest viewer',
      (tester) async {
    await pumpDetail(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('meal_detail_request_to_join_button')),
    );

    expect(find.text('Request to join'), findsOneWidget);
    expect(button.onPressed, isNotNull);
  });
}
