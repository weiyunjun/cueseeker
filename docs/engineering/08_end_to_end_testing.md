# End-to-End Testing

Status: Draft

## 1. Purpose

This document records end-to-end test procedures that are too runtime-specific
for unit tests or integration tests.

Every end-to-end test used to validate a UI, playback, macOS integration, or
performance-sensitive change must document:

- The exact feature or regression under test.
- The build and launch method.
- The diagnostic flags and log commands.
- The user actions to perform.
- The evidence the user should paste back to the assistant.
- The concrete pass/fail criteria.

End-to-end testing should not rely on vague observation. If the assistant needs
logs, counters, screenshots, or a sample file, the test procedure must say so
before the user starts testing.

## 2. Log Handoff Protocol

Use this protocol whenever the assistant needs the user to run a manual
end-to-end test and paste evidence back.

Rules:

- The assistant must name the repository directory and the exact terminal
  commands before asking the user to reproduce a behavior.
- Use a dedicated log terminal before launching the app when runtime logs are
  needed.
- Prefer narrow log predicates. Broad `log stream` output is too noisy for
  assistant analysis.
- Each test run should have a visible start marker in the user's pasted logs,
  either from a documented log message or from the timestamp at which the user
  starts the first action.
- The user should paste the full log block from the start marker through at
  least two seconds after the last tested action.
- If no logs are expected, "no matching output" is valid evidence and should be
  stated as an expected result.
- If a test creates files such as automatic `sample` captures, the document must
  state the expected directory and whether the user should paste the path or the
  file contents.

Default perf log stream:

```bash
/usr/bin/log stream --style compact --predicate 'subsystem == "com.cueseeker.perf"'
```

Normal non-diagnostic app runs should not emit `com.cueseeker.perf` logs.

## 3. UI Invalidation Domain Split

### Goal

Continue splitting UI invalidation domains so Library, Playback, Search, and
future panel modes refresh only the state they render.

This test validates that:

- Search input does not rebuild Library presentation rows.
- Playback time updates do not refresh Library or Search result lists.
- Library disclosure changes do not rebuild Search results or playback render
  state.
- Search result selection updates Playback and Search selection state without
  rebuilding Library rows.
- Side-panel visibility changes update workbench layout without destroying
  panel content state.

### Required Instrumentation

This test uses the default-off UI invalidation counter. Enable it only through
an explicit diagnostic launch flag:

```bash
CUESEEKER_PERF_UI=1
```

or:

```bash
--cueseeker-perf-ui
```

The counter emits narrow `com.cueseeker.perf` logs for UI refresh and expensive
model rebuild events. Current event names:

- `MARK UIInvalidationProbe.enabled`
- `ACTION UI.LibraryPanel.toggled`
- `ACTION UI.SearchPanel.toggled`
- `ACTION UI.LibraryVideo.opened`
- `ACTION UI.SearchQuery.changed`
- `ACTION UI.LibraryFolder.toggled`
- `ACTION UI.SearchResultGroup.toggled`
- `ACTION UI.SearchResults.collapseAll`
- `ACTION UI.SearchResult.opened`
- `UI.ContentView.body`
- `UI.AppTopBar.body`
- `UI.Workbench.body`
- `UI.LibraryPanel.body`
- `UI.LibraryRows.rendered`
- `UI.LibraryPresentationSnapshot.rebuilt`
- `UI.PlaybackArea.body`
- `UI.PlaybackRenderContainer.created`
- `UI.PlaybackTime.published`
- `UI.SearchPanel.body`
- `UI.SearchRows.rendered`
- `UI.SearchPresentation.rebuilt`

The exact implementation may differ, but the log must make it possible to
compare counter deltas before and after each user action.

If `MARK UIInvalidationProbe.enabled` is not visible within three seconds after
launch, the test environment is invalid. Stop immediately and relaunch with
`CUESEEKER_PERF_UI=1` or `--cueseeker-perf-ui`; do not continue with a
log-free manual test.

Heavy probes are not required for this test. Do not enable automatic
`/usr/bin/sample` capture unless a new stall regression appears.

### Launch

Terminal A, log stream:

```bash
/usr/bin/log stream --style compact --predicate 'subsystem == "com.cueseeker.perf"'
```

Terminal B, launch the app with only UI invalidation counters enabled:

```bash
cd /Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native
CUESEEKER_PERF_UI=1 swift run CueSeeker
```

