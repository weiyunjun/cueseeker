# ADR-0011: Playback Fullscreen Uses Main Window Presentation

Status: Accepted

Supersedes: ADR-0010 dedicated playback fullscreen window

## Background

ADR-0010 replaced the old borderless Theater Mode with a dedicated playback
`NSWindow` that enters AppKit Full Screen Space. That direction improved system
fullscreen integration compared with a manually simulated overlay, but it still
splits the app into two visible window identities during playback fullscreen:

```text
Main CueSeeker workbench window
Dedicated playback fullscreen window
```

That split creates user-visible problems. When the user switches away from a
fullscreen video, macOS can reveal the normal CueSeeker workbench window without
the video UI because the playback surface has moved into a separate fullscreen
window. Cursor hiding also becomes harder to reason about because fullscreen
chrome state belongs to the dedicated playback window while app activation
belongs to the whole app. The fullscreen transition can also freeze the visible
video presentation because the live native render view is moved between windows
immediately before AppKit performs a Space transition.

Mainstream macOS video experiences such as browser video fullscreen, QuickTime,
and IINA behave more like one player window entering a video-first fullscreen
presentation. The user does not see a separate empty app shell while fullscreen
video remains in another window.

## Decision

Playback fullscreen should use the main CueSeeker workbench window's native
fullscreen capability, then switch that same window into a video-only playback
presentation for the duration of playback fullscreen.

Rules:

- The standard playback fullscreen path must not create a second playback
  fullscreen `NSWindow`.
- The playback render container must not be moved across windows during
  fullscreen entry or exit.
- Playback fullscreen may put the main CueSeeker workbench window into AppKit
  Full Screen Space, but the visible presentation should be video-first and must
  not expose the normal workbench shell as the fullscreen experience.
- The workbench UI, panel state, search state, selection state, sidebar position,
  panel widths, scroll positions, and focus state should be preserved while the
  video-only presentation is active.
- Exiting playback fullscreen should restore the prior workbench presentation
  without rebuilding unrelated Library, Search, or Shiori rows.
- App fullscreen and playback fullscreen must be represented as distinct states:
  the green traffic-light button or system View fullscreen command may request
  ordinary app fullscreen, while the playback fullscreen command requests
  video-only playback presentation.
- If playback fullscreen starts while the main window is already in ordinary app
  fullscreen, CueSeeker should enter video-only playback presentation inside the
  existing fullscreen Space instead of creating another window.
- If ordinary app fullscreen starts while playback fullscreen is active, the
  playback fullscreen state remains authoritative until the user exits playback
  fullscreen.
- Cursor hiding and fullscreen chrome visibility are still owned by the playback
  fullscreen manager, but cursor hide/unhide calls must be balanced across
  entry, exit, app deactivation, app reactivation, and failed transitions.
- App switching while playback fullscreen is active should rely on AppKit's
  normal fullscreen Space behavior and must not reveal a separate CueSeeker
  workbench window that has lost its video surface.
- If custom fullscreen animation is later required, it should use AppKit's
  fullscreen delegate callbacks and the system-provided duration.

## Rationale

This aligns CueSeeker with professional player behavior while keeping AppKit in
charge of the system fullscreen Space. The user experiences one app window
becoming a playback-focused fullscreen surface, not a second playback window
separated from the workbench.

Keeping the render container in the same window hierarchy avoids the riskiest
part of the ADR-0010 path: moving a live native video presentation surface across
windows immediately before a fullscreen Space animation. If fullscreen animation
still freezes video after this change, the remaining problem should be diagnosed
inside the native display layer, main-queue frame submission, or AppKit layer
commit behavior rather than in window ownership.

The product-level promise remains that playback fullscreen is about the video
experience, not turning the workbench into a general fullscreen workspace. The
implementation may use the main window at the system level, but it must present a
video-only playback mode and restore the workbench afterward.

## Tradeoffs

- CueSeeker must now distinguish ordinary app fullscreen from playback
  fullscreen. The state machine is more explicit and must handle green-button,
  menu, keyboard, Escape, Cmd-Tab, and close-window paths.
- Workbench presentation must be hidden without losing state. Conditional
  teardown of SwiftUI workbench views would risk losing scroll positions,
  selection, panel state, and focus.
- Future UI redesigns must respect the playback fullscreen presentation layer
  instead of assuming fullscreen is a separate playback window.
- Some AppKit fullscreen animation stutter may remain because the system
  fullscreen transition is still controlled by macOS.

## Alternatives Considered

### Keep ADR-0010 Dedicated Playback Window

Rejected. It keeps the main workbench out of system fullscreen, but exposes a
split-window model that does not match mainstream player behavior. It can leave
the user looking at a CueSeeker workbench window with no video UI after app
switching, and it increases the chance of video presentation freeze by moving
the render container across windows during fullscreen entry and exit.

### Return To Borderless Theater Mode

Rejected. It avoids AppKit's fullscreen Space transition, but it requires
CueSeeker to emulate Dock, menu bar, Spaces, app switching, and system overlay
behavior. That was the maintenance burden ADR-0010 correctly removed.

### Use AVPlayerView Fullscreen Directly

Rejected for the current playback stack. CueSeeker owns a project native backend
with FFmpeg demuxing, selectable decode mode, `AVSampleBufferDisplayLayer`
presentation, app-owned controls, and source-faithful ASS overlay rendering.
Replacing that with `AVPlayerView` would be a playback-engine decision, not only
a fullscreen presentation decision.

## Consequences

- ADR-0010 remains historical context but no longer defines the active playback
  fullscreen mechanism.
- Product and engineering documents should describe playback fullscreen as a
  main-window video-only presentation using AppKit native fullscreen behavior.
- Implementation should first update fullscreen state modeling, then replace the
  dedicated playback window path, then verify cursor behavior, app switching, and
  video animation smoothness.
