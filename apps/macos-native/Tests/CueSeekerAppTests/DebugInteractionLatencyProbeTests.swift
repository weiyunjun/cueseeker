import CueSeekerCore
import Foundation
import XCTest
@testable import CueSeekerApp

@MainActor
final class DebugInteractionLatencyProbeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DebugInteractionLatencyProbe.resetForTesting()
    }

    override func tearDown() {
        DebugInteractionLatencyProbe.resetForTesting()
        super.tearDown()
    }

    func testNavigationPreparationEmitsStructuredDebugLogWithCoverStats() async {
        let expectation = expectation(description: "Navigation log emitted")
        var captured: DebugInteractionLatencyProbe.LoggedEvent?

        DebugInteractionLatencyProbe.setTestObserver { event in
            if event.message == "Workbench navigation completed" {
                captured = event
                expectation.fulfill()
            }
        }

        let start = DebugInteractionLatencyProbe.now()
        DebugInteractionLatencyProbe.beginNavigation(
            domain: "workbench",
            from: "library.root",
            to: "library.directory",
            trigger: "card_click",
            startedAt: start
        )
        DebugInteractionLatencyProbe.markNavigationSyncPrepFinished(
            domain: "workbench",
            to: "library.directory",
            at: start + 2_000_000
        )
        let coverStats = LibraryCoverPrewarmStats(
            totalCount: 12,
            cacheHitCount: 3,
            decodedCount: 9,
            elapsedMilliseconds: 185.4
        )
        DebugInteractionLatencyProbe.recordNavigationPreparation(
            domain: "workbench",
            from: "library.root",
            to: "library.directory",
            fallbackTrigger: "card_click",
            preparationStartedAt: start + 2_000_000,
            dataReadyAt: start + 15_000_000,
            coverStats: coverStats,
            containerSwapAt: start + 200_000_000
        )

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(captured?.domain, .system)
        XCTAssertEqual(captured?.fields["domain"], "workbench")
        XCTAssertEqual(captured?.fields["from"], "library.root")
        XCTAssertEqual(captured?.fields["to"], "library.directory")
        XCTAssertEqual(captured?.fields["trigger"], "card_click")
        XCTAssertEqual(captured?.fields["cover_total"], "12")
        XCTAssertEqual(captured?.fields["cover_hit"], "3")
        XCTAssertEqual(captured?.fields["cover_decoded"], "9")
        XCTAssertEqual(captured?.fields["cover_prewarm_ms"], "185.40")
        assertMemoryAndCoverCacheTelemetryFields(in: captured?.fields)
    }

    func testMenuOpenAndItemActionEmitStructuredDebugLogs() async {
        let openExpectation = expectation(description: "Menu open log emitted")
        let actionExpectation = expectation(description: "Menu action log emitted")
        var events: [DebugInteractionLatencyProbe.LoggedEvent] = []

        DebugInteractionLatencyProbe.setTestObserver { event in
            events.append(event)
            if event.message == "Menu open completed" {
                openExpectation.fulfill()
            } else if event.message == "Menu item action executed" {
                actionExpectation.fulfill()
            }
        }

        let startedAt = ProcessInfo.processInfo.systemUptime
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: "card_button_menu",
            trigger: "button_anchor",
            startedAt: startedAt,
            measureMs: 4.25
        )
        DebugInteractionLatencyProbe.recordMenuGateOpen(
            kind: "cardMenu",
            owner: "workbenchPage"
        )
        DebugInteractionLatencyProbe.measureMenuItemAction(
            menuID: "card_button_menu",
            item: "Change Cover"
        ) {}

        await fulfillment(of: [openExpectation, actionExpectation], timeout: 1.0)
        let openEvent = events.first { $0.message == "Menu open completed" }
        XCTAssertEqual(openEvent?.fields["menu_id"], "card_button_menu")
        XCTAssertEqual(openEvent?.fields["owner"], "workbenchPage")
        XCTAssertEqual(openEvent?.fields["trigger"], "button_anchor")

        let actionEvent = events.first { $0.message == "Menu item action executed" }
        XCTAssertEqual(actionEvent?.fields["menu_id"], "card_button_menu")
        XCTAssertEqual(actionEvent?.fields["item"], "Change Cover")
    }

    func testDialogOpenInternalTransitionAndFilePanelEmitStructuredDebugLogs() async {
        let dialogOpenExpectation = expectation(description: "Dialog open log emitted")
        let internalTransitionExpectation = expectation(description: "Dialog internal transition log emitted")
        let filePanelExpectation = expectation(description: "File panel log emitted")
        var events: [DebugInteractionLatencyProbe.LoggedEvent] = []

        DebugInteractionLatencyProbe.setTestObserver { event in
            events.append(event)
            switch event.message {
            case "Dialog open completed":
                dialogOpenExpectation.fulfill()
            case "Dialog internal transition completed":
                internalTransitionExpectation.fulfill()
            case "System file panel completed":
                filePanelExpectation.fulfill()
            default:
                break
            }
        }

        let start = DebugInteractionLatencyProbe.now()
        DebugInteractionLatencyProbe.beginDialogOpen(
            dialogID: "file_detail_video",
            trigger: "get_info",
            startedAt: start,
            syncPrepFinishedAt: start + 3_000_000,
            hasEntranceAnimation: true
        )
        DebugInteractionLatencyProbe.recordDialogAnimationFrame(
            dialogID: "file_detail_video",
            progress: 0.5,
            isEntering: true
        )
        DebugInteractionLatencyProbe.recordDialogAnimationFrame(
            dialogID: "file_detail_video",
            progress: 1.0,
            isEntering: true
        )

        DebugInteractionLatencyProbe.recordDialogInternalTransition(
            dialogID: "file_detail",
            action: "switch_paired_item",
            startedAt: ProcessInfo.processInfo.systemUptime,
            itemCount: 3
        )

        DebugInteractionLatencyProbe.recordSystemFilePanel(
            panelType: "NSOpenPanel",
            trigger: "library_choose_cover",
            mode: "sheet_or_modal",
            startedAt: start,
            panelPresentedAt: start + 12_000_000,
            completedAt: start + 500_000_000,
            didSelect: true
        )

        await fulfillment(
            of: [dialogOpenExpectation, internalTransitionExpectation, filePanelExpectation],
            timeout: 1.0
        )

        let openEvent = events.first { $0.message == "Dialog open completed" }
        XCTAssertEqual(openEvent?.fields["dialog_id"], "file_detail_video")
        XCTAssertEqual(openEvent?.fields["trigger"], "get_info")
        XCTAssertEqual(openEvent?.fields["anim_frames"], "2")
        assertMemoryAndCoverCacheTelemetryFields(in: openEvent?.fields)

        let stepEvent = events.first { $0.message == "Dialog internal transition completed" }
        XCTAssertEqual(stepEvent?.fields["dialog_id"], "file_detail")
        XCTAssertEqual(stepEvent?.fields["transition"], "switch_paired_item")
        XCTAssertEqual(stepEvent?.fields["trigger"], "items_3")
        assertMemoryAndCoverCacheTelemetryFields(in: stepEvent?.fields)

        let panelEvent = events.first { $0.message == "System file panel completed" }
        XCTAssertEqual(panelEvent?.fields["panel_type"], "NSOpenPanel")
        XCTAssertEqual(panelEvent?.fields["trigger"], "library_choose_cover")
        XCTAssertEqual(panelEvent?.fields["result"], "selected")
    }

    func testMainThreadStallThresholdFiltering() {
        var events: [DebugInteractionLatencyProbe.LoggedEvent] = []
        DebugInteractionLatencyProbe.setTestObserver { event in
            events.append(event)
        }

        DebugInteractionLatencyProbe.recordMainThreadStall(
            stalledMilliseconds: 24.5,
            phase: "afterWaiting->beforeWaiting",
            lastAction: "nav:workbench:card_click",
            lastActionAgeMilliseconds: 10.0
        )
        XCTAssertTrue(events.isEmpty)

        DebugInteractionLatencyProbe.recordMainThreadStall(
            stalledMilliseconds: 45_499.1,
            phase: "beforeWaiting->entry",
            lastAction: "nav:command_panel:open_command_panel",
            lastActionAgeMilliseconds: 45_500.0
        )
        XCTAssertTrue(events.isEmpty)

        DebugInteractionLatencyProbe.recordMainThreadStall(
            stalledMilliseconds: 16_139.8,
            phase: "beforeWaiting->afterWaiting",
            lastAction: "nav:command_panel:open_command_panel",
            lastActionAgeMilliseconds: 16_140.0
        )
        XCTAssertTrue(events.isEmpty)

        DebugInteractionLatencyProbe.recordMainThreadStall(
            stalledMilliseconds: 48.2,
            phase: "afterWaiting->beforeWaiting",
            lastAction: "nav:workbench:card_click",
            lastActionAgeMilliseconds: 18.4
        )
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.message, "Main thread stall detected")
        XCTAssertEqual(events.first?.fields["stalled_ms"], "48.20")
        XCTAssertEqual(events.first?.fields["phase"], "afterWaiting->beforeWaiting")
        XCTAssertEqual(events.first?.fields["last_action"], "nav:workbench:card_click")
        XCTAssertEqual(events.first?.fields["last_action_age_ms"], "18.40")
    }

    func testImmediateNavigationDoesNotInheritMismatchedPendingFromSurface() async {
        let expectation = expectation(description: "Overlay close log emitted")
        var captured: DebugInteractionLatencyProbe.LoggedEvent?

        DebugInteractionLatencyProbe.setTestObserver { event in
            if event.message == "Overlay module transition completed" {
                captured = event
                expectation.fulfill()
            }
        }

        let openStart = DebugInteractionLatencyProbe.now()
        DebugInteractionLatencyProbe.beginNavigation(
            domain: "playback_overlay",
            from: "closed",
            to: "playback_overlay_current",
            trigger: "open_playback_overlay",
            startedAt: openStart
        )
        XCTAssertTrue(DebugInteractionLatencyProbe.hasPendingNavigation(domain: "playback_overlay"))

        let closeStart = openStart + 10_000_000
        DebugInteractionLatencyProbe.completeImmediateNavigation(
            domain: "playback_overlay",
            from: "playback_overlay",
            to: "closed",
            trigger: "dismiss_playback_overlay",
            startedAt: closeStart,
            syncPrepFinishedAt: closeStart + 1_000_000
        )
        XCTAssertFalse(DebugInteractionLatencyProbe.hasPendingNavigation(domain: "playback_overlay"))

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(captured?.fields["from"], "playback_overlay")
        XCTAssertEqual(captured?.fields["to"], "closed")
        XCTAssertEqual(captured?.fields["trigger"], "dismiss_playback_overlay")
        assertMemoryAndCoverCacheTelemetryFields(in: captured?.fields)
    }

    func testMenuContextPreservesInitialClickTimestampAndClearsOnClose() async {
        let expectation = expectation(description: "Two menu opens logged")
        expectation.expectedFulfillmentCount = 2
        var events: [DebugInteractionLatencyProbe.LoggedEvent] = []

        DebugInteractionLatencyProbe.setTestObserver { event in
            if event.message == "Menu open completed" {
                events.append(event)
                expectation.fulfill()
            }
        }

        let clickStart = DebugInteractionLatencyProbe.now()
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: "player_more_menu",
            trigger: "chrome_more_button",
            startedAt: clickStart,
            measureMilliseconds: 0
        )
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: "player_more_menu",
            trigger: "layout_measure",
            startedAt: clickStart + 2_000_000,
            measureMilliseconds: 5.5
        )
        DebugInteractionLatencyProbe.recordMenuGateOpen(
            owner: "playbackPage",
            fallbackMenuID: "playerMoreMenu",
            openedAt: clickStart + 8_000_000
        )

        // Simulate a stale context cleared on menu close before opening the next menu.
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: "player_more_menu",
            trigger: "stale_recalculate",
            startedAt: clickStart,
            measureMilliseconds: 5.5
        )
        DebugInteractionLatencyProbe.clearActiveMenuContext()

        let secondOpenAt = clickStart + 5_000_000_000
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: "player_subtitle_menu",
            trigger: "chrome_subtitle_button",
            startedAt: secondOpenAt,
            measureMilliseconds: 3.2
        )
        DebugInteractionLatencyProbe.recordMenuGateOpen(
            owner: "playbackPage",
            fallbackMenuID: "playerSubtitleMenu",
            openedAt: secondOpenAt + 4_000_000
        )

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].fields["menu_id"], "player_more_menu")
        XCTAssertEqual(events[0].fields["trigger"], "chrome_more_button")
        XCTAssertEqual(events[0].fields["prep_and_measure_ms"], "8.00")

        XCTAssertEqual(events[1].fields["menu_id"], "player_subtitle_menu")
        XCTAssertEqual(events[1].fields["trigger"], "chrome_subtitle_button")
        XCTAssertEqual(events[1].fields["prep_and_measure_ms"], "4.00")
    }

    private func assertMemoryAndCoverCacheTelemetryFields(
        in fields: [String: String]?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let fields else {
            XCTFail("Expected non-nil telemetry fields", file: file, line: line)
            return
        }
        guard let memoryMBText = fields["memory_mb"],
              let memoryMB = Double(memoryMBText),
              let deltaMBText = fields["memory_delta_mb"],
              Double(deltaMBText) != nil,
              let peakMBText = fields["peak_memory_mb"],
              let peakMB = Double(peakMBText),
              let coverCacheMBText = fields["cover_cache_mb"],
              let coverCacheMB = Double(coverCacheMBText),
              let coverCacheCountText = fields["cover_cache_count"],
              let coverCacheCount = Int(coverCacheCountText)
        else {
            XCTFail("Missing or malformed memory telemetry fields: \(fields)", file: file, line: line)
            return
        }
        XCTAssertGreaterThan(memoryMB, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(peakMB, memoryMB, file: file, line: line)
        XCTAssertTrue(
            deltaMBText.hasPrefix("+") || deltaMBText.hasPrefix("-"),
            "Expected signed memory_delta_mb, got \(deltaMBText)",
            file: file,
            line: line
        )
        XCTAssertGreaterThanOrEqual(coverCacheMB, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(coverCacheCount, 0, file: file, line: line)
    }
}
