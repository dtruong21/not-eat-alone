# Store frames

Composes the App Store / Google Play screenshots: a caption on a coral
(`WarmPlayfulColorsLight.accent`) canvas above the real capture, rounded with
the `xl` radius token and a soft shadow. Nunito ExtraBold, ink `text` colour
(contrast checked >= 4.5:1 by the test). Output PNGs are opaque 8-bit RGB
(`png_rgb.dart` drops the alpha channel, which App Store rejects).

Shots (source capture -> output): `22_discover_data` 01_discover,
`40_meal_detail_open` 02_meal_detail, `52_requests_data` 03_requests,
`63_chat_messages` 04_chat, `76_chat_safety_sheet` 05_safety.
Captions live in `captions.dart` (French is a draft for native review).

## Regenerate

```sh
# 1. Raw captures (gitignored, 1206x2622), one cell per locale
make ux-capture DEVICE='Convyve E2E' OUT=20-light-default
UX_LOCALE=fr make ux-capture DEVICE='Convyve E2E' OUT=20-fr-light-default

# 2. Compose and write docs/store/screenshots/{en,fr}/{ios-6.9,play-phone}/
fvm flutter test tool/store_frames/store_frames_test.dart \
  --dart-define=STORE_WRITE=true
# optional: --dart-define=STORE_SRC_EN=<dir> --dart-define=STORE_SRC_FR=<dir>

# 3. Verify
sips -g pixelWidth -g pixelHeight -g hasAlpha docs/store/screenshots/*/*/*.png
```

Without `STORE_WRITE=true` the test renders in memory and only checks sizes,
contrast, caption fit and opacity. It skips when a source folder or PNG is
missing.
