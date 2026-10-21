import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

/// Covers `docs/human/requirements/20260826-UI-Card Highlight Single Authority
/// And Menu Input Rules.md` §8.1 for every surface that is not a card: while a
/// menu is open over its layer, or a higher layer covers it, the surface stops
/// answering the pointer.
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
}
