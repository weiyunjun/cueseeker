# 2026-11-16 Command Panel Width, Secondary Header Title Layout, and Root Close Hint

- **Covering Requirement**: `docs/human/requirements/20261116-UI-Command Panel Width Secondary Title Layout And Root Close Hint.md`
- **Referenced Design & Engineering Documents**:
  - `docs/engineering/02_git_workflow.md`
  - `docs/engineering/04_architecture_rules.md`
  - `docs/human/design/playback/Command Panel.md`
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Design Rules.md`
  - `docs/human/design/ui/UI Interaction Rules.md`
  - `docs/human/design/ui/UI Text Selection Rules.md`
  - `docs/human/design/ui/UI Accessibility Rules.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Controls.md`
  - `docs/human/design/ui/UI Components - Domain.md`
  - `docs/human/design/ui/UI Layouts - Playback.md`
  - `docs/human/design/ui/Tooltip Usage Registry.md`
- **Branch / Baseline**: `main` (pre-requirement baseline `3492be4`, requirement commit `4a81577`)

## Scope

1. Narrow `WorkbenchControlMetrics.redesignCommandPanelMaxWidth` from `1040` to `720` without introducing new tokens or changing viewport insets, minimum window width, or minimum media card width (`220px`), so the Command Panel fits 3 cover cards per row at default width and keeps Command Panel `Toast` trailing anchoring synchronized.
2. Left-align secondary header titles (`Search Results`, `Recent Videos`, `Recent Excerpt Lists`) in `PlaybackCommandPanelSecondaryHeader` `12px` (`--spacing-3`) to the right of the back button, remove the superseded `PlaybackCommandPanelHeaderLayoutGeometry` and `PlaybackCommandPanelSecondaryHeaderLayout` types plus obsolete centering tests, keep `WorkbenchSelectableText` with `fullCopyText: title`, and attach `.workbenchTruncatedTextTooltip` (matching the title font size and weight) directly to the title text before `Spacer(minLength: 0)`.
3. Add fixed `Esc` keycap support to `PlaybackCueFooter`, show a `"common.close"` + `Esc` shortcut action button to the left of `Open` / `Copy` (`Return`) exclusively in the `PlaybackCommandPanelRoot` footer, route clicks and accessibility activation through `dismissPlaybackCommandPanelFromUser()`, and place `.commandPanelFooterAction("close")` immediately before `.commandPanelFooterAction("open")` in the Command Panel root accessibility target list.

## Summary of Changes

1. **Command Panel Maximum Width (`apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControlMetrics.swift`)**:
   - Updated `WorkbenchControlMetrics.redesignCommandPanelMaxWidth` from `1_040` to `720` (`--width-command-panel-max: 720px`), shared by both `PlaybackCommandPanel` and `ContentToastLayerHost` in `ContentView.swift`.

2. **Secondary Header Left Alignment & Truncation Tooltip (`apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`)**:
   - Deleted `PlaybackCommandPanelHeaderLayoutGeometry` and `PlaybackCommandPanelSecondaryHeaderLayout`.
   - Replaced the custom centered layout in `PlaybackCommandPanelSecondaryHeader` with an outer `HStack(spacing: WorkbenchControlMetrics.redesignSpacing3)` around the back button, an inner zero-spacing `HStack(spacing: 0)` holding `WorkbenchSelectableText(..., fullCopyText: title, lineLimit: 1, truncationMode: .tail)` + `.workbenchTruncatedTextTooltip(scenarioID: "truncated.command_panel.secondary_title", text: title, font: titleFont)` + `Spacer(minLength: 0)`, and `trailing`.

3. **Root Footer `Close` + `Esc` Action & Accessibility (`PlaybackCueFooter.swift`, `PlaybackCommandPanel.swift`, `AppCoordinator+WorkbenchAccessibility.swift`)**:
   - Added `PlaybackCueFooterKeycap.escapeKey` (`.text("Esc")`), `PlaybackCueFooterKeys.escapeKey`, and `PlaybackCueFooterAction.close(perform:)` using `L("common.close")` in `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCueFooter.swift`.
   - Added `onClose` on `PlaybackCommandPanelRoot` (invoking `appState.dismissPlaybackCommandPanelFromUser()`) and optional `onClose` on `PlaybackCommandPanelFooter` so only the root footer renders `"close"` to the left of `"open"`, leaving all secondary page footers unchanged.
   - Added `.commandPanelFooterAction("close")` before `.commandPanelFooterAction("open")` in `AppCoordinator+WorkbenchAccessibility.swift` for `.commandPanel(.root)` and handled `case "close"` in `activatePlaybackAccessibilityTarget(_:)` via `dismissPlaybackCommandPanelFromUser()` and `reconcilePlaybackAccessibilityFocus()`.

4. **Pure-Logic Test Updates (`Tests/CueSeekerAppTests/`)**:
   - `WorkbenchControlMetricsTests.swift`: updated `mediaCardGridMetricsAndMinimumWindowColumnCountMatchSpecification()` to verify `redesignCommandPanelMaxWidth == 720` and 3-column grid capacity at `680px` (`720 - 40`).
   - `PlaybackSearchOverlayTests.swift`: removed the obsolete `commandPanelSecondaryHeaderCentersShiftsAndTruncatesTitleAroundControls()` test targeting the deleted centering geometry type.
   - `PlaybackSubtitleFocusLayoutTests.swift`: verified `PlaybackCueFooterAction.close` (`id == "close"`, `title == L("common.close")`, `keys == .escapeKey`, and action execution) and `PlaybackCueFooterKeycap.escapeKey`.
   - `WorkbenchAccessibilityStep4Tests.swift`: updated root accessibility target sequences to expect `.commandPanelFooterAction("close")` before `.commandPanelFooterAction("open")`, verified secondary pages omit `"close"`, verified activating `"close"` dismisses the Command Panel and clears accessibility focus, and added `"close"` to `playbackCueFooterReRendersFocusRingAcrossOverlayAndCommandPanelActions`.

## Verification

- **Build check**:
  - `swift build --package-path apps/macos-native`: succeeded cleanly (`Build complete! (11.33s)`).
- **Filtered headless pure-logic unit tests (excluding legacy window-popping suites)**:
  - Command: `swift test --package-path apps/macos-native --filter "PlaybackSearchOverlayTests|WorkbenchControlMetricsTests|PlaybackSubtitleFocusLayoutTests|WorkbenchAccessibilityStep4Tests|NoFolderOnboardingAndFileEmptyStateTests|PlaybackSubtitleFocusKeyboardActionTests|PlaybackReelCopyAndCommandPanelRoutingTests" --skip "playbackOverlayCurrentAndPlaylistShareFullWidthCueGeometry|DebugE2EControllerTests|WorkbenchInputControlsTests|PointerHoverGateTests|CueGroupRefreshScopeIntegrationTests|PlaybackPageFocusIsolationTests"`
  - Result: `141` tests passed in `2.675` seconds (`0` failures; `playbackOverlayCurrentAndPlaylistShareFullWidthCueGeometry` skipped due to a pre-existing `PlaybackOverlayModule.collage` mismatch on `main`).
  - `TooltipTests`: `swift test --package-path apps/macos-native --filter "TooltipTests" --skip "tooltipRemainsVisibleAcrossWindowFocusLossAndDismissesOnWindowClose"` passed `7` tests in `0.642` seconds (`0` failures; `tooltipRemainsVisibleAcrossWindowFocusLossAndDismissesOnWindowClose` skipped because `TooltipCenter()` defaults `installEventMonitors` to `false` on `main`).
- **Engineering doc language check**:
  - `bash scripts/verify_engineering_doc_lang.sh docs/engineering/records/20261116-command-panel-width-secondary-title-layout-and-root-close-hint.md`

## Outcome

All three Command Panel UI adjustments and their pure-logic accessibility/layout updates are built and verified against targeted headless test suites. Pending user visual and interactive end-to-end acceptance (Light & Dark modes, window widths, truncated title selection/copy/tooltip hover, and `Close Esc` button + accessibility traversal) prior to synchronizing the UI design documents.
