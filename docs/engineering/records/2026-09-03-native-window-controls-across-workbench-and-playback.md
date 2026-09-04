# Native window controls across Workbench and playback, placed by one owner

Human-owned documents:

- `docs/human/requirements/20260903-UI-Native Window Controls Across Workbench And Playback.md`

## Why

The Workbench moved the three native buttons out of AppKit's titlebar into a proxy view of its own and put them back on every window update. Two defects followed from that design, not from any one bug. The hover glyphs of the group are decided by the theme frame from a tracking rect at the buttons' *native* place, so the glyphs answered the empty corner and not the moved buttons. And AppKit re-tiles the titlebar when a sheet attaches, which took the buttons back to the corner for the whole sheet animation before the next window update moved them again — the jump the owner photographed. The playback page avoided both by hiding the native buttons and drawing three circles of its own, which cost it everything native: the hover glyphs, the zoom button's tiling menu, the Option behaviours, and consistency with the Workbench.

Measured before anything was changed (§7.1 of the requirement), with a standalone AppKit window built the way the App builds its own:

- `beginSheet` reclaims the three buttons synchronously and then runs the ~265 ms sheet animation *inside the same call*, so a window-update re-apply cannot run before the animation has drawn them at the corner. `endSheet` reclaims them after its animation. A frame-change notification does fire during the reclaim, but a frame set on the notifying button inside its own notification is ignored, so a synchronous re-apply cannot correct the last button either.
- `NSWindow` on macOS 15.5 has no `_mouseInGroup:`; the hover group lives in `NSThemeFrame` (`_leftGroupRect`, `mouseEnteredLeftButtonGroup`). It also has two private setters, `setTitlebarHeight:` and `setStandardWindowButtonGroupOffset:`. With them AppKit itself centres the group in a 45 or 46 pt titlebar and moves it in by a horizontal offset; the group rect follows; the placement and a button's hidden state survive `beginSheet`, `endSheet` and a resize. The offset's vertical component is clamped and unusable; the titlebar height is what centres the group.
- The zoom button's action reaches `toggleFullScreen(_:)` on the window, so an override there can hand the playback page's request to the page's own gate.

So the buttons stay where AppKit keeps them, and the App only tells AppKit the titlebar height and the offset.

## What changed

- `AppWindowControls` is the one owner. It holds a placement — Workbench, or playback with a visible flag — and applies it through the two setters: Workbench inset `--spacing-6` centred in `--height-app-topbar`; playback inset `--padding-player-topbar-x` centred in `--height-player-topbar`, hidden with the Player UI unless a playback layer is open. The native leading edge, the native titlebar height and the cluster width are read from the real buttons at attach; nothing is hard-coded. In fullscreen the owner hands the titlebar back to the system (native height, zero offset, shown) and re-applies the placement on exit. Without the setters the buttons keep their native place; no second path is tried.
- Pages report and place nothing: the playback stage reports its Player UI visibility or an open overlay / Command Panel on appear, on change and on disappear; the delegate reports fullscreen entry and exit.
- Removed from the delegate: the proxy view, the reparenting on every window update and resize, the fullscreen restore dance, and the playback interception of the window close. The red button now closes the main window, which quits the App when it is the last window; playback history is saved on the existing close path.
- The playback page's drawn circles are gone from the top bar. The zoom button, the View menu and the shortcut all reach `toggleFullScreen(_:)` on the main window; on the playback page in the windowed state the override hands the request to the page's fullscreen command, which runs the serialized size-transition gate and the fullscreen feedback, and then calls the window again with the manager already transitioning, so the second call passes to AppKit.
- The return button, `PlaybackReturnButton`, is a Player Circle Button / Standard with `chevron.left` after the window controls, in the player top bar and in the Playback Overlay's top bar at the same place: the overlay's bar is taller, so the button is top-aligned inside the player top bar's height there. Its action is the old red button's "close video and return", with the existing label.
- The Playback Overlay's top bar: Tabs stay centred, the Collage button moves to the trailing edge with the same margin.
- Two tokens hold provisional values pending the owner's (both marked 待填 in the requirement): `--gap-app-topbar-toggle-after-window-controls` is 20px, which keeps the sidebar toggle where it is on screen — the old 18px was measured against an 80pt reserved width while the real cluster ends at 78pt; `--gap-player-window-controls-return` uses `--padding-player-topbar-x` (16px) until a value is chosen.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/AppWindowControls.swift` — new: the owner and the two private setters.
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/PlaybackReturnButton.swift` — new.
- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift` — proxy and reparenting removed; owner attached; fullscreen hand-over; close interception removed; the fullscreen request handler.
- `apps/macos-native/Sources/CueSeekerApp/Shared/CueSeekerMainWindow.swift` — `toggleFullScreen(_:)` override.
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift` — the collapsed toggle position is inset + measured cluster width + the new token; the 80/18 constants are gone.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`, `.../Playback/PlaybackTheme.swift` — the two tokens.
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/LiquidGlassVideoTopBar.swift` — title only, plus the return button; the drawn cluster removed.
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackVideoStage.swift`, `.../Playback/PlaybackPage.swift` — visibility reporting; the open-layer flag; the return action threaded through.
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift` — the return button and the Collage button's new place.
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/LiquidGlassWindowControlButton.swift` has no users left and is deleted by the owner. Its tokens in `PlaybackTheme` and `PlaybackChromeMetrics`, and the `playback.minimize` / `playback.fullscreen` strings, go with the Design System update that retires them.

## Verification

Debug E2E controller, main window 1445×821 on the external display:

