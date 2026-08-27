# Confirmation dims and blocks the whole window, like the other dialogs

Human-owned documents:

- `docs/human/requirements/20260827-UI-Confirmation Dialog Modality And Unified Presentation.md`
- `docs/human/design/UI Application Rules.md`

## Why

`UI Application Rules.md` puts Confirmation in the same 对话框 layer as Edit Cover and the Shiori List Editor, and says only the topmost interactive layer takes pointer, wheel and keyboard. The App did not do that, because Confirmation reached the screen by a different route than the other two.

Edit Cover and the Shiori List Editor are presented as sheets from the window root, so macOS dims and blocks the entire window — sidebar, top bar and page together. Confirmation was drawn as an overlay inside whichever page raised it, with a hand-painted scrim of its own. A scrim can only cover the rectangle it is drawn in, so the sidebar and the top bar kept their normal colour and kept accepting clicks while a destructive confirmation was open. Confirmation also never reported itself to the layer registry, so nothing in the App considered a dialog open, and the freeze rules that the design attaches to a higher layer did not apply to it either.

The fix is not to widen the scrim. It is to stop having two ways to present a modal.

## What changed

Confirmation is now a session, like the other two dialogs. The page that raises one writes it to the app-level confirmation holder; the window root presents it as a sheet alongside Edit Cover and the Shiori List Editor. Dimming and the input barrier come from that one presentation, so the confirmation's own scrim is gone.

The registry's dialog layer now follows all three sessions rather than two, which is what makes the freeze and coverage answers identical for a confirmation and for an editor.

The holder is a small observable object on the coordinator, in the shape `ToastCenter` already established, rather than another `@Published` on `AppCoordinator` itself. Sixteen views observe the coordinator; opening a confirmation should not invalidate them.

Dialogs are deliberately not mutually exclusive. A confirmation raised from inside another dialog is presented by that dialog, and a sheet presented from within a sheet stacks natively — the layer is already open in that case, so nothing else has to change. This session adds no such case; it only leaves the door open, which the requirement asks for.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchConfirmationDialog.swift`
  - `WorkbenchConfirmationSession` and `ConfirmationCenter` added; the dialog takes a session, and its `Color.black.opacity(0.18)` scrim and the `ZStack` around it are gone. The two-init split moved from the view to the session, so the view has one initializer.
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
  - `confirmation` holder added; the dialog-layer observer is `CombineLatest3` over the three sessions.
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
  - Third `.sheet(item:)` at the window root, marked `.interfaceLayer(.dialog)` like its neighbours.
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListOverviewView.swift`
  - `pendingDeletion` state and its overlay replaced by opening the session. Delete still leaves the dialog open when the database rejects the delete.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchShioriTableView.swift`
  - `pendingRemoval` state and its overlay replaced the same way.
- `apps/macos-native/Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift`
  - The `dialog` case no longer documents Confirmation as the exception that blocks input with its own scrim.

No confirmation text, button, style, order, shortcut or resulting action changed, and no token was added, changed or removed.

## Verification

`swift build`: clean. `swift test`: 1098 tests.

The failing set was compared against a pristine HEAD copy rather than judged on its own. `git archive HEAD apps/macos-native` was expanded in a temporary directory with `CUESEEKER_MEDIA_RUNTIME_ROOT` pointed at the repository's media runtime, so the owner's working tree was never reverted. Baseline: 15 distinct failing tests. Changed tree: those same 15 plus 6. All 6 pass when their suites run alone — `LibraryFolderRemovalTests` 8 of 8, `PlaybackSubtitleFocusKeyboardActionTests` 33 of 33 — which is the suite parallelism flake earlier records already describe; the three library ones fail under load with a SQLite `disk I/O error` and the three focus ones with `timedOut`. The 15 shared failures are the known native playback timeline, refresh scope and window geometry ones. `InterfaceLayerFreezeTests`, `ShioriListEditorTests`, `ShioriPresentationTests`, `SubtitleTableRowActionMenuTests` and `MenuInputBarrierTests` pass together, 36 tests.

The behaviour itself was measured with the Debug E2E controller against the owner's real library, not eyeballed. Opening Delete List from a Shiori card's context menu produces a second window of kind `sheet`, 360 by 191, and the capture shows the sidebar, the top bar and the page dimmed together — the same picture Edit List produces. With it open, a click on the sidebar's Library row and a click on the top bar's sidebar toggle both leave the page, the sidebar and the dialog exactly as they were, and a five-line wheel event over the table moves nothing. Escape closes it. The same holds for Remove Shiori raised from a table row's context menu: sheet window, whole-window dim, wheel absorbed, and Cancel restores full brightness with the row and the list's 28 results intact. After the dialog closes, the same sidebar click navigates normally.

Two acceptance points stay the owner's manual check, for reasons the E2E document already states rather than anything this change introduced. Hover is one: `mouseMove` cannot drive SwiftUI `.onHover`, so "no hover change while the dialog is open" and "the highlight stays put until the pointer really moves" cannot be synthesized. Enter is the other: it is wired to the Cancel button through `.defaultAction`, unchanged by this change, and exercising it against the owner's real library risks destroying a list if that wiring were ever wrong. No test capability was added.
