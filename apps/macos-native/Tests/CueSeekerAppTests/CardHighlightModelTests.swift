import AppKit
import CueSeekerCore
import SwiftUI
import Testing
@testable import CueSeekerApp

/// Covers `docs/human/requirements/20261021-UI-Separate Hover And Select States
/// And Unify Pointer Rules.md` for cover card `Hover` and `Select` states.
@Suite(.serialized)
@MainActor
struct CardHighlightModelTests {
    private func workbench() -> CardHighlightModel {
        CardHighlightModel(keepsCurrentWhenPointerLeaves: false)
    }

    private func playback() -> CardHighlightModel {
        CardHighlightModel(keepsCurrentWhenPointerLeaves: true)
    }

    @Test
    func hoverUpdatesImmediatelyWhenCursorIsVisibleAndHidesWhenCursorIsHidden() {
        AppCursorVisibility.resetForTesting()
        defer { AppCursorVisibility.resetForTesting() }

        let model = workbench()
        model.noteHover(true, id: "a")
        #expect(model.hoveredID == "a")
        #expect(model.isHovered("a"))
        #expect(!model.isSelected("a"))

        // Hiding the cursor suppresses Hover while remembering the raw card
        // under the pointer.
        AppCursorVisibility.setHidden(true)
        let hiddenModel = playback()
        hiddenModel.setSelected("a")
        hiddenModel.noteHover(true, id: "b")
        #expect(hiddenModel.selectedID == "a")
        #expect(hiddenModel.hoveredID == nil)
        #expect(!hiddenModel.isHovered("b"))
    }

    @Test
    func selectVisualStyleTakesPriorityOverHoverWithoutStacking() {
        AppCursorVisibility.resetForTesting()
        let model = playback()
        model.setSelected("a")
        model.noteHover(true, id: "b")

        #expect(model.isSelected("a"))
        #expect(!model.isHovered("a"))
        #expect(model.isHovered("b"))
        #expect(!model.isSelected("b"))
        #expect(model.isHighlighted("a"))
        #expect(model.isHighlighted("b"))

        // When Hover and Select sit on the same card, only Select is shown.
        model.noteHover(false, id: "b")
        model.noteHover(true, id: "a")
        #expect(model.isSelected("a"))
        #expect(!model.isHovered("a"))
        #expect(model.isHighlighted("a"))
    }

    @Test
    func wheelScrollingLocksHoverUntilDebounceSettlesOrPointerMoves() {
        AppCursorVisibility.resetForTesting()
        let model = workbench()
        model.noteHover(true, id: "a")
        #expect(model.hoveredID == "a")

        // Scrolling slides another card under a stationary pointer; Hover stays
        // locked during the scroll.
        model.noteScrolled()
        model.noteHover(false, id: "a")
        model.noteHover(true, id: "b")
        #expect(model.hoveredID == "a")

        // Once the 300ms scroll debounce settles, Hover updates to the card
        // now under the pointer.
        model.noteScrollSettled()
        #expect(model.hoveredID == "b")

        // Physical pointer movement during scrolling also immediately updates.
        model.noteScrolled()
        model.noteHover(false, id: "b")
        model.noteHover(true, id: "c")
        #expect(model.hoveredID == "b")
        model.notePointerMoved()
        #expect(model.hoveredID == "c")
    }

    @Test
    func leavingCardClearsHoverWhilePreservingSelect() {
        AppCursorVisibility.resetForTesting()
        let workbenchModel = workbench()
        workbenchModel.noteHover(true, id: "a")
        workbenchModel.noteHover(false, id: "a")
        #expect(workbenchModel.hoveredID == nil)

        let playbackModel = playback()
        playbackModel.setSelected("a")
        playbackModel.noteHover(true, id: "b")
        playbackModel.noteHover(false, id: "b")
        #expect(playbackModel.hoveredID == nil)
        #expect(playbackModel.selectedID == "a")
    }

    @Test
    func rightClickPressUpdatesHoverOnlyAndNeverChangesSelect() {
        AppCursorVisibility.resetForTesting()
        let model = playback()
        model.setSelected("a")
        model.notePress(id: "b")
        #expect(model.selectedID == "a")
        #expect(model.hoveredID == "b")
    }

    @Test
    func unfreezingImmediatelyReevaluatesHoverFromCurrentPointerLocation() {
        AppCursorVisibility.resetForTesting()
        let model = workbench()
        model.notePress(id: "a")
        model.setFrozen(true)

        // While the menu is open, the pointer moves to card "b".
        model.noteHover(false, id: "a")
        model.noteHover(true, id: "b")
        #expect(model.hoveredID == "a")

        // Closing the menu unfreezes the layer and immediately updates Hover to
        // card "b" without waiting for another mouse move.
        model.setFrozen(false)
        #expect(model.hoveredID == "b")
    }

