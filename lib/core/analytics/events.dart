/// Event registry — the typed source of truth in code.
///
/// Every event the app can fire is declared here as a subclass of the sealed
/// `AppEvent` class. If an event isn't in the hierarchy, it can't be passed
/// to `track()` — the compiler rejects it. This is intentional: it keeps the
/// analytics surface bounded.
///
/// Mirror in human-readable form: docs/TRACKING-PLAN.md
/// Add new events via `/track <event_name>` — it updates both files.
///
/// Discipline:
/// - Names: `noun_verb` past-tense, snake_case.
/// - Properties: scalars only. No nested objects.
/// - No PII as property values — reference by user_id only.
library;

// ─── Base ────────────────────────────────────────────────────────────────────

/// The closed family of analytics events. `sealed` forces every event to live
/// in this file (or be `part of` it), which keeps the registry auditable.
sealed class AppEvent {
  const AppEvent();

  /// The event name fired to the analytics provider. snake_case past-tense.
  String get name;

  /// Scalar-only property map. No nested maps, no PII.
  Map<String, Object?> get props;
}

// ─── Universal events ────────────────────────────────────────────────────────

final class AppOpened extends AppEvent {
  const AppOpened({required this.isColdStart});
  final bool isColdStart;

  @override
  String get name => 'app_opened';

  @override
  Map<String, Object?> get props => {'is_cold_start': isColdStart};
}

/// Auth methods. Keep in sync with `SigninMethod` if you split the two.
enum SignupMethod { email, google, apple, phone, anonymous }

final class SignupCompleted extends AppEvent {
  const SignupCompleted({required this.method});
  final SignupMethod method;

  @override
  String get name => 'signup_completed';

  @override
  Map<String, Object?> get props => {'method': method.name};
}

enum SigninMethod { email, google, apple, phone }

final class SigninStarted extends AppEvent {
  const SigninStarted({required this.method});
  final SigninMethod method;

  @override
  String get name => 'signin_started';

  @override
  Map<String, Object?> get props => {'method': method.name};
}

final class SigninCompleted extends AppEvent {
  const SigninCompleted({required this.method});
  final SigninMethod method;

  @override
  String get name => 'signin_completed';

  @override
  Map<String, Object?> get props => {'method': method.name};
}

final class AgeGatePassed extends AppEvent {
  const AgeGatePassed();

  @override
  String get name => 'age_gate_passed';

  @override
  Map<String, Object?> get props => const {};
}

final class AgeGateFailed extends AppEvent {
  const AgeGateFailed();

  @override
  String get name => 'age_gate_failed';

  @override
  Map<String, Object?> get props => const {};
}

final class SignoutCompleted extends AppEvent {
  const SignoutCompleted();

  @override
  String get name => 'signout_completed';

  @override
  Map<String, Object?> get props => const {};
}

// ─── Project-specific events (extend below — keep this section growing) ──────
//
// Example: uncomment and adapt.
//
// final class HabitCreated extends AppEvent {
//   const HabitCreated({required this.schedule, required this.hasReminder});
//   final String schedule;     // 'daily' | 'weekdays' | 'custom'
//   final bool hasReminder;
//
//   @override
//   String get name => 'habit_created';
//
//   @override
//   Map<String, Object?> get props => {
//         'schedule': schedule,
//         'has_reminder': hasReminder,
//       };
// }

final class ProfileCompleted extends AppEvent {
  const ProfileCompleted();

  @override
  String get name => 'profile_completed';

  @override
  Map<String, Object?> get props => const {};
}

final class ProfilePhotoAdded extends AppEvent {
  const ProfilePhotoAdded({required this.count});
  final int count;

  @override
  String get name => 'profile_photo_added';

  @override
  Map<String, Object?> get props => {'count': count};
}

final class ProfileEdited extends AppEvent {
  const ProfileEdited();

  @override
  String get name => 'profile_edited';

  @override
  Map<String, Object?> get props => const {};
}

final class RestaurantSelected extends AppEvent {
  const RestaurantSelected();

  @override
  String get name => 'restaurant_selected';

  @override
  Map<String, Object?> get props => const {};
}

