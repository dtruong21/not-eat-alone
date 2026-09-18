/// Feedback submission — Riverpod AsyncNotifier.
///
/// Pattern (master spec idiom #1):
///   - `build()` returns the initial value (here: `AsyncData(null)` — nothing
///      submitted yet).
///   - Mutations set `state = const AsyncValue.loading()` then
///     `state = await AsyncValue.guard(() => ...)`. Errors propagate
///     into `state.error` automatically.
///   - Inside methods after `build()`, use `ref.read` only. `ref.watch`
///     after `build()` is gotcha #1 in the master spec.
///
/// Wiring in UI:
///
///   final state = ref.watch(feedbackSubmissionProvider);
///   state.when(
///     data: (_) => SubmitButton(onPressed: () =>
///       ref.read(feedbackSubmissionProvider.notifier).submit(input)),
///     loading: () => const CircularProgressIndicator(),
///     error: (e, _) => ErrorBanner(message: e.toString()),
///   );
///
/// Don't generate `feedback_provider.g.dart` by hand — it's emitted by
/// `dart run build_runner watch -d`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart';
import 'package:not_eat_alone/core/analytics/events.dart';

// import '../../core/firebase/feedback_repository.dart';  // user creates via /firestore

part 'feedback_provider.g.dart';

enum FeedbackCategory { bug, idea, praise, other }

class SubmitFeedbackInput {
  const SubmitFeedbackInput({
    required this.category,
    required this.body,
    required this.route,
  });

  final FeedbackCategory category;
  final String body;
  final String route;
}

@riverpod
class FeedbackSubmission extends _$FeedbackSubmission {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> submit(SubmitFeedbackInput input) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // TODO: wire feedback_repository via:
      //   /firestore feedback uid:string category:string body:string
      //
      // Then replace this block with:
      //   final user = ref.read(currentUserProvider);
      //   await ref.read(feedbackRepositoryProvider).create(
      //     user.uid,
      //     Feedback(
      //       uid: user.uid,
      //       category: input.category,
      //       body: input.body,
      //       route: input.route,
      //       appVersion: appVersion,
      //       platform: defaultTargetPlatform.name,
      //     ),
      //   );
      throw UnimplementedError(
        'Wire lib/core/firebase/feedback_repository.dart via /firestore first',
      );
    });

    if (state.hasError) return;

    await track(FeedbackSubmitted(
      category: input.category.name,
      lengthChars: input.body.length,
    ));
  }
}
