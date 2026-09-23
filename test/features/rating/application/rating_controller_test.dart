import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/rating/application/rating_controller.dart';
import 'package:not_eat_alone/features/rating/application/rating_providers.dart';
import 'package:not_eat_alone/features/rating/domain/entities/rating.dart';
import 'package:not_eat_alone/features/rating/domain/repositories/rating_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

const _rating = Rating(
  id: 'match_1_rater_1',
  matchId: 'match_1',
  raterUid: 'rater_1',
  targetUid: 'target_1',
  stars: 5,
  showedUp: true,
);

void main() {
  late MockAuthRepository authRepository;
  late MockRatingRepository ratingRepository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_rating);
  });

  setUp(() {
    authRepository = MockAuthRepository();
    ratingRepository = MockRatingRepository();

    when(() => authRepository.currentUser)
        .thenReturn(const AuthUser(uid: 'rater_1'));
    when(() => ratingRepository.submit(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        ratingRepositoryProvider.overrideWithValue(ratingRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('RatingController', () {
    test(
      'submit() calls ratingRepository.submit with a rating whose raterUid '
      'is the current uid and id is {matchId}_{uid}',
      () async {
        await container.read(ratingControllerProvider.notifier).submit(
              matchId: 'match_1',
              targetUid: 'target_1',
              stars: 5,
              showedUp: true,
            );

        final captured =
            verify(() => ratingRepository.submit(captureAny())).captured;
        expect(captured, hasLength(1));
        final rating = captured.single as Rating;
        expect(rating.id, 'match_1_rater_1');
        expect(rating.matchId, 'match_1');
        expect(rating.raterUid, 'rater_1');
        expect(rating.targetUid, 'target_1');
        expect(rating.stars, 5);
        expect(rating.showedUp, isTrue);

        final state = container.read(ratingControllerProvider);
        expect(state.hasError, isFalse);
      },
    );

    test('submit() with stars <= 0 no-ops', () async {
      await container.read(ratingControllerProvider.notifier).submit(
            matchId: 'match_1',
            targetUid: 'target_1',
            stars: 0,
            showedUp: true,
          );

      verifyNever(() => ratingRepository.submit(any()));
    });

    test('submit() leaves state.hasError true when the write fails', () async {
      when(() => ratingRepository.submit(any()))
          .thenThrow(Exception('write failed'));

      await container.read(ratingControllerProvider.notifier).submit(
            matchId: 'match_1',
            targetUid: 'target_1',
            stars: 5,
            showedUp: true,
          );

      final state = container.read(ratingControllerProvider);
      expect(state.hasError, isTrue);
    });
  });
}
