/// Profile tab root — view and edit your own (already complete) profile.
///
/// Wraps the same [ProfileForm] used by onboarding's `ProfileSetupScreen`.
/// It is a shell tab root, so there is no back arrow and no pop: "Save" calls
/// [ProfileController.save] (a partial update), confirms with a "Profile
/// saved" snackbar and stays. Save is enabled only while the name, bio or
/// gender differ from the saved profile. Photos are not part of that
/// comparison: the form writes each add/remove straight to the profile
/// (see `ProfileController.addPhoto`), so they never wait for Save.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/rating_badge.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/presentation/widgets/profile_form.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

/// The Profile tab screen.
class ProfileEditScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => ProfileEditScreenState();
}

/// State of [ProfileEditScreen].
class ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  ProfileFormData? _formData;

  /// What was last written by Save; until then the loaded profile is the
  /// baseline. Keeps Save disabled right after a save even before the
  /// profile stream catches up.
  ProfileFormData? _saved;

  /// Name and bio compare trimmed (that is what Save writes), the bio's
  /// null and empty are the same, and the photo count is ignored (photos are
  /// saved as they change).
  static ProfileFormData _normalized(ProfileFormData d) => ProfileFormData(
    name: d.name.trim(),
    gender: d.gender,
    bio: (d.bio ?? '').trim(),
    photoCount: 0,
  );

  static ProfileFormData _fromUser(AppUser u) => ProfileFormData(
    name: u.displayName ?? '',
    gender: u.gender,
    bio: u.bio,
    photoCount: 0,
  );

  void _onFormChanged(ProfileFormData data) {
    if (data != _formData) setState(() => _formData = data);
  }

  Future<void> _save() async {
    final data = _formData;
    if (data == null) return;

    final name = data.name.trim();
    final bio = data.bio?.trim();

    await ref
        .read(profileControllerProvider.notifier)
        .save(
          displayName: name.isEmpty ? null : name,
          // A blank bio is sent as '' (null means "leave unchanged" in
          // `updateProfile`), so clearing it really clears it.
          bio: bio ?? '',
          gender: data.gender,
        );

    if (!mounted) return;
    final state = ref.read(profileControllerProvider);
    if (!state.hasError) {
      setState(() => _saved = _normalized(data));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.profileSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final isSubmitting = state.isLoading;
    final me = ref.watch(currentUserDocProvider).value;
    final myUid = me?.uid;
    final data = _formData;
    final baseline = _saved ?? (me == null ? null : _normalized(_fromUser(me)));
    final canSave =
        data != null &&
        baseline != null &&
        data.isValid &&
        _normalized(data) != baseline;
    // Only an invalid form explains itself; merely-unchanged stays silent.
    final l10n = context.l10n;
    final missing = data != null && !data.isValid
        ? localizeMissingFields(l10n, data.missingFields)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navProfile),
        actions: [
          IconButton(
            key: const Key('profile_settings_button'),
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (myUid != null) ...[
                _YourRating(uid: myUid, hasRatings: (me?.ratingCount ?? 0) > 0),
                const SizedBox(height: WarmPlayfulSpacing.s4),
              ],
              ProfileForm(onChanged: _onFormChanged),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              AppButton(
                label: l10n.commonSave,
                loadingLabel: l10n.commonSaving,
                isLoading: isSubmitting,
                onPressed: isSubmitting || !canSave ? null : _save,
              ),
              // Always mounted so screen readers announce text changes.
              Semantics(
                liveRegion: true,
                container: true,
                child: missing == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(
                          top: WarmPlayfulSpacing.s2,
                        ),
                        child: Text(
                          l10n.profileStillNeeded(missing),
                          key: const Key('profile_save_hint'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.wp.muted),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your rating" + the star badge, or "No ratings yet". Wraps rather than
/// overflowing at large text sizes.
class _YourRating extends StatelessWidget {
  const _YourRating({required this.uid, required this.hasRatings});

  final String uid;
  final bool hasRatings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      key: const Key('profile_your_rating'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: WarmPlayfulSpacing.s2,
      runSpacing: WarmPlayfulSpacing.s1,
      children: [
        Text(
          l10n.profileYourRating,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: WarmPlayfulType.h2Weight,
          ),
        ),
        if (hasRatings)
          RatingBadge(uid: uid)
        else
          Text(
            l10n.profileNoRatings,
            style: textTheme.bodySmall?.copyWith(color: context.wp.muted),
          ),
      ],
    );
  }
}
