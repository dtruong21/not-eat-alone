/// Shared profile form — name, gender, bio, and photo grid.
///
/// Used by both `ProfileSetupScreen` (forced onboarding) and
/// `ProfileEditScreen` (settings). Owns its own text-field state and the
/// photo add/remove flow (`profileControllerProvider`), and reports the
/// current form values back to its parent via [ProfileForm.onChanged] —
/// the parent decides what "valid" means for its own submit button
/// ([ProfileFormData.isValid] covers the common case: name + gender + at
/// least one photo).
///
/// Existing photo thumbnails come from `currentUserDocProvider` (the
/// signed-in user's Firestore doc) rather than local state, so a photo
/// add/remove is reflected here as soon as the doc stream updates — no
/// separate "pending photos" list to keep in sync.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

/// Maximum number of profile photos a user may have. Mirrors
/// `ProfileController`'s `_maxPhotos` — kept in sync manually since that
/// constant isn't exported (the form only needs it to hide the "add photo"
/// tile; the controller is the source of truth that actually enforces it).
const kProfilePhotoLimit = 6;

const _maxNameLength = 40;
const _maxBioLength = 300;

/// Snapshot of the form's current values, reported to the parent screen on
/// every change via [ProfileForm.onChanged].
@immutable
class ProfileFormData {
  const ProfileFormData({
    required this.name,
    required this.gender,
    required this.bio,
    required this.photoCount,
  });

  final String name;
  final Gender? gender;
  final String? bio;
  final int photoCount;

  /// True once the required set is satisfied: a non-blank name, a chosen
  /// gender, and at least one photo.
  bool get isValid =>
      name.trim().isNotEmpty && gender != null && photoCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileFormData &&
          other.name == name &&
          other.gender == gender &&
          other.bio == bio &&
          other.photoCount == photoCount);

  @override
  int get hashCode => Object.hash(name, gender, bio, photoCount);
}

const _genderOptions = <(Gender, String)>[
  (Gender.woman, 'Woman'),
  (Gender.man, 'Man'),
  (Gender.nonBinary, 'Non-binary'),
];

class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({required this.onChanged, super.key});

  /// Called after every build with the form's current values — including
  /// once right after the first frame, so a parent that starts with no
  /// data still learns the (invalid) initial state.
  final ValueChanged<ProfileFormData> onChanged;

  @override
  ConsumerState<ProfileForm> createState() => ProfileFormState();
}

