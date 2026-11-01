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

    @MainActor
    @Test
    func hostingViewClearsAndSuppressesHoverWhileWindowIsUnfocusedAndRestoresSingleTargetOnFocusRegain() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()

        var hoveredButtons: Set<Int> = []
        let rowView = HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
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
        }
        .frame(width: 220, height: 50)

        let window = CueSeekerWindow(
            contentRect: NSRect(x: -5_000, y: -5_000, width: 220, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isWindowFocusedOverrideForTesting = true
        let host = CueSeekerHostingView(rootView: rowView)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons.isEmpty)

        // Hover button 1 (centered around x = 85, y = 25) while focused.
        let button1Point = CGPoint(x: 85, y: 25)
        host.mouseLocationOverrideForTesting = button1Point
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons == [1])
        #expect(PointerHoverScrollState.shared.activeHoverListenerCountForTesting == 1)

        // Losing window focus clears Hover immediately.
        window.isWindowFocusedOverrideForTesting = false
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons.isEmpty)
        #expect(PointerHoverScrollState.shared.activeHoverListenerCountForTesting == 0)

        // Moving across buttons while unfocused does not trigger any Hover.
        if let moveWhileUnfocused = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: CGPoint(x: 135, y: 25),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        ) {
            host.mouseEntered(with: moveWhileUnfocused)
            host.mouseMoved(with: moveWhileUnfocused)
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons.isEmpty)

        // Regaining focus restores Hover only on the button currently under the pointer.
        host.mouseLocationOverrideForTesting = CGPoint(x: 135, y: 25)
        window.isWindowFocusedOverrideForTesting = true
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons == [2])
    }

    @MainActor
    @Test
    func scrollingLazyGridInHostingViewLocksHoverAndPointerUntilScrollDebounceSettles() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        defer { PointerHoverScrollState.shared.resetForTesting() }

        let cardHighlight = CardHighlightModel(keepsCurrentWhenPointerLeaves: true)
        cardHighlight.setSelected("card-0")

        let gridView = ScrollView {
            LazyVGrid(columns: [GridItem(.fixed(80))], spacing: 20) {
                ForEach(0..<10, id: \.self) { index in
                    let cardID = "card-\(index)"
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 80, height: 60)
                        .onHover { isHovered in
                            cardHighlight.noteHover(isHovered, id: cardID, showsHand: true)
                        }
                }
            }
        }
        .frame(width: 100, height: 150)

        let window = CueSeekerWindow(
            contentRect: NSRect(x: -5_000, y: -5_000, width: 100, height: 150),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isWindowFocusedOverrideForTesting = true
        let host = CueSeekerHostingView(rootView: gridView)
        window.contentView = host
        AppPointerShape.attach(to: window, isMenuOpen: { false })
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        // Hover card-0 at (50, 120) (30pt from the top of the 150pt scroll view).
        let stationaryPoint = CGPoint(x: 50, y: 120)
        host.mouseLocationOverrideForTesting = stationaryPoint
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(cardHighlight.hoveredID == "card-0")
        #expect(cardHighlight.selectedID == "card-0")
        #expect(AppPointerShape.model.shape == .grab)

        func findScrollView(_ view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            for subview in view.subviews {
                if let found = findScrollView(subview) {
                    return found
                }
            }
            return nil
        }
        let scrollView = findScrollView(host)
        #expect(scrollView != nil)

        // Begin wheel scrolling and scroll 160pt so card-2 sits under the stationary pointer.
        PointerHoverScrollState.shared.noteScrolled()
        scrollView?.contentView.scroll(to: CGPoint(x: 0, y: 160))
        scrollView?.reflectScrolledClipView(scrollView!.contentView)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        // While scroll debounce is active, Hover and pointer shape remain locked on card-0.
        #expect(cardHighlight.hoveredID == "card-0")
        #expect(AppPointerShape.model.shape == .grab)

        // Once the 300ms scroll debounce settles, Hover updates to card-2 and Select stays on card-0.
        PointerHoverScrollState.shared.settleScroll()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(cardHighlight.hoveredID == "card-2")
        #expect(cardHighlight.selectedID == "card-0")
        #expect(AppPointerShape.model.shape == .grab)

        // Scroll again so the 20pt spacing gap between card-0 and card-1 (y = 60..80) sits under the pointer.
        PointerHoverScrollState.shared.noteScrolled()
        scrollView?.contentView.scroll(to: CGPoint(x: 0, y: 35))
        scrollView?.reflectScrolledClipView(scrollView!.contentView)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(cardHighlight.hoveredID == "card-2")

        // When scroll debounce settles over the gap, Hover clears to nil and pointer shape resets to arrow.
        PointerHoverScrollState.shared.settleScroll()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(cardHighlight.hoveredID == nil)
        #expect(cardHighlight.selectedID == "card-0")
        #expect(AppPointerShape.model.shape == .arrow)
    }

    @MainActor
    @Test
    func scrollingMenuInHostingViewLocksHoverAndReevaluatesHoveredPositionOnSettle() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        defer { PointerHoverScrollState.shared.resetForTesting() }

        let menuHighlight = MenuHighlightModel()
        menuHighlight.open(selectablePositions: Array(0..<10), defaultPosition: 0)
        defer { menuHighlight.close() }

        let menuView = ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { position in
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 120, height: 30)
                        .onHover { isHovered in
                            menuHighlight.noteHover(isHovered, at: position)
                        }
                }
            }
        }
        .frame(width: 120, height: 90)

        let window = CueSeekerWindow(
            contentRect: NSRect(x: -5_000, y: -5_000, width: 120, height: 90),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isWindowFocusedOverrideForTesting = true
        let host = CueSeekerHostingView(rootView: menuView)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        // Hover row 0 near the top (y = 75 in bottom-left window coordinates -> 15pt from top).
        let stationaryPoint = CGPoint(x: 60, y: 75)
        host.mouseLocationOverrideForTesting = stationaryPoint
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(menuHighlight.hoveredPosition == 0)
        #expect(menuHighlight.selectedPosition == 0)

        func findScrollView(_ view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            for subview in view.subviews {
                if let found = findScrollView(subview) {
                    return found
                }
            }
            return nil
        }
        let scrollView = findScrollView(host)
        #expect(scrollView != nil)

        // Scroll down by 90pt (3 rows) while keeping the pointer stationary.
        PointerHoverScrollState.shared.noteScrolled()
        scrollView?.contentView.scroll(to: CGPoint(x: 0, y: 90))
        scrollView?.reflectScrolledClipView(scrollView!.contentView)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(menuHighlight.hoveredPosition == 0)

        // Settling after the 300ms scroll debounce updates the unified menu highlight to row 3.
        PointerHoverScrollState.shared.settleScroll()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
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
    func synchronousMenuRelayClearsStaleTriggerButtonHoverWhenPointerMovedAwayWhileMenuWasOpen() {
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

        let window = CueSeekerWindow(
            contentRect: NSRect(x: -5_000, y: -5_000, width: 220, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isWindowFocusedOverrideForTesting = true
        let host = CueSeekerHostingView(rootView: rowView)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        // 1. Hover button 0 (centered around x = 20, y = 25) and open its menu.
        let button0Point = CGPoint(x: 20, y: 25)
        host.mouseLocationOverrideForTesting = button0Point
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons == [0])

        var firstMenuToken: InterfaceLayerRegistry.OpenMenuToken? =
            layers.registerOpenMenu(ownedBy: .workbenchPage)
        #expect(layers.isFrozen(.workbenchPage))

        // 2. While the menu is open, MenuGate swallows .mouseMoved outside the menu,
        // so AppKit never sends mouseExited/.onHover(false) to button 0.
        let outsideRowPoint = CGPoint(x: 190, y: 25)
        host.mouseLocationOverrideForTesting = outsideRowPoint
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
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons.isEmpty)

        // 4. When the pointer stays over button 0 while its menu is open and the
        // menu closes without opening a new menu, button 0 keeps its Hover state.
        host.mouseLocationOverrideForTesting = button0Point
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons == [0])

        var thirdMenuToken: InterfaceLayerRegistry.OpenMenuToken? =
            layers.registerOpenMenu(ownedBy: .workbenchPage)
        thirdMenuToken = nil
        _ = thirdMenuToken
        #expect(hoveredButtons == [0])
    }

    @MainActor
    @Test
    func exitingPlaybackOverlayWithNestedWorkbenchHostingViewPreservesPlayerButtonHover() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        defer { PointerHoverScrollState.shared.resetForTesting() }

        let layers = InterfaceLayerRegistry()
        var hoveredWorkbenchButtons: Set<Int> = []
        var hoveredPlayerButtons: Set<Int> = []

        let workbenchHeaderContent = HStack(spacing: 10) {
            Rectangle()
                .fill(Color.gray)
                .frame(width: 40, height: 30)
                .onPointerHover { isHovered in
                    if isHovered {
                        hoveredWorkbenchButtons.insert(0)
                    } else {
                        hoveredWorkbenchButtons.remove(0)
                    }
                }
            Spacer()
        }
        .frame(width: 220, height: 30)

        let rootView = ZStack {
            VStack(spacing: 0) {
                NestedCueSeekerHostingViewRepresentable(rootView: workbenchHeaderContent)
                    .frame(width: 220, height: 30)
                Spacer(minLength: 0)
            }
            .frame(width: 220, height: 100)
            .interfaceLayer(.workbenchPage)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { index in
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 40, height: 30)
                            .onPointerHover { isHovered in
                                if isHovered {
                                    hoveredPlayerButtons.insert(index)
                                } else {
                                    hoveredPlayerButtons.remove(index)
                                }
                            }
                    }
                    Spacer()
                }
                .frame(width: 220, height: 50)
            }
            .frame(width: 220, height: 100)
            .interfaceLayer(.playbackPage)
        }
        .frame(width: 220, height: 100)
        .modifier(InterfaceLayerCoverageBridge(layers: layers))

        let window = CueSeekerWindow(
            contentRect: NSRect(x: -5_000, y: -5_000, width: 220, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isWindowFocusedOverrideForTesting = true
        let host = CueSeekerHostingView(rootView: rootView)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        layers.setOpen(.playbackPage, true)
        layers.setOpen(.playbackOverlay, true)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(layers.isFrozen(.playbackPage))

        // Move the pointer over Player button 0 (bottom bar at y = 25 in window
        // coordinates, outside the top 220x30 nested workbench hosting view)
        // while Playback Overlay is open, then close Playback Overlay.
        let playerButton0Point = CGPoint(x: 20, y: 25)
        host.mouseLocationOverrideForTesting = playerButton0Point
        layers.setOpen(.playbackOverlay, false)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(!layers.isFrozen(.playbackPage))
        #expect(hoveredPlayerButtons == [0])
        #expect(hoveredWorkbenchButtons.isEmpty)

        // Subsequent mouseMoved events on the root hosting view must continue to
        // transition Hover between Player buttons and clear Hover in empty space.
        let playerButton1Point = CGPoint(x: 70, y: 25)
        host.mouseLocationOverrideForTesting = playerButton1Point
        if let moveToButton1 = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: playerButton1Point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        ) {
            host.mouseMoved(with: moveToButton1)
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredPlayerButtons == [1])
        #expect(hoveredWorkbenchButtons.isEmpty)

        let emptyPoint = CGPoint(x: 180, y: 25)
        host.mouseLocationOverrideForTesting = emptyPoint
        if let moveToEmpty = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: emptyPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        ) {
            host.mouseMoved(with: moveToEmpty)
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredPlayerButtons.isEmpty)
        #expect(hoveredWorkbenchButtons.isEmpty)
    }

    @MainActor
    @Test
    func statusIndicatorInteractiveTextHoverSetsGrabCursorOnlyWhenClickable() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        defer { PointerHoverScrollState.shared.resetForTesting() }

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

        let window = CueSeekerWindow(
            contentRect: NSRect(x: -5_000, y: -5_000, width: 260, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isWindowFocusedOverrideForTesting = true
        let host = CueSeekerHostingView(rootView: view)
        window.contentView = host
        AppPointerShape.attach(to: window, isMenuOpen: { false })
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        // Hover interactive status text near top row (y = 66 in bottom-left window coords)
        host.mouseLocationOverrideForTesting = CGPoint(x: 60, y: 66)
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(AppPointerShape.model.shape == .grab)

        // Hover non-interactive "Last Updated: --" row (y = 28 in bottom-left window coords)
        host.mouseLocationOverrideForTesting = CGPoint(x: 60, y: 28)
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(AppPointerShape.model.shape == .arrow)
    }

    @MainActor
    @Test
    func clickingLeftOrRightOnUnfocusedWindowActivatesFocusAndRestoresHoverAndMenuInteraction() throws {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        defer { PointerHoverScrollState.shared.resetForTesting() }

        var hoveredButtons: Set<Int> = []
        let menuHighlight = MenuHighlightModel()
        menuHighlight.open(selectablePositions: [0, 1, 2], defaultPosition: nil)
        defer { menuHighlight.close() }

        let rootView = VStack(spacing: 10) {
            HStack(spacing: 10) {
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
            }
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { position in
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 40, height: 30)
                        .onHover { isHovered in
                            menuHighlight.noteHover(isHovered, at: position)
                        }
                }
            }
        }
        .frame(width: 160, height: 80)

        let window = CueSeekerWindow(
            contentRect: NSRect(x: -5_000, y: -5_000, width: 160, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let host = CueSeekerHostingView(rootView: rootView)
        window.contentView = host
        window.orderFrontRegardless()
        defer {
            window.contentView = nil
            window.orderOut(nil)
        }
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        // 1. Before any activation or click, the window is unfocused and suppresses hover.
        #expect(!window.isFocusedForHover)
        let button0Point = CGPoint(x: 30, y: 60)
        host.mouseLocationOverrideForTesting = button0Point
        if let moveWhileUnfocused = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: button0Point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 0,
            pressure: 0
        ) {
            host.mouseEntered(with: moveWhileUnfocused)
            host.mouseMoved(with: moveWhileUnfocused)
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons.isEmpty)

        // 2. Left-clicking inside the unfocused window immediately activates focus and syncs hover.
        let leftDown = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: button0Point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1
        ))
        window.sendEvent(leftDown)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(window.isFocusedForHover)
        #expect(window.hasUserInteractionFocus)
        #expect(hoveredButtons == [0])

        // 3. Resigning active clears user interaction focus and immediately clears hover.
        NotificationCenter.default.post(
            name: NSApplication.didResignActiveNotification,
            object: NSApp
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(!window.isFocusedForHover)
        #expect(!window.hasUserInteractionFocus)
        #expect(hoveredButtons.isEmpty)

        // 4. Right-clicking inside the unfocused window immediately activates focus so open
        //    context menus and submenu triggers respond to hover without a prior left-click.
        let menuRow1Point = CGPoint(x: 80, y: 20)
        host.mouseLocationOverrideForTesting = menuRow1Point
        let rightDown = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: menuRow1Point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 3,
            clickCount: 1,
            pressure: 1
        ))
        window.sendEvent(rightDown)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(window.isFocusedForHover)
        #expect(menuHighlight.hoveredPosition == 1)
        #expect(menuHighlight.highlightedPosition == 1)

        // 5. Activating a second CueSeekerWindow (e.g. Settings window) transfers focus and
        //    clears hover on the first window.
        let secondWindow = CueSeekerWindow(
            contentRect: NSRect(x: -4_500, y: -4_500, width: 120, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        defer { secondWindow.orderOut(nil) }
        secondWindow.activateWindowForFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(!window.isFocusedForHover)
        #expect(secondWindow.isFocusedForHover)
        #expect(menuHighlight.hoveredPosition == nil)
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

        #expect(window.isKeyWindow)
        #expect(window.isFocusedForHover)
        #expect(addressField.isCurrentlyFocused)
        let editor = try #require(addressField.currentEditor() as? NSTextView)
        #expect(editor.insertionPointColor == WorkbenchRedesignColors.NS.borderFocus)

        // Delayed system didBecomeKeyNotification must not clear the user's click focus on Address.
        NotificationCenter.default.post(
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(addressField.isCurrentlyFocused)

        host.displayIfNeeded()
        let rep = try #require(addressField.bitmapImageRepForCachingDisplay(in: addressField.bounds))
        addressField.cacheDisplay(in: addressField.bounds, to: rep)
        var nonTransparentInsertionPixels = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<min(24, rep.pixelsWide) {
                if let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                   color.alphaComponent > 0.1 {
                    nonTransparentInsertionPixels += 1
                }
            }
        }
        #expect(nonTransparentInsertionPixels > 0)
    }
}

private struct NestedCueSeekerHostingViewRepresentable<Content: View>: NSViewRepresentable {
    let rootView: Content

    func makeNSView(context: Context) -> CueSeekerHostingView<Content> {
        CueSeekerHostingView(rootView: rootView)
    }

    func updateNSView(_ nsView: CueSeekerHostingView<Content>, context: Context) {
        nsView.rootView = rootView
    }
}
