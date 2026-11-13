# Implementation Record: Debug And Release Storage And Preferences Isolation

## Requirement

- `docs/human/requirements/20261113-Engineering-Debug And Release Storage And Preferences Isolation.md`

## Scope

- Symmetrically isolate local Application Support storage (`CueSeeker.sqlite`, `Covers/`, `WebDAVSubtitleCache/`), system caches (`ASSFontAliasResolver`), and preferences (`UserDefaults`) between Release (`release` / `com.cueseeker.release`) and Debug (`debug` / `com.cueseeker.debug`) builds while keeping logs under `~/Library/Application Support/CueSeeker/logs/<release|debug>/`.
- Remove obsolete legacy preference domain auto-merging (`com.cueseeker.app` / `CueSeeker`).
- Replace bundle-identifier-only single-instance detection with per-environment `flock` lock files (`CueSeeker.instance.lock`) so Release and command-line Debug builds can run concurrently while duplicate launches within the same build environment activate the running window and exit.
- Keep unit tests completely isolated in temporary directories and temporary preference files cleaned up at process exit.

## Steps

1. **Core Environment Path & Suite Resolution (`ApplicationInfo.swift`, `WebDAVSupport.swift`)**:
   - Added `ApplicationInfo.preferencesSuiteIdentifier(for:)`, `applicationSupportDirectoryURL(for:baseApplicationSupportDirectoryURL:fileManager:)`, and `cachesDirectoryURL(for:baseCachesDirectoryURL:fileManager:)` scoped to `AppBuildConfiguration` (`debug` / `release`).
   - Added `unitTestApplicationSupportDirectoryURL` and `unitTestCachesDirectoryURL` alongside `unitTestSubtitleCacheDirectoryURL` with automatic `atexit` cleanup.
   - Removed legacy preference domain migration from `WebDAVConfigurationStore` and updated `WebDAVSubtitleCache.defaultCacheDirectoryURL` to resolve under `<Application Support>/CueSeeker/<debug|release>/WebDAVSubtitleCache` (or `unitTestSubtitleCacheDirectoryURL` in unit tests).
2. **Playback Font Environment Cache Isolation (`ASSFontAliasResolver.swift`)**:
   - Updated `ASSFontAliasEnvironmentCache.defaultCacheURL` to resolve under `~/Library/Caches/CueSeeker/<debug|release>/ASSFontAliasResolver/` and use `ApplicationInfo.unitTestCachesDirectoryURL` during unit tests.
3. **App Persistence, Database Path, Single-Instance Guard & Benchmark Tooling (`ApplicationPersistence.swift`, `AppCoordinator.swift`, `SingleInstanceGuard.swift`, `main.swift`, `SearchBench/main.swift`)**:
   - Removed `migrateLegacyDefaultsIfNeeded` from `ApplicationPersistence` and pointed `sharedUserDefaults(for:)` to `ApplicationInfo.preferencesSuiteIdentifier(for:)`.
   - Updated `AppCoordinator.defaultDatabaseURL` to resolve `<Application Support>/CueSeeker/<debug|release>/CueSeeker.sqlite` (and per-test isolated paths inside `unitTestApplicationSupportDirectoryURL` during unit tests).
   - Rewrote `SingleInstanceGuard` using non-blocking exclusive `flock(LOCK_EX | LOCK_NB)` with `O_CLOEXEC` and holder-PID recording on `<environmentSupportDir>/CueSeeker.instance.lock`.
   - Updated `SearchBench` to resolve `selectedFolderPaths` from `com.cueseeker.debug` or `com.cueseeker.release` matching the target database's parent directory.
4. **Automated Tests & Engineering Rules (`ApplicationInfoTests.swift`, `WebDAVSupportTests.swift`, `PlaybackRequestTests.swift`, `ApplicationPersistenceTests.swift`, `docs/engineering/`)**:
   - Updated and added unit tests covering environment path/suite isolation, unit-test directory isolation, cross-environment parallel lock acquisition, and same-environment duplicate lock rejection.
   - Updated `05_database_rules.md`, `06_testing_rules.md`, `09_macos_media_runtime_and_packaging.md`, `10_url_scheme.md`, and `docs/changelog.md`.

## Verification

- Verified Debug and Release builds (`swift build` and `swift build -c release`) and targeted + full unit test suites pass with zero residue in `~/Library/Application Support/CueSeeker/{release,debug,logs}`, `~/Library/Caches/CueSeeker/`, and `~/Library/Preferences/`.

## Outcome

- Release and Debug builds are completely isolated across databases, covers, remote subtitle caches, system caches, preferences, and instance locks, while unit tests remain isolated in temporary storage.

## Follow-ups

- User manual E2E verification of concurrent Release and Debug execution and independent folder/settings persistence.
