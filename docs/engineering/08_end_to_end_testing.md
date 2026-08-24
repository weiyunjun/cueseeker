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

## 1.1 Debug In-App UI Control

Known CueSeeker-owned macOS UI flows use the Debug in-app E2E controller by
default. The controller captures the actual WindowServer composition of every
visible CueSeeker-owned window with ScreenCaptureKit, dispatches left and right
clicks at a documented complete-scene coordinate, dispatches pointer-move and
separable drag events, dispatches a discrete vertical mouse
wheel event at a documented coordinate, posts documented keyboard events
inside the app, reports whether the App currently hides the cursor, and sets the
main window's width. It does not reconstruct views,
move the real pointer, request
Accessibility or Input Monitoring permission, inspect other applications, or
locate controls from screenshots.

Launch from a PTY so commands can be written to the running process:

```bash
cd apps/macos-native
swift run CueSeeker --cueseeker-debug-e2e
```

The controller is compiled only for Debug, starts only when the explicit
argument is present, and requires macOS 14 or newer. On macOS 14.4 and newer,
ScreenCaptureKit's current-process capture does not require Screen Recording
permission. macOS 14.0 through 14.3 uses the system Screen Recording permission
and returns an explicit restart instruction when newly granted. A normal Debug
or Release launch does not read E2E commands.

Read the prefixed ready record before acting:

```text
CUESEEKER_E2E {"artifactDirectory":"...","sceneID":"...-0","status":"ready","windows":[...]}
```

`width` and `height` describe the union of the visible CueSeeker windows in
logical points. Coordinates use that complete scene's upper-left corner as
`(0, 0)`, increase rightward and downward, and are independent of backing scale.
`windows` records each window's scene-relative frame, type, title, number, and
front-to-back order; order `0` is frontmost. All included windows must be fully
contained by the same display. A test procedure must state the expected window
layout and either pre-agreed coordinates or coordinate formulas derived from
the `inspect` window bounds and documented layout offsets. Stop when the layout
differs; do not use a screenshot to rediscover the control.

Supported commands are one JSON object per line:

```json
{"action":"inspect"}
{"action":"capture","name":"after-known-click"}
{"action":"click","x":80,"y":155,"sceneID":"current-scene-id"}
{"action":"scroll","x":80,"y":420,"deltaY":-3,"sceneID":"current-scene-id"}
{"action":"keyPress","key":"enter","modifiers":[],"sceneID":"current-scene-id"}
{"action":"setWidth","width":1100,"sceneID":"current-scene-id"}
{"action":"mouseMove","x":80,"y":155,"sceneID":"current-scene-id"}
{"action":"rightClick","x":80,"y":155,"sceneID":"current-scene-id"}
{"action":"mouseDown","x":80,"y":155,"sceneID":"current-scene-id"}
{"action":"mouseDrag","x":240,"y":155,"sceneID":"current-scene-id"}
{"action":"mouseUp","x":240,"y":155,"sceneID":"current-scene-id"}
```

`inspect` returns the current scene contract without producing an image.

`click` resolves the frontmost visible CueSeeker window at the scene coordinate,
converts the point to that window, and posts a left-button down/up pair to the
AppKit event queue. It performs normal click activation but does not call a
control action or mutate product state directly. A stale `sceneID`, non-finite
coordinate, scene gap, or out-of-bounds point returns an error without posting
either event. Every successful click returns a fresh `sceneID`, logical size,
pixel size, scale, and window layout; the next click must use that returned ID.

`scroll` uses the same complete-scene coordinates and frontmost-window routing
as `click`, then posts one non-precise, line-based AppKit scroll-wheel event.
`deltaY` must be a nonzero signed integer: positive values scroll up toward the
content start and negative values scroll down toward the content end. One
command has no trackpad gesture, momentum, inertial, continuous-scroll, or
scrollbar-drag semantics; repeat commands with each returned fresh `sceneID`
when a procedure requires more scrolling. A stale `sceneID`, invalid coordinate,
zero or non-integer `deltaY`, missing target window, or event-construction
failure returns an error without posting the event. Known-coordinate automated
scrolling should use this command instead of remaining a manual wheel action.

`keyPress` posts one non-repeating AppKit key-down/key-up pair to the current
CueSeeker key window and first responder. Supported `key` values are letters,
digits, `enter`, `escape`, `tab`, `space`, `leftArrow`, `rightArrow`, `upArrow`,
and `downArrow`. Supported modifiers are `command`, `option`, `control`, `shift`,
and `function`; use an empty array for an unmodified key. The command requires
an active CueSeeker app, a visible key window in the current scene, and a current
`sceneID`. It never posts a system-wide event and never calls the shortcut's
product action directly. Success returns a fresh `sceneID`; stale state,
unsupported keys or modifiers, unavailable key windows, and event-construction
failure are explicit errors.

`setWidth` resizes the main window only. `width` is a finite positive length in
logical points; the window's height and upper-left corner do not change. AppKit
clamps the request to the window's own minimum and maximum size, so read the
effective width from the returned scene rather than assuming the requested value
was applied. Use this command to verify width-dependent adaptive layout instead
of resizing the window by hand. It does not change backing scale, display
configuration, or product state. A stale `sceneID`, a non-positive or non-finite
`width`, a missing main window, or a resulting scene that breaks the
single-display rule is an explicit error; a scene rebuild failure restores the
previous frame so a failed command leaves the window unchanged. Success returns
a fresh `sceneID` plus `windowWidth`, the width actually in effect.

`mouseMove` posts one AppKit `mouseMoved` event using the same complete-scene
coordinates and frontmost-window routing as `click`. It does not activate the
app, raise a window, or move the real pointer.

`mouseMove` has a hard platform limit that a test procedure must respect. AppKit
routes `mouseMoved` to the window's current first responder, and only views that
derive their hovered element from the event's own location react to it. The
Workbench subtitle table works this way. `NSTrackingArea` enter/exit callbacks
and SwiftUI's `.onHover` are driven by the real cursor position instead, so a
synthesized move never reaches them: SwiftUI cards, popover rows, and every
control whose hover state comes from `.onHover` cannot be hovered by this
command. Hover behavior on those surfaces stays a manual acceptance step. Do not
read an absent hover effect after `mouseMove` as a product defect without first
checking which mechanism the surface uses.

`rightClick` posts a right-button down/up pair at the scene coordinate and, like
`click`, performs normal click activation. Use it for the Workbench table row
context menu. The Library cover context menu installs its right-click monitor
only while the card reports SwiftUI hover, so it cannot be opened by this
command alone; it remains a manual acceptance step for the same reason
`mouseMove` cannot drive `.onHover`.

`mouseDown`, `mouseDrag`, and `mouseUp` split a left-button drag into separable
steps for interactions that need the intermediate motion, such as selecting
subtitle text in the Playback Overlay before its selected-text menu appears.
`mouseDown` activates the app exactly as `click` does; `mouseDrag` and `mouseUp`
do not, so a sequence never reorders windows midway. The controller enforces the
order: `mouseDrag` or `mouseUp` without an open press, and a second `mouseDown`
before a release, fail with `invalidDragSequence` without posting an event. Each
step returns a fresh `sceneID` that the next step must use.

