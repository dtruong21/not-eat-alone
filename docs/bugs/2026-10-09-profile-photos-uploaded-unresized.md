## [P2] (inferred) Profile photos are uploaded at original resolution and avatars decode full-size images

**Repro:**
1. Profile setup or edit -> Add photo -> pick a high-resolution gallery image (48-200MP phones produce 10-30MB JPEGs; 12MP is 3-6MB).
2. Open Discover/Chats with several hosts' photos on a mid-tier Android phone.

**Expected:** Uploads are bounded (e.g. 1080px, quality 80), well under the Storage rule limit (`request.resource.size < 8MB`), and list avatars are decoded at avatar size.
**Actual:** `ProfileForm._pickPhoto` calls `ImagePicker().pickImage(source: gallery)` with no `maxWidth/maxHeight/imageQuality` and uploads the bytes unchanged as `image/jpeg` (`PhotoStorageDataSource.upload`): originals over 8MB are rejected by `storage.rules` and surface only as a generic profile error; accepted ones cost bandwidth/Storage and every `CircleAvatar`/`NetworkImage` (Discovery cards, chat list, chat bar, inbox, meal detail) decodes the full bitmap (a 12MP photo is about 48MB decoded) with no `ResizeImage`/`cacheWidth`, risking jank/OOM on a feed of 20 hosts. None of the `NetworkImage`s has `onBackgroundImageError`, so a 404 (photo just removed, deleted account) is reported through `FlutterError.onError`, which `bootstrap` records to Crashlytics as fatal.

**Device/OS:** code analysis only; NOT VERIFIED on hardware (no device).
**Build:** develop @ 8cf1b41
**Frequency:** depends on the user's camera.

**Hypothesis:** `pickImage(maxWidth: 1080, maxHeight: 1080, imageQuality: 80)`; use `ResizeImage(NetworkImage(url), width: 2 * radius * dpr)` (or `cached_network_image` with `memCacheWidth`) and pass `onBackgroundImageError: (_, __) {}` on avatars. Optionally record non-fatal (`fatal: false`) for async errors in `PlatformDispatcher.onError`.
