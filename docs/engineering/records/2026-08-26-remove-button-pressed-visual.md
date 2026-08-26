# Nothing happens while a button is held down

Human-owned documents:

- `docs/human/requirements/20260826-UI-Remove Button Pressed Visual.md`

## Why

The design system never had a pressed state. Button, Icon Button, Toolbar
Button, Sidebar Item, Tab, Menu Item and the player controls each list Default,
Hover, Selected or Open, Focused and Disabled, and nothing else. The one place
the word appears at all is Cover / Editor Action, which spells out that a press
adds no visual.

The App had grown one anyway, in two independent ways that were never asked
for. Cards and player buttons shrank under the pointer, each with its own scale
and its own easing, and the speed menu painted its highlight a second time from
the press. Separately, every button left on SwiftUI's `.plain` style inherited
the system's own press dimming, which is why the Sidebar's top-level pages
flashed on click while its child rows, drawn with the project's own style, did
not.

This record covers the first half: the press visuals the App wrote itself.

## What changed

Every remaining press branch is gone. The state a button is in when it is
pressed is the state it already had — Hover, Selected, Highlighted or Focused —
and it holds that appearance until the button is released.

Two things fell out as orphans and went with it. `LiquidGlassControlState` had
a `pressed` case that only ever resolved to the hover fill, and
`PlaybackCinematicBacking` took an `isPressed` flag that only ever repainted the
hover circle; one caller passed it and three already relied on the default.
Neither can be produced any more, so both are removed rather than left as dead
switches.

`--scale-library-media-card-pressed` was the only motion token behind any of
this. Its single consumer is gone, so the Swift constant is gone too. The token
itself is owner-maintained and is removed from the design system at acceptance.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/LibraryOverviewComponents.swift`
  - The card style drops its press scale and that scale's animation.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
  - `redesignLibraryMediaCardPressedScale` removed.
- `apps/macos-native/Sources/CueSeekerApp/Shared/LiquidGlassSelectableCard.swift`
  - The Shiori card drops its press scale; `LiquidGlassControlState.pressed`
    removed and `resolvedState` no longer takes the press.
- `apps/macos-native/Sources/CueSeekerApp/Search/Library/LibraryEpisodeButton.swift`
  - The episode tile drops its press scale.
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeIconButton.swift`,
  `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeView.swift`
  - The circle and capsule buttons drop their press scale, and the inner hover
    circle is asked of Hover alone.
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeSpeedMenu.swift`
  - The menu item drops its press scale, and its background is the highlight
    alone.
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
  - `PlaybackCinematicBacking` loses its `isPressed` parameter.

No hover, selected, highlighted, focused or disabled appearance changed, and no
hit area, action or timing changed.

## Verification

`swift build`: clean. `swift test`: 1098 tests. Against the same tree with the
change stashed the failing set is identical apart from two names that failed in
the changed run and pass on their own —
`playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue` and
`subtitleFocusShioriIdentityDistinguishesSameTimeSiblingCues` — the suite
parallelism flake earlier records already note. The shared failures are the
known native playback timeline, refresh scope, library folder removal and window
geometry ones.

The absence of a press visual is the owner's manual check. It can be automated
with what the project already has — the Debug E2E controller splits `mouseDown`
from `mouseUp`, so a capture taken while the button is held can be compared with
an idle one — and that is worth adding when a regression is suspected. No test
capability was added here.