Every scene response includes `pointerVisible`, which is `false` while the App
hides the system cursor and `true` otherwise. Screenshots never contain the
cursor, so this field is the only evidence for pointer-visibility rules. The
playback page is currently the only owner that hides the cursor.

`capture` accepts a nonempty name made from letters, numbers, hyphens, and
underscores. It writes a PNG under the per-process temporary artifact directory
from the ready record, then returns its absolute path and the complete scene
metadata. The image contains the windows' actual positions, front-to-back
occlusion, title bars, focus state, controls, video frame, and subtitles as
composed by WindowServer. Before capture, the controller verifies that
ScreenCaptureKit resolved every visible CueSeeker window. Permission failure,
multiple displays, a missing window, layout changes during capture, encoding
failure, and save failure are explicit errors; none may fall back to view
capture, reconstruction, or an external screenshot tool.

Every response is a single JSON record prefixed with `CUESEEKER_E2E`. A command
is complete only after its `status` is `ok`. Feature work that continues beyond
the controller's bounded post-interaction event wait must keep its existing log,
state, or bounded-wait condition before requesting the result screenshot.

Screenshots verify visible outcomes only. Logs, database state, playback state,
timings, and other feature-specific evidence remain required where applicable.
System permission dialogs, OS menus, physical controllers, and
cross-application focus remain explicit manual tests when their behavior is the
subject under test.

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
section 6. Use section 6 for Search, Shiori, dynamic row geometry, and
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
4. Do not press Return; confirm input alone starts Search after the
   100-millisecond debounce.
5. Wait for the Search result list and Exact count to settle before recording
   observations or scrolling.

"Settled" means the Search pane is no longer showing the empty `Searching`
state or spinner, the `Found <count> results in <count> files` summary is
visible, and the visible result list has not changed for at least two seconds.

Visible results may appear before Exact completion. For final benchmark
observations, the summary count and file count must be complete when the result
list is considered settled.

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

## 5. Superseded Playback Subtitle Focus Keyboard Actions

> Superseded by section 8. Do not use the Space-playback or Enter-no-op steps
> below for current acceptance. They are retained only as the historical gate
> for the earlier single-module Subtitle Focus implementation.

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

Verify that Search and Shiori present individual Cues
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
- Save at least one fixture Cue to Shiori.
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
   Confirm additional Cues appear below each primary Cue in smaller, more muted
   text while the same primary Cue remains the row and action identity.
5. With `Show Cue Group` On, left-click and right-click additional Cue text.
   Confirm the shared interaction region uses the primary Cue for Play and Copy
   Cue Text, Copy Cue Group Text is additionally available, and no menu item is
   named `Context`. Turn the switch Off and confirm only the extra menu item
   and additional text disappear.
6. Open Shiori and type a query one character at a time. Confirm results and the
   exact result count update without Return, only Primary Cue text matches, and
   a Display Title-only query returns no rows. Repeat the Cue presentation checks
   on a saved Cue; confirm its Cue, time, and date identity remain unchanged and
   the table is not reloaded merely because presentation changed. Confirm no
   Shiori Tags column or interaction is present.
7. Set `Show Cue Group` On and quit. Start the performance log before relaunch,
   then open the same table for its first mount. Confirm its first visible
   presentation is already On, with no intermediate Off frame and no redundant
   owner update caused solely by initial preference hydration.
8. Cover that On table with the playback page and turn `Show Cue Group` Off.
   Confirm no covered-table work occurs. Close playback and confirm the newly
   visible table applies Off exactly once without rebuilding the playback render
   host. Quit and relaunch once more to confirm Off persisted.

### Evidence To Paste Back

- The short commit hash and pass/fail for each numbered action.
- Before/after screenshots for width reflow and `Show Cue Group` on Search and
  Shiori.
- The scoped counter deltas for each action, including any
  `playback.render_host_*` changes.
- The visible result count and stable primary Cue identity used for the anchor
  and action checks.

### Acceptance Criteria

The gate passes only if:

- Search count, pagination, selection, and actions are based on
  individual Cues; sibling matches from one Cue Group remain distinct.
- Every primary and displayed additional Cue line is visible. Row geometry
  follows `16 + 24P + 20S`, including width wrapping and source line breaks.
- `Show Cue Group` defaults Off on fresh state, persists across launches, and is
  presentation-only. It changes neither query execution, row identity snapshot,
  result count, sorting, selection, primary Cue identity, nor action target.
- Width and preference changes remeasure only visible rows plus overscan for the
  currently eligible surface. Search and Shiori counters remain
  independently scoped; hidden surfaces may defer work until visible.
- Reflow preserves the anchored primary Cue and its first visual line's
  screen-space position instead of preserving only a raw scroll offset.
- No table presentation action rebuilds Library, recreates the playback render
  host, reruns Search, or reloads Shiori data.
- No rainbow cursor, scroll jump, stale row, duplicate row, clipped Cue, or
  action retargeting occurs.

## 7. Long-GOP Search Result Audio Continuity

### Goal

Confirm that opening and switching to the reported long-GOP Search result does
not produce repeated audio interruptions, while bounded playback, pause,
timeline seek, and playback-rate behavior remain intact.

### Build And Launch

Terminal A:

```bash
cd /Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native
swift build
CUESEEKER_PERF_PLAYBACK=1 swift run CueSeeker 2>&1 | tee /tmp/cueseeker-long-gop-e2e.log
```

Terminal B:

```bash
cd /Users/weiyunjun/Documents/Code/CueSeeker
git rev-parse --short HEAD
```

Keep the output device, system volume, CueSeeker volume, and playback rate
unchanged during each listening comparison.

### Preconditions

- `/Volumes/Samsung/影视/赛马娘 第1季` is mounted and indexed.
- Searching for `年長組` returns the `12:36 - 12:39` result from
  `[Nekomoe kissaten][Uma Musume][01][1080p][JPSC].ass`.
- The paired media is
  `[Nekomoe kissaten][Uma Musume][01][1080p][JPSC].mp4`.
- Start with playback rate 1.0x and subtitles visible.

### Actions

1. Search for `年長組`, open the exact `12:36 - 12:39` result, and listen from
   entry through bounded completion. Confirm speech and background audio remain
   continuous; also confirm video and subtitles advance normally and playback
   stops once at the cue end.
2. Return to Search and repeat action 1 ten times. Record pass/fail for each
   attempt. There must be no repeatable short mute, restart, double completion,
   or late audio after the page returns to its paused end state.
3. Open another result from the same episode, then switch directly back to the
   reported result without closing Playback. Repeat this switch ten times and
   listen through at least one second after each switch. The target must not
   inherit old-position audio or pause three times near entry.
4. While the reported result is playing, press the timeline near `12:32`, drag
   to the target near `12:36`, and release. Confirm audio is silent while
   dragging, resumes only after release, and then remains continuous with the
   target video and subtitle.
