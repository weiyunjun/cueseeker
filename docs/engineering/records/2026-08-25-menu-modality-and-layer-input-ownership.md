# Menu modality and layer input ownership

Human-owned documents:

- `docs/human/requirements/20260825-UI-Menu Modality And Layer Input Ownership.md`

## Why

The App's five menus each decided for themselves what the rest of the window was
allowed to do while they were open, and the answer was "everything". Scrolling
carried the page out from under an open menu, the pointer kept moving the
current row or card away from the one the menu belonged to, and a menu that was
no longer the topmost surface still competed for keys and presses.

The accepted requirement settles all of it with three rules: a higher surface
takes every input and freezes what is below instead of closing or clearing it;
four of the five menus ban scrolling for the whole window while they are open;
and the object a menu hangs off keeps its highlight until the menu closes.

## What changed

### A higher surface freezes the menus below instead of closing them

Presenting the Command Panel used to close the speed menu and the selected-text
menu. That was a workaround for input ownership, not a product rule: both menus
are consulted for keys before the panel is, so leaving them open left them
holding the arrow keys. The rule is now the layer itself — a menu belongs to the
surface that opened it and never outranks what is stacked above that surface —
so the key owner asks whether the Command Panel is present before offering a key
to either menu, and the menus stay on screen.

Two monitors had to learn the same thing. A menu closes on the first press
outside itself, and it decides "outside" from the pointer alone; an `NSEvent`
monitor never sees hit testing, so a press on the Command Panel read as a press
outside the menu, closed it, and was swallowed on the way. The speed menu's
monitor now stands down while the panel is open, and the reel's selected-text
monitor stands down while a higher layer covers the reel. The covering flag was
already in `PlaybackSubtitleFocusSessionStore` for the wheel; it is now published
and handed to the reel rather than duplicated.

The frozen speed menu also stops drawing hover and pressed feedback, through the
suppression flag it already accepts for scrubbing.

Files: `Playback/PlaybackStore.swift`, `App/AppCoordinator+Playback.swift`,
`Playback/Chrome/PlaybackChromeView.swift`,
`Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`,
`Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`,
`Playback/SubtitleFocus/PlaybackPlaylistOverlay.swift`,
`Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`.

### Four menus ban scrolling for the whole window

Each of the four menus already installs one window-wide event monitor while it
is open, and each already answers "is this point on me". The ban reuses both:
the monitor takes the wheel as well, passes it on when the pointer is on the
menu — the one place the reader may still scroll — and drops it everywhere else.
Nothing new arbitrates, and no scroll view had to be gated one by one.

The reel's wheel monitor carries the ban for both of its hosts, because the
monitor is window-wide: a selected-text menu opened in the Playback Overlay
stops the playlist and the page, and one opened in the Command Panel stops the
panel's own list. A menu that a higher surface has frozen bans nothing; it lets
the event travel on so the surface above decides.

The speed menu keeps scrolling as it was: the requirement exempts it.

Files: `Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`,
`TableSandbox/SubtitleTableView.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`.

### The surface below a menu freezes, and the anchor stays lit

The table stops updating hover while a menu is open, and stops clearing it when
the pointer leaves for the menu. Freezing alone would have left the anchor lit
only by accident — because the pointer happened to hover the row on its way to
the right-click — so opening the menu now says which row is lit. An automated
right-click that never moved the pointer first lights the same row.

The card grids resolve their highlight the same way, but the "which card owns
the open menu" fact stays in the one modifier every card already applies, and is
handed back through a binding. The three card kinds gain a stored flag and one
branch each; none of them carries its own copy of the rule.

Files: `TableSandbox/SubtitleTableView.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`,
`Shiori/ShioriListOverviewView.swift`.

### A dialog freezes the surface below rather than clearing it

Opening a dialog used to wipe the table's hover, drop the card grid's lit card,
and close an open menu. The requirement makes covering uniform: the layer below
keeps its picture and only stops taking input. The table now leaves its
highlight and its open menu alone, and the cards stop following the pointer
instead of going dark. Work already in flight — a text drag, a cue-state tip —
still stops, because it is not a picture.

Files: `TableSandbox/SubtitleTableView.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`,
`Shiori/ShioriListOverviewView.swift`.

## Verification

- `swift build`
- `swift test --filter CueSeekerAppTests --no-parallel`
- `PlaybackNormalShortcutTests` — the test that asserted the old "both menus
  close" rule now asserts the frozen behaviour: both menus stay open, the arrows
  and Enter reach the Command Panel, and the speed menu answers the arrows again
  once the panel closes.
- `SubtitleTableVirtualRowTests` — the test that asserted the old "the rest of
  the table stays hoverable" rule now asserts the freeze, and a new test covers
  a dialog covering the table.
- Four tests fail on this machine before and after the change, for reasons the
  change does not touch: two localization assertions that expect English while
  the App runs in Chinese, one user-defaults migration assertion, and two
  one-second waits in the refresh-scope integration suite. The full parallel run
  fails a different subset each time; the serial run is the stable signal.

Debug E2E against the running App, on the Shiori list of 397 rows. Every
capture below was compared pixel by pixel, not by eye:

- **The wheel with no menu open** scrolls the table, and scrolling back returns
  the first capture byte for byte. That is the control for the two that follow.
- **Acceptance 1.** Right-click row 3, then one wheel step down: the capture
  after the wheel is **byte-identical** to the capture before it. Nothing in the
  window moved.
- **Acceptance 3 and 4.** With that menu open, move the pointer to row 6: the
  only pixels that change in the whole window are the traffic lights at
  (8,8)–(76,28), which react to the window, not to the table. Row 3 keeps its
  highlight and row 6 takes none. The table's hover follows the event's own
  location, so a synthesized move does reach it, as
  `docs/engineering/08_end_to_end_testing.md` §1.1 records.
- **The ban lifts with the menu.** A press outside closes the menu and is spent
  on closing it; the next wheel step scrolls the table again.

Three acceptance points could not be driven, and no capability was added for
them. They need manual acceptance in the App:

- **Acceptance 2, 5, 6 and 7** need the playback chrome and the speed menu. The
  chrome appears on real cursor movement, which the controller does not produce
  — the same limit `20260824-UI-Menu Placement And Outside Interaction` already
  recorded. The key ownership and the freeze are covered by the unit test above;
  what needs eyes is that a click inside the Command Panel leaves the speed menu
  open and is answered by the panel.
- **The card and cover menus** in acceptance 1, 3 and 4 install their right-click
  monitor only while the card reports SwiftUI hover, which a synthesized move
  cannot produce. The requirement already assigns them manual acceptance.
- **Acceptance 8** is covered by a unit test rather than the controller, because
  a dialog is opened from a control the controller cannot activate.

Outcome matched expectations.
