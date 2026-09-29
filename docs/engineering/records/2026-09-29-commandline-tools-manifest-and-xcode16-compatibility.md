# CommandLineTools ManifestAPI and Xcode 16 Build Compatibility

Human-owned documents:

- `docs/human/requirements/20260929-Engineering-CommandLineTools-ManifestAPI-Conflict-Resolution.md`

## Why

After migrating development to a new macOS environment with Xcode 16.2 / Swift 6.0.3, `scripts/package_macos_app.sh` failed with two distinct issues:
1. Manifest compilation failed with unresolved symbol `PackageDescription.Package.__allocating_init(... swiftLanguageVersions: [PackageDescription.SwiftVersion]? ...)`. A leftover Swift 5.10 `arm64-apple-macos.private.swiftinterface` in CommandLineTools took precedence over the Swift 6 `.swiftinterface`, generating symbol calls to the retired `SwiftVersion` enum instead of the Swift 6 dylib's `SwiftLanguageMode`.
2. After clearing the orphaned private interface, SwiftPM defaulted targets to Swift 6 language mode under `swift-tools-version: 6.0`, triggering strict concurrency compile errors across UI stores and views. Furthermore, Xcode 16 SwiftPM injected developer framework rpaths into the executable, triggering bundle verification failures.

## What changed

- Configured `swiftLanguageModes: [.v5]` in `apps/macos-native/Package.swift` to keep the application compiled under the stable Swift 5 language mode on Xcode 16.
- Fixed cross-actor default argument expressions under the Swift 6 compiler:
  - `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore.swift`: Made `cueContentStore` default to `nil` and initialized within `@MainActor init`.
  - `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackStore.swift`: Marked `init` with `@MainActor` and resolved `interfaceLayers` default to `nil`.
  - `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`: Marked `init` with `@MainActor` and resolved `interfaceLayers` default to `nil`.
- Updated `apps/macos-native/Sources/CueSeekerApp/App/main.swift` to instantiate the `@MainActor` `AppDelegate` inside `MainActor.assumeIsolated`.
- Updated `scripts/package_macos_app.sh` to strip non-bundled rpaths (such as `/Library/Developer/...` framework rpaths injected by Xcode 16) before code-signing.

## Verification

- Built release target: `swift build -c release --product CueSeeker` succeeded without warnings or errors.
- Ran `./scripts/package_macos_app.sh` and verified self-contained `CueSeeker.app` bundle was successfully created.
- Bundle verification (`./scripts/verify_macos_app_bundle.sh .build/distribution/CueSeeker.app`) verified strict codesign and valid rpaths (`Exit code: 0`).
