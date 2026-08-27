# The footer stops hinting and starts doing

Human-owned documents:

- `docs/human/requirements/20260827-UI-Playback Footer Shortcut Buttons.md`

## Why

The footer under the Playback Overlay and the Command Panel told the reader
which arrow keys move the selection — the one thing nobody needs telling — and
said nothing about the four actions that actually sit on a key. The three cue
actions were reachable only by knowing that S, C and X did something.

It also had a legibility bug on exactly one of the two surfaces. The keycap
colour was an alias of the hover background, which is a step deeper than a white
popover but the same grey as the Playback Overlay's own background. On the
Overlay the keycap had no edge at all; in the Command Panel it read fine, which
is why it survived this long.

## What changed

### One footer instead of two

There were two implementations. `PlaybackCueFooter` served Current, the subtitle
Playlist and the Command Panel's search results; a private
`PlaybackCommandPanelFooter` with its own private keycap served the Command
Panel's other three pages, at a different font weight, a different keycap size
and a hand-written corner radius. Both needed the same new buttons, so they are
now one component that takes a surface, an optional status string and a list of
actions.

Which actions a page passes is the page's own answer, because the keys already
differ: Current and the subtitle Playlist pass all four; the Command Panel's
search results pass all four; its root and its two Recent pages pass Open alone;
the Video Playlist passes Play alone; and a Current view that is assembling a
collage passes Select alone, because the cue actions are rejected there anyway.

### Clicking runs the shortcut, not a copy of it

Every button calls the same coordinator entry point its key calls —
`requestPlaybackSubtitleFocusAction`, `requestPlaybackCommandPanelSearchAction`,
`openSelectedPlaybackCommandPanelItem` — so the deferral queue, the
already-saved feedback and the reel-settling rules apply to a click exactly as
they apply to a keypress. Nothing about what the actions do was touched.

The Video Playlist's Play button resolves the selected episode through
`primaryActionVideo()` and hands it to the same `onOpenEpisode` closure Return
uses, rather than routing through the cue-action path that module rejects.

Hover is gated by `onPointerHover`, which already answers the menu-open and
covered-layer rules from `UI Application Rules.md`. That gate asks about the
layer the surface is on, so the footer claims its own layer — without that it
would read the workbench page, which is covered for as long as playback is open,
and the buttons would never light.

### Colour per surface, not per component

The requirement chose fixed colours per surface over one translucent overlay, so
the footer's surface enum carries three colours each for the Playback Overlay
and the Command Panel: the button's hover background, the keycap's default, and
the keycap's hover. Each is a step deeper than the last, and hovering a button
deepens its keycap with it. `--color-keycap-bg`, which was an alias of
`--color-bg-hover`, is retired.

### Growing instead of shrinking

Every label used to be pinned to one line. The actions now sit in a small
right-aligned wrapping layout: at full width they are one row, and at 520pt they
become two rows and the footer gets taller. Nothing is elided.

That made the footer's height a measurement rather than a constant. Only one
place depended on the constant — Current subtracts the footer from the reel's
viewport, because the footer is an overlay on the reel rather than a sibling
above it — so the footer publishes its laid-out height through a preference and
Current subtracts what it reads. The other three footers are already stacked and
needed nothing.

## Verification

`swift build` clean. `swift test --filter
'PlaybackSubtitleFocus|PlaybackCommandPanel|PlaybackPlaylist|Layout'` — 194
tests pass.

The full suite has failures, and they are not this change: the two
`CueGroupRefreshScopeIntegrationTests` failures reproduce identically on a clean
export of the parent commit, and both fail on a one-second wait for a workbench
Shiori table scroll to land. The rest are native playback audio/video timeline
and window-scene tests that time out on this machine.

Run in the App through the Debug in-app E2E controller, following the new
section 14 of `docs/engineering/08_end_to_end_testing.md`:

- Current shows the cue count and the four buttons; the keycaps are clearly
  separable from the Overlay background, which is the defect this fixes.
- Clicking `Copy Cue Text` put the selected cue's text on the clipboard;
  clicking `Copy Deep Link` put that cue's Markdown deep link on it.
- The Video Playlist, which had no footer at all, shows `13 videos` and `Play`.
- The Command Panel root shows `Open` alone; its search results show
  `241 results (Showing first 50 results)` and the four buttons.
- At a 520pt window the four buttons wrapped onto a second row with the footer
  taller and no label shortened.

Left to the owner, as section 14 records: hover, because a synthesized
`mouseMove` cannot drive SwiftUI `.onHover`; Dark Appearance, which needs the
system setting changed; and the `Save to Shiori` button, because clicking it
writes a Shiori row.

## Not done here

The Design System entries — the new button component, the keycap's hover state
and per-surface colours, the Footer that the Playback Overlay Layout has never
listed despite the App having one, and the Command Panel Footer descriptions —
are held until the owner accepts the visual result, per §8 of the requirement.
