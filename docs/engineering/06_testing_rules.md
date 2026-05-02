# Testing Rules

Status: Draft

## 1. Purpose

This document defines testing expectations for the native macOS rewrite of CueSeeker.

It describes what must be verified before a milestone is considered complete. It does not define implementation code.

## 2. Testing Principles

Testing should focus on the local subtitle search and playback workflow.

Principles:

- Test pure logic directly where possible.
- Test database behavior with real SQLite and FTS5.
- Test macOS integration points with focused integration or manual checks.
- Keep fixture data small, explicit, and version controlled when practical.
- Do not depend on the user's personal subtitle library for automated tests.
- Each milestone must have acceptance checks tied to product requirements.

## 3. Required M1 Test Coverage

M1 is not complete until the minimal local loop is verified.

Required coverage areas:

- Local folder selection and stored folder configuration.
- Recursive `.srt` scanning.
- SRT parsing.
- Same-directory video matching.
- SQLite schema creation.
- FTS5 indexing and search.
- Incremental reindexing behavior.
- Stale entry removal.
- Search result selection.
- Local playback open and timestamp seek behavior.
- User-visible error handling for missing files and unreadable inputs.

Not every area must be automated in M1, but manual checks must be documented when automation is impractical.

## 4. Unit Tests

Unit tests should cover deterministic logic without relying on macOS UI.

Required unit test areas:

- SRT block parsing.
- Multi-line subtitle text parsing.
- Timestamp parsing and millisecond conversion.
- Malformed subtitle block handling.
- Subtitle file extension filtering.
- Video basename matching.
- Simple language suffix removal.
- Search query normalization or validation, if implemented outside the database layer.

Rules:

- Unit tests must not require access to the user's real subtitle folders.
- Unit tests should use small inline or fixture-based examples.
- Parser tests must include both valid and malformed input.
- Timestamp tests must include boundary-like cases such as zero time and hour-level timestamps.

## 5. Database Tests

Database behavior must be tested with SQLite, not mocked as plain in-memory collections.

Required database test areas:

- Fresh schema creation.
- Schema version value.
- Migration from each supported previous schema version.
- Insert and replace subtitle entries for a source file.
- Delete stale subtitle entries.
- FTS5 insert, update, delete, and search consistency.
- Empty query behavior.
- Invalid query behavior.
- Result limits and predictable ordering.
- CJK search behavior at least matching the archived Flutter implementation's practical behavior.
- Search scoped to the currently selected folders.
- Startup reconciliation that removes or excludes index rows outside the
  currently selected folders.
- Clearing derived index data when no folders are selected.

Rules:

- Tests must use isolated test databases.
- Tests must not mutate a production user database.
- Tests should verify durable user state separately from rebuildable index state.
- Migration tests must fail if a fresh schema and migrated schema diverge unexpectedly.

## 6. Integration Tests

Integration tests should verify the main local data flow across modules.

Required M1 integration scenarios:

- Index a fixture folder containing valid `.srt` files and matching videos.
- Index a fixture folder with unreadable or malformed subtitle content and continue processing valid files.
- Reindex after a subtitle file changes.
- Reindex after a subtitle file is removed.
- Search indexed content and resolve a result to video path plus `start_ms`.
- Handle a search result whose matched video no longer exists.
- Remove a configured folder and verify its indexed subtitle rows no longer
  appear in search results.
- Start with stale indexed rows from a previously removed folder and verify they
  are reconciled or excluded from search.

Rules:

- Integration tests should use fixture directories, not personal media libraries.
- Fixture video files may be tiny placeholder media files if playback tests do not inspect actual decoding.
- Tests that require real media decoding may be separated from fast default tests.

## 7. UI Smoke Tests

The native UI must have smoke coverage before milestone completion.

Required M1 smoke checks:

- App launches.
- First-launch or no-folder state is visible.
- A folder can be added through the intended UI path.
- Indexing status is visible during or after indexing.
- Search input accepts text.
- Search results render without layout breakage.
- Selecting a result updates selection state.
- Playback area opens or reports a clear error.

Rules:

- UI smoke tests may be automated or manually documented during early development.
- Text input shortcuts must continue to behave like native macOS text fields.
- Keyboard shortcuts must be checked for conflicts before being considered complete.