5. Reopen the reported result, pause after its first visible frame, wait one
   second, and resume. Confirm there is no audio before resume and no mute or
   restart immediately after resume.
6. Play the reported result once at 0.5x and once at 2.0x. Confirm both runs
   remain continuous and finish once at the same cue endpoint.
7. Close Playback during a target run, reopen the same result, and listen
   through completion. Confirm no old audio leaks across close/reopen and no
   hang, crash, or stale segment-completion event occurs.

### Log Review

After the actions, stop Terminal A with Control-C and run:

```bash
rg -n "Native playback rebuffer|Native playback failed|PLAYER_.*fail" /tmp/cueseeker-long-gop-e2e.log
```

For this local mounted-media case, no `Native playback rebuffer` line is
expected during the reported result. Preserve the matching log block if any
line is returned.

### Evidence To Paste Back

- The short commit hash under test and the selected audio output device.
- Pass/fail for actions 1 through 7, including all ten direct opens and all ten
  same-episode switches.
- Whether any audible mute, restart, click, or A/V offset was observed, with the
  exact attempt and timestamp.
- The complete output of the log-review command.
- On failure, a short screen recording with audible output and the surrounding
  `/tmp/cueseeker-long-gop-e2e.log` block.

### Acceptance Criteria

The gate passes only if:

- All direct opens and in-session switches play continuously without the
  reported repeatable audio interruption.
- Timeline dragging is silent, release resumes the correct generation, and
  pause-after-first-frame never starts audio early.
- 0.5x, 1.0x, and 2.0x preserve continuous audio and one bounded completion.
- No old PCM, callback, or segment event crosses seek, close, or reopen.
- Video and subtitles remain synchronized enough for cue review, and no target
  run logs a false native rebuffer event.

## 8. Playback Multi-Module Overlay

### Goal

Validate the complete Playback Multi-Module Overlay described by
`docs/human/requirements/20260714-Feature-Playback Multi-Module Overlay.md`,
`docs/human/requirements/20260720-Feature-Playback Multi-Module Overlay Light Mode.md`, and
`docs/human/design/UI Design System.md` together with
`docs/human/design/UI Application Rules.md`: one temporary Session contains Current, optional
Playlist, Search, Recent, Library, and Shiori; module switches retain temporary
state, while every Overlay exit destroys that state and cancels its work.

This gate also verifies the real macOS behavior that Store and hosting tests
cannot prove: effective Light, Dark, and Auto visual hierarchy, live appearance
changes, first responder and IME behavior, pointer regions, trackpad and
scrollbar input, card layout, feedback layering, and real playback pause, seek,
and continuation.

### Build And Launch

Run the deterministic source-growth and cancellation prerequisites first:

```bash
cd /Users/weiyunjun/Documents/Code/CueSeeker
cd apps/macos-native
swift test --filter searchPlaybackPlaylistFollowsExactProgressInsteadOfFreezingClickedRows
swift test --filter playbackSearchEnterPromotesRunningExactSourcePastSessionTeardown
swift test --filter playbackLibraryRejectsStaleDetailSuccessFailureAndDismissal
swift test --filter playbackMultiModuleOverlayStopCancels
swift test --filter 'subtitleFocusVisualLineStackPreservesEverySourceLineAtStrictFivePointGap|subtitleFocusVisualLineStackUsesStrictFivePointGapAcrossSoftWraps|subtitleFocusNativeTextLayoutDrawsEveryFittingLineAtStrictInternalGap|playbackCueResultKeepsFivePointGapAcrossGroupHardSoftAndCueBoundaries'
cd ../..
```

All five commands must pass. The first two mechanically verify source growth,
final count, and fixed order positions for the Workbench-origin and
Playback-Search-origin Playlist sources. The next two use suspended loaders to
prove that an in-flight Library Detail load and all other Session work are
cancelled and cannot publish late success or failure. The fifth proves the
strict 5-pixel typographic gap across hard breaks, soft wraps, Cue boundaries,
and Additional-to-Primary boundaries. The manual gate below verifies the
corresponding real UI;
it does not depend on a human being fast enough to close a local database read
while that read is still in flight.

Terminal A builds the packaged app, creates a fresh log, and writes visible run
markers. Keep it open while performing the actions:

```bash
cd /Users/weiyunjun/Documents/Code/CueSeeker
git rev-parse --short=7 HEAD
scripts/verify_macos_media_runtime.sh .build/media-runtime/arm64-macos13
scripts/package_macos_app.sh --output /private/tmp/CueSeeker-Overlay-E2E.app
/usr/bin/env bash -o pipefail <<'BASH'
LOG=/tmp/cueseeker-playback-multi-module-overlay.log
APP=/private/tmp/CueSeeker-Overlay-E2E.app/Contents/MacOS/CueSeeker
: > "$LOG"
printf '=== CUESEEKER OVERLAY E2E START %s ===\n' \
  "$(date '+%Y-%m-%d %H:%M:%S%z')" | tee -a "$LOG"
"$APP" 2>&1 | tee -a "$LOG"
app_status=${PIPESTATUS[0]}
printf '=== CUESEEKER OVERLAY E2E END %s exit=%s ===\n' \
  "$(date '+%Y-%m-%d %H:%M:%S%z')" "$app_status" | tee -a "$LOG"
exit "$app_status"
BASH
```

No diagnostic flag or temporary probe is required. After action 17, quit the
packaged app normally and wait for Terminal A to print the End marker. A
nonzero End status or any failure predicate in Log Review And Handoff fails the
gate.

Terminal B is used for clipboard checks and exact evidence capture:

```bash
pbpaste > /private/tmp/cueseeker-overlay-e2e-clipboard-before.txt
pbpaste
```

### Preconditions

- Use the normal indexed Library, not a test database. It must contain at least
  two playable folders, one folder with multiple Episodes, Recent history, and
  at least two Shiori rows.
- Record the current Workbench Search query and filters, then clear all filters
  so term-only Workbench Search and Playback Search have the same folder scope.
- Choose two term-only Search queries with enough matches that visible results
  appear before Exact completion. `の` is the standard first query for the
  current Library; the second query must also expose visible-to-Exact growth.
- Know one multi-line Primary Cue, one Result with Additional Cues, one already
  saved Shiori, and two different unsaved Primary Cues. The first unsaved Cue
  must belong to the video opened in action 1. The second must belong to the
  Episode deliberately opened at the end of action 11; alternatively, choose a
  different unsaved Cue from that Episode before action 12. The two newly saved
  Shiori may be removed after the test.
- Start with `Show Cue Group` On. Record its starting value and restore that
  value during cleanup.
- Close other CueSeeker processes before launching the packaged build.
- Keep the window size and position unchanged while taking every before/after
  scroll-restoration screenshot. Each pair must show the same selected identity
  and the same screen-space top edge of a named visible Result or card.

### Actions

