# Table Sandbox Step 5 — Phase B3: Hover Play/Copy Buttons on the Cues Cell

Human requirement:

- `docs/human/requirements/20260605-Feature-UI Redesign.md` (item 7)

## Scope

Phase B3 adds the Notion-style hover actions to the Cues cell. Platform UI/UX
only; still on static sample data.

- `CueHoverButtons` (SwiftUI): a small floating toolbar with two buttons,
  `Play` (play.fill) and `Copy` (doc.on.doc), each reusing the existing
  `ToolbarButtonStyle`. The toolbar has an opaque background + hairline border so
  it stays readable over the cue text.
- `SubtitleCuesCellView` (subclass of `SubtitleTextCellView`, which is no longer
  `final`): hosts the toolbar via `NSHostingView`, pinned to the cell's left,
  hidden by default and shown only while the pointer is over the Cues cell.
  Selection, drawing, and mouse handling are inherited, so text selection still
  works where the buttons aren't.
- Coordinator: `viewFor` now dequeues `SubtitleCuesCellView` for the Cues column
  and wires `onPlay`/`onCopy`. `playRow` calls the table's `onPlay` closure
  (real playback is wired in B4); `copyRow` copies that row's merged cue text to
  the pasteboard.

Per the requirement, the buttons are not hidden during a drag selection.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- End-to-end (owner): hover a Cues cell shows Play/Copy at its left; Copy puts
  the cue text on the clipboard; Play logs in this phase (sample data). Text
  selection and cmd+A/cmd+C from B2 still work.

## Fix — hover lifecycle bugs found in E2E

Two bugs reported after scrolling/hovering:

- Multiple cells showed the buttons after scrolling: a recycled cell kept its
  previous "shown" state. Fixed by resetting the buttons to hidden in
  `setActions` (called on every reuse in `viewFor`).
- Buttons vanished when moving off a button but still inside the cell: crossing
  onto/off the buttons subview fires a spurious `mouseExited`. Fixed by ignoring
  the exit while the pointer is still inside the cell's bounds.

## Fix 2 — centralized hover (row background + buttons)

The first fix only addressed the buttons; the row hover background still showed
on multiple rows after fast scrolling, because per-view tracking areas are
unreliable across reuse/fast scroll. Reworked hover into a single source of
truth:

- Removed the per-cell and per-row tracking areas. `SubtitleTableRowView.isHovered`
  and `SubtitleCuesCellView.setButtonsVisible` are now set externally.
- The table has one tracking area (`mouseMoved` + entered/exited). The
  coordinator keeps a single `hoveredRow` (the row under the cursor) and, on
  change, hides the old row's background/buttons and shows the new one's.
- Scrolling recomputes the hovered row from the last mouse point (clip-view
  bounds-change observation), so a stationary cursor over a scrolling list keeps
  exactly one row hovered.
- `viewFor` / `rowView(forRow:)` initialize hover state from `hoveredRow`, so
  recycled views are always correct.

This fixes both the multi-row hover after scrolling and the buttons vanishing
when moving between the buttons and the cell text.

## Fix 3 — memory: drop SwiftUI entirely, use AppKit hover buttons (option B)

E2E showed ~60MB memory growth on fast scrolling. A first attempt to reduce the
SwiftUI hosting to a single shared toolbar did not help, so per the owner's
decision that attempt was reverted (`git revert`) and the hover buttons were
reimplemented in pure AppKit (no `NSHostingView`/SwiftUI at all in the table):

- `PillButton` (NSView): icon + title, rounded, subtle hover/press background
  matching the toolbar look, with its own click handling.
- `CueButtonsToolbar` (NSView): opaque background + hairline holding the Play and
  Copy pills.
- `SubtitleCuesCellView` hosts the AppKit toolbar (hidden by default). Central
  hover still drives a single visible row's `setButtonsVisible`; `setActions`
  wires `onClick` to `playRow` / `copyRow`.
- Removed the SwiftUI `CueHoverButtons`. The table no longer instantiates any
  SwiftUI view per cell.

Introducing one AppKit button family here is an accepted, deliberate deviation
from the app's otherwise all-SwiftUI buttons.

## Outcome

Build green; Phase B3 complete (pending the owner's memory re-check). Phase B
(sandbox table on fake data) is feature-complete: virtualized table,
fonts/wrapping, cross-row/column selection with the frozen header, cmd+A /
cmd+C (TSV), drag auto-scroll, and AppKit hover Play/Copy. Next is B4 (real
data, Search box, playback wiring).
