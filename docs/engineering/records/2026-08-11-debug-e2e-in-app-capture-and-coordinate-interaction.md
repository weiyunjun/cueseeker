# Requirement

- `docs/human/requirements/20260811-Engineering-Debug End-to-End In-App Capture And Coordinate Interaction.md`

# Scope

- Add an explicit Debug-only command path for in-app screenshots and known-coordinate left clicks.
- Keep screenshots as visible-result evidence rather than a control-location mechanism.
- Preserve normal Debug, Release, product URL Scheme, and product-state behavior.

# Steps

- Added a Debug E2E controller that reads one-line `capture` and `click` commands from the running process input and emits prefixed JSON results.
- Captured the main window directly from its AppKit view hierarchy into a per-process PNG artifact directory.
- Reused the existing Playback current-frame screenshot presentation during window capture so video and subtitles remain available without desktop capture.
- Converted upper-left logical content coordinates to AppKit window coordinates and dispatched a normal left mouse down/up pair through window hit testing.
- Updated the testing rules and end-to-end procedure with the command protocol, coordinate contract, evidence boundary, and failure behavior.

# Verification

- The focused Debug E2E tests pass for command parsing, coordinate conversion, AppKit hit testing, PNG output, invalid coordinates, and invalid capture names.
- `swift test --no-parallel --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` passes all remaining 969 tests. The skipped pre-existing order-dependent persistence test also passes when run alone.
- `swift build -c release --product CueSeeker` passes. The Release executable does not contain the Debug E2E launch flag; the Debug executable does.
- A real Debug launch emitted its ready dimensions and artifact directory.
- The running app produced a readable `2866 × 1642` in-app PNG at a `2×` backing scale.
- A known-coordinate click changed the visible Workbench state, and a following in-app capture recorded the changed state.
- A second known-coordinate click opened real playback; the in-app capture contained the submitted video frame and both visible subtitle lines.

# Outcome

- Known CueSeeker UI flows can now click documented positions and capture evidence without system screenshots, image recognition, real-pointer movement, or Accessibility permission.
- Playback capture fails when no submitted frame exists instead of silently substituting external desktop capture.

# Follow-ups

- Feature-specific E2E procedures should replace manual known-UI clicks with documented Debug controller coordinates when those procedures are next exercised or updated.