1. In Workbench Search, type the first broad query without pressing Return. As
   soon as the first usable Result appears, record the clicked Primary Cue and
   open it before Exact completion. Confirm input alone starts Search after the
   100-millisecond debounce and Playback opens that Result.
2. Press Enter during playback. Confirm playback pauses; the Overlay covers the
   complete Stage; Playback Chrome and Progress disappear; feedback remains the
   top layer; and the appearance-aware Sidebar reads Current, Playlist, Search,
   Recent, Library, Shiori in that order with only two text/icon colors. Confirm
   Pointer starts hidden, Wheel alone does not reveal it, physical Pointer Move
   reveals it, and any key-down hides it again.
   In Light Appearance, confirm the Overlay background, Current, Playlist,
   Search, Shiori, Playlist Sequence Number, Sidebar, Search Box, Recent,
   Library, and Scrollbar use their documented Light tokens. Change Appearance
   to Dark while the Overlay remains open and confirm every visible surface
   updates without changing the current Module, selected identity, Reel
   position, or card scroll position. Repeat with Auto and confirm the result
   follows the current macOS appearance. Before testing Current or any other
   module, immediately click Playlist, drag to its
   end, and record the last Sequence Number as the early partial count `P`.
   Sample the last Sequence once per second for three observations and record
   the first larger value as `P1`. If no increase can be observed because the
   source may already have reached Exact by first entry, mark this source-growth
   sub-run `INCONCLUSIVE`, choose a broader query, and restart actions 1 and 2.
   Do not report the feature as failed solely because this run missed the
   partial state. Continue only after one run records `P1 > P`, then return to
   Current.
3. In Current, verify the default Cue, then use Up, Down, wheel, trackpad, and
   scrollbar. Hover and click selected and unselected Cue text and resize the
   window. There must be no Cue hover treatment or pointer cursor. Clicks must
   do nothing and not reach Video; selection and accepted placement survive
   reflow. Multi-line typographic gaps must look uniform; exact typographic
   bounds are not inferred from visible glyph ink. The deterministic geometry
   prerequisite proves the strict 5-pixel internal gap. Record the selected Cue
   and take the Current-before screenshot.
4. Press C on the known multi-line Current Cue, run `pbpaste`, and compare the
   complete source line breaks. Press S on the first unsaved Cue and then again.
   Confirm `Subtitle Copied`, `Shiori Saved`, then `Shiori Already Saved` render
   above the still-open paused Overlay without moving Current. Press Space and
   confirm it is consumed: the Overlay remains open and paused, with no seek,
   selection change, or playback action.
5. Click every available Sidebar Item and confirm each click switches exactly
   once; every enabled Item must show the pointing-hand cursor, while hover must
   not introduce a third color or selection background. Click the Selected Item
   and confirm it does not navigate again. Return to Current and take the
   Current-after screenshot: its recorded Cue and exact placement must match
   action 3. Then use unmodified Tab through every module and back.
   While Playback Search owns the editor focus, press and hold Tab; one physical
   key-down may advance only once, native focus traversal must not occur, and no
   other module-switch button or shortcut may appear.
6. Return to the Workbench-origin Playlist and verify Sequence Numbers,
   Additional Cues, and all Reel navigation methods. Hover and click selected
   and unselected Results; there must be no Result hover state or pointer cursor,
   and both clicks must remain inert. Select a non-first Result, scroll it to a
   named screen position, and take Playlist-before. Leave with a Sidebar click,
   return with a Sidebar click, and take Playlist-after without resizing;
   selection and the named Result's top-edge pixel coordinate must be identical.
   Drag to the end once per second until the last Sequence Number remains
   unchanged for three consecutive observations. This stability is not proof of
   Exact completion: record the value only as candidate count `N`, together with
   the complete Primary Cue text at Sequence 1, Sequence 2, and Sequence `N` in
   the Workbench-origin order ledger.
7. Press Escape, close Playback, and wait for the original Workbench Search to
   report its final Exact `{W} rows`. Record the complete Primary Cue text at
   Workbench row 1, row 2, and row `W`. `W` must equal `N`, and all three
   fixed-position texts must equal the corresponding Playlist ledger entries.
   If `W != N`, the three-second sample ended before Exact completion; mark that
   manual count/order sub-run `INCONCLUSIVE` and repeat actions 1 through 7 with
   a broader query or a longer observation interval. Do not reinterpret this
   timing mismatch as a product failure; the deterministic prerequisite is the
   authoritative source-growth check. A passing manual ledger still requires
   one completed run with `W == N` and all three texts equal. Reopen the same
   Workbench Result, open the Overlay, and confirm its fresh Playlist again ends
   at Sequence `W` in that recorded order.
8. Open Playback Search. Type literal `s` and `c` and confirm both remain ordinary
   editor input. Click Inline Clear before entering the second broad Japanese
   query. Enter that query through a Japanese IME by observing marked
   composition text, candidate conversion, and commit; do not paste it or press
   Return. Confirm Results update 100 milliseconds after the latest edit, the
   first Result becomes selected, Up/Down changes the Result while the caret
   remains in the field, and native selection plus Cmd+A/C continue to work.
   Hover Inline Clear and confirm its full `24 x 24pt` hit region shows the
   pointing-hand cursor. Hover and click selected and unselected Results. There must be no Result
   hover state or pointer cursor, and neither click may change selection, start
   playback, reach Video, or remove editor focus.
   Select a non-first Result, scroll away from the start, and take Search-before.
   Click Current and then Search in the Sidebar and take Search-after: query,
   committed text, Results, selection, exact pixel offset, and editor focus must
   be unchanged. Confirm the Workbench Search Feature already exposes the same
   current Query and loaded Result collection without copying a Playback-owned
   dataset. Explicitly click Inline Clear and confirm an empty Result state
   with no focus ring, then re-enter the same second broad Japanese query through
   IME for action 9.
9. Before Playback Search reaches Exact completion, press Enter on a settled
   Result. Confirm playback starts at that Primary Cue and the old Overlay is
   destroyed. Immediately reopen the Overlay and enter Playlist. Record its
   partial last Sequence Number as `S0` and sample it once per second. Record
   the first larger value as `S1`. If no
   post-promotion increase is observed within three samples, mark this sub-run
   `INCONCLUSIVE`, choose a broader query, and repeat actions 8 and 9. After at
   least one increase with `S1 > S0`, use the same three-consecutive-observation
   rule from action 6 to record candidate count `S`.
   Record complete Primary Cue text at Sequence 1, Sequence 2, and Sequence `S`
   in the Playback-Search-origin order ledger. Exit Playback and confirm it
   returns directly to Workbench Search with the identical shared Query and the
   now-formal empty Filter; wait for final Exact `{X} rows`, and record the same
   three Workbench positions. If `X != S`, mark the manual
   count/order sub-run `INCONCLUSIVE` and repeat actions 8 and 9 with a broader
   query or longer observation; the deterministic promotion prerequisite, not
   the three-second stability sample, decides source-growth correctness. A
   passing manual ledger requires `X == S`, all three ordered texts equal, and at
   least one observed post-promotion count increase.
