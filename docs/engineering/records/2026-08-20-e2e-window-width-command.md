# Requirement

- `docs/human/requirements/20260820-Engineering-Debug End-to-End Window Width Command.md`

# Scope

- Add a Debug E2E command that sets the main window's width so width-dependent adaptive layout can be verified automatically.
- Preserve the existing scene-token contract, single-display rule, response metadata, and Release isolation.
- Do not add height adjustment, window movement, full-screen switching, multi-window resizing, or scale changes.

# Steps

- Added `setWidth` parsing with a required finite positive `width` and current `sceneID`, and extended the strict argument guards of the five existing commands to reject a stray `width`.
- Added `DebugE2EWindowSizeDispatcher`, which resizes only the main window and leaves its height and upper-left corner unchanged. AppKit clamps the request to the window's own minimum and maximum size.
- Reused the existing scene revision, scene rebuild, and response metadata path after each successful resize, and reported the effective width as `windowWidth` rather than `width`, which the scene payload already uses for the scene bounds.
- Restored the previous window frame when the post-resize scene rebuild fails, so a failed command leaves the window unchanged and does not advance the scene revision.
- Added an explicit `invalidWindowWidth` failure for a non-positive or non-finite width.
- Documented the command format, width semantics, clamping, failure conditions, and capability boundary in the Debug in-app E2E section.

# Verification

- `swift test --filter DebugE2EControllerTests` passed all 8 tests, covering `setWidth` parsing, rejected widths, effective resize with unchanged height and upper-left corner, scene invalidation, and the existing `click`, `scroll`, `keyPress`, and capture regressions.
- `swift test --no-parallel --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` ran 1005 tests with only the two previously recorded Shiori refresh timing issues in `showCueGroupInvalidationIsScopedToMountedShiori` and `shioriTableStartsAtTopAfterPanelRemount`, both of which reproduce when run alone and are unrelated to this change.
- A live Debug E2E run started at `1445 × 821`, resized to `1000`, captured, resized to `1400`, and captured again. Each successful command returned a fresh `sceneID` and the effective `windowWidth`. The two captures show the Shiori overview grid reflowing from a wrapped four-plus-one layout to a single row of five, confirming that adaptive layout responds to the command.
- Live failure cases behaved as specified. A `width` of `3000` exceeded the display, returned `windowsSpanMultipleDisplays`, and a following `inspect` confirmed the window stayed at its previous width with an unchanged `sceneID`. A stale `sceneID` returned `sceneChanged` and a `width` of `0` returned `invalidCommand`, neither of which changed the window. A following `scroll` still succeeded.
- `swift build -c release --product CueSeeker` passed. The Release executable contains neither the Debug E2E flag, the `CUESEEKER_E2E` prefix, nor `invalidWindowWidth`. The only `setWidth` match is AppKit's own `setWidthTracksTextView:` selector.

# Outcome

- Debug E2E procedures can now verify width-dependent adaptive layout without resizing the window by hand, and a failed resize leaves the window and scene contract untouched.

# Follow-ups

- Feature-specific E2E procedures that assert responsive layout should set the width with this command instead of stating a fixed window size as a precondition.
