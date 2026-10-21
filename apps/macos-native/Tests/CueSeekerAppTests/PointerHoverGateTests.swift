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

        // Losing window focus clears Hover immediately.
        window.isWindowFocusedOverrideForTesting = false
        host.syncMouseHoverForWindowFocus()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        #expect(hoveredButtons.isEmpty)

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
}
