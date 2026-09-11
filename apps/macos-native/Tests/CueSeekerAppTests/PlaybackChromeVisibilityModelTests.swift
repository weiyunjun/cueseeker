import AppKit
import Testing
@testable import CueSeekerApp

/// The rules of `docs/human/requirements/20260912-UI-Player UI And Pointer
/// Visibility Rules.md`, driven through the model's focus and pointer seams
/// and with the countdown's end called instead of waited for.
@MainActor
private final class PlayerArea {
    let model = PlaybackChromeVisibilityModel()
    let window: NSWindow
    let view: NSView
    private var isFocused = true
    /// In window coordinates; the player area fills the window's content.
    var pointer = NSPoint(x: 400, y: 300)

    init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let view = PlaybackChromeTrackingNSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView?.addSubview(view)
        self.view = view
        model.hasWindowFocus = { [unowned self] _ in self.isFocused }
        model.pointerScreenLocation = { [unowned self] in
            self.window.convertPoint(toScreen: self.pointer)
        }
        AppCursorVisibility.resetForTesting()
        model.enterVideoPage()
        model.updatePlayerAreaView(view)
    }

    func movePointer(to point: NSPoint) {
        pointer = point
        model.pointerMovedInPlayerArea(view: view)
    }

    func setFocused(_ isFocused: Bool) {
        self.isFocused = isFocused
        model.focusChanged()
    }

    /// A control's frame around the pointer, in the area's top-left
    /// coordinates.
    var frameUnderPointer: CGRect {
        CGRect(x: pointer.x - 20, y: (600 - pointer.y) - 20, width: 40, height: 40)
    }

    func finish() {
        model.leaveVideoPage()
        AppCursorVisibility.resetForTesting()
    }
}

@MainActor
@Test
func playerUIAndPointerShowOnEntryAndHideTogetherAfterIdle() {
    let area = PlayerArea()
    defer { area.finish() }

    #expect(area.model.isPlayerUIVisible)
    #expect(area.model.isPointerVisible)
    #expect(area.model.isIdleCountdownRunning)

    area.model.idleElapsed()
    #expect(!area.model.isPlayerUIVisible)
    #expect(!area.model.isPointerVisible)
    #expect(AppCursorVisibility.isCursorHidden)
    #expect(!area.model.isIdleCountdownRunning)

    area.movePointer(to: NSPoint(x: 410, y: 300))
    #expect(area.model.isPlayerUIVisible)
    #expect(area.model.isPointerVisible)
    #expect(!AppCursorVisibility.isCursorHidden)
    #expect(area.model.isIdleCountdownRunning)
}

@MainActor
@Test
func pointerOnClickableControlOrScrubbingStopsTheCountdown() {
    let area = PlayerArea()
    defer { area.finish() }

    area.model.setInteractiveFrames([area.frameUnderPointer])
    #expect(!area.model.isIdleCountdownRunning)
    area.model.idleElapsed()
    #expect(area.model.isPlayerUIVisible)
    #expect(area.model.isPointerVisible)

    area.movePointer(to: NSPoint(x: 100, y: 100))
    #expect(area.model.isIdleCountdownRunning)

    area.model.setScrubbing(true)
    #expect(!area.model.isIdleCountdownRunning)
    area.model.setScrubbing(false)
    #expect(area.model.isIdleCountdownRunning)
}

@MainActor
@Test
func hiddenPlayerUIControlsDoNotStopTheCountdown() {
    let area = PlayerArea()
    defer { area.finish() }

    area.model.idleElapsed()
    area.setFocused(false)
    #expect(area.model.isPointerVisible)
    #expect(!area.model.isPlayerUIVisible)

    area.model.setInteractiveFrames([area.frameUnderPointer])
    area.setFocused(true)
    #expect(area.model.isIdleCountdownRunning)
    area.model.idleElapsed()
    #expect(!area.model.isPointerVisible)
}

@MainActor
@Test
func sameWindowLayerShowsThePointerAndFreezesThePlayerUI() {
    let area = PlayerArea()
    defer { area.finish() }

    area.model.setLayerOpen(true)
    #expect(area.model.isPointerVisible)
    #expect(area.model.isPlayerUIVisible)
    #expect(!area.model.isIdleCountdownRunning)
    area.model.setLayerOpen(false)
    #expect(area.model.isPlayerUIVisible)
    #expect(area.model.isIdleCountdownRunning)

    area.model.idleElapsed()
    area.model.setLayerOpen(true)
    #expect(area.model.isPointerVisible)
    #expect(!AppCursorVisibility.isCursorHidden)
    #expect(!area.model.isPlayerUIVisible)
    // Not governed while the layer is open: a controller's request changes nothing.
    area.model.pointerHideRequested()
    #expect(area.model.isPointerVisible)
    area.model.setLayerOpen(false)
    #expect(!area.model.isPlayerUIVisible)
    #expect(area.model.isIdleCountdownRunning)
    area.model.idleElapsed()
    #expect(!area.model.isPointerVisible)
    #expect(AppCursorVisibility.isCursorHidden)
}

@MainActor
@Test
func losingFocusOrLeavingTheWindowHidesThePlayerUIAndShowsThePointer() {
    let area = PlayerArea()
    defer { area.finish() }

    area.model.idleElapsed()
    area.setFocused(false)
    #expect(!area.model.isPlayerUIVisible)
    #expect(area.model.isPointerVisible)
    #expect(!AppCursorVisibility.isCursorHidden)
    #expect(!area.model.isIdleCountdownRunning)
    area.setFocused(true)
    #expect(!area.model.isPlayerUIVisible)
    #expect(area.model.isPointerVisible)
    #expect(area.model.isIdleCountdownRunning)

    area.movePointer(to: NSPoint(x: 400, y: 300))
    #expect(area.model.isPlayerUIVisible)
    area.pointer = NSPoint(x: -10, y: 300)
    area.model.pointerExitedPlayerArea(view: area.view)
    #expect(!area.model.isPlayerUIVisible)
    #expect(area.model.isPointerVisible)
    #expect(!area.model.isIdleCountdownRunning)
}

@MainActor
@Test
func fullscreenEntryAndControllerInputHideBoth() {
    let area = PlayerArea()
    defer { area.finish() }

    area.model.enteringFullscreen()
    #expect(!area.model.isPlayerUIVisible)
    #expect(!area.model.isPointerVisible)
    #expect(AppCursorVisibility.isCursorHidden)

    area.movePointer(to: NSPoint(x: 300, y: 300))
    #expect(area.model.isPlayerUIVisible)
    #expect(area.model.isPointerVisible)

    area.model.pointerHideRequested()
    #expect(!area.model.isPlayerUIVisible)
    #expect(!area.model.isPointerVisible)
}
