# Standalone App Resource Bundle Loading

Human-owned documents:

- `docs/human/requirements/20260929-Bug-Standalone App Crash On Resource Bundle Loading.md`

## Why

Packaged standalone `CueSeeker.app` crashed immediately on launch on independent machines with a `fatalError` when attempting to load `CueSeekerNative_CueSeekerApp.bundle`. SwiftPM's auto-generated `Bundle.module` checked only the app root or the original developer build machine's absolute path. In an assembled macOS `.app` bundle, resources live in `Contents/Resources/`, which caused `Bundle.module` to fail outside the local development environment.

## What changed

- Added `Bundle.appResources` in `AppResourceBundle.swift`:
  - First searches standard macOS app bundle resources in `Contents/Resources/CueSeekerNative_CueSeekerApp.bundle`.
  - Searches `Bundle.main.resourceURL` and token bundle locations.
  - Retains fallback for local executable and test runners (`swift run`, `swift test`).
- Replaced direct `Bundle.module` accesses with `Bundle.appResources` across:
  - `AppLocalization.swift` (localizations and strings bundle resolution)
  - `AppIcon.swift` (SVG asset loading)
  - `AnkiPackageExporter.swift` (export SVG icon markup)
- Added `AppResourceBundleTests.swift` to verify localization and SVG icon resolution through `Bundle.appResources`.

## Verification

- `swift test --package-path apps/macos-native --filter AppResourceBundleTests` passed (2/2 tests passed).
- `swift test --package-path apps/macos-native --filter AppLocalizationTests` passed (4/4 tests passed).
- Executed `./scripts/package_macos_app.sh`, successfully produced self-contained `CueSeeker.app`.
- Ran `./scripts/verify_macos_app_bundle.sh .build/distribution/CueSeeker.app` and confirmed Designated Requirement and strict code-signing validation passed.
- Launched the packaged binary from `/tmp` and verified clean startup without resource loading fatal error.
