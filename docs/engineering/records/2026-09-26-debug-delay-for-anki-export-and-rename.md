# Debug delay for Anki export and rename

Human-owned documents:

- `docs/human/requirements/20260926-Engineering-Debug Delay For Anki Export And Rename.md`
- `docs/human/requirements/20260925-Feature-Playback Continues When Content Leaves The Database.md` (5. 测试延迟)

## Why

Export to Anki, file rename (`.fileGroup`), and folder rename (`.folder`) tasks finish quickly, making it difficult to accept and verify task states (such as In Progress state, cancellation, and concurrency interactions) inside the App during development. Reusing the existing `CUESEEKER_DEBUG_TASK_DELAY_SECONDS` environment variable across these tasks provides a consistent way to slow down task execution for testing without altering release builds or introducing new entities.

## What changed

- **Expose debug task delay helper**: In `AppCoordinator+Indexing.swift`, made `waitForDebugTaskDelay(environment:)` package/internal so it can be called across coordinator extensions, and supported passing an environment dictionary for unit testing.
- **Add delay to rename tasks**: In `AppCoordinator+LibraryRename.swift`, updated `configureRenameRunner()` to await `AppCoordinator.waitForDebugTaskDelay()` before delegating to `AppCoordinator.runRename(...)`, delaying both file rename and folder rename operations by the specified seconds while the task is in `.running` state.
- **Add delay to Anki export tasks**: In `AppCoordinator+AnkiExport.swift`, added `configureAnkiExportRunner()` which sets `tasks.runExport` to await `AppCoordinator.waitForDebugTaskDelay()` before calling `TaskQueueStore.ankiExportRunner(...)`.
- **Wire runner configuration in coordinator initialization**: In `AppCoordinator.swift`, invoked `configureAnkiExportRunner()` during `init`.
- **Make `runExport` mutable on `TaskQueueStore`**: Changed `private let runExport` to `var runExport` on `TaskQueueStore` to match `runRename`, `runIndex`, `runAddFolder`, and `runRemoveFolder`.
- **Unit test coverage**: Created `DebugTaskDelayTests.swift` to verify non-positive or missing environment values return immediately and positive delay values wait as expected.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+LibraryRename.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+AnkiExport.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskQueueStore.swift`
- Tests: `apps/macos-native/Tests/CueSeekerAppTests/DebugTaskDelayTests.swift`

## Verification

- `swift test --filter DebugTaskDelayTests`: 3 tests passed.
- `swift test --filter TaskQueueStoreTests`: 27 tests passed.
- `swift test --filter SearchStoreTests`: 27 tests passed.
- `swift build`: passed.
- `swift build -c release --product CueSeeker`: passed (verified `#if DEBUG` ensures Release builds do not read or wait on debug environment variable).
