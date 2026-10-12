/// Network avatar helpers: decode at avatar size and tolerate a missing photo.
library;

import 'package:flutter/widgets.dart';

/// [url] as an [ImageProvider] decoded no larger than a [radius] avatar needs
/// (device-pixel-ratio aware), instead of the full-resolution bitmap. A 12 MP
/// photo is ~48 MB decoded; a 40 dp avatar needs a tiny fraction of that.
ImageProvider avatarImage(
  BuildContext context,
  String url, {
  required double radius,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return ResizeImage(
    NetworkImage(url),
    width: (radius * 2 * dpr).ceil(),
    allowUpscaling: false,
  );
}

/// `CircleAvatar.onBackgroundImageError` handler: a photo that 404s (just
/// removed, deleted account) falls back to the avatar's child/background
/// instead of reporting a fatal-looking framework error to Crashlytics.
void ignoreAvatarImageError(Object error, StackTrace? stackTrace) {}
