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
- `ACTION UI.LibraryFolders.toggleAll`
- `ACTION UI.SearchResultGroup.toggled`
- `ACTION UI.SearchResults.toggleAll`
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
3. Focus Search and type a short query that returns results.
4. Expand and collapse one Library folder.
5. Click a Search result for the currently indexed Library.
6. Toggle the right Search Panel closed and open.
7. Toggle the left Library Panel closed and open.
8. Drag the playback progress bar or use a seek shortcut.

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
- During Search query input, Search counters may increase, but Library
  presentation snapshot rebuilds must remain `0`, and the playback render
  container must not be recreated.
- During Library folder expand or collapse, Library panel counters may increase,
  but Search presentation rebuilds and playback render container creation must
  remain `0`.
- Clicking a Search result may update Search selection and Playback state, but
  must not rebuild Library presentation rows.
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
