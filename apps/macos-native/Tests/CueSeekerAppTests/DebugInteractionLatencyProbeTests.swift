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

        let stepEvent = events.first { $0.message == "Dialog internal transition completed" }
        XCTAssertEqual(stepEvent?.fields["dialog_id"], "file_detail")
        XCTAssertEqual(stepEvent?.fields["transition"], "switch_paired_item")
        XCTAssertEqual(stepEvent?.fields["trigger"], "items_3")

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
}