## 8. Playback Verification

Playback requires both automated-adjacent verification and manual acceptance.

Required M1 playback checks:

- A matched local video can be opened.
- Playback can seek to `start_ms`.
- Play and pause controls work.
- Manual seek controls work.
- Missing video files produce a clear error.
- Selecting another result for the same open video seeks instead of unnecessarily reopening when practical.

Required M2 playback interaction checks:

- Playback fullscreen affects only the video experience and does not put the main app window into macOS Full Screen.
- Cmd-Tab and other system overlays remain visible above the Theater Mode window.
- Theater Mode hides when the app resigns active and restores when the app becomes active again.
- Fullscreen keyboard shortcuts execute playback commands without revealing the playback operation controls.
- Mouse or click activity reveals fullscreen controls and cursor and restarts the inactivity timer.
- Selecting a search result, clicking app-owned feature buttons, selecting another sidebar section, or clicking the Playback Inspector clears Search field focus.
- Cmd-Tab away and back, titlebar double-click resize, native traffic-light clicks, and foreground/background transitions do not intentionally clear Search field focus.
- The speed menu has no separate show or hide animation.
- The speed button hover area, speed button click area, and speed menu width are aligned.
- The speed menu remains visible only while the pointer is inside the documented rectangular hover region spanning the menu and speed button.

Rules:

- Frame-perfect seek accuracy is not required for M1.
- Seek must be close enough for subtitle context review.
- Playback memory and performance measurements must run outside the execution
  sandbox because sandboxed runs can distort process memory observations.
  Sandboxed memory samples must not be used as authoritative playback evidence.
- Playback engine-specific behavior must be documented after the engine is selected.
- Final playback engine verification criteria must be updated after the playback ADR is accepted.

## 9. File Access and Sandboxing Tests

Local folder access must be verified explicitly.

Required checks:

- Selected folders can be scanned.
- Removed folders are no longer indexed on refresh.
- Removed folders no longer contribute search results.
- Permission loss or unreadable folders are reported clearly.
- If sandboxing is enabled, folder access persists across app restart through the documented mechanism.
- If sandboxing is disabled for early personal use, that assumption is documented before packaging.

## 10. Test Fixtures

Fixture data should be small and intentional.

Required fixture categories:

- Valid English `.srt`.
- Valid CJK `.srt`.
- Multi-line subtitle entries.
- Missing sequence numbers if supported by parser behavior.
- Malformed blocks.
- Same-basename video match.
- Language-suffix subtitle match, such as `Movie.en.srt` to `Movie.mp4`.
- Subtitle file with no matching video.

Rules:

- Fixture files should avoid copyrighted media or large binary assets.
- Placeholder or generated media should be used when possible.
- Fixture names should make the tested condition obvious.

## 11. Manual Acceptance Checks

Each milestone must have a short manual acceptance checklist.

M1 manual checklist:

```text
Launch native macOS app
Add a local subtitle folder
Run indexing
Search for known subtitle text
Confirm result text, video name, and timestamp are shown
Click a result
Confirm local video opens
Confirm playback starts near the subtitle start time
Remove the configured folder
Confirm the same subtitle text no longer appears in Search
Confirm missing or unreadable files show clear errors
Restart app and confirm configured folder state is preserved if persistence is implemented
```

Rules:

- Manual checks must be updated when the product workflow changes.
- Manual checks should not replace deterministic automated tests for parser, database, and search behavior.

## 12. Regression Policy

Bug fixes should add tests when the bug is deterministic and testable.

Rules:

- Parser bugs should add parser tests.
- Database bugs should add migration or query tests.
- Search ranking or query bugs should add search fixtures.
- Playback bugs should add the closest practical automated check plus a manual verification note if needed.
- UI regressions should add smoke coverage where the native test setup allows it.

## 13. Milestone Completion Rule

A milestone is not complete until:

- Required product acceptance criteria are checked.
- Relevant automated tests pass.
- Known manual-only checks are documented.
- Test gaps are listed explicitly.
- Database migrations, if any, have fresh-create and migrate-path verification.
- Playback behavior, if included in the milestone, has been verified against the selected playback strategy.
