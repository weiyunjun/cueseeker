# Requirement

- `docs/human/requirements/20260811-Engineering-Debug End-to-End In-App Capture And Coordinate Interaction.md`

# Scope

- Replace the main-content-view capture with complete-scene ScreenCaptureKit output.
- Add complete-scene inspection and stale-scene protection to known-coordinate clicks.
- Keep screenshots as visible-result evidence rather than a control-location mechanism.
- Preserve normal Debug, Release, product URL Scheme, and product-state behavior.

# Steps

- Added `inspect`, `capture`, and stale-scene-protected `click` commands with complete-scene dimensions and front-to-back window metadata.
- Enumerated every visible CueSeeker-owned AppKit window, required one display, and captured their actual WindowServer composition with ScreenCaptureKit.
- Removed the Playback capture substitute so captures use the currently displayed video frame and subtitles directly.
- Converted complete-scene coordinates to the frontmost target window and posted a normal AppKit left mouse down/up pair without moving the pointer or calling product actions.
- Made capture permission, missing-window, multi-display, layout-change, coordinate, encoding, and save failures explicit with no reconstruction or incomplete fallback.
- Updated the testing rules and end-to-end procedure with the complete-scene contract, current-process capture behavior, command protocol, and failure boundaries.

# Verification

- Focused Debug E2E tests pass for command parsing, complete-scene geometry, frontmost-window click routing, PNG output, invalid coordinates, and invalid capture names.
- `swift test --no-parallel --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` passes 969 tests. The skipped pre-existing order-dependent persistence test passes when run alone.
- `swift build -c release --product CueSeeker` passes. The Release executable contains neither the Debug E2E launch flag nor a ScreenCaptureKit dependency.
- A real Debug launch reported a `1433 × 821` logical scene, `2866 × 1642` pixel output, `2×` scale, scene token, and current window layout.
- Known-coordinate clicks opened and closed the Settings window and Shiori Sheet through AppKit's event queue without blocking standard window controls.
- Complete-scene captures contain the main window plus the real Settings window and Number Field, and the main window plus the real Shiori Sheet, Text Field, and Text Area.
- A playback capture contains the actual decoded video frame and both visible subtitle lines without a temporary replacement view.

# Outcome

- Known CueSeeker UI flows can click documented complete-scene positions and capture all visible app windows without external screenshots, image recognition, real-pointer movement, or Accessibility permission.
- Screenshots now represent the actual WindowServer composition, including independent windows, Sheets, standard controls, video, subtitles, focus, and occlusion.

# Follow-ups

- Feature-specific E2E procedures should replace manual known-UI clicks with documented Debug controller coordinates when those procedures are next exercised or updated.