final class MealCreated extends AppEvent {
  const MealCreated({required this.womenOnly});
  final bool womenOnly;

  @override
  String get name => 'meal_created';

  @override
  Map<String, Object?> get props => {'women_only': womenOnly};
}

final class DiscoveryViewed extends AppEvent {
  const DiscoveryViewed({required this.count});
  final int count;

  @override
  String get name => 'discovery_viewed';

  @override
  Map<String, Object?> get props => {'count': count};
}

final class MealOpened extends AppEvent {
  const MealOpened({required this.womenOnly});
  final bool womenOnly;

  @override
  String get name => 'meal_opened';

  @override
  Map<String, Object?> get props => {'women_only': womenOnly};
}

final class JoinRequested extends AppEvent {
  const JoinRequested({required this.womenOnly});
  final bool womenOnly;
  @override
  String get name => 'join_requested';
  @override
  Map<String, Object?> get props => {'women_only': womenOnly};
}

final class RequestApproved extends AppEvent {
  const RequestApproved();
  @override
  String get name => 'request_approved';
  @override
  Map<String, Object?> get props => const {};
}

final class RequestDenied extends AppEvent {
  const RequestDenied();
  @override
  String get name => 'request_denied';
  @override
  Map<String, Object?> get props => const {};
}

final class MatchCreated extends AppEvent {
  const MatchCreated({required this.womenOnly});
  final bool womenOnly;
  @override
  String get name => 'match_created';
  @override
  Map<String, Object?> get props => {'women_only': womenOnly};
}

final class ChatOpened extends AppEvent {
  const ChatOpened();
  @override
  String get name => 'chat_opened';
  @override
  Map<String, Object?> get props => const {};
}

final class MessageSent extends AppEvent {
  const MessageSent();
  @override
  String get name => 'message_sent';
  @override
  Map<String, Object?> get props => const {};
}

final class PushPermissionGranted extends AppEvent {
  const PushPermissionGranted({required this.granted});
  final bool granted;
  @override
  String get name => 'push_permission_granted';
  @override
  Map<String, Object?> get props => {'granted': granted};
}

final class PushOpened extends AppEvent {
  const PushOpened({required this.type});
  final String type;
  @override
  String get name => 'push_opened';
  @override
  Map<String, Object?> get props => {'type': type};
}

final class UserBlocked extends AppEvent {
  const UserBlocked();
  @override
  String get name => 'user_blocked';
  @override
  Map<String, Object?> get props => const {};
}

final class UserReported extends AppEvent {
  const UserReported({required this.targetType});
  final String targetType;
  @override
  String get name => 'user_reported';
  @override
  Map<String, Object?> get props => {'target_type': targetType};
}

final class AccountDeletionRequested extends AppEvent {
  const AccountDeletionRequested();
  @override
  String get name => 'account_deletion_requested';
  @override
  Map<String, Object?> get props => const {};
}

final class PostMealPromptShown extends AppEvent {
  const PostMealPromptShown();
  @override
  String get name => 'post_meal_prompt_shown';
  @override
  Map<String, Object?> get props => const {};
}

final class MealRated extends AppEvent {
  const MealRated({required this.stars, required this.showedUp});
  final int stars;
  final bool showedUp;
  @override
  String get name => 'meal_rated';
  @override
  Map<String, Object?> get props => {'stars': stars, 'showed_up': showedUp};
}

// ─── User properties registry ────────────────────────────────────────────────

/// Sparse by design. Add a property only when it drives segmentation or is
/// needed for cross-event analysis. Set via `identify()` in `client.dart`.
///
/// All fields nullable — `identify()` merges; pass only what you're updating.
class UserProperties {
  const UserProperties({
    this.signupDate,
    this.signupMethod,
    this.appVersion,
    this.platform,
  });

  final String? signupDate; // ISO date
  final SignupMethod? signupMethod;
  final String? appVersion; // semver
  final String? platform; // 'ios' | 'android' | 'web'

  Map<String, Object?> toMap() => {
        if (signupDate != null) 'signup_date': signupDate,
        if (signupMethod != null) 'signup_method': signupMethod!.name,
        if (appVersion != null) 'app_version': appVersion,
        if (platform != null) 'platform': platform,
      };
}
