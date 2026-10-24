import AppKit
import SwiftUI
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
func pointerOnClickableControlOrDraggingStopsTheCountdown() {
    let area = PlayerArea()
    defer { area.finish() }

    area.model.setInteractiveFrames([area.frameUnderPointer])
    #expect(!area.model.isIdleCountdownRunning)
    area.model.idleElapsed()
    #expect(area.model.isPlayerUIVisible)
    #expect(area.model.isPointerVisible)

    area.movePointer(to: NSPoint(x: 100, y: 100))
    #expect(area.model.isIdleCountdownRunning)

    area.model.setDragging(true)
    #expect(!area.model.isIdleCountdownRunning)
    area.model.setDragging(false)
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
func sameWindowLayerPreservesPointerVisibilityAndFreezesThePlayerUI() {
    let area = PlayerArea()
    defer { area.finish() }

    area.model.setLayerOpen(true)
    #expect(area.model.isPointerVisible)
    #expect(area.model.isPlayerUIVisible)
    #expect(!area.model.isIdleCountdownRunning)
    area.model.setLayerOpen(false)
    #expect(area.model.isPlayerUIVisible)
    #expect(area.model.isIdleCountdownRunning)

    // Opening Playback Overlay or Command Panel after the cursor was hidden by
    // idle does not actively unhide the cursor.
    area.model.idleElapsed()
    area.model.setLayerOpen(true)
    #expect(!area.model.isPointerVisible)
    #expect(AppCursorVisibility.isCursorHidden)
    #expect(!area.model.isPlayerUIVisible)
    // Moving the mouse while the layer is open unhides the cursor.
    area.movePointer(to: NSPoint(x: 410, y: 300))
    #expect(area.model.isPointerVisible)
    #expect(!AppCursorVisibility.isCursorHidden)
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

@MainActor
@Test
func stageTapInteractiveRectFollowsPlayerUIVisibilityAndChromeBoundaries() {
    let stageSize = CGSize(width: 1280, height: 720)

    let visibleRect = PlaybackChromeMetrics.stageTapInteractiveRect(
        stageSize: stageSize,
        isPlayerUIVisible: true
    )
    #expect(visibleRect == CGRect(x: 0, y: 54, width: 1280, height: 720 - 54 - 74))
    // Topbar (0..<54) is excluded when Player UI is visible.
    #expect(!visibleRect.contains(CGPoint(x: 640, y: 27)))
    // Top letterbox below 54px, video center, left/right pillarbox, and the 16px
    // progressTopPadding strip (630..<646) above the 18px scrubber hit area are included.
    #expect(visibleRect.contains(CGPoint(x: 640, y: 54)))
    #expect(visibleRect.contains(CGPoint(x: 640, y: 80)))
    #expect(visibleRect.contains(CGPoint(x: 20, y: 360)))
    #expect(visibleRect.contains(CGPoint(x: 1260, y: 360)))
    #expect(visibleRect.contains(CGPoint(x: 640, y: 720 - 90)))
    #expect(visibleRect.contains(CGPoint(x: 640, y: 720 - 75)))
    // Progress scrubber hit area (646..<664) and bottom controls row (664..<720) are excluded.
    #expect(!visibleRect.contains(CGPoint(x: 640, y: 720 - 74)))
    #expect(!visibleRect.contains(CGPoint(x: 12, y: 720 - 65)))
    #expect(!visibleRect.contains(CGPoint(x: 640, y: 720 - 30)))

    let hiddenRect = PlaybackChromeMetrics.stageTapInteractiveRect(
        stageSize: stageSize,
        isPlayerUIVisible: false
    )
    #expect(hiddenRect == CGRect(x: 0, y: 0, width: 1280, height: 720))
    #expect(hiddenRect.contains(CGPoint(x: 640, y: 27)))
    #expect(hiddenRect.contains(CGPoint(x: 640, y: 720 - 30)))
}

@MainActor
@Test
func draggableTitlebarViewPassesThroughHitTestingWhenPlayerUIIsHidden() {
    let view = DraggableNSView(frame: NSRect(x: 0, y: 0, width: 800, height: 54))
    #expect(view.hitTest(NSPoint(x: 400, y: 27)) === view)

    view.allowsHitTesting = false
    #expect(view.hitTest(NSPoint(x: 400, y: 27)) == nil)
}

@MainActor
@Test
func cueQueueControlBarReportsInteractiveRegionWithStableWidthAcrossGapValuesAndKeepsPlayerUIVisible() {
    let suiteName = "CueSeekerCueQueueBarTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }
    let settings = SettingsStore(userDefaults: userDefaults)
    let stageSize = CGSize(width: 800, height: 600)
    let centerY = PlaybackChromeMetrics.cueQueueBarCenterY(stageHeight: stageSize.height)
    let expectedCenterY: CGFloat = 504
    #expect(centerY == expectedCenterY)

    var reportedFrames: [CGRect] = []
    let rootView = ZStack(alignment: .topLeading) {
        Color.clear
        HStack(spacing: 0) {
            PlaybackCueQueueControlBar(settings: settings)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PlaybackChromeMetrics.chromeHorizontalPadding)
        .frame(
            width: stageSize.width,
            height: PlaybackChromeMetrics.cueQueueBarHeight,
            alignment: .leading
        )
        .position(x: stageSize.width / 2, y: centerY)
    }
    .frame(width: stageSize.width, height: stageSize.height)
    .overlayPreferenceValue(PlayerInteractiveRegionKey.self) { anchors in
        GeometryReader { proxy in
            let frames = anchors.map { proxy[$0] }
            Color.clear
                .onAppear { reportedFrames = frames }
                .onChange(of: frames) { _, newFrames in reportedFrames = newFrames }
        }
    }
    .environmentObject(settings.localization)
    .environmentObject(settings.playbackShortcuts)

    let host = NSHostingView(rootView: rootView)
    host.frame = CGRect(origin: .zero, size: stageSize)
    let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: stageSize),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))

    #expect(reportedFrames.count == 1)
    let initialFrame = try! #require(reportedFrames.first)
    #expect(abs(initialFrame.minX - PlaybackChromeMetrics.chromeHorizontalPadding) < 0.5)
    #expect(abs(initialFrame.height - PlaybackChromeMetrics.cueQueueBarHeight) < 0.5)
    #expect(abs(initialFrame.maxY - (stageSize.height - PlaybackChromeMetrics.bottomControlRegionHeight - PlaybackChromeMetrics.cueQueueBarBottomGap)) < 0.5)
    #expect(initialFrame.width > 180 && initialFrame.width < stageSize.width / 2)

    for gap in [0, 100, 500, 1_000, 10_000] {
        settings.setAutoSwitchCueSequenceGapMilliseconds(gap)
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        let currentFrame = try! #require(reportedFrames.first)
        #expect(abs(currentFrame.width - initialFrame.width) < 0.01)
        #expect(abs(currentFrame.minX - initialFrame.minX) < 0.01)
        #expect(abs(currentFrame.minY - initialFrame.minY) < 0.01)
    }

    let area = PlayerArea()
    defer {
        area.finish()
        window.orderOut(nil)
    }
    area.model.setInteractiveFrames([initialFrame])

    // Pointer inside the Cue Queue Control Bar (e.g. over the read-only gap value or 4px gap)
    // counts as hovering a Player UI interactive control and stops the 3s idle countdown.
    area.movePointer(
        to: NSPoint(
            x: initialFrame.midX,
            y: stageSize.height - initialFrame.midY
        )
    )
    #expect(!area.model.isIdleCountdownRunning)

    // Moving the pointer to the video stage to the right of the dock restarts the idle countdown.
    area.movePointer(
        to: NSPoint(
            x: initialFrame.maxX + 40,
            y: stageSize.height - initialFrame.midY
        )
    )
    #expect(area.model.isIdleCountdownRunning)
}
