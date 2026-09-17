# Opening the same video kept its audio track, and the More menus were fixed in width and place

Human-owned documents:

- `docs/human/requirements/20260917-Bug-Audio Track Not Reset On Same Video Open And More Menu Width And Bounds.md`
- `docs/human/design/UI Design System.md` (Menu, Player More Menu, Audio Track
  Submenu, Player Bottom Control Bar Layout), which the requirement updates
  after acceptance

## Why it happened

Every way of opening an item on the playback page ends in the same three open
paths (search result, excerpt, Library video). When the video asked for was
already open, each path only seeked inside it, and the default audio track
reaches the player only when a video is opened. So Command Panel's Recent
Videos, Recent Excerpt Lists and search, the Playlist, previous and next, the
automatic switch to the next cue and a Deep Link all kept whatever track was
playing. Leaving the playback page stops the player, which is why opening from
the Workbench was never affected. Repeat seeks inside the current cue and never
goes through these paths.

The More menu took the speed menu's fixed width, so a longer localized label
such as `Default Audio Track` was cut off. The audio track submenu had a fixed
width of its own. Both menus were placed inside the stage inset by the controls'
margin on all four sides, so a submenu pushed down or up to fit could cover the
control buttons or the top bar, and a submenu wider than the room beside the
More menu was pushed over it.

## What changed

- The three open paths seek in place only when the open video is the same one
  and already plays the audio track the item opens on. Otherwise they open the
  video, which applies the default audio track. The comparison is against the
  track the player reports, so a default track the file does not have reopens
  the video on each open and still lands on the first track.
- The fullscreen button is the rightmost control again; the More button sits to
  its left.
- The More menu and its submenus share one area: below the top bar, above the
  buttons by the gap the menu already kept from them, and inside the controls'
  side margin.
- The More menu is measured as it lays out; its triggers take the width of the
  widest label.
- Each audio track submenu is measured with every name on one line, then held to
  the width cap and to the room on the side it opens to: right when it fits,
  else left, else the wider side. Its tracks are laid out at that width, so
  names wrap there. When the area cannot hold its height it scrolls; the
  scrollbar widens it where the room allows and otherwise comes out of the
  tracks' width, so it never covers the More menu.
- The fixed More menu width is gone, and the audio track width is now the cap,
  still 300 pt, pending the owner's value in-app.
- The speed menu needed no change: it opens above its button inside the bottom
  chrome, and at the smallest window height (560 pt) its top edge is still about
  200 pt below the top bar.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackAudioTrack.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Playback.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Excerpt.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Library.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeMoreMenu.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackMoreMenuTests.swift` — new
  cases for the submenu width on each side and at the cap, narrowing to the
  wider side without covering the More menu, scrolling between the top bar and
  the buttons, and a measured More menu at the narrowest window that fits its
  labels and keeps both submenus inside the area.

## Verification

`swift build`: clean, no warnings in the touched files.

`swift test --filter PlaybackMoreMenuTests`: 8 tests pass, 4 of them new.

Full `swift test`: 1252 tests, 16 failing, in the native playback timeline,
Debug E2E controller, refresh-scope integration and Library folder removal
suites, the ones the previous record lists as failing under load. Run alone, 11
of them pass. `showCueGroupInvalidationIsScopedToMountedExcerpt` and
`excerptTableStartsAtTopAfterPanelRemount` also fail on an unmodified copy of
`HEAD` (`git archive` into the scratchpad) with the same expectations.
`sceneUsesVisibleWindowUnionAndTopLeftCoordinates` and
`searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces` failed once alone
and then passed twice in a row with the change. None of these suites touches the
code changed here.

Not automated: which audio track plays, and how the menus look. The Debug E2E
controller cannot report the playing audio track, and the requirement leaves the
interface and the audio to the owner's acceptance in the App.

Outcome: implemented as the requirement describes; awaiting the owner's
acceptance in the App, including the width cap.
