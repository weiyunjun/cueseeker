# Playback DS5 Controller Support

## Requirement

- `docs/human/requirements/20260731-Feature-Playback DS5 Controller Support.md`
- `docs/human/design/Controller.md`

## Scope

Implement the initial macOS DualSense controller version for the video page,
Playback Overlay, Command Panel, and Collage. Keep the application-facing input
interface independent of controller brands while supporting and verifying only
the standard DualSense profile in this change.

## Steps

1. Added positional controller input events, a dominant-axis thumbstick
   interpreter, and a DualSense `GameController` adapter with connection,
   disconnection, discovery, and repeat lifecycle ownership.
2. Routed normalized controller events through the existing Playback keyboard
   state machine where behavior is equivalent, while retaining native
   first-responder deletion and paste commands.
3. Added previous-module navigation and moved Collage Copy/Export execution to
   the preview Store so controller and mouse actions share one implementation.
4. Declared Extended Gamepad support in the packaged App and extended bundle
   verification to require both controller keys.
5. Added controller routing and thumbstick interpretation tests, and documented
   the stable platform boundary and repeat thresholds.

## Post-implementation correction

Initial physical review exposed three gaps between controller routing and the
keyboard-equivalence rule in `docs/human/design/Controller.md`:

1. Unhandled keyboard events normally returned to AppKit were discarded by the
   controller path, so native text movement, marked-text movement, and character
   insertion did not run.
2. Circle reached the shared Escape handler, but normal-video fullscreen exit
   still depended on AppKit receiving a physical keyboard event.
3. The thumbstick monitor started repeat timing after application-level delivery
   even when the active interface did not allow that directional repeat.

The controller router now preserves shared keyboard handling first and falls
back to native first-responder text commands only when an editable control owns
the unhandled action. Normal-video Escape explicitly exits Playback fullscreen.
The monitor now receives the routing result and current repeat eligibility,
starts repeat only for an accepted direction, cancels rejected repeat without
resetting the active stick, and therefore requires a new deadzone cycle before
another activation.

## Verification

- `swift build --product CueSeeker`: passed.
- Focused controller, Collage preview, and overlay input selection: passed, 12
  tests.
- Post-correction controller, Playback Overlay, Command Panel, fullscreen
  Escape, native text fallback, and thumbstick lifecycle selection: passed, 27
  tests.
- Post-correction unfiltered `swift test`: executed 941 tests and reported 19
  issues. No controller test failed; reported issues remained in existing native
  media timeline/presentation timing, shared test-database I/O, Subtitle Table
  right-click positioning, and refresh-scope instrumentation.
- The unfiltered `swift test` run executed 937 tests and reported 12 failing
  tests with 15 issues while also logging shared test-database I/O failures.
  Ten failures passed when isolated. The remaining two are the previously
  documented Subtitle Table right-click menu-position tests, which reproduce
  alone with the existing 40-point discrepancy and do not exercise files
  changed by this requirement.
- `plutil -lint packaging/macos/Info.plist`: passed.
- `scripts/package_macos_app.sh --output
  /private/tmp/CueSeeker-DS5-Verification.app`: passed, including the existing
  architecture, dependency, and code-signing verifier.
- The packaged App declares `GCSupportsControllerUserInteraction = true` and
  `GCSupportedGameControllers[0].ProfileName = ExtendedGamepad`, and its
  executable links the system `GameController` framework.
- Physical DS5 over Bluetooth: pending human hardware verification.
- Physical DS5 over USB: pending human hardware verification.

## Outcome

The implemented scope passed build, focused behavior tests, plist validation,
release packaging, dependency inspection, and signing verification. Physical
DS5 acceptance remains pending because the connected controller is available
only to the human reviewer. No DS4, Xbox, or Nintendo controller is claimed as
supported by this change.

## Follow-ups

- Run the interaction matrix with a physical DS5 over Bluetooth and USB.
- Add separate human-owned requirements before claiming or adapting another
  controller family.
