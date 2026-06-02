# Startup Database Side Effects Step 2

Date: 2026-06-02

Human-owned document:

- `docs/human/requirements/20260602-Bug-App Startup Database Side Effects.md`

## Request

Remove ordinary App startup database side effects so startup keeps the database
available without running indexing-like maintenance, derived-index rebuilds,
storage statistics queries, or cache-clearing work.

## Baseline

- `swift test` passed before implementation: 7 XCTest tests and 169 Swift
  Testing tests.
- Added `appStartupDoesNotRunDatabaseMaintenanceWhenIdle` as a failing
  regression test before changing the startup implementation. It failed because
  `AppCoordinator` created `startupDatabaseTask` during initialization.

## Implementation

- Removed the ordinary startup `reconcileIndexedContent(activeFolders:)` and
  `storageStats()` background task from `AppCoordinator`.
- Removed startup-time AI chunk cache clearing from `AppCoordinator`
  initialization so opening the App does not perform that extra database write.
- Added a startup regression test that verifies indexed search data and AI
  chunk cache data remain available immediately after App startup and that no
  startup database maintenance task or storage stats load is scheduled.

## Verification

- `swift test --filter appStartupDoesNotRunDatabaseMaintenanceWhenIdle` passed
  after the implementation.
- Targeted regression coverage passed for startup, explicit reconcile behavior,
  missing search-order-row failure behavior, AI cache helper behavior, and
  playback navigation resume behavior.
- Full `swift test` passed after implementation: 7 XCTest tests and 170 Swift
  Testing tests.

## Outcome

Ordinary App startup no longer schedules database reconcile, derived search
index rebuild, storage stats loading, or AI cache clearing. Explicit database
maintenance and indexing paths remain covered by existing tests.
