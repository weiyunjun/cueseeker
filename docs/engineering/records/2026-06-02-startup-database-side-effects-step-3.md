# Startup Database Side Effects Step 3

Date: 2026-06-02

Human-owned document:

- `docs/human/requirements/20260602-Bug-App Startup Database Side Effects.md`

## Request

Confirm that removing ordinary startup database maintenance did not remove the
explicit indexing responsibility for rebuilding searchable data, derived search
order, Library presentation state, and database statistics after user-triggered
indexing.

## Baseline

- Targeted pre-change coverage passed for startup, indexing, reindexing,
  explicit reconcile behavior, folder removal, Library presentation snapshots,
  missing search-order-row failure behavior, and product-ordered visible search.

## Implementation

- Added an App-level regression test for explicit `indexFolder` flow. The test
  starts the App without startup maintenance, explicitly indexes a folder, then
  verifies visible Search results, Library presentation rows, and storage stats
  are available after the explicit indexing task completes.
- Stabilized the settings test helper by initializing `NSApplication.shared`
  on the main actor before constructing `SettingsStore`, matching AppKit's
  expectation for appearance updates during tests.
- No production code changed in this step.

## Verification

- The new App-level startup/indexing regression tests passed.
- Targeted third-step coverage passed with 11 Swift Testing tests.
- The first full `swift test` run exposed the existing test helper's missing
  AppKit initialization; after the helper fix, full `swift test` passed with 7
  XCTest tests and 171 Swift Testing tests.

## Outcome

Explicit indexing remains the path that prepares Search and Library data. App
startup stays free of database maintenance work, and the test suite now covers
both sides of that boundary.
