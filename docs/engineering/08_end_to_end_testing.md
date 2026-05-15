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
- Topbar Library/Shiori switching changes the active content mode without
  resetting inactive mode state or rebuilding unrelated presentation rows.

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
- `ACTION UI.WorkbenchContentPanel.toggled`
- `ACTION UI.WorkbenchMode.selected`
- `ACTION UI.LibraryVideo.opened`
- `ACTION UI.SearchQuery.changed`
- `ACTION UI.LibraryFolder.toggled`
- `ACTION UI.SearchResultGroup.toggled`
- `ACTION UI.SearchResults.collapseAll`
- `ACTION UI.SearchResult.opened`
- `UI.ContentView.body`
- `UI.AppTopBar.body`
- `UI.Workbench.body`
- `UI.WorkbenchModeRail.body`
- `UI.WorkbenchContentPanel.body`
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
4. Verify Search results are expanded by default for the new query.
5. Click `Collapse All` in Search and verify all current result groups collapse.
6. Modify the query and verify the new Search results are expanded by default.
7. Expand and collapse one Library folder.
8. Click an episode button inside an expanded Library folder.
9. Click a Search result for the currently indexed Library.
10. Click Library and Shiori in the topbar, then focus the topbar Search field,
    verifying the active content mode changes without resetting playback.
11. Verify the workbench has no visible Mode Rail, right-side Search panel, or
    resizable content-panel divider.
12. Drag the playback progress bar or use a seek shortcut.
13. Click Search and Shiori through the topbar flow, verifying Search shows the
    current Search results and Shiori shows the current Shiori mode or empty
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
- The removed Mode Rail, side Search panel, or panel-resize divider appearing
  in the active workbench.
- Topbar Library/Shiori switching resetting playback or Search state
  unexpectedly.

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
- New Search results must be expanded by default. The Search panel may expose a
  fixed `Collapse All` command for the current result set, but must not retain a
  global collapsed mode across a new query.
- The Search summary must read `Found <count> results in <count> files` and
  must not expose rendered-row counts.
- Library must not expose a panel-wide `Collapse All` or `Expand All` command;
  Library folder disclosure remains per-folder.
- The topbar must show Library and Shiori icons immediately to the left of the
  Search field. The previous Mode Rail, right-side Search toggle, and resizable
  content-panel divider must not appear.
- Switching topbar modes must not reset playback, the active Search query,
  loaded Search results, Shiori groups, or Library disclosure state.
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

## 4. Search Optimization Gate

### Goal

Validate that a Search optimization step preserves the visible app workflow
after the benchmark and automated tests have already passed.

This gate is not the first source of performance data. Search performance data
should come from `SearchBench`, Search timing logs, or default-off probes. Do
not add Search-performance numbers to the front-end UI merely to run this gate
while the optimization path is unstable.

### Preconditions

- The benchmark queries `大丈夫`, `今日`, and `の` have been run for the commit
  under test, with raw timings and averages recorded.
- Relevant automated tests have passed.
- The app is launched against an indexed Library that can return Search results
  for at least one broad query and one narrower query.

### Fixed Search Sequence

Run the three Search queries in this exact order:

1. `大丈夫`
2. `今日`
3. `の`

For each query:

1. Focus the topbar Search field.
2. Select the full previous query text.
3. Type the next query exactly.
4. Press Return once.
5. Wait for the initial Search result list to settle before recording
   observations or scrolling.

"Settled" means the Search pane is no longer showing the empty `Searching`
state or spinner, the `Found <count> results in <count> files` summary is
visible when results exist, and the visible result list has not changed for at
least two seconds.

If the step under test includes background exact counts, background summaries,
or delayed metadata, also wait for the documented log or benchmark completion
event before accepting the final count. Do not infer performance completion
from a front-end timing display unless that UI surface has already been
explicitly accepted.

### Per-Query Actions

#### `大丈夫`

Purpose: narrow-result sanity check.

Actions:

