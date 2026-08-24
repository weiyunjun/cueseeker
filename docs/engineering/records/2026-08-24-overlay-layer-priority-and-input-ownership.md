# Overlay layer priority and input ownership

Human-owned documents:

- `docs/human/requirements/20260824-UI-Overlay Layer Priority And Input Ownership.md`

## Why

The playback page stacks surfaces, but nothing decided which of them owned
input. Two defects followed from the same gap.

Opening the Command Panel over the Playback Overlay left the wheel with the
overlay. The overlay's cue reel claims wheel events with a window-wide event
monitor and decides whether an event is its own by asking whether the pointer
falls inside its own rectangle. That rectangle still covers everything stacked
on top of it, and its monitor was installed first, so it answered "mine" for
every wheel event over the Command Panel and consumed it. The Command Panel's
own reel, whose monitor is installed later, never saw them. SwiftUI hit testing
was already correct here — `PlaybackPage` stops hit testing on the overlay while
the panel is open — but an `NSEvent` monitor bypasses hit testing entirely.

Opening the Command Panel while the speed menu or the selected-text menu was
open left the arrow keys with the menu. `handlePlaybackKeyDown` is the App's
single owner of playback-page keys, but its branches are ordered by hand, and
both menus are consulted before the Command Panel. Opening the panel did not
close them, so a menu that was no longer the topmost surface kept the keys.

## What changed

### The wheel follows the topmost surface

`PlaybackSubtitleFocusSessionStore` learns whether a higher overlay covers it,
and reports it through the two gates the reels already consult, so both the
Current reel and the Playlist reel are covered by one flag rather than a new
channel per surface.

The reel's monitor also stopped swallowing wheel events it is not taking. A reel
that declines an event still covered whatever sat above it, so dropping the
event starved the surface on top; passing it on lets that surface's own monitor
take it. Nothing else on the playback page consumes the wheel, so the pre-existing
suppression cases — a pending keyboard action, a scrollbar drag — behave as
before: the event reaches no other handler either way.

`PlaybackStore` is the one place that knows both facts, so it keeps them in step:
presenting the panel, dismissing it, and starting a focus session all refresh who
owns input.

Files: `Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`,
`Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`,
`Playback/PlaybackStore.swift`.

### Menus below the Command Panel close

Presenting the Command Panel closes the speed menu and the selected-text menu.
With both closed, the existing branch order in `handlePlaybackKeyDown` already
gives the panel the arrow keys, Enter and Escape, so no branch was reordered.
That order still matters and was deliberately left alone: a selected-text menu
opened inside the Command Panel is above it and must keep the keys.

The selected-text menu is closed through the Escape path it already implements,
rather than by threading a second callback from the reel through the overlay and
the page, so the menu keeps one dismissal route.

That reuse exposed a gap the App run caught. The channel it travels on — the
reel publishing its key handler into `PlaybackStore` — was only wired for the
Current module. The Playlist module's reel opens the same selected-text menu but
published nothing, so the store had no handler to close and the menu survived,
merely hidden behind the panel until Escape revealed it again. The Playlist
overlay now publishes on the same channel. The Command Panel's own reel keeps
the default and publishes nothing: a menu opened inside the panel is above it and
its own monitor already handles it.

Files: `Playback/PlaybackStore.swift`,
`Playback/SubtitleFocus/PlaybackPlaylistOverlay.swift`,
`Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`.

## Verification

- `swift build` clean.
- Two regression tests in `PlaybackNormalShortcutTests` assert the two defects
  directly. `openingCommandPanelClosesTheMenusUnderneathIt` opens the speed menu
  and a selected-text menu, presses `K`, and checks that both are gone, that the
  selected-text menu received exactly one Escape, and that closing the panel
  brings neither back. `openCommandPanelTakesWheelAndScrollbarFromThePlaybackOverlay`
  starts a focus session, checks it takes wheel and scrollbar input, opens the
  panel and checks both are refused, then closes the panel and checks the session
  takes the wheel again.
- The suites covering the changed area — subtitle focus, multi-module overlay,
  search/shiori/library overlays, command panel, speed menu — ran 173 tests with
  one failure, `playbackShioriCopiesSettledPrimaryCueAsMarkdownLink`, which
  asserts an English feedback string and read the Chinese one. That failure is
  present without this change.
- The full suite was run twice with the change and once with all three source
  files restored from Git. Every run stops at the same ~27.7 s ceiling and marks
  whichever media-dependent cases are still in flight as failed, so its failure
  set moves between runs in both directions: the baseline run failed
  `libraryFolderRemovalAndIndexingRejectEachOther`, which passed with the change,
  and the two runs with the change disagreed with each other on six cases.

### Debug E2E against the running App

Run on a Shiori list of 396 cues with the Playback Overlay on its Playlist
module. All six acceptance items pass.

- Wheel, no panel: three wheel steps over the overlay moved the focused cue from
  #114 to #117, and the screenshot before and after differ. This is the
  unchanged behaviour acceptance item 6 asks for.
- Wheel, panel open: nine wheel steps with the pointer over the open Command
  Panel left the overlay **byte-identical** to the screenshot taken before the
  panel opened. Before this change the same nine steps moved it nine cues.
- Keys, panel open: the down arrow moved the panel's own highlight, and Escape
  closed the panel.
- Speed menu: opened from the player chrome with 1x checked and highlighted.
  Pressing `K` left no menu on screen and opened the panel; the down arrow then
  moved the panel's highlight from Recent Videos to Recent Shioris. Escape closed
  the panel and the speed menu did not return.
- Selected-text menu: a three-step drag across a cue opened it with Copy
  highlighted. Pressing `K` closed it and opened the panel; the down arrow moved
  the panel's highlight. Escape closed the panel and the menu did not return,
  while the text selection itself correctly stayed.

The selected-text half of acceptance items 4 and 5 **failed on the first App
run** and is what uncovered the Playlist wiring gap described above. The
screenshots that led to it: the menu was absent while the panel covered it, the
panel still took the down arrow, and Escape then revealed the menu still open
underneath. The fix was made and all six items were re-run from a fresh launch.

## Outcome

All six acceptance items pass in the running App, and both defects are also
reproduced by tests that fail without the change.

The unit tests did not catch the Playlist gap, because the wiring they would have
had to exercise is SwiftUI view construction rather than store logic. The App run
caught it. Treat that as the reason acceptance for this kind of change belongs in
the App and not only in the suite.

The wheel fix is narrower than the requirement's general rule: it makes the
Command Panel take the wheel from the Playback Overlay, which is the only place
two wheel-claiming surfaces stack today. A third such surface would need to be
added to the same flag rather than inheriting the rule automatically.

Wiring the Playlist reel onto the key-handler channel also gives that module's
selected-text menu the arrow keys and Enter, which it did not have before. That
is what `20260824-UI-Menu Highlight And Single Selection.md` already asks for and
was missed for this module; it is noted here rather than claimed as this
requirement's scope.

The requirement's §3.2 also covers the pointer. No code was added for it: the
playback page already stops hit testing on the overlay while the panel is open,
and that path was left untouched.