Equivalent launch-argument form:

```bash
cd /Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native
swift run CueSeeker --cueseeker-perf-ui
```

If the app is launched normally without diagnostic flags, Terminal A should
produce no matching output. That verifies heavy diagnostics remain default-off,
but it does not prove invalidation-domain isolation.

Expected startup evidence:

```text
MARK UIInvalidationProbe.enabled pid=<pid>
COUNT UI.ContentView.body ...
```

### Preconditions

Use a real indexed Library with enough data to expose row rebuilds:

- At least 10 Library folders.
- At least one expanded Library folder with multiple videos.
- At least one playable video with subtitles.
- At least one Search query with visible grouped results.

The user's personal media library is acceptable for this manual end-to-end
check. Automated tests must still use fixtures.

### Actions

Perform these actions in order. After each action, wait about two seconds so
queued UI updates and log lines can settle.

1. Start playback from Library.
2. Let playback run idle for 30 seconds.
3. Focus Search, type a short query that returns results, and press Return.
4. Verify Search results are expanded by default for the new query.
5. Click `Collapse All` in Search and verify all current result groups collapse.
6. Modify the query, press Return, and verify the new Search results are
   expanded by default.
7. Expand and collapse one Library folder.
8. Click an episode button inside an expanded Library folder.
9. Click a Search result for the currently indexed Library.
10. Toggle the Right Learning Panel closed and open.
11. Toggle the left Library Panel closed and open.
12. Drag the playback progress bar or use a seek shortcut.
13. Resize the left and right panels and verify the titlebar controls stay
    visually aligned with the corresponding panel regions.
14. Click the right titlebar Search icon and Shiori icon, verifying Search shows
    the current Search panel and Shiori shows the current Shiori panel or empty
    Shiori state.

### Evidence to Paste Back

Paste the log block from app launch through two seconds after the final action.
The pasted block must include `MARK UIInvalidationProbe.enabled` and the
`ACTION UI...` marker for each manual action being evaluated.

If the log is too large, paste one block per action with the action name written
above it, for example:

```text
ACTION 3: Search query input
<log lines>
```

Also state whether any visible user-facing issue occurred:

- Rainbow cursor.
- Delayed click response.
- Lost Library scroll position.
- Lost Search result state.
- Playback pause, restart, or visible seek delay.
- Search result click not immediately loading the intended subtitle source.
- Missing or incorrect Search summary text.
- Missing Search default-expanded result groups after a new query.
- Any `Expand All` action appearing in Search or any Library-wide
  `Collapse All` / `Expand All` action appearing in Library.
- Titlebar mode icons not tracking the resized side-panel widths.
- Right titlebar Search or Shiori mode switching resetting playback or Search
  state unexpectedly.

### Acceptance Criteria

The UI invalidation split passes only if the logs and manual behavior satisfy
these criteria:

- The log contains `MARK UIInvalidationProbe.enabled` within three seconds of
  launch. Without this marker, the run is not a valid test.
- Every evaluated user action has a corresponding `ACTION UI...` marker before
  the counter deltas being judged.
- During 30 seconds of idle playback, `UI.PlaybackTime.published` may increase,
  but `UI.LibraryPresentationSnapshot.rebuilt`,
  `UI.SearchPresentation.rebuilt`, and `UI.PlaybackRenderContainer.created`
  must not increase.
- During Search query input before Return, Search counters must not increase,
  Library presentation snapshot rebuilds must remain `0`, and the playback
  render container must not be recreated.
- After Return commits a Search query, Search counters may increase, but
  Library presentation snapshot rebuilds must remain `0`, and the playback
  render container must not be recreated.
- New Search results must be expanded by default. The Search panel may expose a
  fixed `Collapse All` command for the current result set, but must not retain a
  global collapsed mode across a new query.
- The Search summary must read `Found <count> results in <count> files` and
  must not expose rendered-row counts.
- Library must not expose a panel-wide `Collapse All` or `Expand All` command;
  Library folder disclosure remains per-folder.
- The left titlebar mode region must show the Library folder icon when the
  Library panel is expanded. The right titlebar mode region must show Search
  and Shiori icons when the right panel is expanded. Search displays the
  existing Search panel, and Shiori displays the current Shiori panel or empty
  Shiori state.
- Titlebar mode icons and side-panel collapse toggles must remain visually
  aligned with the current side-panel width during manual divider resize and
  side-panel collapse or expand animation.
