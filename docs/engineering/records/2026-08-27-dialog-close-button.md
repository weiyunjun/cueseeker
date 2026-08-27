# Every modal dialog closes from its own header

Human-owned documents:

- `docs/human/requirements/20260827-UI-Dialog Close Button.md`
- `docs/human/design/UI Design System.md`

## Why

All three modal dialogs could only be dismissed from their footer or from Esc. The Design System's shared Dialog anatomy already lists a Close Button built from Icon Button, so the affordance was described but never built.

Closing is the dialog's own action, not the footer's. Cancel is a content-level action that happens, in all three current dialogs, to be nothing more than the close path itself; a future dialog may have a close button and no Cancel at all. The implementation therefore binds the close button to the dialog's close, not to whatever the footer offers.

## What changed

One shared header carries the title and the close button, so the three dialogs cannot drift apart and the header maps to the one Dialog anatomy the Design System describes. It is placed inside each dialog's existing 24-point padding, which is what puts the button's trailing edge at the dialog's own inset without any new number.

The button is `WorkbenchIconButton` at its Default size, which is already the Design System's Icon Button — `--size-icon-button`, `--radius-control`, `--size-control-icon`, and the Default, Hover, Focused and Disabled states. No token, colour, radius or spacing value was added, changed or replaced, and no new component was introduced beyond the header itself.

Edit Cover and the Shiori List Editor close through the same handler their Cancel already used, and the button carries the same `isSaving` guard, so a save in flight blocks the close button exactly as it blocks Cancel.

Confirmation is the case where close and Cancel are not the same thing. The dialog now takes an explicit close closure that clears the session; it does not run the caller's cancel action. Both of today's confirmations pass a cancel action that only clears the session, so the visible result is identical, but a confirmation with no cancel action will still close.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogHeader.swift`
  - New. Title, flexible gap, close button.
- `apps/macos-native/Sources/CueSeekerApp/Library/LibraryEditCoverDialog.swift`
  - Title text replaced by the shared header; close bound to `onCancel`, disabled while saving.
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListEditor.swift`
  - Same, bound to `onClose`.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchConfirmationDialog.swift`
  - Same, plus an `onClose` parameter on the view.
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
  - The confirmation sheet passes a close that clears the session.
- `apps/macos-native/Sources/CueSeekerApp/Resources/*.lproj/Localizable.strings`
  - `common.close` added in English, Simplified Chinese and Traditional Chinese for the button's accessibility label. No visible copy changed.

## Verification

`swift build`: clean.

`swift test`: 1098 tests. The failing set was compared against a pristine baseline rather than judged on its own. `git archive HEAD apps/macos-native` was expanded in the scratchpad with `CUESEEKER_MEDIA_RUNTIME_ROOT` pointed at the repository's media runtime, so the working tree was never reverted. Baseline: 15 distinct failing tests — the known native playback timeline, refresh scope and window geometry ones. Changed tree: 14, of which 11 are shared with the baseline and 3 are different members of suites the baseline also fails in. All 3 pass when their suites run alone — `LibraryFolderRemovalTests` 8 of 8, `NativePlaybackPresentationTransitionTests` 2 of 2, `PlaybackSubtitleFocusKeyboardActionTests` 33 of 33 — which is the suite parallelism flake earlier records describe. Four tests that fail in the baseline pass in the changed tree, in the same flaky suites. No dialog test regressed: `InterfaceLayerFreezeTests`, `ShioriListEditorTests`, `ShioriPresentationTests`, `SubtitleTableRowActionMenuTests` and `MenuInputBarrierTests` pass together, 36 tests.

The behaviour was measured with the Debug E2E controller against the real library, not eyeballed. All three dialogs open as sheets and all three show the close button at the header's trailing edge, 32 by 32, inset 24 points from the dialog's own edges: Shiori List Editor 792 by 403, Edit Cover 760 by 600, Confirmation 360 by 199. A click at each computed centre closed its dialog and left the page as it was. The delete confirmation closed with the library still reading 5 Lists · 678 Cues and the card highlight still on 列表 5, so closing did not delete and did not move the highlight. Enter in Edit Cover changed nothing, because Save is the default action and is disabled with no image chosen; Esc closed it. Both match the behaviour before this change.

One difference from the baseline is recorded rather than corrected. The close button is the first focusable control in each dialog, so on open the focus ring is on it. The baseline put that ring on Cancel — confirmed by running the pristine copy and capturing Edit Cover, where Cancel carries the ring. Enter and Esc are unaffected, as measured above, because they are driven by the footer's `.defaultAction` and `.cancelAction` rather than by focus. The requirement asks for Icon Button's Focused state, so removing the button from the key view loop would contradict it; the owner should decide whether initial focus is meant to stay on Cancel.

Two acceptance points remain manual, for reasons the E2E document already states. Hover on the close button is one: `mouseMove` cannot drive SwiftUI `.onHover`, so no synthesized event produces the Hover background. The saving state is the other: reaching it needs a real image chosen through the system open panel, which the controller does not drive, and the state is transient. Both are limits of the existing capability, not of this change, and no test capability was added.