1. Run the fixed Search entry sequence for `大丈夫`.
2. Wait until the initial list is settled.
3. Do not scroll unless the changed step specifically targets narrow-query
   scrolling.
4. Open the first visible result.
5. Return to Search if playback opens.

Acceptance:

- The summary uses `Found <count> results in <count> files`.
- At least one subtitle-file group and one result row are visible.
- The visible result row contains a plausible match for `大丈夫`.
- Opening the first result selects the row and opens or seeks playback to the
  expected subtitle context.
- No front-end Search-performance diagnostics are visible unless explicitly
  accepted for the step.

#### `今日`

Purpose: medium-result paging and grouping check.

Actions:

1. Run the fixed Search entry sequence for `今日`.
2. Wait until the initial list is settled.
3. Scroll down exactly three full viewport steps. A full viewport step means
   Page Down once, or a trackpad/mouse-wheel scroll that moves the list by
   approximately one visible page.
4. After each viewport step, wait one second before the next scroll.
5. Open one visible result after the third scroll.
6. Return to Search if playback opens.

Acceptance:

- The summary uses `Found <count> results in <count> files`.
- Search results remain grouped by subtitle file.
- Scrolling three viewport steps does not show empty loaded groups, duplicate
  rows, visibly stale rows from the previous query, or a stuck loading state.
- If the step implements lazy loading or paging, any load-more action triggered
  by these scrolls must be expected by that step and visible in the agreed log
  or benchmark evidence.
- Opening a result after scrolling selects the row and opens or seeks playback
  to the expected subtitle context.

#### `の`

Purpose: broad-query stress check for high-frequency CJK search.

Actions:

1. Run the fixed Search entry sequence for `の`.
2. Wait until the initial list is settled.
3. Scroll down exactly six full viewport steps, waiting one second after each
   step.
4. If the step includes lazy loading or paging, continue waiting after the sixth
   viewport step until the documented load-more log event or settled-list state
   appears, up to ten seconds.
5. If the Search page exposes `Collapse All`, click it once after the scroll
   check settles.
6. Wait two seconds after `Collapse All`.

Acceptance:

- The summary uses `Found <count> results in <count> files`.
- The Search pane remains responsive while scrolling the broad result set.
- The list does not display summary-only subtitle-file aliases without an
  intentional loading/provisional state.
- Lazy loading, if part of the step, progresses predictably from ordinary
  scrolling and does not require stopping at a precise pixel position.
- `Collapse All`, if present, changes only the visible collapse state. It must
  not trigger an unintended load-more request, append unrelated results, or
  reveal rows that belong to a different query.
- No front-end Search-performance diagnostics are visible unless explicitly
  accepted for the step.

### Evidence to Record

Record:

- The commit under test.
- The exact query strings, in the required order.
- The benchmark summary for the three required queries.
- Whether automated tests passed.
- For each query, the visible summary text after the initial list settles.
- For `今日`, whether exactly three full viewport scrolls completed without a
  visible workflow issue.
- For `の`, whether exactly six full viewport scrolls completed, whether a
  load-more wait was needed, and whether `Collapse All` triggered any
  unexpected load.
- Any log block requested for the step.
- Any visible workflow issue, including stale counts, wrong grouping, empty
  loaded groups, accidental lazy-load triggers, scroll jumps, delayed playback
  selection, or front-end diagnostics that were not explicitly accepted.

### Acceptance Criteria

The gate passes only if:

- The benchmark result does not regress on the metric targeted by the step.
- Automated tests pass.
- The three-query Search sequence runs in order: `大丈夫`, `今日`, `の`.
- The visible Search workflow still preserves result identity, grouping,
  ordering, folder scope, lazy-loading behavior, collapse/expand behavior, and
  playback target timestamps.
- The required wait and scroll counts are followed: no scroll for `大丈夫`
  unless the step requires it, three full viewport scrolls for `今日`, and six
  full viewport scrolls for `の`.
- Search-performance diagnostics remain in logs or benchmark output unless a
  front-end diagnostic surface has already been explicitly accepted.