- Titlebar mode icons must not fade during side-panel collapse or expand. They
  should disappear or appear by clipping as the titlebar drawer strip is pushed
  in or out, and the titlebar animation must finish with the side-panel body
  animation.
- Switching right-panel modes must not reset playback, the active Search query,
  loaded Search results, or Library disclosure state.
- During Library folder expand or collapse, Library panel counters may increase,
  but Search presentation rebuilds and playback render container creation must
  remain `0`.
- Clicking a Library episode button or Search result row may update selection
  and Playback state, but must not rebuild unrelated presentation rows.
- Dense Library/Search rows and group headers should use lightweight row tap
  handling rather than SwiftUI `Button` wrappers. Top-level command buttons may
  remain buttons.
- Side-panel toggle actions may refresh the workbench layout, but must preserve
  Library collapse state, Search result state, scroll position where practical,
  and the playback render container.
- There must be no `MainThread.stall`, no automatic sample capture, and no
  rainbow cursor during the test.
- Search result click-to-playback must still feel immediate. A state split is
  not acceptable if it delays subtitle source loading or video seek behavior.

### Failure Handling

If the test fails, the assistant should first identify which action caused the
unexpected counter increase or visible regression. Do not continue broad UI
refactors until the failing invalidation path is understood.

If the failure is a visible stall, rerun a narrow diagnostic test with:

```bash
CUESEEKER_PERF_WATCHDOG=1 CUESEEKER_PERF_RUNLOOP=1
```

Enable `CUESEEKER_PERF_AUTOSAMPLE=1` only when the stall is long enough to need
a process sample and the user has agreed to capture one.

### Cleanup

After the invalidation-domain work is accepted:

- Keep lightweight counters only if they remain default-off and useful.
- Remove or gate any temporary probes added for the investigation.
- Update this document if the accepted event names or pass/fail thresholds
  change.

## 4. Search Result Sequence Playback

### Goal

Validate the committed Search interaction and Search-result sequence playback
flow.

This test validates that:

- Search runs only when Return commits the Search field draft.
- Escape restores uncommitted Search field edits to the current committed query.
- Clicking a Search result plays that result as a bounded subtitle review
  moment.
- One-second fade transitions continue the underlying video while picture fades
  to black and audio fades to silence.
- Same-subtitle-filename overlap continuity skips the fade only when the
  configured subtitle-count window reaches the cue immediately before the next
  result and that cue's end timestamp `b` satisfies `0ms <= b - c <= 1000ms`.
- Committing a new query during active sequence playback invalidates automatic
  advancement after the current result fades out.
- The Autoplay Settings switches control whether Search and Shiori result
  playback advances after the current cue fades out.
- The Autoplay subtitle-count fields control how many subtitle cues are included
  in each Search or Shiori playback window, default to `3`, clamp to `1...999`,
  and are disabled when the corresponding autoplay switch is off.

### Required Instrumentation

No diagnostic flag is required for the first acceptance run. The test is
primarily visual and auditory.

If runtime logs are needed while debugging, use the default performance log
stream and launch with:

```bash
CUESEEKER_PERF_UI=1 CUESEEKER_PERF_PLAYBACK=1
```

Normal runs without diagnostic flags should not emit `com.cueseeker.perf` logs.

### Launch

Terminal A, optional log stream:

```bash
/usr/bin/log stream --style compact --predicate 'subsystem == "com.cueseeker.perf"'
```

Terminal B, normal launch:

```bash
cd /Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native
swift run CueSeeker
```

Diagnostic launch, only if requested:

```bash
cd /Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native
CUESEEKER_PERF_UI=1 CUESEEKER_PERF_PLAYBACK=1 swift run CueSeeker
```

### Preconditions

Use an indexed Library with playable local videos and at least one query that
returns multiple results in the same subtitle file.

For full coverage, choose or create result pairs with:

- A normal non-continuous pair where the next result does not satisfy
  `0ms <= b - c <= 1000ms`.
- A same-subtitle-filename pair satisfying `0ms <= b - c <= 1000ms`.
- A same-subtitle-filename pair where the next result is reached only because the
  autoplay subtitle count includes intervening subtitle cues.
- A query whose last result is near the end of its video, when available.
- At least two Shiori rows in the visible Shiori panel.

The user's personal media library is acceptable for this manual end-to-end
check. Automated tests must still use fixtures.

### Actions

Perform these actions in order.

