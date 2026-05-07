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
- Friendly Search result group title derivation from parent folder name and
  same-extension sibling subtitle rank.
- Finder-like natural filename ordering for friendly Search result group titles,
  including numeric cases such as `aa2.ass` before `aa11.ass`.
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
- Pure Japanese kana search behavior, including hiragana, katakana, and
  halfwidth katakana queries.
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
- The `Q` shortcut copies the current subtitle without interfering with editable
  text input.
- The copy-current-subtitle button copies the same text as the `Q` shortcut.
- Mouse or click activity reveals fullscreen controls and cursor and restarts the inactivity timer.
- Selecting a search result, clicking app-owned feature buttons, selecting
  another sidebar section, or clicking the Playback Area clears Search field
  focus.
- Cmd-Tab away and back, titlebar double-click resize, native traffic-light clicks, and foreground/background transitions do not intentionally clear Search field focus.
- The speed menu has no separate show or hide animation.
- The speed button hover area, speed button click area, and speed menu width are aligned.
- The speed menu remains visible only while the pointer is inside the documented rectangular hover region spanning the menu and speed button.
- The leftmost app sidebar still shows and switches `Search` and `Settings`
  independently from the Search workspace pane layout.
- The Search workspace places playback on the left and Search controls/results
  on the right.
- Collapsing the right-side Search Panel expands playback width, preserves the
  selected result, and does not pause playback.
- Reopening the Search Panel restores the current Search context when practical.

Rules:

- Frame-perfect seek accuracy is not required for M1.
- Seek must be close enough for subtitle context review.
- Playback memory and performance measurements must run outside the execution
  sandbox because sandboxed runs can distort process memory observations.
  Sandboxed memory samples must not be used as authoritative playback evidence.
- Software playback memory mitigation must be verified with unsandboxed
  physical-footprint and RSS samples at roughly 50 ms resolution, click-to-first
  target-frame timing, click-to-stable-playback timing, seek preroll behavior,
  and a manual check for visible frame jumps or audible restarts.
- A software playback memory fix is not acceptable if it materially increases
  click-to-first-frame latency, reduces decoder parallelism as its primary
  strategy, or masks the issue only by changing the measurement method.
- Playback read-ahead changes must be checked against local files, mounted NAS
  paths, and representative network-jitter conditions using the same playback
  policy. Verification should confirm that audio, video, and subtitles pause as
  a unit when reads stall, rather than allowing audio to run ahead.
- Playback read-ahead verification should record startup latency, queued packet
  cap behavior, seek/session replacement cleanup, and whether rebuffer events
  become fewer or shorter under network read pressure.
- ASS subtitle rendering memory work must be judged primarily through
  end-to-end playback acceptance, not isolated renderer probes alone. The core
  acceptance question is whether the user-visible memory drop is meaningful
  while playback, seeking, subtitle visibility toggling, and Theater Mode remain
  stable.
- ASS renderer measurements should compare the same video across no subtitles,
  SRT subtitles, simple ASS subtitles, and complex ASS subtitles. Useful
  observation points include process memory after open, after steady playback,
  after repeated seeks, after subtitle hide/show toggles, after fullscreen
  transitions, and after closing playback.
- Complex ASS segmentation acceptance should record private resident memory
  before the dense effect section, at peak playback, and after leaving the dense
  section for at least two minutes. Private resident memory is the primary
  process-owned metric; real resident memory is useful context but includes
  shared framework, font, video, and graphics pages.
- Numeric memory samples are supporting evidence for ASS renderer changes, but
  they do not replace perceptual acceptance. A change should not be accepted if
  memory appears lower only in a narrow sample while visible playback behavior,
  subtitle fidelity, responsiveness, or lifecycle stability regresses.
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
- Valid `.ass`.
- ASS file with multiple `Dialogue` events sharing exact timing.
- ASS file with near-equal `Dialogue` timings that must not be grouped.
- ASS file with `Comment` events that must not be indexed.
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

## 14. M2 ASS Subtitle Test Coverage

The first M2 ASS implementation is complete only after ASS indexing, grouped
search results, and click-to-playback behavior are verified.

Current verification:

- The Swift test suite passed with 43 tests using
  `swift test --package-path apps/macos-native` after the first ASS
  implementation.

Required parser coverage:

- ASS `[Events]` `Format:` field mapping.
- `Dialogue` event parsing with non-default field order.
- `Comment` events excluded from searchable subtitles.
- Override-tag removal for documented `{...}` cases.
- ASS line-break normalization for documented `\N` cases.
- Exact-time cue grouping by subtitle file, `start_ms`, and `end_ms`.
- Near-equal ASS timestamps not grouped by tolerance.
- Cue lines preserved without deduplication.
- Stable display-order fallback to source event order when layout projection is
  unavailable.

Required database and search coverage:

- Fresh schema creation for cue groups and cue lines.
- Migration from the previous supported schema version.
- Migration preserves durable configuration and rebuilds derived subtitle index
  data.
- FTS rows link to cue groups.
- Search returns cue groups, not individual ASS cue lines.
- A query that matches one cue line returns the full cue group.
- Query terms split only across different cue lines do not produce a result.
- Search results remain scoped to currently selected folders.

Required integration coverage:

- Index a fixture folder containing `.srt` and `.ass` files.
- Match language-suffix ASS files such as `Movie.scjp.ass` to `Movie.mp4`.
- Reindex after an ASS file changes and rebuild its cue groups and cue lines.
- Remove a configured folder and verify ASS-derived rows no longer appear in
  search results.
- Select an ASS search result and resolve it to matched video path plus
  `start_ms`.

Playback verification for the first ASS step:

- Clicking an ASS search result opens or updates the Playback Area.
- Playback opens the matched video and seeks to the cue group's `start_ms`.
- Source ASS subtitle rendering is not required for this first ASS step.

## 15. ASS Renderer Routing Coverage

CueSeeker currently supports a single active ASS playback renderer: the
`libass`-backed source-faithful overlay.

Required routing coverage:

- ASS search results load the source `.ass` file, or the matching
  source-derived render segment, for playback rendering.
- Playback attaches `SourceFaithfulASSSubtitleOverlayView` for ASS subtitle
  sources.
- Playback does not attach native ASS or ASS Lite fallback overlays.
- Settings does not expose an ASS renderer selector.
- The existing subtitle visibility control shows and hides the `libass` overlay.
- The overlay follows both the Playback Area and Theater Mode fullscreen.
- Missing or unreadable subtitle files do not prevent video playback.
- SRT playback subtitle behavior does not regress.

Known deferred behavior should remain documented when tests cover graceful
degradation cases.

## 16. Source-faithful ASS Rendering Pipeline Coverage

The source-faithful ASS rendering pipeline is complete only after search,
playback startup, render preparation, and complex ASS rendering behavior are
verified separately.

CueSeeker currently has one active ASS playback renderer: the `libass`-backed
source-faithful overlay. Tests should verify that ASS playback routes to this
overlay only, Settings does not expose an ASS renderer picker, and native ASS or
ASS Lite fallback renderers are not reachable from the active playback path.

Required `libass` manual checks:

- Common ASS dialogue appears correctly enough for subtitle-context review.
- Complex ASS samples with vector drawing, clipping, karaoke, transforms, and
  short-duration events render through the source `.ass` file or a
  source-derived render segment.
- Font behavior is compared against reference players for real samples that
  rely on embedded, adjacent, or system fonts.
- Font behavior is compared against reference players for real samples that
  rely on matched-video font attachments. The test sample should include at
  least one ASS subtitle whose named font exists only as a video container
  attachment so fallback-font regressions are visible.
- Font behavior is compared against reference players for real samples that
  rely on adjacent external font folders, such as a sibling `Fonts` directory.
  The check must verify the playback path, not only the isolated ASS rendering
  probe.
- Subtitle output maps to the displayed video rectangle.
- Playback, seek, subtitle visibility toggling, Playback Area, and Theater
  Mode remain stable.
- Search result selection and video open or seek do not wait for ASS renderer
  loading or rendering.

Required search projection coverage:

- Real dialogue and lyric text remains searchable.
- Vector drawing path commands such as `m ... b ...` are not returned as search
  result text.
- Repeated visual-effect fragments do not create duplicate user-facing search
  results unless they contain distinct readable subtitle text.
- Cue group timing remains stable and can be used as the playback seek target.

Required render timeline coverage:

- Timed `Dialogue` events are preserved for playback rendering even when they
  use `Effect=fx`.
- `\p` vector drawing events remain in the render timeline.
- `\clip`, `\iclip`, `\pos`, `\move`, blur, alpha, border, scale, and karaoke
  metadata remain available to the renderer.
- Short-duration and zero-duration events do not corrupt timeline indexing or
  cancellation behavior.
- Cache invalidation uses source subtitle path, file size, modified time, and
  renderer version.
- Time-windowed preparation uses indexed cue-group timing to choose the selected
  cue window and nearby deterministic windows while still retrieving exact
  render payload from the source `.ass` file.
- Partial timeline caches are keyed by both source file identity and prepared
  time window, and they invalidate when the source subtitle file changes.
- Large ASS render-segment caches must be verified at the indexing and playback
  boundary: indexing stores segment scripts, unchanged reindex skips only when
  those segments exist, and legacy `libass` can load the segment from memory for
  the current timestamp.
- Font-resource plumbing must be verified for both full-source ASS loading and
  indexed render-segment loading. A render segment must receive the same
  renderer font directory or extracted attachment cache as the full-source path.
- Playback subtitle source tests must verify that ASS playback can carry matched
  video identity and renderer font resource context without reintroducing an ASS
  renderer picker or native ASS fallback route.
- Legacy `libass` unchanged-frame reuse must be tested with a static ASS sample:
  the first cropped render should produce a visible payload, and a subsequent
  unchanged timestamp in the same static interval should return no cropped
  payload so the playback overlay can reuse the existing layer contents.
- Complexity-aware ASS segmentation tests must cover the 256 KB activation
  threshold, low-complexity widening, and dense effect regions shrinking to
  shorter windows without dropping overlapping source events.
- Regression checks for the segmenter should include a real complex ASS sample
  with a dense effect section followed by ordinary dialogue, verifying that the
  indexed windows shrink only around the dense section and widen again after it.
- ASS render-segment cache migration tests must verify that older segmentation
  algorithm versions are ignored for unchanged source files and rebuilt on the
  next indexing pass.

Required non-blocking playback checks:

- Selecting a large ASS search result updates the selected row before ASS source
  parsing finishes.
- Opening or seeking video does not wait for ASS parsing or renderer
  initialization.
- Stale ASS preparation tasks are cancelled when another result is selected.
- Subtitle rendering can attach later and catch up to the current playback time.
- ASS rendering failure does not stop video playback or playback controls.

Required renderer checks:

- Leading `\fs`, `\fscx`, and `\fscy` size overrides affect ordinary dialogue
  sizing in native `v0`.
- Complex ASS fixtures with vector drawing, clipping, and karaoke-like repeated
  effect events render without treating drawing commands as text.
- Playback Area and Theater Mode fullscreen use the same renderer output
  lifecycle.
- Subtitle visibility toggles renderer output without stopping the video.
- SRT playback subtitle behavior does not regress.