- Workbench: the three buttons at 24pt from the left edge, centred in the 45pt top bar, native look. The sidebar toggle in the collapsed state sits directly after them, at the same x as before.
- Task panel (a sheet): captured right after the click and after it settled, and again while closing — the buttons never left their place; the close button dimmed the native way while the sheet was up.
- Playback: native buttons at 16pt, centred in the 46pt top bar, the return button after them, the title centred. A synthetic move revealed the Player UI and the buttons with it; when the Player UI hid, they hid.
- Playback Overlay (Enter): buttons and return button visible at the same place as in the player top bar; Tabs centred; Collage at the right.
- Command Panel (K): the three buttons stay visible over it.
- The return button in the player top bar went back to the Workbench, where the buttons took the Workbench placement again.
- The green button on the playback page: a synthetic click entered system fullscreen (window 1504×846, no chrome), Escape exited it back to 1445×821.

Not automatable, left to the owner as the requirement says: the hover glyphs on the moved group, the zoom button's tiling menu on hover or long press, and the sheet transition at eye speed. Pointer-driven tracking is not reachable from the controller's synthetic events.

Full `swift test`: 1132 tests, 13 issues, all in the families the earlier records list as failing on the baseline tree — cue group refresh scope, library folder removal, native playback audio rebuild, and the Debug E2E window-geometry cases — plus two subtitle-focus Shiori tests that timed out under the full run and pass when run alone (`swift test --filter "subtitleFocusDownThenShioriSavesTheFinalSettledCue|subtitleFocusShioriKeySavesIdempotentlyAndKeepsPausedSession"`: 2 tests pass). No test references the window controls.

## Known limits

- The two setters are private. They were measured on macOS 15.5 only; on a system without them the buttons stay at their native place and the layouts still reserve the room.
- The Escape-driven and native-titlebar fullscreen exits keep their existing paths; only fullscreen *entry* from the playback page is routed through the page's gate, as before with the drawn zoom button.

## Follow-up (2026-09-04): fullscreen entered by the tiling menu, the transition animations, one place for every page

Human-owned document: the same requirement, amended (§2.5, §2.7, §4.1, acceptance 10–12).

### Why

Three things came from the owner's first round with the native buttons.

- The green button's tiling menu enters system fullscreen without the playback page's fullscreen manager, whose state stays "windowed". A click on the green button in that fullscreen reached the `toggleFullScreen(_:)` override, whose guard — playback page visible, manager windowed — held, so the click was handed to the page's *entry* command; the manager found the window already fullscreen, switched itself to "active" and showed the Enter Fullscreen feedback, and AppKit's exit never ran.
- The owner switched the buttons to their native place on `windowWillEnterFullScreen` and left them shown; the exit put them back only on `windowDidExitFullScreen`. AppKit draws the exit animation with the titlebar at its native place, so the buttons appeared at the corner until the animation ended.
- The owner gave the two pages two geometries (24pt in 45pt for the Workbench, 16pt in 46pt for playback), so the group moved between pages.

### What changed

- `CueSeekerMainWindow.toggleFullScreen(_:)`: a window whose style mask already holds `.fullScreen` goes straight to AppKit; the page's gate is asked for entries only. Exit is the system's, whoever entered — the tiling menu included — so CueSeeker leaves its half of a split view and the other app keeps its fullscreen.
- `AppWindowControls`: one geometry for every page, inset `--spacing-6` centred in `--height-app-topbar`; the placement only decides visibility now. Through both fullscreen transitions the buttons are hidden: hidden with the native place on `windowWillEnterFullScreen`, shown on `windowDidEnterFullScreen` for the system's titlebar, hidden on `windowWillExitFullScreen`, and placed again on `windowDidExitFullScreen`; a failed exit shows them again. `AppDelegate` gained the three delegate calls.
- `PlaybackReturnButton`: laid out on the controls' centre line — the top-aligned `--height-app-topbar` band — in both the 46pt player top bar and the 54pt overlay bar; its inset starts from `--spacing-6`. `LiquidGlassVideoTopBar` top-aligns it.
- `LiquidGlassWindowControlButton.swift`, deleted by the owner, is committed with this change.

### Verification

Debug E2E controller, red-button centroid measured in the captures (top-left region, 2× scale):

- Workbench (Recent page) 30.7 / 22.2 pt; playback 30.7 / 22.3 pt; Playback Overlay 30.8 / 22.2 pt; back on the Workbench 30.7 / 22.2 pt — the same place on every page (acceptance 12).
- Playback, F then Escape: captures 0.3 s and 2 s after each key show no button at the corner or anywhere in the top-left band (window 1504×846 in fullscreen, 1445×821 after). After the exit a synthetic move revealed the Player UI and the buttons at 30.7 / 22.3 pt. The eye-speed look of the animations, and the tiling-menu path itself, remain the owner's — the controller cannot open the tiling menu.
- The return button at its new place brought the Workbench back.

Full `swift test`: 1132 tests, 25 issues, in the families the earlier records list as failing on the baseline tree — native playback timeline and audio, library folder removal, cue group refresh scope, and the Debug E2E window-geometry cases. Everything outside those families that failed under the full run passes alone (`swift test --filter` on `playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue`, `subtitleFocusShioriIdentityDistinguishesSameTimeSiblingCues`, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`); the three refresh-scope cases that still fail alone failed the same way before this change. No test references the window controls or the fullscreen override.

### Known limits

- Fullscreen entered by the tiling menu leaves the playback page in its windowed presentation (top bar, Player UI rules); only the button semantics were corrected. Adopting such an entry into the fullscreen manager was left out on purpose.