10. Reopen playback and the Overlay. In Recent, confirm the first available card
    is selected. Use all four arrows, scroll away from the start, and take
    Recent-before. With Pointer visible, Hover another available card and
    confirm Hover appears while Selected remains unchanged; move to blank space
    and confirm Hover disappears while Selected stays. Hide Pointer with a key
    and confirm Hover disappears without changing Selected; reveal it by
    movement, then scroll a new card under the stationary Pointer and confirm
    only Hover changes. Exercise the card context menu and
    confirm it has the accepted actions, no item named `Context`, and its actions
    remain locked to the right-clicked card until close. Click another Sidebar
    module and then click Recent; take
    Recent-after and confirm the selected identity and named card's top-edge
    pixel coordinate are identical. In a separate fresh Session, left-click a
    Recent card and confirm its existing primary playback action destroys the
    Overlay and opens that exact media item. Selected must reuse the complete
    card Hover visual with no Focus Ring, border, or independent selected fill.
11. Before reopening Playback, enter Workbench Library. Confirm its Summary Row
    displays the visible Folder count plus Video and Subtitle totals, and that
    the Folder count equals the number of Folder Cards currently displayed.
    Confirm `Add Content` opens Settings with Library selected. Return to
    Workbench, compare Library and Shiori level one, and confirm they share the
    same Summary Row, adaptive Grid, card width, Hover, and Pressed structure;
    only Shiori cards include the Description line. Enter one Library Folder
    and confirm its Video Card Grid has no persistent default selection. Start
    playback from that folder, reopen the Overlay, and enter Video Playlist.
    Confirm the current video is selected, use all four arrows, scroll, and take
    Library-Detail-before. Selected must reuse the full-card Hover visual with
    no Focus Ring, border, or independent selected fill. Verify four-arrow
    navigation and the shared card context menu with no item named `Context`.
    Playback Video Cards must match Workbench Folder Detail card layout and
    content exactly apart from persistent selection. Leave and return with the
    top tabs, then take Library-Detail-after and compare the selected identity
    and named Video Card top-edge coordinate. Within that Session, left-click
    the Video Card chosen for the second unsaved Cue; each original pointer
    action must occur once, and video playback must destroy the Overlay and open
    that exact video.
12. Reopen the Overlay and enter Shiori. Confirm only subtitle Results appear.
    Select a non-first Result, scroll to a named position, and take Shiori-before.
    Click Current, navigate to the planned second unsaved Primary Cue, and save
    it. If that Cue is no longer unsaved, select a different unsaved Cue from the
    currently playing Episode and record its identity before saving. Click
    Shiori again and take Shiori-after: the previously selected Result identity
    and exact pixel offset must survive even though the new Shiori was inserted
    first. Hover and click selected and unselected Shiori Results. There must be
    no Result hover state or pointer cursor, and both clicks must remain inert.
    Verify C preserves the selected Primary Cue's complete line breaks and S
    reports `Shiori Already Saved` without deleting or duplicating it.
13. Create nondefault state in Current, Playback Search, Recent, both Library
    levels, Shiori, and Playlist when available, then press Escape. Confirm no
    implicit seek and restoration of the playback state captured at Overlay
    open. Reopen with Enter and visit every available module: the new Session
    must start on Current; Playback Search must show the current shared Search
    Query but reset its Overlay-local selection and offset. A Video Playlist
    must select its current available video and use an initial offset that only
    reveals that card when needed. A Cue Playlist must reopen at its default
    first Result.
14. In separate fresh Sessions, execute playback Enter from Current, Cue
    Playlist, Playback Search, Recent, Video Playlist, and Shiori. For Current,
    Cue Playlist, and Shiori, also verify S and C against the settled Primary
    Cue; use already saved targets for these repeated S checks so no third test
    Shiori is created. Search continues to treat S/C as editor input. Every
    playback Enter must execute at most once under key repeat, destroy the
    Session before seek or media open, and use the exact selected Primary Cue or
    video-card action.
    Across separate successful runs, close Playback after playing from Search,
    Shiori, Recent, and Video Playlist. Require return to current Workbench
    Search with its current Query, Workbench Shiori, Workbench Recent, and the
    exact Workbench Library Folder Detail respectively. Failed playback and
    module-only browsing must retain the prior Return Context; after close the
    context must not leak into the next Playback Page.
15. Start playback from Workbench Shiori, open the Overlay, and mechanically
    compare Playlist's final count and the Primary Cue texts at Sequence 1,
    Sequence 2, and the last Sequence against the existing Shiori
    navigation scope. Start playback from Library and then Recent; Video
    Playlist must show only the current folder's shared Video Cards and select
    the current video when each new Overlay Session opens.
16. Build a `Show Cue Group = On` comparison ledger using explicit count
    bridges; Search and Shiori Overlay do not expose a numeric count of their
    own. For Playlist, use the last Sequence Number from one fixed
    Workbench-origin source and record `L_on`. For Playback Search, run one fixed
    query, press Enter to promote it, reopen Playlist, and use its last Sequence
    Number plus the matching filter-free Workbench Exact `xx rows` value using
    the action 9 method; record the matched value as `Q_on`. For Shiori, record
    Workbench Shiori's `xx rows` value as `H_on` before starting playback from
    one fixed Shiori Result. On all three Overlay surfaces, also record one
    Primary Cue's complete text and stable source order position as its
    observable identity. Exit Playback, which destroys the Session, turn
    `Show Cue Group` Off, and repeat the same three bridges with the same origin,
    query, and Shiori scope to obtain `L_off`, `Q_off`, and `H_off`. Each new
    Session must select its default first item; it must not preserve the prior
    Session's selection. Navigate to each recorded Primary Cue by its stable
    source position. Require `L_on == L_off`, `Q_on == Q_off`, and
    `H_on == H_off`; order positions, Primary Cue text, identity, and actions
    must also match exactly. Only Additional Cues may disappear; Current and
    every Primary Cue must otherwise remain unchanged.
17. Start a broad Playback Search and close the Playback Page immediately. The
    shared Search Query and loaded Feature results must remain visible in
    Workbench, while Overlay-local selection, offset, feedback, and pending
    presentation work disappear. In a separate run, enter Video Playlist and
    immediately close Playback. Wait two seconds, open a different video, and
    reopen the Overlay: no old Overlay hierarchy, selection, offset, feedback,
    error, or late presentation work may appear, while shared Workbench Feature
    data remains intact.
18. Optionally repeat open, full Tab cycle, and Escape twenty times while
    observing `scripts/watch_player_memory.sh`. After warm-up, retained memory
    must not grow monotonically with every destroyed Session. Report this
    optional observation separately; it is not required to pass this gate.

### Log Review And Handoff

After actions 1 through 17, optionally action 18, quit the packaged app and
wait for the End marker. In Terminal B run this exact review:

```bash
LOG=/tmp/cueseeker-playback-multi-module-overlay.log
FAILURE_PATTERN='(Fatal error:|Assertion failed:|Precondition failed:|NSInternalInconsistencyException|uncaught exception|Native playback failed:|Failed to (open Playback Subtitle Focus|play continuously from cue|load|hydrate)|(Open|Prepare|Execute|Bind|Step) failed:)'
start_count="$(rg -c '^=== CUESEEKER OVERLAY E2E START ' "$LOG" || true)"
clean_end_count="$(rg -c '^=== CUESEEKER OVERLAY E2E END .* exit=0 ===$' "$LOG" || true)"
failure_matches="$(rg -n "$FAILURE_PATTERN" "$LOG" || true)"
if [[ "$start_count" == 1 && "$clean_end_count" == 1 && -z "$failure_matches" ]]; then
  echo 'OVERLAY_E2E_LOG_REVIEW=PASS'
else
  echo 'OVERLAY_E2E_LOG_REVIEW=FAIL'
  printf '%s\n' "$failure_matches"
fi
sed -n '/^=== CUESEEKER OVERLAY E2E START /,/^=== CUESEEKER OVERLAY E2E END /p' "$LOG"
```

The assistant interprets the log only as follows: exactly one Start marker,
exactly one End marker with `exit=0`, no line matching `FAILURE_PATTERN`, and the
literal `OVERLAY_E2E_LOG_REVIEW=PASS` are required. Paste the complete `sed`
range from Start through End even when it contains no diagnostic lines. On a
failure, identify the action and include the visible result plus the log from
the Start marker through at least two seconds after that action; do not treat a
missing log line as evidence that a visible failure passed.

### Evidence To Paste Back

- The seven-character commit hash and packaging verification result.
- The complete output of all four deterministic prerequisite commands.
- Pass/fail for actions 1 through 17; action 18 is optional.
- `OVERLAY_E2E_LOG_REVIEW=PASS` and the complete Start-to-End log range.
- `pbpaste` output for the multi-line Current Cue, one Playlist Primary Cue, and
  the selected Shiori Result.
- Both count/order ledgers. Each must include the early partial count, the first
  larger count, candidate Playlist count, final Workbench `xx rows`, Primary Cue
  text at first/second/last, and a per-field match result.
- The Show Cue Group On/Off ledger with the Playlist Sequence, promoted Search
  Playlist plus Workbench Exact, and Workbench Shiori count bridges, including
  `L_on/L_off`, `Q_on/Q_off`, and `H_on/H_off` equality results.
- Each inconclusive source-growth attempt, its query, and why it was retried;
  inconclusive attempts are neither passes nor product failures.
- One screenshot of the full Sidebar and one screenshot each of Playlist with
  Sequence Numbers, focused Playback Search with marked IME text, Recent,
  Library Detail, Shiori, and feedback above the Overlay.
- The named before/after screenshot pairs for Current, Playlist, Playback
  Search, Recent, Library Folder, Library Detail, and Shiori. State the selected
  identity and screen-space top-edge coordinate used for every pixel comparison.
- A recording from the early Workbench Result open through Playlist growth and
  ledger capture, a recording of Playback Search promotion through its Playlist
  growth, Shiori identity preservation after prepend, and one Enter
  teardown/reopen cycle.
- On failure, the exact action, visible result, and required marked log range.

### Acceptance Criteria

The gate passes only if:

- Sidebar order, optional Playlist behavior, icons, effective Light, Dark, and
  Auto appearance, live appearance-state preservation, two-color selection, no
  Divider, and non-collapsible layout match the human UI document. Unmodified
  Tab is the only module-cycle command.
- Current retains its accepted Cue geometry and navigation. Playlist, Search,
  and Shiori share the same Focus Anchor, dynamic Result geometry, scrollbar,
  motion, and viewport-bounded behavior; Result clicks remain inert.
- Workbench and Playback Search are live with the 100-millisecond debounce.
  Playback Search preserves native IME editing focus and promotes the same
  still-growing source into Playlist without freezing an early snapshot. Both
  count/order ledgers and their deterministic prerequisites must match exactly.
- Playlist sequence, Search/Shiori Primary Cue actions, Show Cue Group, Recent
  cards, and both Library levels match their documented existing data order and
  pointer behavior.
- Every module restores its own within-Session selection and exact native scroll
  offset, supported by its named before/after pair. A Shiori prepend preserves
  the selected Result identity, and Library Back restores the previous Folder
  state. Sidebar, Cue Result, Recent, and Library pointer checks all pass.
- S/C keep the Overlay paused and open; Enter playback and media-card actions
  synchronously destroy it. Space is consumed without an action. Escape restores
  the captured playback state without seeking. The cancellation prerequisites
  pass, and Playback Page close or source replacement never publishes stale
  state in the manual runs.
- Every reopened Overlay is a new Session beginning on Current for a video
  Playlist or no available Playlist, and on Playlist for a Cue Playlist, with
  no prior query, temporary rows, hierarchy, selection, offset, task, or cache.
  Turning Show Cue Group Off across such Sessions preserves the recorded Primary Cue
  content, identity, count, order, and action while correctly resetting the new
  Session's selection to its default.
- No crash, stale action, duplicate playback open, pointer-region regression,
  hidden feedback, unexpected seek, or blocked input method is observed, and the
  exact log review prints PASS.

### Cleanup

- In Workbench Shiori, remove both Shiori created solely for actions 4 and 12.
- Restore the starting `Show Cue Group` value.
- Restore the recorded Workbench Search query and filters.
- After evidence is safely retained, restore the original clipboard and remove
  the temporary artifacts:

```bash
pbcopy < /private/tmp/cueseeker-overlay-e2e-clipboard-before.txt
rm -f /private/tmp/cueseeker-overlay-e2e-clipboard-before.txt
rm -rf /private/tmp/CueSeeker-Overlay-E2E.app
rm -f /tmp/cueseeker-playback-multi-module-overlay.log
```

- The Recent and Library playback actions update normal Playback History. Use
  disposable media for this gate if those durable history updates must not
  remain in the personal Library.

## 9. Library Detail Shared Cover Summary

### Feature

Verify that Workbench Library Folder Detail renders the shared adaptive Cover
Summary above its shared Recent-style Video Card Grid, uses the current folder
metadata and cover, and keeps both regions in one scroll context. This visual
gate does not activate Play or Resume and therefore does not alter Playback
History.

### Preconditions

- Use a Debug build at the requirement commit or its implementation descendant.
- At least one current Library folder has one available Episode.
- Start on the Workbench Shiori overview with its first list visible.
- CueSeeker starts with one visible main window and the 240-point Sidebar
  expanded.
- Record the active Light or Dark appearance with the evidence; repeat the gate
  in the other appearance during final visual acceptance.
- Recent and Shiori Sidebar groups are expanded. Let the main-window frame from
  `inspect` be `M`, with `M.minX`, `M.minY`, `M.maxX`, and `M.maxY`. Under this
  layout, use Library `(M.minX + 80, M.minY + 217)`, Data
  `(M.minX + 80, M.minY + 253)`, Shiori
  `(M.minX + 80, M.minY + 289)`, Shiori's first list
  `(M.minX + 80, M.minY + 325)`, the first Library folder card
  `(M.minX + 360, M.minY + 210)`, and the safe detail scroll point
  `(M.maxX - 64, M.maxY - 64)`.
