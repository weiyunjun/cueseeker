# Requirement

- `docs/human/requirements/20260814-Feature-Sidebar Selection Settings Icon Alignment And Dock Window Labels.md`
- `docs/human/design/UI Design System.md`

# Scope

- Align the Workbench and Settings Sidebar selection presentation.
- Align Settings category icons and extend the Sidebar through the titlebar.
- Keep the native Dock window labels stable as `CueSeeker` and `Settings`.

# Steps

- Mapped selected Sidebar background and content to shared semantic color tokens.
- Suppressed primary-item selection while a Recent or Shiori child is selected.
- Replaced Settings `Label` rows with the shared fixed icon-column and item metrics.
- Made the Settings window full-size-content with a transparent hidden title while preserving its `Settings` window title.
- Removed playback-driven main-window title changes and the now-unused display-title projection.
- Registered a standard AppKit Window menu so visible titled windows participate in the native Dock window list; AppKit owns window insertion, removal, focus indication, and activation.
- Added the explicit manual Dock-menu acceptance sequence without extending the in-app E2E controller into OS-owned UI.

# Verification

- `swift build --product CueSeeker` passed.
- `swift build -c release --product CueSeeker` passed.
- `swift test --filter WorkbenchLayoutState` passed all 10 focused layout-state tests after the Window-menu correction.
- The focused Workbench layout and Debug E2E suites passed 17 tests.
- Existing Debug E2E capture verified the Settings Sidebar behind the traffic lights, no visible window title, aligned category rows, child-only selection, and window metadata titled `CueSeeker` and `Settings`.
- A focused AppKit lifecycle probe verified that ordering a titled window to the front adds it to the registered Window menu and closing it removes the item again.
- The broader 1,000-test run passed 998 tests. Two Shiori refresh-scope timing assertions failed and reproduced in isolation; this change does not modify those tests or their AppKit table refresh path.

# Outcome

- The native Window-menu integration is now present, and the corrected build is ready for visual and Dock-menu acceptance.
- The Dock menu remains a native macOS system-menu acceptance check; no additional automated E2E capability is required.

# Follow-ups

- After final UI acceptance, synchronize the accepted tokens and Settings layout rules into the UI Design System and record the user-visible outcome in the changelog.
