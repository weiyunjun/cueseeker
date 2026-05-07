# ADR-0010: Playback Fullscreen Uses AppKit Full Screen Space

Status: Accepted

Supersedes: ADR-0005 fullscreen mechanism

## Background

CueSeeker previously used a borderless Theater Mode window for playback
fullscreen. That decision came from the embedded `libmpv` era, where moving an
`MPVRenderView` through AppKit's native Full Screen Space transition could
crash because SwiftUI view lifetime, OpenGL render-context lifetime, and
`libmpv` callbacks were tightly coupled.

ADR-0007 removed production `libmpv` compatibility. The active playback stack
is native-only and already owns a stable singleton render container. The old
reason for avoiding AppKit's native Full Screen Space transition no longer
applies to production playback.

The borderless Theater Mode approach also does not match standard macOS
fullscreen behavior. It can hide the Dock and menu bar, but it cannot make the
desktop, wallpaper, other app windows, menu bar, and Spaces transition behave
like a normal macOS fullscreen window. Continuing to emulate that behavior would
increase maintenance cost and leave visible UX inconsistencies.

## Decision

Playback fullscreen should use a dedicated playback `NSWindow` that enters and
exits AppKit's native Full Screen Space with `toggleFullScreen(_:)`.

Rules:

- The main CueSeeker workbench window must not be put into fullscreen when the
  playback fullscreen command is used.
- Playback fullscreen should move the existing singleton native playback render
  container into the dedicated playback window before that window enters native
  fullscreen.
- AppKit should own the Full Screen Space transition, including Dock, menu bar,
  desktop, wallpaper, Space, Mission Control, and system overlay behavior.
- Fullscreen command state should be driven by AppKit lifecycle callbacks such
  as `windowWillEnterFullScreen`, `windowDidEnterFullScreen`,
  `windowWillExitFullScreen`, and `windowDidExitFullScreen`.
- If custom fullscreen animation is later required, it should use AppKit's
  custom fullscreen delegate callbacks and the system-provided duration, not a
  guessed fixed delay.
- CueSeeker must not manually simulate system fullscreen with an always-on-top
  borderless overlay window for the standard playback fullscreen path.
- Fullscreen entry and exit must not create a second playback render view or a
  second backend render context.

## Rationale

This aligns playback fullscreen with standard macOS behavior. It lets the
system handle the parts of fullscreen that are inherently Space-level concerns
instead of making CueSeeker approximate them with presentation options and
window levels.

The native-only playback stack removes the earlier `libmpv`-specific conflict.
The still-relevant invariant from ADR-0005 is render-container stability: the app
must move one stable playback render container instead of creating or destroying
backend render state during fullscreen transitions.

## Tradeoffs

- Native Full Screen Space transitions are controlled by AppKit and may feel
  heavier than an instant borderless overlay.
- CueSeeker must coordinate the temporary playback window, render-container
  movement, and return to the embedded Playback Area carefully.
- Future fullscreen side panels should use AppKit-compatible approaches, such
  as auxiliary windows or in-window overlays, rather than reviving a custom
  always-on-top Theater Mode simulation.

## Alternatives Considered

### Keep Borderless Theater Mode

Rejected. It avoids the Space transition, but it cannot match macOS fullscreen
behavior and requires CueSeeker to manually emulate Dock, menu bar, app
switching, deactivation, window level, and animation behavior.

### Fullscreen the Main Workbench Window

Rejected. Playback fullscreen should affect the video experience, not the
entire CueSeeker workbench with Library and Search panels.

### Custom Fullscreen Animation First

Deferred. AppKit's default fullscreen transition should be the baseline. Custom
fullscreen delegate animation may be introduced only after the native path is
proven and only if it remains synchronized with the system-provided duration.

## Consequences

- Product and engineering documents should describe playback fullscreen as a
  dedicated playback window entering AppKit Full Screen Space.
- ADR-0005 remains historical context for the old `libmpv` crash analysis and
  for the singleton render-container invariant, but its Theater Mode fullscreen
  mechanism is superseded.
- Implementation should replace the current borderless Theater Mode code path
  before further fullscreen polish depends on it.
