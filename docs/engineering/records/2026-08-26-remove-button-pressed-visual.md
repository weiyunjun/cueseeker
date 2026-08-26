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

## The other half: the press SwiftUI adds on its own

`.buttonStyle(.plain)` is not a neutral style on macOS. It draws no chrome, but
it still dims the label for as long as the mouse is held down. Nothing in the
App asked for that, and nothing in the App could see it — it is not in any of
these files. It is why the Sidebar's top-level pages flashed on click while its
child rows did not: the pages are `.plain`, the child rows already use the
project's own style.

The project had solved this once before. `StaticButtonStyle` draws the label and
nothing else, and the facet option rows adopted it in July for exactly this
reason. It is now the style every button uses; no new mechanism was added, and
the one comment explaining why sits on the style itself rather than on each of
the twenty-four call sites.

Every one of those labels already states its own colour for enabled, disabled
and selected, so nothing depended on `.plain` for its appearance. Hit area,
focus ring, hover and action are untouched.

Files:

- Twenty-four `.buttonStyle(.plain)` call sites across Workbench controls, the
  Sidebar, Settings, the search and library headers, the cover summary, the
  subtitle table checkbox, and the player and overlay chrome now pass
  `StaticButtonStyle()`.
- `apps/macos-native/Sources/CueSeekerApp/Shared/HoverEffectModifier.swift`
  - `StaticButtonStyle` gains the note that says what it is for.

`CueHoverButtons` and the `ToolbarButtonStyle` it uses were left alone. They are
the pre-redesign row Play/Copy pair: the coordinator still builds the host at
init, but every caller passes `isRedesign: true` and the layout pass hides it
before it can appear. Its press effect cannot be seen, and removing dead code is
not part of this requirement.

### Verification

`swift build`: clean. `swift test`: 1098 tests, the same failing set as the
stashed baseline apart from `subtitleFocusDownThenShioriSavesTheFinalSettledCue`,
which passes on its own — the suite parallelism flake again, in the other
direction this time, since the baseline run had a name this run does not.

The press itself was measured rather than eyeballed, using the Debug E2E
controller's separable `mouseDown`. Holding the Sidebar's Library page down and
capturing before release: 1330 pixels of that row differ from idle on the
baseline tree, up to 58 levels of dimming, and 0 pixels differ with the change
in place. The same held capture on the Workbench Select button and on Library's
Add Content primary button differs from idle by 0 pixels; Add Content keeps its
focus ring while held, which is the state it is actually in.

Cards could not be measured the same way. This machine's library is empty, so
there is no card to hold, and card hover cannot be synthesized in the first
place. That half stays the owner's manual check, as the requirement's acceptance
already assumes.

## Follow-up: the row buttons that could not be seen

The owner extended the requirement to delete the pre-redesign row Play/Copy
pair rather than leave it in place. It was worth deleting for a reason beyond
tidiness: it was not inert. The coordinator still built its hosting view at
init, still kept it as a subview of the document, and a layout function was
still being called from twelve places across the table — on data updates, on
enablement changes, on scrolls, on hover changes, on menu open and menu close —
each call reaching a function whose first act was to hide the thing and return.
Every one of those call sites read as if the table maintained something it had
not maintained since the redesign.

That is also why the deletion is larger than the two type names suggest. The
view, its hosting property, the branch that created it, the layout function and
all twelve calls go together; leaving any of them would leave the same
misleading trail.

Two of the calls sat in branches that existed only for them. The scroll handler
chose between repositioning an open menu and laying the buttons out, and the
scrollbar-drag handler had an else that did nothing else; both collapse to the
work that remains. A comment at menu close explaining that the hover stays where
the menu left it went with the call it was attached to — the rule it states
lives in `docs/human/design/UI Application Rules.md`, and there is no longer a
statement here for it to explain.

The removal orphaned the `table.row.play` and `table.row.copy` strings, which
had no other consumer; they are gone from all three localizations.

The same pass emptied `HoverEffectModifier.swift` of everything except
`StaticButtonStyle`: `ToolbarButtonStyle` had exactly one caller, the deleted
row buttons, and `HoverBackgroundModifier` with its `hoverBackground` helper had
none at all. By owner decision the file keeps its name; renaming or moving the
one surviving style is not part of this requirement.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
  - `CueHoverButtons`, the `buttonsHost` property, its creation branch,
    `layoutHoverButtons` and its twelve call sites.
- `apps/macos-native/Sources/CueSeekerApp/Shared/HoverEffectModifier.swift`
  - Only `StaticButtonStyle` remains.
- `apps/macos-native/Sources/CueSeekerApp/Resources/*.lproj/Localizable.strings`
  - `table.row.play` and `table.row.copy` removed.

### Verification

`swift build`: clean. `swift test`: 1098 tests, the same failing set as the
stashed baseline plus three names that pass on their own — the suite parallelism
flake, unchanged in character from the earlier runs.

Nothing was expected to move on screen and nothing did: every deleted call
reached a function that returned before doing anything, because `isRedesign` is
true at every call site. The Workbench Search page was captured after the
deletion and renders as before; the pixel differences against the earlier
capture are the Shiori group left expanded and the search field left unfocused
by this session's own navigation, not the change.