    @Test
    func unfreezingAfterPointerLeftAllCardsClearsHoverImmediately() {
        AppCursorVisibility.resetForTesting()
        let model = workbench()
        model.notePress(id: "a")
        model.setFrozen(true)
        model.noteHover(false, id: "a")
        #expect(model.hoveredID == "a")

        model.setFrozen(false)
        #expect(model.hoveredID == nil)
    }

    @Test
    func keyboardSelectionMoveImmediatelyClearsHoverAndSuppressesUntilPointerMoves() {
        AppCursorVisibility.resetForTesting()
        defer { AppCursorVisibility.resetForTesting() }
        let model = playback()
        model.setSelected("a")
        model.noteHover(true, id: "b", showsHand: true)
        #expect(model.selectedID == "a")
        #expect(model.hoveredID == "b")
        #expect(AppPointerShape.model.shape == .grab)

        // Moving selection by keyboard / controller immediately clears Hover on
        // card "b", resets the card hand cursor, and suppresses new Hover until
        // the pointer actually moves.
        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
        model.setSelected("c")
        #expect(model.selectedID == "c")
        #expect(model.hoveredID == nil)
        #expect(AppPointerShape.model.shape == .arrow)

        // Stationary hover reports or scroll debounce settling do not restore Hover.
        model.noteHover(true, id: "b", showsHand: true)
        #expect(model.hoveredID == nil)
        PointerHoverScrollState.shared.noteScrolled()
        PointerHoverScrollState.shared.settleScroll()
        #expect(model.hoveredID == nil)

        // Moving the pointer restores Hover on the card under the pointer.
        PointerHoverScrollState.shared.notePointerMoved()
        #expect(model.hoveredID == "b")
        #expect(AppPointerShape.model.shape == .grab)
    }

    @Test
    func resetClearsSelectAndHoverForSubInterfaceSwitch() {
        AppCursorVisibility.resetForTesting()
        let model = playback()
        model.setSelected("a")
        model.noteHover(true, id: "b")

        model.reset()
        #expect(model.selectedID == nil)
        #expect(model.hoveredID == nil)
    }

    @Test
    func windowResignFocusClearsUnfrozenHoverWhilePreservingSelectAndFrozenHover() {
        AppCursorVisibility.resetForTesting()
        let activeModel = playback()
        activeModel.setSelected("a")
        activeModel.noteHover(true, id: "b")
        #expect(activeModel.selectedID == "a")
        #expect(activeModel.hoveredID == "b")

        activeModel.noteWindowDidResignFocus()
        #expect(activeModel.selectedID == "a")
        #expect(activeModel.hoveredID == nil)

        let frozenModel = workbench()
        frozenModel.notePress(id: "c")
        frozenModel.setFrozen(true)
        frozenModel.noteWindowDidResignFocus()
        #expect(frozenModel.hoveredID == "c")

        frozenModel.setFrozen(false)
        #expect(frozenModel.hoveredID == nil)
    }

    @Test
    func workbenchAnimatesHoverBackgroundWhilePlaybackDisablesHoverAnimation() {
        #expect(workbench().animatesHoverBackground)
        #expect(!playback().animatesHoverBackground)
        #expect(WorkbenchControlMetrics.redesignLibraryCoverActionBackgroundLightOpacity == 0.72)
        #expect(WorkbenchControlMetrics.redesignLibraryCoverActionBackgroundDarkOpacity == 0.72)
        #expect(WorkbenchControlMetrics.redesignLibraryCoverActionHoverBackgroundLightOpacity == 0.56)
        #expect(WorkbenchControlMetrics.redesignLibraryCoverActionHoverBackgroundDarkOpacity == 0.56)
        #expect(WorkbenchControlMetrics.redesignLibraryCoverActionPressedBackgroundLightOpacity == 0.40)
        #expect(WorkbenchControlMetrics.redesignLibraryCoverActionPressedBackgroundDarkOpacity == 0.40)
    }

