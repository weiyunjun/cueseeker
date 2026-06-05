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

## Outcome

Build green; Phase B3 complete. Phase B (sandbox table on fake data) is now
feature-complete: virtualized table, fonts/wrapping, cross-row/column selection
with the frozen header, cmd+A / cmd+C (TSV), drag auto-scroll, and hover
Play/Copy. Next is B4 (real data, Search box, playback wiring).
