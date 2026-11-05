import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

/// Covers `docs/human/requirements/20260826-UI-Card Highlight Single Authority
/// And Menu Input Rules.md` §8.1 for every surface that is not a card: while a
/// menu is open over its layer, or a higher layer covers it, the surface stops
/// answering the pointer.
@Suite(.serialized)
struct PointerHoverGateTests {
    @Test
    func anActiveSurfaceIsToldWhatThePointerDid() {
        var gate = PointerHoverGate()

        #expect(gate.report(true, isFrozen: false) == true)
        #expect(gate.report(false, isFrozen: false) == false)
    }

    @Test
    func nothingIsSaidTwice() {
        var gate = PointerHoverGate()
        #expect(gate.report(true, isFrozen: false) == true)

        // A repeat of what the surface is already painting says nothing.
        #expect(gate.report(true, isFrozen: false) == nil)
        #expect(gate.freezeChanged(isFrozen: false) == nil)
    }

    @Test
    func aFrozenSurfaceIsToldNothingAndKeepsItsPicture() {
        var gate = PointerHoverGate()

        #expect(gate.report(true, isFrozen: true) == nil)
        #expect(gate.report(false, isFrozen: true) == nil)
    }

    @Test
    func whereThePointerEndedUpIsDeliveredWhenTheFreezeLifts() {
        var gate = PointerHoverGate()
        #expect(gate.report(true, isFrozen: false) == true)

        // A menu opens, and the pointer walks off the control while it is up.
        #expect(gate.freezeChanged(isFrozen: true) == nil)
        #expect(gate.report(false, isFrozen: true) == nil)

        // The menu closes: the control must not be left lit behind the pointer.
        #expect(gate.freezeChanged(isFrozen: false) == false)
    }

    @Test
    func aPointerThatCameBackToWhereItStartedChangesNothing() {
        var gate = PointerHoverGate()
        #expect(gate.report(true, isFrozen: false) == true)

        #expect(gate.freezeChanged(isFrozen: true) == nil)
        #expect(gate.report(false, isFrozen: true) == nil)
        #expect(gate.report(true, isFrozen: true) == nil)

        #expect(gate.freezeChanged(isFrozen: false) == nil)
    }

    @Test
    func windowFocusLossImmediatelyClearsHoverAndSuppressesUntilFocusReturns() {
        var gate = PointerHoverGate()
        var locationGate = PointerHoverLocationGate()

        #expect(gate.report(true, isFrozen: false, isWindowFocused: true) == true)
        #expect(
            locationGate.report(
                CGPoint(x: 40, y: 10),
                isFrozen: false,
                isWindowFocused: true
            ) == .some(CGPoint(x: 40, y: 10))
        )

        // Losing window focus immediately clears delivered Hover and location.
        #expect(gate.freezeChanged(isFrozen: false, isWindowFocused: false) == false)
        #expect(locationGate.freezeChanged(isFrozen: false, isWindowFocused: false) == .some(nil))

