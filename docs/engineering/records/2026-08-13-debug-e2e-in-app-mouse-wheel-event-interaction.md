# Requirement

- `docs/human/requirements/20260813-Engineering-Debug End-to-End In-App Mouse Wheel Event Interaction.md`

# Scope

- Add one coordinate-targeted vertical mouse-wheel command to the Debug in-app E2E controller.
- Preserve complete-scene coordinates, frontmost-window routing, stale-scene protection, and Release isolation.
- Document the command for future automated UI procedures.

# Steps

- Added `scroll` parsing for complete-scene `x`, `y`, nonzero integer `deltaY`, and `sceneID` fields.
- Built one non-precise AppKit scroll-wheel event from a window-bound event and posted it through CueSeeker's application event queue.
- Rejected stale scenes, invalid coordinates, zero deltas, missing target windows, and event-construction failures before posting.
- Added focused coverage for parsing, validation, frontmost-window routing, and both vertical directions.
- Updated the end-to-end testing rules and changelog with the supported command and its discrete-wheel boundaries.

# Verification

- `swift test --filter DebugE2EControllerTests` passes all 7 tests.
- A plain parallel `swift test` run completed 991 tests with 25 issues; the new scroll test passed, while failures occurred in other suites and one scene test was affected by concurrently visible test windows.
- `swift test --no-parallel --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` completed 990 tests with 2 issues in `showCueGroupInvalidationIsScopedToMountedShiori` and `shioriTableStartsAtTopAfterPanelRemount`; the Debug E2E suite passed.
- `swift build -c release --product CueSeeker` passes. A Release executable string scan finds no Debug E2E launch flag, scroll parser error, scroll dispatcher, or scroll validation marker.
- A real Debug E2E run clicked Shiori and then `列表 5`. Four fresh-scene scroll commands at `(800, 700)` with `deltaY: -12` moved the visible rows from row 1 to a partially visible row 3 and first fully visible row 4, with the scrollbar moving down.
- A fresh-scene command at the same coordinate with `deltaY: 48` restored row 1 and the scrollbar to the top.

# Outcome

- Known-coordinate Debug E2E flows can now exercise vertical scrolling in either direction through CueSeeker's normal AppKit path without moving the pointer, posting global events, requesting input permissions, or mutating product state directly.

# Follow-ups

- The two unrelated full-suite refresh timing failures require a separate requirement if they are to be investigated.
