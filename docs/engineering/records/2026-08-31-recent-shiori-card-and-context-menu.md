# Recent Shiori card and context menu

Human-owned documents:

- `docs/human/requirements/20260831-UI-Recent Shiori Card And Context Menu.md`

## Why

Recent Shioris was the one place a Shiori list did not look like a Shiori list.
The Shiori page has always shown a card — cover, cue-count badge, name,
description — with a right-click menu for editing and deleting. The three Recent
surfaces instead showed a wide resume row: the same cover beside a stack of
name, description, resume position and the most recent cue, with no menu at all
and no hand pointer.

So the same object had two appearances depending on where the reader met it, and
the two Recent interfaces plus the Command Panel could not act on a list without
first navigating to the Shiori page. The requirement settles it in one
direction: the card is the Shiori list, everywhere.

The resume position and the recent cue text disappear with the row. That loss is
accepted in the requirement rather than worked around with a card variant,
because a second card shape would reintroduce the split the change is closing.

## What changed

### One card, one menu, four interfaces

The card and its menu were private to the Shiori page. They now live in a shared
grid that all four interfaces mount: the Shiori page, the Recent overview, the
Recent Shioris section and the Command Panel's Recent Shioris page. The grid
resolves "edit", "delete" and "may this list be deleted" from the app state
itself, so no call site repeats the menu, and a change to the menu lands in all
four places at once.

The grid follows the pattern the video cards already use. When the page hosts
the right-click menu at its own root — the Recent page does, so a menu opened
from a video card is not painted under the Shiori section below it — the grid
uses that host instead of standing up one of its own.

Files: `Shiori/ShioriListCardGrid.swift` (new),
`Shiori/ShioriListOverviewView.swift`, `TableSandbox/WorkbenchTestLibraryView.swift`.

### The Command Panel's two Recent pages became one page

Recent Shioris was a one-dimensional list: up and down moved by one, left and
right did nothing. As a grid it needs what Recent Videos already had — a column
count measured from the panel's width, the on-screen position of every card, and
a scroll that only moves when the keyboard's card is actually off screen.

Rather than copy that plumbing, the two pages now share one: they differ only in
their title, the grid they show and the count in the footer. The store state and
the coordinator entry point that carried it were named after Recent Videos and
are now named for what they are — the Recent card grid — with the page itself
answering whether it is laid out as a grid.

Files: `Playback/SubtitleFocus/PlaybackCommandPanel.swift`,
`Playback/PlaybackStore.swift`, `App/AppCoordinator+PlaybackCommandPanel.swift`,
`App/AppCoordinator+Playback.swift`.

## Verification

- `swift build` — clean.
- `swift test` — 1125 tests. The failures are the pre-existing environment- and
  timing-dependent ones: native playback audio and presentation transitions, the
  window-scene geometry checks, the user-defaults migration assertion, and the
  refresh-scope integration waits. Two of those, `shioriTableStartsAtTopAfterPanelRemount`
  and `showCueGroupInvalidationIsScopedToMountedShiori`, fail deterministically;
  both were confirmed failing on the parent commit `6282827d` with the change
  stashed, so neither is caused by this work. The suites closest to the change —
  the Command Panel keyboard actions, card highlight, card menu placement, Shiori
  presentation and navigation, media selection — pass.

Debug in-app E2E against the running App, main window `1445 × 821`, using the
existing `click`, `rightClick`, `keyPress` and `capture` commands. No E2E command
or test facility was added.

- **Shiori page.** The overview still renders its card grid unchanged after the
  card moved out of the page file.
- **Recent overview.** Recent Shioris renders five cards in the same grid as the
  Recent Videos section above it, cover badge and all. Right-clicking a card
  opens Edit List / Delete List and leaves that card lit.
- **Recent Shioris section.** The same grid at full width; right-clicking the
  second card opens the menu on that card.
- **Command Panel Recent Shioris.** The page now shows the card grid with the
  first card selected. Two right-arrow presses move the selection two cards along
  the row, which the old list could not do. Right-clicking the fourth card opens
  the menu there and moves the highlight onto it, and choosing Edit List opens the
  Shiori List Editor dialog above the panel.

Dark theme was not captured. The card is the existing component with its existing
tokens and no new colour values, and it already ships in dark on the Shiori page,
but the requirement's acceptance asks for both themes and that check is
outstanding.

Outcome matched expectations.
