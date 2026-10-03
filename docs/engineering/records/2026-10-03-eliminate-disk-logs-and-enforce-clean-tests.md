# Eliminate Disk Logs And Enforce Clean Tests

Human-owned documents:

- `docs/human/requirements/20261003-Engineering-Eliminate Disk Logs And Enforce Clean Tests.md`

## Why

1. **Eliminate Runtime Disk Logging Before Open Source**:
   - The native app previously created a persistent `CueSeeker` directory under `~/Library/Logs/` via `AppLogDirectory` and logged full search query text, file paths, and subtitle samples to JSONL files on every search by default (`searchE2ELoggingEnabled = true`).
   - Leaving persistent search query logs on disk is a privacy issue and unacceptable for an open-source release. All automatic disk logging must be permanently removed from both Release and Debug builds.
2. **Prevent Host Preference Pollution from Tests**:
   - Tests generating random suite names with `UserDefaults(suiteName: "CueSeeker...-\(UUID())")` caused macOS `cfprefsd` to write empty `.plist` files into `~/Library/Preferences/`. Over repeated test runs, more than 150,000 orphaned `.plist` files accumulated on the host machine.
   - Calling `removePersistentDomain(forName:)` only resets the dictionary in `cfprefsd` without unlinking the file on disk.
3. **Prevent Host Temporary File Pollution from SQLite WAL/SHM**:
   - SQLite databases initialized with `PRAGMA journal_mode = WAL;` create `-wal` and `-shm` sidecars alongside `.sqlite`.
   - Tests calling `try? FileManager.default.removeItem(at: databaseURL)` only unlinked the main `.sqlite` file, stranding tens of thousands of `-wal` and `-shm` files in `$TMPDIR`.

## What changed

- **Search & Settings Runtime Cleanups**:
  - Removed `searchE2ELoggingEnabled` property, key, default registration, and decoder from `SettingsStore.swift`.
  - Removed "Search E2E JSON Logs" toggle and divider from `SettingsDeveloperCategory.swift`.
  - Removed `settings.developer.e2e_logs` and note from all `Localizable.strings` (`en`, `zh-Hans`, `zh-Hant`).
  - Deleted `AppLogDirectory.swift`.
  - Redirected `AppPerformanceProbe.swift` sample files from `AppLogDirectory` to `$TMPDIR/CueSeeker-main-thread-samples`.
  - Rewrote `SearchPerformanceLogger.swift`: eliminated `SearchE2ELogWriter`, `SearchPerformanceLogWriter`, `writeE2ESearchPage`, and JSONL benchmark serialization types. Retained in-memory metrics and `os.Logger` signposts guarded by `CUESEEKER_PERF_SEARCH`.
  - Removed `e2eLoggingEnabled` arguments and `writeE2ESearchPage` calls from `SearchStore+Execution.swift`, `AppCoordinator+Search.swift`, and `SearchStoreTests.swift`.
  - Guarded `NSApp?.appearance` in `SettingsStore.swift` with optional chaining to prevent crashes in non-windowed test contexts where `NSApplication.shared` is not yet initialized.

- **Test Isolation and Clean Teardown**:
  - Created `apps/macos-native/Tests/CueSeekerAppTests/TestCleanupSupport.swift`:
    - Added `UserDefaults.temporary(suiteName:)` which creates suite plist files directly in `$TMPDIR` via absolute path instead of polluting `~/Library/Preferences/`.
    - Added `UserDefaults.removePersistentDomainAndPlist(forName:)` which synchronizes domain deletion and unlinks the file from disk.
    - Added `removeTemporaryDatabase(at:)` which unlinks the `.sqlite` file along with its `-wal` and `-shm` sidecars.
  - Added `removeTemporaryDatabase(at:)` to `apps/macos-native/Tests/CueSeekerCoreTests/DatabaseTestSupport.swift`.
  - Replaced `try? FileManager.default.removeItem(at: databaseURL)` with `removeTemporaryDatabase(at: databaseURL)` across all test files in `CueSeekerCoreTests` and `CueSeekerAppTests`.
  - Updated `CueGroupRefreshScopeIntegrationTests.swift` harness `tearDown()` to delete its temporary directory and clean up its suite preferences.
  - Replaced `UserDefaults(suiteName:)` with `UserDefaults.temporary(suiteName:)` across `CueSeekerAppTests`.

## Verification

- Automated tests:
  - `swift build`: succeeded.
  - `swift build --build-tests`: succeeded.
  - `swift test --filter SearchStoreTests`: 27/27 passed.
  - `swift test --filter SearchDatabaseTests`: 46/46 passed.
  - `swift test --filter TaskQueueStoreTests`: 29/29 passed.
  - `swift test --filter AnkiPackageExporterTests`: 9/9 passed.
- Host cleanliness checks:
  - Checked `~/Library/Preferences/CueSeeker*`: 0 files found.
  - Checked `$TMPDIR/CueSeeker*`: 0 files found after test runs.