    @Test
    func coverCardsUseUnifiedPointerHoverAndReevaluateHoverAndCursorOnMenuAndDialogUnfreeze() throws {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        AppPointerShape.resetForTesting()
        defer {
            PointerHoverScrollState.shared.resetForTesting()
            AppPointerShape.resetForTesting()
        }

        let layers = InterfaceLayerRegistry()
        let highlight = CardHighlightModel(keepsCurrentWhenPointerLeaves: false)
        let actions = LibraryCardActionHandlers(
            revealFile: { _ in },
            openFolder: { _ in },
            changeCover: { _, _, _ in },
            markVideo: { _, _ in },
            markFolder: { _, _ in }
        )
        let folderA = CompleteLibraryFolderSummaryPresentation(
            folderPath: "/library/folder-a",
            folderTitle: "Folder A",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 12
        )
        let folderB = CompleteLibraryFolderSummaryPresentation(
            folderPath: "/library/folder-b",
            folderTitle: "Folder B",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 12
        )

        let cardsView = HStack(spacing: 16) {
            LibraryFolderCard(
                folder: folderA,
                highlight: highlight,
                isSelected: highlight.isSelected(folderA.id),
                isHovered: highlight.isHovered(folderA.id),
                actions: actions,
                openContextMenu: { _, _, _ in },
                onOpen: {}
            )
            .frame(width: 180, height: 150)

            LibraryFolderCard(
                folder: folderB,
                highlight: highlight,
                isSelected: highlight.isSelected(folderB.id),
                isHovered: highlight.isHovered(folderB.id),
                actions: actions,
                openContextMenu: { _, _, _ in },
                onOpen: {}
            )
            .frame(width: 180, height: 150)
        }
        .frame(width: 420, height: 180)
        .cardHighlightFreeze(highlight)
        .modifier(InterfaceLayerCoverageBridge(layers: layers))
        .environmentObject(makeTestAppLocalizationStore())

        let host = NSHostingView(rootView: cardsView)
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 180)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        func collectCardProbes(in view: NSView) -> [PointerHoverProbeView] {
            var result: [PointerHoverProbeView] = []
            if let probe = view as? PointerHoverProbeView,
               probe.bounds.width >= 150 {
                result.append(probe)
            }
            for subview in view.subviews {
                result.append(contentsOf: collectCardProbes(in: subview))
            }
            return result
        }
        func hasLegacyFocusOnlyProbe(in view: NSView) -> Bool {
            if view is WindowFocusHoverProbeView {
                return true
            }
            return view.subviews.contains(where: hasLegacyFocusOnlyProbe)
        }

        #expect(!hasLegacyFocusOnlyProbe(in: host))
        let cardProbes = collectCardProbes(in: host).sorted {
            $0.convert(NSPoint.zero, to: host).x < $1.convert(NSPoint.zero, to: host).x
        }
        #expect(cardProbes.count == 2)

        // 1. Right-click Card A to open its context menu, move pointer to a non-card
        // blank area while the menu is open, then dismiss the menu:
        // Card A's Hover and `...` button must clear and cursor must stay `.arrow`.
        cardProbes[0].session?.report(true)
        highlight.notePress(id: folderA.id)
        #expect(highlight.hoveredID == folderA.id)
        #expect(AppPointerShape.model.shape == .grab)

        var menuToken: InterfaceLayerRegistry.OpenMenuToken? =
            layers.registerOpenMenu(ownedBy: .workbenchPage)
        AppPointerShape.reset()
        #expect(layers.isFrozen(.workbenchPage))
        #expect(AppPointerShape.model.shape == .arrow)

        cardProbes[0].session?.report(false)
        #expect(highlight.hoveredID == folderA.id)

        menuToken = nil
        _ = menuToken
        #expect(highlight.hoveredID == nil)
        #expect(!highlight.isPointerHovered(folderA.id))
        #expect(AppPointerShape.model.shape == .arrow)

        // 2. Right-click Card A to open its menu, move pointer onto Card B while
        // frozen, then dismiss the menu: Card A clears, Card B lights up, cursor is `.grab`.
        cardProbes[0].session?.report(true)
        highlight.notePress(id: folderA.id)
        menuToken = layers.registerOpenMenu(ownedBy: .workbenchPage)
        AppPointerShape.reset()

        cardProbes[0].session?.report(false)
        cardProbes[1].session?.report(true)
        #expect(highlight.hoveredID == folderA.id)
        #expect(AppPointerShape.model.shape == .arrow)

        menuToken = nil
        _ = menuToken
        #expect(highlight.hoveredID == folderB.id)
        #expect(AppPointerShape.model.shape == .grab)

        // 3. Open menu from Card B's `...` action button (cursor is `.arrow`), move
        // pointer to blank space, then dismiss: Card B clears and cursor stays `.arrow`.
        highlight.noteActionButtonHover(true, id: folderB.id)
        #expect(AppPointerShape.model.shape == .arrow)
        menuToken = layers.registerOpenMenu(ownedBy: .workbenchPage)
        AppPointerShape.reset()

        highlight.noteActionButtonHover(false, id: folderB.id)
        cardProbes[1].session?.report(false)
        menuToken = nil
        _ = menuToken
        #expect(highlight.hoveredID == nil)
        #expect(AppPointerShape.model.shape == .arrow)

        // 4. Open a dialog from Card B's menu, close the menu while the dialog keeps
        // `.workbenchPage` frozen, leave Card B, then close the dialog:
        // Card B clears and cursor stays `.arrow`.
        cardProbes[1].session?.report(true)
        highlight.notePress(id: folderB.id)
        menuToken = layers.registerOpenMenu(ownedBy: .workbenchPage)
        AppPointerShape.reset()

        layers.setOpen(.dialog, true)
        menuToken = nil
        _ = menuToken
        #expect(layers.isFrozen(.workbenchPage))
        #expect(highlight.hoveredID == folderB.id)

        cardProbes[1].session?.report(false)
        layers.setOpen(.dialog, false)
        #expect(!layers.isFrozen(.workbenchPage))
        #expect(highlight.hoveredID == nil)
        #expect(AppPointerShape.model.shape == .arrow)
    }
}
