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

The cross-domain Library, Playback, and Search isolation goals in this procedure
remain current. Its older grouped Search-card and `Collapse All` actions are
Superseded and must be skipped or replaced by the native Cue-table actions in
section 6. Use section 6 for Search, Shiori, Context, dynamic row geometry, and
`Show Cue Group` refresh-scope acceptance; retain the other isolation checks
below.

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
- The Search summary must always read
  `Found <count> results in <count> files`. It must not expose rendered-row
  counts or provisional wording.
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

The query and performance goals in this gate remain current. Its grouped-card,
group-disclosure, and `Collapse All` UI actions are Superseded and must be
skipped or replaced by section 6's native Cue-table actions. Group-specific
pass/fail criteria do not apply to the current UI.

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
visible, and the visible result list has not changed for at least two seconds.

The current accepted Search flow is exact-count first: the summary count and
file count must already be complete when the initial result list settles.

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
- The list does not display summary-only subtitle-file aliases without loaded
  matching rows.
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
- For Search-layer pagination / cursor steps, the JSONL page records for the
  run, summarized as
  `Query | page count observed | returned sequence | groups sequence |
  renderedRows sequence | hasMore | cursor sequence | nextCursor sequence |
  duplicate rows | stale rows | Collapse All unexpected load | pass/fail`.
- For exact-count Search steps, the JSONL page records for the run,
  summarized as
  `Query | countState sequence | knownResultCount sequence |
  knownFileCount sequence | totalCount sequence | fileSummaries sequence |
  countState stayed exact | pass/fail`.
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
- When the step changes Search-layer pagination, every observed load-more page
  must advance from the previous page's `nextCursor`; `returned`,
  `renderedRows`, and visible file groups must progress without duplicate rows,
  skipped rows, stale rows, or an unintended global load caused by `Collapse All`.
- Search-performance diagnostics remain in logs or benchmark output unless a
  front-end diagnostic surface has already been explicitly accepted.

## 5. Playback Subtitle Focus Keyboard Actions

### Goal

