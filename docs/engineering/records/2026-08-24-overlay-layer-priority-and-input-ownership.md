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

Files: `Playback/PlaybackStore.swift`.

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
  and the two runs with the change disagreed with each other on six cases. The
  two `subtitleFocus…Shiori…` cases that appeared in one such run pass in 0.1 s
  when run on their own against the changed code, three times in a row.

### Debug E2E acceptance is not done

The requirement's acceptance is written for the existing Debug E2E controller and
needs no new capability, but the run could not be performed here. Two
preconditions are outside this change:

- CueSeeker was already running (pid 31916). The single-instance guard rejects a
  second launch, and killing the owner's running App is not something to do
  unasked.
- Two displays are attached. The controller fails capture explicitly when the
  scene is not contained by one display.

The acceptance items therefore remain open, and the behaviour in the running App
is unverified. What is verified is the state machine underneath it, at the two
gates the reels and the key owner actually read.

## Outcome

Both defects are reproduced by tests that fail without the change and pass with
it. The wheel fix is narrower than the requirement's general rule: it makes the
Command Panel take the wheel from the Playback Overlay, which is the only place
two wheel-claiming surfaces stack today. A third such surface would need to be
added to the same flag rather than inheriting the rule automatically.

The requirement's §3.2 also covers the pointer. No code was added for it: the
playback page already stops hit testing on the overlay while the panel is open,
and that path was left untouched.