- Stop without clicking if `inspect` reports another window count or layout.
  Screenshots must not be used to recalculate coordinates.

### Build And Launch

Run from a PTY so the same process accepts controller commands:

```bash
cd apps/macos-native
swift run CueSeeker --cueseeker-debug-e2e
```

No diagnostic environment variable or separate unified-log stream is required.
The `CUESEEKER_E2E` records in this terminal are the controller log. Every
action must return `status: ok`, and each following action must use the fresh
`sceneID` returned by the preceding action.

### Actions And Evidence

1. Send `{"action":"inspect"}` and verify the complete-scene preconditions.
2. Send a named `capture` for `library-cover-summary-before`.
3. Click Shiori's first list at its documented coordinate and capture
   `shiori-cover-summary-reference`. With the Sidebar expanded, its accepted
   Cover Summary horizontal edges are `M.minX + 240 + 32` and `M.maxX - 32`.
4. Click Library at its documented coordinate, wait for the existing bounded
   post-click delay, and capture `library-cover-summary-overview`. The overview
   must be loaded; stop if the first card is absent or still loading.
5. Click the first folder card at its documented coordinate and capture
   `library-cover-summary-detail` after the response.
6. Verify the detail capture shows, in order, one folder title, one
   `xx videos yy subtitles` line, the complete folder path, and one Resume or
   Play button. The displayed counts must equal the current Video Card Grid count,
   the background must fill the rounded summary without distortion or padding,
   and the summary and grid must have the same horizontal edges. The Library
   Cover Summary edges must also equal the Shiori reference and the documented
   window-relative bounds.
7. At the documented safe detail scroll point, issue one `scroll` with
   `deltaY: -4`, then capture `library-cover-summary-scrolled`. The Cover
   Summary and Video Card Grid must move in the same page viewport; no nested
   vertical scrollbar may appear.
8. Issue one `scroll` at the same coordinate with `deltaY: 4`. Restore the
   original Shiori overview with the documented Shiori coordinate, then capture
   `library-cover-summary-restored`.

Each named image path and the complete controller records from `inspect`
through the restored capture are the evidence handoff. A valid failure report
names the action and includes its last successful `sceneID`, the returned error
or visible mismatch, and the corresponding capture path. Examples include a
count different from the Video Card Grid, metadata sharing one line, an image with
letterboxing or stretching, unequal horizontal edges, or a second scrollbar.

### Acceptance Criteria

- All controller actions return `status: ok` for the unchanged complete scene.
- Library detail contains one shared full-width Cover Summary followed by the
  shared Recent-style Video Card Grid in the same viewport.
- Shiori and Library Cover Summary horizontal edges both equal
  `M.minX + 240 + 32` and `M.maxX - 32` in the accepted complete scene.
- Title, folder-local counts, complete path, and Resume or Play are separate,
  readable rows; the button is Disabled only when no playable content exists.
- The cover remains aspect-fill and center-cropped, with the existing shared
  radius, scrim, text, button, and spacing in the active appearance.
- Scrolling moves the summary out with the grid and exposes no nested vertical
  scrolling or horizontal-boundary mismatch.

### Cleanup

- Restore the starting Workbench Shiori overview before quitting so the Debug
  run does not leave the persisted panel mode changed.
- Quit the Debug process with Control-C after recording the final controller
  response. The temporary E2E artifact directory may be deleted after evidence
  review; no product data cleanup is required because playback is not opened.

## 10. Shared Video Card And Media Navigation

### Feature

Verify that Library Folder Detail and Playback Video Playlist reuse the Recent
Videos card, that a new Playlist Session selects the current video, that a
revisited Playlist preserves Session-local selection, and that selection reveal
keeps every keyboard-selected item fully visible without forcing visible cards
to the viewport center. Pointer Hover remains the explicit manual portion of
this gate.

### Automated Checks

Run:

```bash
cd apps/macos-native
swift test --filter 'PlaybackLibrary|playbackMedia|WorkbenchScrollView'
swift test --filter 'playbackCommandPanel|recentShioriPlayback'
```

The checks must confirm preferred-current selection with unavailable fallback,
Session continuity, adaptive media-grid navigation, exact scroll-offset
retention, nearest-edge reveal, no scrolling for an already fully visible
target, and top or bottom reveal for partially visible and unmaterialized
Command Panel Recent Video targets.

### In-App E2E Preconditions

- Use the Debug in-app controller.
- Start on the Workbench Recent overview with Library at `(80, 217)`.
- The first Library folder at `(360, 210)` has at least two available videos;
  its first Video Card is at `(380, 390)` after detail loading.
- Stop if `inspect` reports another window count or layout, or if any documented
  card is unavailable.

### In-App E2E Actions

1. Capture Recent Videos, click Library, click the first folder, and capture
   `shared-video-card-library-detail`. Confirm every Video Card uses the same
   folder title, `EPxx`, watch-status Badge, progress, and time structure as
   Recent Videos; the removed left-cover/right-metadata row must not appear.
2. Click the first Video Card, press Enter to open the Overlay, press Tab to
   enter Playlist, and capture `shared-video-card-playback-playlist-current`.
   The current first video must be Selected with the complete card Hover visual.
3. Press Right Arrow to select the second video and capture
   `shared-video-card-playlist-session-before`. Press Tab twice and capture
   `shared-video-card-playlist-session-after`; identity and pixel position must
   match the before capture.
4. Press Enter to play the selected second video. Reopen the Overlay with Enter,
   enter Playlist with Tab, and capture
   `shared-video-card-playlist-new-session-current-ep02`. The second video must
   be Selected in the new Session; the first video must not be Selected.

Every command must return `status: ok` with a fresh scene identifier. The card
Grid must keep its top edge while a fully visible selection changes. Repeated
keyboard movement must leave the final Selected card fully inside the viewport;
a partially visible card is invalid and may be revealed only at the nearest
edge.

### Manual Hover Acceptance

With Pointer visible, verify card and Recent Shiori Hover. Use keyboard or
controller input to hide Pointer and confirm Hover visuals disappear while
keyboard Selected remains. Move the mouse across cards and confirm Hover
returns and changes independently without changing or clearing Selected. No
Pointer Move automation is added for this requirement.

## 11. Workbench Topbar And Page Title Hierarchy

### Feature

Verify the shared Workbench function topbar, Back routing, page-title hierarchy,
count-free Recent detail titles, compact baseline-aligned Recent overview
navigation, and the reduced Cover Summary detail top spacing across the eight
affected routes.

### Automated Checks

Run:

```bash
cd apps/macos-native
swift test --filter 'WorkbenchLayoutState|workbenchPageTitle'
```

