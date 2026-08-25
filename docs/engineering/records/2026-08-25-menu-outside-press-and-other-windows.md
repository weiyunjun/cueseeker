# Menu outside press and other windows

Human-owned documents:

- `docs/human/requirements/20260825-UI-Menu Outside Press And Other Windows.md`

## Why

Every menu had written its own answer to "what happens to a press that did not
land on me", and the four answers disagreed. Pressing inside the Settings window
closed the table row menu, left the card menu alone, and closed the speed menu
while also swallowing the press — so the reader's first click in Settings could
vanish. None of them let a right-click travel on, which is how macOS hands a
right-click from one menu straight to the next.

The accepted requirement settles it in three sentences: a press that belongs to
another window is none of the menu's business; within the menu's own window the
left button is spent closing the menu; the right button closes it and travels
on, so whatever it lands on opens its own menu in the same press.

## What changed

### One decision, four callers

`MenuOutsidePress` answers the question once and every menu asks it:
`apps/macos-native/Sources/CueSeekerApp/Shared/MenuOutsidePress.swift`. An event
carrying a window that is not the menu's own is left alone; an event with no
window of its own — the system menu bar is the case that matters — counts as the
menu's own surface, so the left and right rules apply to it too, which is what
macOS itself does there.

The four monitors now switch on that answer: the table row menu in
`SubtitleTableView.swift`, the card and cover menu in
`WorkbenchTestLibraryView.swift`, the speed menu in `PlaybackChromeView.swift`,
and the selected-text menu in `PlaybackSubtitleFocusReel.swift` — one
implementation serving both the Playback Overlay and the Command Panel.

### The right-click relay

Two gates existed only to stop a second menu opening while one was open — the
table's `!isMenuOpen` and the card trigger's `!isContextMenuOpen`. Both are gone:
the press that closed the old menu is the same press that opens the new one.

Order had to stop mattering. The old menu is closed by an event monitor and the
new one is opened by a different monitor or by the table's own `rightMouseDown`,
and nothing guarantees which runs first. So the table closes synchronously on the
forward path, ahead of the responder chain, and the card host closes *the menu it
saw*: `dismissContextMenu(openedAs:)` does nothing if a different menu is already
open.

### One highlight, not two

A card used to remember for itself that it owned the open menu, and with a relay
both the old and the new card would have believed it. The host now records which
card the menu hangs off and publishes it; each card compares that with its own
identity. This removed a `@State` and a `@Binding` from all three card types.

### The speed menu had no window to compare against

It is drawn by SwiftUI with no view of its own to ask, so it was reading the
window out of the event it was judging — the reason a press in Settings was
measured against playback-page coordinates. `MenuHostWindowReader` reports the
hosting window. Until it reports, a press counts as this window's, so a menu can
never become impossible to close.

## Verification

`swift build` clean. `swift test`: 1061 tests, the same five failures as the
baseline — two `CueGroupRefreshScopeIntegrationTests` cases that fail on the
untouched tree as well, and three native playback timeline cases that pass in
isolation and only fail inside the full run. `LibraryCardMenuPlacementTests` was
updated for the new opener signature and passes.

In-app with `--cueseeker-debug-e2e`:

- **Relay, cards.** With the first Recent card's menu open, a right-click on the
  fourth card closes that menu and opens the fourth card's own menu in the same
  press. Only the fourth card is lit; the first is not.
- **Relay, table.** With row 2's menu open, a right-click on row 6 opens row 6's
  menu and moves the highlight there.
- **Relay onto something with no menu.** A right-click on a Recent Shiori row —
  those rows have no menu — closes the open menu and opens nothing.
- **Left press is still spent.** A left press on the table outside the menu
  closes it and does not start the row's playback or change the page.

Not reachable from the E2E controller, left for manual acceptance: the Settings
window cases (acceptance 5–7; the controller cannot send `⌘,` and routes clicks
only to the frontmost CueSeeker window), the system menu bar cases (acceptance 4),
and the middle button (acceptance 8).

## Outcome

Matches the requirement for everything the controller can reach. The Settings
window, system menu bar and middle-button rows of the acceptance list still need
a human pass.