1. Focus Search and type a query. Verify that results do not change before
   Return.
2. Press Escape. Verify the field restores to the current committed query.
3. Type the query again and press Return. Verify results appear and the summary
   reflects the committed query.
4. Click a result with a non-continuous next result. Verify playback starts at
   the clicked result, the row is selected, and playback does not continue past
   the selected cue except for the one-second fade.
5. Watch the transition. Verify the video continues underneath while the picture
   fades to black and audio fades to silence, then the next result becomes
   selected and starts playback.
6. Click or wait into a same-subtitle-filename pair where the configured
   subtitle-count window reaches the cue immediately before the next result and
   satisfies `0ms <= b - c <= 1000ms`. Verify there is no black fade, playback
   remains continuous, and selection switches when playback reaches `c`.
7. Start another sequence, edit the Search field, and do not press Return.
   Verify the current playback sequence continues normally.
8. While a result is playing, commit a different query with Return. Verify the
   current result finishes and fades to black, then playback stays black and
   silent instead of advancing.
9. If a near-end-of-video result is available, play it and verify the
   one-second fade completes even when less than one second of media remains
   after the cue end.
10. Open Settings, choose `Autoplay`, disable `Search result autoplay`, and
    click a Search result. Verify the selected cue plays and fades out, then
    remains black and silent without advancing.
11. Enable `Search result autoplay` again, set its subtitle count to `3`, and
    verify Search result advancement resumes with the clicked cue plus up to two
    following cues.
12. Disable `Shiori result autoplay`, click a Shiori row, and verify the saved
    cue plays and fades out without advancing.
13. Enable `Shiori result autoplay`, set its subtitle count to `3`, click the
    same Shiori row, and verify playback advances to the next visible Shiori row
    after the configured subtitle window and fade-out.

### Evidence to Paste Back

Paste a short note with:

- The committed query used for the sequence.
- Whether Return-only Search and Escape restore passed.
- The observed non-continuous transition behavior.
- The observed same-subtitle-filename continuity behavior, including the two
  timing windows when practical.
- Whether committing a new query stopped advancement after fade-out.
- Whether both Autoplay switches changed advancement behavior without changing
  the clicked cue's bounded playback and fade-out.
- Whether the subtitle-count fields affected Search and Shiori playback windows
  and were disabled while autoplay was off.
- Any visible or audible mismatch, delayed seek, missing black frame, selection
  mismatch, or unexpected continuation.

If diagnostic logs were requested, paste the log block from app launch through
two seconds after the last tested action. If no matching output appears during a
normal run, state `no matching perf output`.

### Acceptance Criteria

The Search result sequence playback test passes only if:

- Typing without Return does not change results, counts, selection, or active
  sequence playback.
- Escape restores uncommitted edits to the current committed query.
- Return commits the draft and replaces the Search results.
- The clicked result starts at its start timestamp and remains selected until
  sequence logic advances it.
- Non-continuous adjacent results fade picture and audio out over one second
  before the next result opens or seeks.
- The fade completes even when the current media has less than one second
  remaining after the cue end.
- Same-subtitle-filename adjacent results skip the fade only when the configured
  subtitle-count window reaches the cue immediately before the next result and
  `0ms <= b - c <= 1000ms`, with selection switching at `c`.
- Committing a new query during playback does not interrupt the current result,
  but prevents automatic advancement after that result fades out.
- With `Search result autoplay` off, Search result playback stops black and
  silent after the clicked cue fades out.
- With `Search result autoplay` on, Search result playback advances after
  fade-out when a next result exists.
- Search result subtitle-count edits are clamped to `1...999`, are disabled
  while Search result autoplay is off, and apply to newly started rules rather
  than mutating an active rule.
- With `Shiori result autoplay` off, Shiori playback stops black and silent
  after the clicked saved cue fades out.
- With `Shiori result autoplay` on, Shiori playback advances through later
  visible Shiori rows after fade-out.
- Shiori subtitle-count edits are clamped to `1...999`, are disabled while
  Shiori result autoplay is off, and apply to newly started rules rather than
  mutating an active rule.

### Failure Handling

If the test fails, identify whether the failure is Search commit state,
sequence invalidation, fade execution, same-file continuity, or row selection.
Do not broaden playback refactors until the failing responsibility is isolated.

### Cleanup

Keep any added diagnostic probes default-off. Remove temporary probes once the
acceptance failure they were added for is understood.