The checks must confirm that Back is enabled only for Recent Videos, Recent
Shioris, Library Folder Detail, and Shiori List Detail; page titles reuse the
28-point Cover Summary title size without a count path; Recent overview section
titles and counts remain 18 and 14 points with 8-point title-to-count and
4-point count-to-arrow spacing; the six titled pages share 32-point horizontal,
4-point top, and 24-point bottom padding; and the shared detail top padding is
exactly 20 points smaller than the previous 24-point page padding.

### In-App E2E Preconditions

- Use the Debug in-app controller with one visible main window. Recent and
  Shiori are expanded and the Sidebar is visible.
- Set Settings > Appearance to Light before the first run and repeat the gate
  in Dark. Restore the starting appearance during cleanup.
- Let the main-window frame from `inspect` be `M`. The accepted expanded-Sidebar
  coordinates are Sidebar Toggle `(M.minX + 212, M.minY + 23)`, Back
  `(M.minX + 280, M.minY + 23)`, Search `(M.minX + 80, M.minY + 73)`, Recent
  `(M.minX + 80, M.minY + 109)`, Recent Videos
  `(M.minX + 80, M.minY + 145)`, Recent Shioris
  `(M.minX + 80, M.minY + 181)`, Library
  `(M.minX + 80, M.minY + 217)`, Data
  `(M.minX + 80, M.minY + 253)`, Shiori
  `(M.minX + 80, M.minY + 289)`, Shiori's first list
  `(M.minX + 80, M.minY + 325)`, and the first Library folder card
  `(M.minX + 360, M.minY + 210)`.
- On the expanded-Sidebar Recent overview, the Recent Videos header title,
  count, arrow, and same-row blank checks are
  `(M.minX + 300, M.minY + 109)`, `(M.minX + 407, M.minY + 109)`,
  `(M.minX + 429, M.minY + 109)`, and `(M.maxX - 64, M.minY + 109)`.
- With the Sidebar collapsed, Sidebar Toggle is
  `(M.minX + 114, M.minY + 23)` and Back is
  `(M.minX + 158, M.minY + 23)`.
- Stop before clicking if `inspect` reports another window count or layout, or
  if the documented Library folder and Shiori list are absent. Screenshots must
  not be used to recalculate coordinates.

### In-App E2E Actions

1. Open Search and capture `workbench-search-primary-{appearance}`. Click Back
   and capture again; Search must remain active because Back is Disabled.
2. Open Recent and capture `workbench-recent-primary-{appearance}`. Confirm the
   page title is visually larger than the unchanged Recent Videos and Recent
   Shioris section titles. Require each 14-point count and compact arrow to use
   the title's first text baseline.
3. Click the blank check and require the Recent overview to remain active. Click
   the Recent Videos title and capture `workbench-recent-videos-{appearance}`;
   require no page-title count, then click Back. Repeat with the count and arrow
   checks, requiring the same detail route each time. Open Recent Shioris from
   the Sidebar and capture `workbench-recent-shioris-{appearance}` with no
   page-title count.
4. Open Library and capture `workbench-library-primary-{appearance}`. Open the
   first folder and capture `workbench-library-detail-{appearance}`; require one
   Cover Summary title and no duplicate page title. Click Back and require the
   Library overview.
5. Open Data and capture `workbench-data-primary-{appearance}`. Click Back and
   require Data to remain active because Back is Disabled.
6. Open Shiori and capture `workbench-shiori-primary-{appearance}`. Open its
   first list and capture `workbench-shiori-detail-{appearance}`; require one
   Cover Summary title and no duplicate page title. Click Back and require the
   Shiori overview.
7. Return to Recent, collapse the Sidebar at its documented coordinate, and
   capture `workbench-recent-primary-collapsed-{appearance}` with the compact
   navigation groups intact. Expand the Sidebar at its documented coordinate,
   reopen the first Shiori list, collapse again, and capture
   `workbench-shiori-detail-collapsed-{appearance}`. Click Back at its documented
   coordinate and capture `workbench-shiori-primary-collapsed-{appearance}`.
   Expand the Sidebar before repeating the gate in the other appearance.

Every interaction must return `status: ok` and the next interaction must use
its fresh `sceneID`.

### Acceptance Criteria

- Outside the unchanged Sidebar segment, the app topbar contains only Back and
  no title. Back is Disabled on all five primary pages and Enabled on all four
  secondary pages, where it returns to the owning primary page.
- Search, Recent, Library, Data, Shiori, Recent Videos, and Recent Shioris use the
  same 28-point Bold page-title style with the semantic Primary text color.
  Their title, Summary, action, and Grid or List content share 32-point
  horizontal bounds, 4-point top padding, and 24-point bottom padding.
- Recent Videos and Recent Shioris detail titles append no count.
- Recent overview section titles remain 18-point Semibold and their counts
  remain 14-point Regular Secondary with monospaced digits. Title, count, and
  arrow share the first text baseline; the arrow follows the count by 4 points.
  The visible group is one click target, while same-row blank space is inert.
- Library and Shiori details add no page title above Cover Summary. Their Cover
  Summary titles remain 28-point Bold White, and both detail bodies use the
  shared 4-point top padding instead of 24 points.
- Light, Dark, expanded-Sidebar, and collapsed-Sidebar captures have no clipped,
  duplicated, or overlapping title or navigation control.

### Cleanup

- Restore the starting appearance, expanded Sidebar, and Shiori overview.
- Quit the Debug process with Control-C. The temporary capture directory may be
  removed after evidence review; this gate does not change product data.

## 12. Dock Window List

### Feature

Verify that the native Dock menu lists CueSeeker-owned windows with stable
labels and lets AppKit own focus indication and window activation.

### Preconditions And Launch

Run the current build without diagnostic environment variables:

```bash
cd apps/macos-native
swift run CueSeeker
```

No diagnostic log output is expected. Keep the main window open and close the
Settings window before starting.

### Manual Actions

1. Right-click the running CueSeeker Dock icon. Require one `CueSeeker` window
   item, no `Settings` item, and a checkmark beside `CueSeeker`.
2. Open Settings with Command-comma, then right-click the Dock icon. Require
   both `CueSeeker` and `Settings`, with only `Settings` checked.
3. Choose `CueSeeker` from the Dock menu. Require the main window to become key;
   reopen the Dock menu and require only `CueSeeker` to be checked.
4. Choose `Settings` from the Dock menu. Require Settings to become key; reopen
   the Dock menu and require only `Settings` to be checked.
5. Close Settings. Require `Settings` to disappear from the Dock menu while
   `CueSeeker` remains.
6. Navigate through Workbench and start video playback. Require the main-window
   Dock item to remain `CueSeeker` in both states.

### Failure Examples

- Only `Options`, `Show All Windows`, `Hide`, and `Quit` are present.
- A page, category, or video title replaces `CueSeeker` or `Settings`.
- Closing Settings leaves a stale item, or choosing an item does not activate
  its window.
- The checkmark does not follow the key window.

### Evidence And Cleanup

Provide Dock-menu screenshots for steps 1 through 5 and report whether step 6
kept the `CueSeeker` label. Quit CueSeeker after the check; no files or product
data are created by this procedure.
