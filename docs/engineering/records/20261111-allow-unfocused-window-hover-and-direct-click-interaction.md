# 2026-11-11: Allow Unfocused Window Hover and Direct Click Interaction Without Window Penetration

## Requirement
- `docs/human/requirements/20261111-UI-Allow Unfocused Window Hover And Direct Click Interaction Without Window Penetration.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/retrospectives/20261105-Retrospective-Window Focus Spoofing And Synthetic Event Injection Breaking Launch And Clicks.md`

## Scope
Allow exposed (unoccluded) regions of all CueSeeker windows (Main Window and Settings Window) to respond naturally to pointer hover, `Tooltip`, playback `Player UI` wake/auto-hide, and first-click direct execution (`acceptsFirstMouse`) regardless of whether the window or application currently holds focus, while strictly preventing window penetration through covering windows and strictly preserving the 2026-11-05 retrospective guardrails (zero focus spoofing, zero fake coordinates, zero synthetic `NSEvent` injection, zero manual `makeKeyAndOrderFront` inside `sendEvent`).

## Steps
1. **Unfocused Hover & Tooltip Without Window Penetration (`PointerHover`, `CardHighlightModel`, `MenuHighlightModel`, `MenuSubmenu`, `CueSeekerMainWindow`, `MenuGate`, `Tooltip`, `TableScrollbarPrimitive`, `WorkbenchScrollView`, `SubtitleTableChromeAndHeaderViews`, `SubtitleTableCoordinator+SelectionAndInput`, `SubtitleTableView`, `PlaybackCollagePreview`, `PlaybackSubtitleFocusReel`)**:
   - Removed focus-loss hover/tooltip clearing and unfocused hover suppression (`didResignActiveNotification` / `didResignKeyNotification` clearing, `isWindowFocused`, `isHostingWindowFocused`, `CardHighlightWindowProbe`, and `MenuHighlightWindowProbe`) across all SwiftUI and AppKit surfaces.
   - Switched custom AppKit tracking areas (`PointerHoverProbeView`, `WindowFocusHoverProbeView`, `TooltipTrackingNSView`, `TableScrollbarOverlayView`, `SubtitleVirtualTableHeaderView`, `SubtitleVirtualTableDocumentView`, `PlaybackCollagePreviewScrollContainerView`) to `.activeAlways` so macOS WindowServer natively clips tracking to unoccluded window regions.
   - Added topmost WindowServer ownership checks (`NSWindow.windowNumber(at:belowWindowWithWindowNumber:) == window.windowNumber`) wherever stationary coordinates (`mouseLocationOutsideOfEventStream`) or exit transitions are evaluated, ensuring covering windows (such as Finder or CueSeeker's Settings window) immediately clear hover underneath and never penetrate.
2. **Single-Click Direct Execution on Unfocused Windows (`AppPointerShape`, `TableScrollbarPrimitive`, `SubtitleTableChromeAndHeaderViews`, `PlaybackCollagePreview`, `PlaybackSubtitleFocusReelDocumentView`, `PlaybackSubtitleFocusOverlay`, `WorkbenchTextAreaInput`, `TitlebarBackgroundView`)**:
   - Overrode `acceptsFirstMouse(for:) -> Bool { true }` on `CueSeekerHostingView` and custom interactive AppKit views, switched subtitle table header hosts onto `CueSeekerHostingView`, and allowed unfocused `leftMouseDown` in `PlaybackCollagePreview` to pass cleanly to `window.sendEvent` so the first click/drag executes the control action while macOS naturally activates the window.
   - Updated `AppPointerShape` so `NSApp.isActive` applies the decided cursor (`Grab`, `I-beam`, or arrow) over any exposed CueSeeker window even when another CueSeeker window holds focus, while yielding global cursor ownership to macOS when an external application is active.
3. **Playback `Player UI` & Cursor Visibility Rules (`PlaybackChromeVisibilityModel`)**:
   - Added topmost window ownership checking (`isPointerOverPlayerWindow`) to `isPointerInPlayerArea` so covering windows do not wake `Player UI` and moving onto a covering window hides `Player UI`.
   - Updated `pointerMoved()`, `reevaluate()`, `isIdleCountdownDue`, and `idleElapsed()` so unfocused exposed player areas wake `Player UI` on motion and auto-hide `Player UI` after 3 seconds of idle while keeping the OS cursor visible (hiding the OS cursor remains restricted to a focused playback window, and losing focus while the cursor is hidden immediately unhides the OS cursor without forcibly waking `Player UI`).
4. **Architecture Rules & Unit Tests (`04_architecture_rules.md`, `PointerHoverGateTests`, `CardHighlightModelTests`, `MenuHighlightModelTests`, `PlaybackChromeVisibilityModelTests`, `SubtitleTableVirtualRowTests`, `TooltipTests`, `WorkbenchAccessibilityStep4Tests`)**:
   - Updated `docs/engineering/04_architecture_rules.md` to reflect unfocused hover, `.activeAlways` tracking, topmost window ownership verification, and `acceptsFirstMouse` behavior.
   - Updated and expanded unit tests covering unfocused hover preservation/updates, `acceptsFirstMouse` across hosting and custom AppKit views, cross-window unoccluded hover, covering-window non-penetration, and unfocused `Player UI` 3s auto-hide without hiding the OS cursor.

## Verification
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "PointerHoverGateTests|CardHighlightModelTests|MenuHighlightModelTests|PlaybackChromeVisibilityModelTests|SubtitleTableVirtualRowTests|TooltipTests|PointerShapeModelTests|MenuInputBarrierTests|InterfaceLayerFreezeTests|WorkbenchAccessibilityStep1Tests|WorkbenchAccessibilityStep2Tests|WorkbenchAccessibilityStep3Tests|WorkbenchAccessibilityStep4Tests|WorkbenchPageScrollbarTests|PlaybackCollagePreviewTests|TaskCardMenuTests|FileCardMenuTests"` — all tests passed with zero warnings in modified files.

## Outcome
All unit and integration checks passed cleanly and matched the requirement specifications. End-to-end interactive and visual verification across external apps and multi-window layouts is ready for user acceptance.

## Follow-ups
- Propose and commit `docs/human/design/` updates after user E2E acceptance when requested.
