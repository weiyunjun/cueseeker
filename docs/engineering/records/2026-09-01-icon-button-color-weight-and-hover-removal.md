# Icon Button Color, Weight And Hover Removal

Human-owned requirement:
`docs/human/requirements/20260901-UI-Icon Button Color Weight And Hover Removal.md`

Related design: `docs/human/design/UI Design System.md`
(Icon Button, Sidebar Toggle, Sidebar Item, Dialog, Command Panel Secondary Layout,
Icon, Text, Background).

## Why

The neutral text ramp accepted on 2026-08-30 turned the text tokens into pure
greys but explicitly left the icon tokens alone, so every pure icon button kept
the older blue-cast slate value while the text beside it went neutral. The icon
weights were never written down at all, which let three different values
(Semibold, Bold, Medium) accumulate across buttons that are meant to read as one
control. This change moves the pure icon buttons onto the text ramp, gives their
weight a single token, removes their hover background, and shrinks the Dialog
close glyph.

## Implementation

New tokens, all recorded next to the metrics they belong with:

- `--weight-control-icon` = `medium`, applied to every pure icon button.
- `--size-dialog-close-icon` = `14px`, applied to the Dialog close button through
  a new optional `iconSize` on `WorkbenchIconButton`; every other instance keeps
  `--size-control-icon`.
- `--size-app-sidebar-item-chevron` = `10px`, recording the sidebar expansion
  chevron's existing glyph size so it is no longer a bare number.

Retired: `--color-bg-active-clear-hover`. Its only call site already passed
`isActiveContext: false`, so the branch was dead before the hover removal; the
parameter went with it.

Colors: Default moved from `--color-icon-default` (and `--color-icon-muted` on the
sidebar chevron and the inline clear) to `--color-text-secondary`; Disabled moved
from `--color-icon-disabled` / `--color-icon-muted` to `--color-text-disabled`.
The three icon tokens stay because the search magnifier, Sidebar Item icons, the
labelled buttons' leading icons, the Library file tree and Settings still use them.

Hover: `WorkbenchIconButton`, `WorkbenchInlineClearButton` and the sidebar toggle
lost their `isHovered` state and hover background. The icon button's background
now only answers the open state. The sidebar toggle's disabled look moved from a
blanket opacity to an explicit disabled icon color, matching the other buttons.
The Command Panel secondary Back lost its always-on `--color-bg-hover` fill and
went from a 48pt box with a 10pt radius to `--size-icon-button`; with no
background left, the radius has nothing to draw and the button is a bare glyph
with a click region.

Files: `Shared/WorkbenchRedesignTokens.swift`,
`Shared/WorkbenchControls/WorkbenchControls.swift`,
`Shared/WorkbenchControls/WorkbenchDialogHeader.swift`, `Tasks/TaskPanel.swift`,
`Workbench/ContentView.swift`,
`Playback/SubtitleFocus/PlaybackCommandPanel.swift`.

## Verification

- `swift build` — clean.
- `swift test` — 1125 tests. The failures are the repository's existing
  environment- and timing-dependent set: native playback media timelines, the
  auto-pause seek boundary and the cue-group refresh-scope waits. They are the
  same set recorded on the previous requirement and none of them touch control
  styling.

Debug in-app E2E against the running App, main window `1445 x 821`, scale 2, using
`click`, `keyPress`, `mouseMove` and `capture`. No E2E command or test facility was
added. Colors below are read out of the captured PNGs, not judged by eye.

Light theme:

- Sidebar toggle, top-bar Back, task entry, sidebar Recent chevron, search clear,
  filter trigger, Shiori List Editor close, task panel close — all `#494949`,
  which is `--color-text-secondary`.
- Back on a primary page (disabled) — `#9A9A9A`, which is `--color-text-disabled`.
- Search magnifier — `#667085`, unchanged and out of scope, so a search field now
  shows a slate magnifier beside a neutral clear button. This is the split the
  requirement leaves open.
- Dialog close and task panel close glyphs measure 22 x 22 device pixels, 11pt,
  against the filter trigger's 16pt glyph: the close buttons shrank, the button
  boxes did not.
- Task entry open state: accent fill with a white glyph, unchanged.

Dark theme, switched through Settings > Appearance and restored to Light
afterwards:

- The same buttons — `#B9B9B9`; disabled Back — `#606060`; magnifier — `#A1A1AA`.
- Task panel close glyph again 22 x 22 device pixels; task entry open state again
  accent fill with a white glyph.

Not verified in the running App:

- **Hover removal.** `onPointerHover` is SwiftUI `.onHover`, and the controller's
  documented limit is that a synthesized `mouseMove` never reaches it. The hover
  state and its background were deleted from the source, but confirming the
  absence on screen stays a manual acceptance step.
- **Command Panel secondary Back.** Reaching it needs the `K` shortcut on the
  playback page, and the controller's key events did not reach that app-level key
  hook in this session; the window kept losing key status. Its change is verified
  by source only and needs a manual check.