Verify the owner-visible behavior introduced by
`docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
and the still-compatible keyboard-action contract in
`docs/human/requirements/20260710-Feature-Playback Subtitle Focus Keyboard Actions.md`:
normal playback exposes only the circular subtitle control and `Q` shortcut,
while Playback Subtitle Focus uses exact-cue `S`, `C`, and Space actions with no
cue pointer actions or action menu. Focus geometry must also use complete
individual-Cue text and accepted fitting/oversized placement.

### Build And Launch

Repository:

`/Users/weiyunjun/Documents/Code/CueSeeker`

Run in a terminal:

```sh
cd /Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native
swift build
printf 'CueSeeker E2E sentinel' | pbcopy
swift run CueSeeker 2>&1 | tee /tmp/cueseeker-subtitle-focus-keyboard-actions.log
```

No diagnostic probe flag is required. Keep the launch terminal open. If any
step fails, preserve `/tmp/cueseeker-subtitle-focus-keyboard-actions.log` and
the terminal output from the failing action through two seconds afterward.

### Preconditions

- Use an indexed video with at least fifteen individual Cues.
- Include one cue containing two or more source lines so exact clipboard line
  breaks can be checked.
- Include fitting one-, two-, and three-visual-line Cues. When available, also
  include one Cue whose natural height exceeds the Focus reel viewport.
- Start from a cue that has not yet been saved as Shiori for this run.
- Keep a second terminal available for `pbpaste` checks.
- Record the commit under test with `git rev-parse --short HEAD`.

### Actions

#### Normal Playback

1. Open the indexed video from a Search result and leave Playback Subtitle
   Focus closed.
2. Inspect the bottom-player right group. It must contain the standalone
   circular subtitle button, speed capsule, and fullscreen button. It must not
   contain Shiori or copy-subtitle buttons, and the subtitle button must not be
   embedded in their former capsule group.
3. Press `S`, then `C`. Wait one second after each key.
4. In the second terminal run `pbpaste`. It must still print
   `CueSeeker E2E sentinel`. No Shiori/copy feedback or Shiori record may be
   created by either normal-playback key.
5. Press `Q` once. Confirm subtitle visibility changes, the circular button
   selected state follows the new visibility state, and the HUD shows
   `Subtitles On` or `Subtitles Off` as appropriate.
6. Press `Q` again and confirm subtitle visibility and button state return to
   their starting values.

#### Playback Subtitle Focus

1. Press Enter to open Playback Subtitle Focus. Confirm playback pauses and the
   focus overlay appears without an action menu.
2. Move the pointer across selected and unselected cue text. Confirm there is no
   hover color or pointing-hand cue cursor. Click selected and unselected cue
   text and confirm selection, Focus Anchor, reel position, playback state, and
   overlay state do not change.
3. Navigate with Up, Down, wheel or trackpad, and the scrollbar. Confirm each
   mechanism changes the focused Cue by ordinal. A fitting Cue settles with its
   complete bounds centered on the fixed Focus Anchor; an oversized Cue settles
   top-aligned and starts from its first visual line.
4. Visit the known one-, two-, and three-line Cues. Confirm every visual line is
   present and their resolved heights are approximately 76, 128, and 180 points
   when all three fit the reel. Narrow and widen the playback window; confirm
   wrapping changes height without changing the selected Cue identity, and the
   Cue returns to its accepted placement.
5. If an oversized Cue is available, enter it through keyboard, wheel, and
   scrollbar navigation. Confirm each settled entry starts from the first visual
   line, aligns the Cue top to the reel top, and clips only trailing display
   content while keeping the same Cue selected.
6. Focus the known multi-line cue and press `C`. Confirm `Subtitle Copied`
   appears above the focus overlay, the overlay remains visible, playback stays
   paused, and cue/reel/scrollbar positions do not change. Run `pbpaste` in the
   second terminal and compare the complete text and line breaks with the
   focused cue.
7. On an unsaved focused cue, press `S`. Confirm `Shiori Saved` appears above
   the focus overlay, the overlay remains visible, playback stays paused, and
   selection/reel/scrollbar state does not move.
8. Press `S` again on the same cue. Confirm `Shiori Already Saved` appears and
   no duplicate Shiori is created.
9. Press Down and immediately press `C` before the reel transition finishes.
   After settlement, run `pbpaste`. Confirm the copied text belongs to the new
   cue settled at the Focus Anchor, not the previous cue, and that the action
   executes only once.
10. Press Enter while the focus overlay is visible. Confirm it performs no
   action, opens no menu, and leaves the paused focus state unchanged.
11. Focus a cue with an identifiable start and press Space. Confirm the focus
   overlay closes, playback begins continuously from that cue's start, and the
   HUD shows `Play`.
12. Reopen Playback Subtitle Focus, navigate with the scrollbar, and press
    Escape. Confirm the overlay closes without an implicit seek and restores
    the playback state captured when this focus Session opened.

### Evidence To Paste Back

- The short commit hash under test.
- Pass/fail for every numbered action above.
- The `pbpaste` result after normal `S`/`C`, focused-cue `C`, and immediate
  Down-then-`C`.
- A screenshot of the normal bottom-player right group.
- Screenshots showing `Shiori Saved`, `Shiori Already Saved`, and
  `Subtitle Copied` above the still-visible focus overlay.
- A short screen recording or precise written observation for Down-then-`C`
  settlement and Space continuous playback.
- Screenshots or a recording showing fitting multi-line centering, width reflow
  with stable Cue identity, and oversized head-first placement when an
  oversized fixture is available.
- On failure, the relevant block from
  `/tmp/cueseeker-subtitle-focus-keyboard-actions.log` and the exact action that
  produced it.

### Acceptance Criteria

The gate passes only if:

- Normal playback has no Shiori/copy buttons or current-time Shiori/copy key
  commands; `Q` alone toggles subtitle visibility and its circular button state.
- Cue hover and click create no visual, selection, action, menu, playback, or
  cursor response while Up, Down, wheel, and scrollbar navigation still work.
- One-, two-, and three-line fitting Cues show every line at approximately 76,
  128, and 180 points, remain centered on the fixed Focus Anchor, and preserve
  selected Cue identity through width reflow.
- An oversized Cue, when available, resolves to the reel height and returns to
  top-aligned first-line-visible placement after keyboard, wheel, scrollbar, or
  width-reflow settlement.
- Focus `S` saves the exact settled cue idempotently, shows the correct saved or
  already-saved HUD, and keeps the paused overlay and navigation state intact.
- Focus `C` copies the exact complete cue text with source line breaks, shows
  `Subtitle Copied`, and keeps the paused overlay and navigation state intact.
- An action accepted during motion runs once against the final settled cue.
- Enter is a no-op inside the focus overlay.
- Focus Space closes the overlay, starts continuous playback from the exact
  focused cue start, and shows `Play`.
- No crash, duplicate action, hidden feedback, stale Session action, unexpected
  seek, or unrelated workbench reset occurs.

## 6. Cue-Centric Table Presentation And Refresh Scope

### Goal

Verify that Search, Shiori, and Search-hosted Context present individual Cues
through the shared native virtual table, render complete dynamic-height content,
and isolate `Show Cue Group` and width reflow from query/data and unrelated UI.

### Build And Launch

Terminal A:

```bash
/usr/bin/log stream --style compact --predicate 'subsystem == "com.cueseeker.perf"'
```

Terminal B:

```bash
cd /Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native
CUESEEKER_PERF_UI=1 swift run CueSeeker
```

Stop if `MARK UIInvalidationProbe.enabled` does not appear within three seconds.
The relevant scoped counters use these families:

```text
table.search.*
table.context.*
table.shiori.*
playback.render_host_*
```

Within each table family, inspect `native_make`, `native_update`,
`dynamic_row_measurement`, `dynamic_row_draw`,
`show_cue_group_owner_update`, `width_reflow_owner_update`, and
`dynamic_scroll_anchor_correction`. Width reflow also emits
`ACTION UI.SubtitleTable.<surface>.width_reflow`.

### Preconditions

- Index a subtitle fixture containing at least two matching individual Cues in
  the same Cue Group, plus one-line and multi-line primary Cues.
- Include enough rows to scroll, with source line breaks and text that wraps
  when the window narrows.
- Save at least one fixture Cue to Shiori and ensure it can be opened in
  Search-hosted Context.
- In Settings / Search, confirm `Show Cue Group` exists immediately below
  Search Scope as a native switch.
- Record the short commit hash with `git rev-parse --short HEAD`.

### Actions

After each action, wait two seconds and preserve the corresponding log block.

1. Launch with `Show Cue Group` Off and run a query matching two Cues from the
   same Cue Group. Confirm they appear as separate result rows and contribute
   separately to the result count.
2. Inspect one-line and multi-line rows. Confirm complete text is visible, with
   no ellipsis, truncation, maximum line count, or clipped source line break.
3. Scroll until a distinctive primary Cue is visible and record the screen
   position of its first visual line. Narrow the window enough to wrap Cues,
   then widen it again.
4. Open Settings / Search, turn `Show Cue Group` On, and return to Search.
   Confirm additional Cues appear above each primary Cue in smaller, more muted
   text while the same primary Cue remains the row and action identity.
5. With `Show Cue Group` On, left-click and right-click additional Cue text.
   Confirm the shared interaction region uses the primary Cue for Play,
   Context, and Copy Cue Text; confirm Copy Cue Group Text is additionally
   available. Turn the switch Off and confirm only the extra menu item and
   additional text disappear.
6. Open Context from the distinctive primary Cue and repeat the width and
   `Show Cue Group` checks. Confirm Context uses the same dynamic table contract
   and returns to the exact primary Cue.
7. Open Shiori and repeat the checks on the saved Cue. Confirm the Shiori Cue,
   tags, time, and date identity remain unchanged and the table is not reloaded
   merely because presentation changed.
8. Set `Show Cue Group` On and quit. Start the performance log before relaunch,
   then open the same table for its first mount. Confirm its first visible
   presentation is already On, with no intermediate Off frame and no redundant
   owner update caused solely by initial preference hydration.
9. Cover that On table with the playback page and turn `Show Cue Group` Off.
   Confirm no covered-table work occurs. Close playback and confirm the newly
   visible table applies Off exactly once without rebuilding the playback render
   host. Quit and relaunch once more to confirm Off persisted.

### Evidence To Paste Back

- The short commit hash and pass/fail for each numbered action.
- Before/after screenshots for width reflow and `Show Cue Group` on Search,
  Context, and Shiori.
- The scoped counter deltas for each action, including any
  `playback.render_host_*` changes.
- The visible result count and stable primary Cue identity used for the anchor
  and action checks.

### Acceptance Criteria

The gate passes only if:

- Search count, pagination, selection, Context return, and actions are based on
  individual Cues; sibling matches from one Cue Group remain distinct.
- Every primary and displayed additional Cue line is visible. Row geometry
  follows `16 + 24P + 20S`, including width wrapping and source line breaks.
- `Show Cue Group` defaults Off on fresh state, persists across launches, and is
  presentation-only. It changes neither query execution, row identity snapshot,
  result count, sorting, selection, primary Cue identity, nor action target.
- Width and preference changes remeasure only visible rows plus overscan for the
  currently eligible surface. Search, Context, and Shiori counters remain
  independently scoped; hidden surfaces may defer work until visible.
- Reflow preserves the anchored primary Cue and its first visual line's
  screen-space position instead of preserving only a raw scroll offset.
- No table presentation action rebuilds Library, recreates the playback render
  host, reruns Search, rebuilds Context scope, or reloads Shiori data.
- No rainbow cursor, scroll jump, stale row, duplicate row, clipped Cue, or
  action retargeting occurs.
