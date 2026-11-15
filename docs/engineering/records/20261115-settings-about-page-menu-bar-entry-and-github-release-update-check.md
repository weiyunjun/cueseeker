# Settings About Page, Menu Bar Entry, and GitHub Release Update Check

- Date: 2026-11-15
- Related Requirement: `docs/human/requirements/20261115-Feature-Settings About Page Menu Bar Entry And GitHub Release Update Check.md`
- Scope: `CueSeekerCore`, `CueSeekerCoreTests`, `CueSeekerApp`, `CueSeekerAppTests`

## Changes Made

- **`CueSeekerCore` semantic version comparison & GitHub Release evaluation** (`Sources/CueSeekerCore/GitHubReleaseUpdateChecker.swift`):
  - Added `GitHubReleaseUpdateChecker` with `repositoryURL` (`https://github.com/weiyunjun/cueseeker`), `latestReleaseAPIURL` (`https://api.github.com/repos/weiyunjun/cueseeker/releases/latest`), `SemanticVersion` (strips optional `v`/`V` prefix, compares numeric dot segments cleanly), pure `evaluateResponse(statusCode:data:currentVersion:)` (`404`, `draft == true`, `prerelease == true`, or non-higher versions map to `.upToDate`; higher formal release maps to `.updateAvailable(version:releaseURL:)` with canonical `vX.Y.Z` tag string; non-200 or malformed payloads map to `.failed`), and async `checkLatestRelease(currentVersion:session:requestTimeout:)`.
- **In-memory update lifecycle & Settings tokens/controls reuse** (`Settings/SettingsStore.swift`, `Settings/SettingsLayout.swift`, `Shared/WorkbenchControls/WorkbenchControlMetrics.swift`, `Shared/WorkbenchControls/WorkbenchControls.swift`):
  - Added `WorkbenchControlMetrics.redesignAboutAppIconSize` (`80`, `--size-about-app-icon`).
  - Added `showsSpinner: Bool = false` on `WorkbenchButton`, rendering `WorkbenchSpinner()` in place of `icon` identically to `WorkbenchPrimaryButton`.
  - Generalized `SettingsGroup` with `title: String? = nil` so untitled Settings cards reuse the shared `L-02.3` card container without duplicating chrome.
  - Added in-memory-only `SettingsStore.ReleaseUpdateState` (`idle`, `checking`, `upToDate`, `available(version:releaseURL:)`, `failed`), cached bundle-first `aboutAppIconImage` (with `NSApp?.applicationIconImage` fallback), `CFBundleShortVersionString` lookup (`"0.1.0"` fallback), and `checkForUpdates()`, `performAboutUpdateAction()`, `openGitHubRepository()`.
- **Menu Bar entry, Settings About page, pointer/drag symmetry, accessibility & localization** (`App/AppDelegate.swift`, `Settings/SettingsView.swift`, `Settings/SettingsAboutCategory.swift`, `Shared/WorkbenchAccessibility.swift`, `App/AppCoordinator+WorkbenchAccessibility.swift`, `Resources/*/Localizable.strings`):
  - Added top app menu item `About %@` (`showAboutSettings(_:)`) separated above `Settings…`, bringing forward the `Settings` window and navigating directly to `.about` (recorded in Settings Back/Forward history) while preserving `.general` default / last-category behavior on `⌘,` and topbar Settings button.
  - Added `case about` (`AppIcon.info`) to `SettingsCategory` and implemented `SettingsAboutCategory` with centered `80px` app icon, app name, version, aligned multiline description, and untitled two-row Settings card (`Software Update` 5-state indicator/action row and `Repository` row).
  - Implemented composite `GitHub Repository` hotspot pairing `WorkbenchSelectableText` (`preferredPointerShape: isRepositoryHovered ? .grab : .arrow`, `showsUnderline: isRepositoryHovered`, tap-vs-drag `I-beam` selection) with trailing `spacing-2` + `link-simple` (`18px`) `SettingsPointerCursorArea` (`resetCursorRects()` + `PointerShapeProviding` + `< 2.0pt` non-drag click) under a shared `.onPointerHover(showsHand: true)` so hover suppression keeps `.arrow` while stationary, hover shows `.pointingHand` across text + gap + icon with underline only under text, and dragging across text does not open the webpage.
  - Extended `SettingsAccessibilityTarget` (`aboutUpdateAction`, `aboutRepositoryLink`) and `AppCoordinator+WorkbenchAccessibility` (`About` target list, focus ring preservation during `.checking` disabled state, `redesignFieldRadius` focus ring on `GitHub Repository` hotspot), updated `Localizable.strings` (`en`, `zh-Hans`, `zh-Hant`), and updated the existing `SettingsCategory.allCases` expectation in `Tests/CueSeekerAppTests/WorkbenchAccessibilityStep3Tests.swift`.
- **Offline pure-logic unit tests** (`Tests/CueSeekerCoreTests/GitHubReleaseUpdateCheckerTests.swift`):
  - Added static tests covering `SemanticVersion` parsing/normalization/comparison and `evaluateResponse` handling of `404`, `draft`, `prerelease`, equal/older/higher releases, HTTP error status codes, and malformed JSON payloads without network requests.

## Verification

- `swift build --package-path apps/macos-native`: Build complete (`0.31s`).
- `swift test --package-path apps/macos-native --no-parallel --filter GitHubReleaseUpdateCheckerTests`: `4 passed` (`0` failed, `0.001s`).
- `swift test --package-path apps/macos-native --no-parallel --filter CueSeekerCoreTests`: XCTest `FileSizeFormatterTests` `5 passed` (`0` failed); Swift Testing `415` tests (`414 passed`, `1` pre-existing unrelated failure `CueFacetCountCacheTests.watchStateChangesUpdateOnlyWatchFacetCounts` at `CueFacetCountCacheTests.swift:174`).
- End-to-end interactive UI, pointer/hover suppression, menu navigation, browser opening, and accessibility acceptance remain with the user.
