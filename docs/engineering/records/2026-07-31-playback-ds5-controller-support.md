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

## Verification

- `swift build --product CueSeeker`: passed.
- Focused controller, Collage preview, and overlay input selection: passed, 12
  tests.
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