        // Hover reports while unfocused are suppressed.
        #expect(gate.report(true, isFrozen: false, isWindowFocused: false) == nil)
        #expect(
            locationGate.report(
                CGPoint(x: 90, y: 10),
                isFrozen: false,
                isWindowFocused: false
            ) == nil
        )

        // Regaining window focus restores Hover for the target currently under the pointer.
        #expect(gate.freezeChanged(isFrozen: false, isWindowFocused: true) == true)
        #expect(
            locationGate.freezeChanged(isFrozen: false, isWindowFocused: true)
                == .some(CGPoint(x: 90, y: 10))
        )
    }

    @MainActor
    @Test
    func cardAndMenuHighlightModelsClearAndSuppressHoverWhenWindowResignsFocus() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        defer {
            PointerHoverScrollState.shared.resetForTesting()
            AppPointerShape.resetForTesting()
        }

        let cardHighlight = CardHighlightModel(keepsCurrentWhenPointerLeaves: true)
        cardHighlight.setSelected("card-0")
        cardHighlight.noteHover(true, id: "card-1", showsHand: true)
        #expect(cardHighlight.hoveredID == "card-1")
        #expect(cardHighlight.selectedID == "card-0")

        let menuHighlight = MenuHighlightModel()
        menuHighlight.open(selectablePositions: [0, 1, 2], defaultPosition: nil)
        defer { menuHighlight.close() }
        menuHighlight.noteHover(true, at: 1)
        #expect(menuHighlight.hoveredPosition == 1)

        // Resigning window focus clears card and menu Hover while preserving card Select.
        NotificationCenter.default.post(
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        #expect(!cardHighlight.isWindowFocused)
        #expect(cardHighlight.hoveredID == nil)
        #expect(cardHighlight.selectedID == "card-0")
        #expect(!menuHighlight.isWindowFocused)
        #expect(menuHighlight.hoveredPosition == nil)

        // Background hover callbacks while unfocused are ignored.
        cardHighlight.noteHover(true, id: "card-2", showsHand: true)
        menuHighlight.noteHover(true, at: 2)
        #expect(cardHighlight.hoveredID == nil)
        #expect(menuHighlight.hoveredPosition == nil)

        // Regaining window focus immediately restores stationary Hover and re-enables hover tracking.
        NotificationCenter.default.post(
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        #expect(cardHighlight.isWindowFocused)
        #expect(menuHighlight.isWindowFocused)
        #expect(cardHighlight.hoveredID == "card-1")
        #expect(AppPointerShape.model.shape == .grab)
        #expect(menuHighlight.hoveredPosition == 1)
        cardHighlight.noteHover(true, id: "card-2", showsHand: true)
        menuHighlight.noteHover(true, at: 2)
        #expect(cardHighlight.hoveredID == "card-2")
        #expect(menuHighlight.hoveredPosition == 2)
    }

    @MainActor
    @Test
    func openingSecondWindowKeepsUnfocusedMainWindowCardAndMenuHoverSuppressed() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        AppPointerShape.resetForTesting()
        defer {
            PointerHoverScrollState.shared.resetForTesting()
            AppPointerShape.resetForTesting()
        }

        let mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: 280, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let mainHostView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        mainWindow.contentView = mainHostView

        let cardHighlight = CardHighlightModel(keepsCurrentWhenPointerLeaves: true)
        cardHighlight.hostView = mainHostView
        cardHighlight.setSelected("card-0")

        let menuHighlight = MenuHighlightModel()
        menuHighlight.hostView = mainHostView
        menuHighlight.open(selectablePositions: [0, 1, 2], defaultPosition: 0)
        defer { menuHighlight.close() }

        // Simulate opening Settings window over the Main Window:
        // mainWindow resigns key, settingsWindow becomes key, and the pointer moves.
        NotificationCenter.default.post(
            name: NSWindow.didResignKeyNotification,
            object: mainWindow
        )
        NotificationCenter.default.post(
            name: NSWindow.didBecomeKeyNotification,
            object: settingsWindow
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        PointerHoverScrollState.shared.notePointerMoved()

        #expect(!cardHighlight.isHostingWindowFocused)
        #expect(!menuHighlight.isHostingWindowFocused)

        // Hover callbacks from the unfocused Main Window remain suppressed and do not show a grab cursor.
        cardHighlight.noteHover(true, id: "card-1", showsHand: true)
        cardHighlight.noteActionButtonHover(true, id: "card-1")
        menuHighlight.noteHover(true, at: 2)
        #expect(cardHighlight.hoveredID == nil)
        #expect(menuHighlight.hoveredPosition == nil)
        #expect(AppPointerShape.model.shape == .arrow)
    }

    @MainActor
    @Test
    func scrollingCardGridLocksHoverAndPointerUntilScrollDebounceSettles() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        AppPointerShape.resetForTesting()
        defer {
            PointerHoverScrollState.shared.resetForTesting()
            AppPointerShape.resetForTesting()
        }

        let cardHighlight = CardHighlightModel(keepsCurrentWhenPointerLeaves: true)
        cardHighlight.setSelected("card-0")

        // Hover card-0 initially.
        cardHighlight.noteHover(true, id: "card-0", showsHand: true)
        #expect(cardHighlight.hoveredID == "card-0")
        #expect(cardHighlight.selectedID == "card-0")
        #expect(AppPointerShape.model.shape == .grab)

        // Begin wheel scrolling and let card-2 slide under the stationary pointer.
        PointerHoverScrollState.shared.noteScrolled()
        cardHighlight.noteHover(false, id: "card-0", showsHand: true)
        cardHighlight.noteHover(true, id: "card-2", showsHand: true)

        // While scroll debounce is active, Hover and pointer shape remain locked on card-0.
        #expect(cardHighlight.hoveredID == "card-0")
        #expect(AppPointerShape.model.shape == .grab)

        // Once the 300ms scroll debounce settles, Hover updates to card-2 and Select stays on card-0.
        PointerHoverScrollState.shared.settleScroll()
        #expect(cardHighlight.hoveredID == "card-2")
        #expect(cardHighlight.selectedID == "card-0")
        #expect(AppPointerShape.model.shape == .grab)

        // Scroll again so a spacing gap between cards sits under the pointer.
        PointerHoverScrollState.shared.noteScrolled()
        cardHighlight.noteHover(false, id: "card-2", showsHand: true)
        #expect(cardHighlight.hoveredID == "card-2")

        // When scroll debounce settles over the gap, Hover clears to nil.
        PointerHoverScrollState.shared.settleScroll()
        #expect(cardHighlight.hoveredID == nil)
        #expect(cardHighlight.selectedID == "card-0")
    }

    @MainActor
    @Test
    func scrollingMenuLocksHoverAndReevaluatesHoveredPositionOnSettle() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        defer { PointerHoverScrollState.shared.resetForTesting() }

        let menuHighlight = MenuHighlightModel()
        menuHighlight.open(selectablePositions: Array(0..<10), defaultPosition: 0)
        defer { menuHighlight.close() }

        menuHighlight.noteHover(true, at: 0)
        #expect(menuHighlight.hoveredPosition == 0)
        #expect(menuHighlight.selectedPosition == 0)

        // Scroll down by 3 rows while keeping the pointer stationary.
        PointerHoverScrollState.shared.noteScrolled()
        menuHighlight.noteHover(false, at: 0)
        menuHighlight.noteHover(true, at: 3)
        #expect(menuHighlight.hoveredPosition == 0)

        // Settling after the 300ms scroll debounce updates the unified menu highlight to row 3.
        PointerHoverScrollState.shared.settleScroll()
        #expect(menuHighlight.hoveredPosition == 3)
        #expect(menuHighlight.selectedPosition == 3)
        #expect(menuHighlight.highlightedPosition == 3)
    }

    @Test
    func keyboardSuppressionImmediatelyClearsDeliveredHoverAndRestoresOnPointerMove() {
        var gate = PointerHoverGate()
        #expect(gate.report(true, isFrozen: false) == true)

        // Keyboard / controller navigation immediately clears active Hover.
        #expect(
            gate.freezeChanged(
                isFrozen: false,
                isSuppressedByKeyboard: true
            ) == false
        )

        // Stationary hover reports while suppressed are remembered but not delivered.
        #expect(
            gate.report(
                true,
                isFrozen: false,
                isSuppressedByKeyboard: true
            ) == nil
        )

        // Once the pointer moves (isSuppressedByKeyboard == false), Hover is restored.
        #expect(
            gate.freezeChanged(
                isFrozen: false,
                isSuppressedByKeyboard: false
            ) == true
        )
    }

    @MainActor
    @Test
    func synchronousMenuRelayClearsStaleTriggerButtonHoverWhenPointerMovedAwayWhileMenuWasOpen() throws {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        defer { PointerHoverScrollState.shared.resetForTesting() }

        let layers = InterfaceLayerRegistry()
        var hoveredButtons: Set<Int> = []
        let rowView = HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 30)
                    .onPointerHover { isHovered in
                        if isHovered {
                            hoveredButtons.insert(index)
                        } else {
                            hoveredButtons.remove(index)
                        }
                    }
            }
            Spacer()
        }
        .frame(width: 220, height: 50)
        .modifier(InterfaceLayerCoverageBridge(layers: layers))

        let host = NSHostingView(rootView: rowView)
        host.frame = NSRect(x: 0, y: 0, width: 220, height: 50)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        func collectProbes(in view: NSView) -> [PointerHoverProbeView] {
            var result: [PointerHoverProbeView] = []
            if let probe = view as? PointerHoverProbeView {
                result.append(probe)
            }
            for subview in view.subviews {
                result.append(contentsOf: collectProbes(in: subview))
            }
            return result
        }
        let probes = collectProbes(in: host).sorted {
            $0.convert( NSPoint.zero, to: host).x < $1.convert(NSPoint.zero, to: host).x
        }
        #expect(probes.count == 3)

        // 1. Hover button 0 and open its menu.
        probes[0].session?.report(true)
        #expect(hoveredButtons == [0])

        var firstMenuToken: InterfaceLayerRegistry.OpenMenuToken? =
            layers.registerOpenMenu(ownedBy: .workbenchPage)
        #expect(layers.isFrozen(.workbenchPage))

        // 2. While the menu is open, pointer leaves button 0; button 0 stays lit while frozen.
        probes[0].session?.report(false)
        #expect(hoveredButtons == [0])

        // 3. Synchronously close the first menu and open a row context menu in the
        // same call stack (zero RunLoop turns between close and reopen).
        firstMenuToken = nil
        var secondMenuToken: InterfaceLayerRegistry.OpenMenuToken? =
            layers.registerOpenMenu(ownedBy: .workbenchPage)
        #expect(layers.isFrozen(.workbenchPage))
        #expect(!hoveredButtons.contains(0))

        // Release second menu token and verify button 0 stays unhovered.
        secondMenuToken = nil
        _ = firstMenuToken
        _ = secondMenuToken
        #expect(hoveredButtons.isEmpty)

        // 4. When the pointer stays over button 0 while its menu is open and the
        // menu closes without opening a new menu, button 0 keeps its Hover state.
        probes[0].session?.report(true)
        #expect(hoveredButtons == [0])

        var thirdMenuToken: InterfaceLayerRegistry.OpenMenuToken? =
            layers.registerOpenMenu(ownedBy: .workbenchPage)
        thirdMenuToken = nil
        _ = thirdMenuToken
        #expect(hoveredButtons == [0])
    }

    @MainActor
    @Test
    func statusIndicatorInteractiveTextHoverSetsGrabCursorOnlyWhenClickable() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        AppPointerShape.resetForTesting()
        defer {
            PointerHoverScrollState.shared.resetForTesting()
            AppPointerShape.resetForTesting()
        }

        let view = VStack(alignment: .leading, spacing: 10) {
            WorkbenchStatusIndicator(
                "Last Updated: 26-10-30 10:00",
                onTapText: {}
            )
            WorkbenchStatusIndicator(
                "Last Updated: --",
                onTapText: nil
            )
        }
        .frame(width: 260, height: 80, alignment: .topLeading)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 260, height: 80)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        func collectProbes(in view: NSView) -> [PointerHoverProbeView] {
            var result: [PointerHoverProbeView] = []
            if let probe = view as? PointerHoverProbeView {
                result.append(probe)
            }
            for subview in view.subviews {
                result.append(contentsOf: collectProbes(in: subview))
            }
            return result
        }
        let handProbes = collectProbes(in: host).filter { $0.session?.showsHand == true }
        #expect(handProbes.count == 1)

        handProbes[0].session?.report(true)
        #expect(AppPointerShape.model.shape == .grab)

        handProbes[0].session?.report(false)
        #expect(AppPointerShape.model.shape == .arrow)
    }

    @Test
    @MainActor
    func dialogTextFieldClickShowsAccentColorInsertionPointEvenWithoutSystemWindowActivation() throws {
        _ = NSApplication.shared
        let layers = InterfaceLayerRegistry()
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: -5_000, y: -5_000, width: 1_000, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        window.isFocusLocked = { layers.hasUncoveredOpenMenu }
        window.dialogSize = { layers.topDialogSize }
        window.isWorkbenchCovered = { layers.isCovered(.workbenchPage) }

        let session = WebDAVFolderDialogSession()
        let host = NSHostingView(
            rootView: WorkbenchDialogLayer(
                dialogIDs: [AnyHashable(session.id)],
                topBandHeight: 52
            ) {
                WebDAVFolderDialog(
                    session: session,
                    onConfirm: {},
                    onClose: {}
                )
                .environment(\.workbenchDialogID, .webdav)
                .workbenchDialog()
            }
            .frame(width: 1_000, height: 700)
            .modifier(InterfaceLayerCoverageBridge(layers: layers))
            .opensWithoutFocus()
        )
        host.frame = NSRect(x: 0, y: 0, width: 1_000, height: 700)
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
        host.layoutSubtreeIfNeeded()

        func findAddressField(in view: NSView) -> WorkbenchNativeSingleLineTextField? {
            if let field = view as? WorkbenchNativeSingleLineTextField {
                return field
            }
            for subview in view.subviews {
                if let found = findAddressField(in: subview) {
                    return found
                }
            }
            return nil
        }

        let addressField = try #require(findAddressField(in: host))
        #expect(!addressField.isCurrentlyFocused)
        #expect(!window.isKeyWindow)

        let clickPoint = addressField.convert(
            NSPoint(x: addressField.bounds.midX, y: addressField.bounds.midY),
            to: nil
        )
        let leftDown = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: clickPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 10,
            clickCount: 1,
            pressure: 1
        ))
        let leftUp = try #require(NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: clickPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime + 0.01,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 10,
            clickCount: 1,
            pressure: 0
        ))
        NSApp.postEvent(leftUp, atStart: false)
        window.sendEvent(leftDown)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        #expect(addressField.isCurrentlyFocused)
        #expect(window.shouldPreserveCurrentFocusOnBecomeKey)
        let editor = try #require(addressField.currentEditor() as? NSTextView)
        #expect(editor.insertionPointColor == WorkbenchRedesignColors.NS.borderFocus)

        // Delayed system didBecomeKeyNotification must not clear the user's click focus on Address.
        NotificationCenter.default.post(
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(addressField.isCurrentlyFocused)
    }
}