/// Public (not `_`-prefixed) so widget tests can reach [debugInjectPickedBytes]
/// via a `GlobalKey<ProfileFormState>` — driving the native image picker in a
/// widget test isn't possible, so tests inject the "picked" bytes directly
/// and exercise the same add-photo path production code uses.
class ProfileFormState extends ConsumerState<ProfileForm> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  Gender? _gender;
  bool _prefilled = false;

  Uint8List? _debugPickedBytes;

  /// The last [ProfileFormData] reported to [ProfileForm.onChanged].
  ///
  /// `build()` reports the current form values on every build (via
  /// [_notifyChanged]'s post-frame callback), and the parent's handler
  /// typically calls `setState`, which triggers another build. Without this
  /// guard, that would fire `onChanged` — and therefore `setState` — every
  /// frame forever, since the data is only compared by the parent, not here.
  /// Skipping the callback once the reported value stops changing breaks
  /// that loop.
  ProfileFormData? _lastReported;

  /// Test-only hook: makes the next "add photo" tap use [bytes] instead of
  /// invoking `ImagePicker`. Production code should only ever populate this
  /// via the real picker in [_pickPhoto].
  @visibleForTesting
  void debugInjectPickedBytes(Uint8List bytes) {
    _debugPickedBytes = bytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _notifyChanged(int photoCount) {
    final data = ProfileFormData(
      name: _nameController.text,
      gender: _gender,
      bio: _bioController.text,
      photoCount: photoCount,
    );
    if (data == _lastReported) return;
    _lastReported = data;

    // Scheduled rather than called inline: this runs from build(), and the
    // parent's onChanged typically calls setState — doing that synchronously
    // while a build is in flight would throw.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(data);
    });
  }

  Future<void> _pickPhoto() async {
    var bytes = _debugPickedBytes;
    _debugPickedBytes = null;

    if (bytes == null) {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      bytes = await picked.readAsBytes();
    }

    if (!mounted) return;
    await ref.read(profileControllerProvider.notifier).addPhoto(bytes);
  }

  Future<void> _removePhoto(String url) async {
    await ref.read(profileControllerProvider.notifier).removePhoto(url);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserDocProvider).value;
    final photoUrls = user?.photoUrls ?? [];

    if (!_prefilled && user != null) {
      _prefilled = true;
      _nameController.text = user.displayName ?? '';
      _bioController.text = user.bio ?? '';
      _gender = user.gender;
    }

    final controllerState = ref.watch(profileControllerProvider);
    final isBusy = controllerState.isLoading;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    _notifyChanged(photoUrls.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Photos',
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: WarmPlayfulType.h2Weight,
          ),
        ),
        const SizedBox(height: WarmPlayfulSpacing.s2),
        _PhotoGrid(
          photoUrls: photoUrls,
          isBusy: isBusy,
          onAdd: _pickPhoto,
          onRemove: _removePhoto,
        ),
        if (controllerState.hasError) ...[
          const SizedBox(height: WarmPlayfulSpacing.s2),
          Text(
            'Something went wrong — please try again.',
            style: textTheme.bodyMedium?.copyWith(color: colors.error),
          ),
        ],
        const SizedBox(height: WarmPlayfulSpacing.s5),
        TextFormField(
          key: const Key('profile_name_field'),
          controller: _nameController,
          maxLength: _maxNameLength,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: WarmPlayfulSpacing.s4),
        Text(
          'I am a',
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: WarmPlayfulType.h2Weight,
          ),
        ),
        const SizedBox(height: WarmPlayfulSpacing.s2),
        SegmentedButton<Gender>(
          emptySelectionAllowed: true,
          segments: [
            for (final (value, label) in _genderOptions)
              ButtonSegment(value: value, label: Text(label)),
          ],
          selected: {?_gender},
          onSelectionChanged: (selected) {
            setState(() => _gender = selected.isEmpty ? null : selected.first);
          },
        ),
        const SizedBox(height: WarmPlayfulSpacing.s4),
        TextFormField(
          key: const Key('profile_bio_field'),
          controller: _bioController,
          maxLength: _maxBioLength,
          maxLines: 4,
          minLines: 3,
          decoration: InputDecoration(
            labelText: 'Bio',
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photoUrls,
    required this.isBusy,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> photoUrls;
  final bool isBusy;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final canAddMore = photoUrls.length < kProfilePhotoLimit;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: WarmPlayfulSpacing.s2,
        mainAxisSpacing: WarmPlayfulSpacing.s2,
      ),
      itemCount: photoUrls.length + (canAddMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < photoUrls.length) {
          final url = photoUrls[index];
          return _PhotoThumbnail(
            key: ValueKey('profile_photo_$url'),
            url: url,
            onRemove: isBusy ? null : () => onRemove(url),
          );
        }
        return _AddPhotoTile(
          key: const Key('add_photo_tile'),
          isBusy: isBusy,
          onTap: isBusy ? null : onAdd,
        );
      },
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.url, required this.onRemove, super.key});

  final String url;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Icon(Icons.broken_image_outlined, color: colors.outline),
            ),
          ),
        ),
        Positioned(
          top: WarmPlayfulSpacing.s1,
          right: WarmPlayfulSpacing.s1,
          child: GestureDetector(
            onTap: onRemove,
            child: CircleAvatar(
              radius: WarmPlayfulSpacing.s3,
              backgroundColor: colors.surface,
              child: Icon(
                Icons.close,
                size: WarmPlayfulSpacing.s4,
                color: colors.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap, required this.isBusy, super.key});

  final VoidCallback? onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
          ),
          child: Center(
            child: isBusy
                ? SizedBox(
                    height: WarmPlayfulSpacing.s4,
                    width: WarmPlayfulSpacing.s4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : Icon(Icons.add_a_photo_outlined, color: colors.outline),
          ),
        ),
      ),
    );
  }
}
