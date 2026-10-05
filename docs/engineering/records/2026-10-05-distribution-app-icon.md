# Distribution App Icon

Human-owned documents:

- `docs/human/requirements/20261005-UI-Distribution App Icon.md`

## Why

1. **Brand & Identification**:
   - Provide a distinct, native macOS application icon for packaged distribution builds of CueSeeker.
   - Ground the icon in the core product metaphor: a solid magnifying glass ("Seek") framing two lines of subtitle capsules ("Cue") centered on a standard macOS dark squircle base.
2. **Environment Differentiation**:
   - Keep debug and local development builds without custom app icons (relying on system defaults) to make distribution packages and active development instances immediately distinguishable.

## What changed

1. **Icon Vector Generation**:
   - Created `scripts/generate_app_icon.swift`, rendering the vector magnifying glass and subtitle cues onto an 824x824 squircle (1024x1024 canvas) using native AppKit and CoreGraphics.
   - Built standard `AppIcon.iconset` across all required macOS retina resolutions (16x16 up to 1024x1024) and invoked `iconutil` to produce `packaging/macos/AppIcon.icns`.
2. **Packaging Configuration**:
   - In `packaging/macos/Info.plist`, configured `CFBundleIconFile` and `CFBundleIconName` to `AppIcon`.
   - In `scripts/package_macos_app.sh`, added `ICON_SOURCE` copying `AppIcon.icns` into `$APP_PATH/Contents/Resources/`.
3. **Packaging Verification**:
   - In `scripts/verify_macos_app_bundle.sh`, added validation asserting that `$CONTENTS/Resources/AppIcon.icns` exists and `CFBundleIconFile` is set to `AppIcon`.

## Verification

- Vector generation: `scripts/generate_app_icon.swift` successfully compiled and generated `packaging/macos/AppIcon.icns`.
- App packaging & verification: Ran `./scripts/package_macos_app.sh`, successfully bundling `AppIcon.icns` into `CueSeeker.app` and passing all bundle verification checks.
