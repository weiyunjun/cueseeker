import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleTableHeightInvalidationSchedulerCoalescesRapidScrollRequests() {
    var reasons: [String] = []
    let scheduler = SubtitleTableHeightInvalidationScheduler(delayNanoseconds: 10_000_000) { reason in
        reasons.append(reason)
    }

    for _ in 0..<20 {
        scheduler.schedule(reason: "scroll")
    }

    scheduler.flushForTesting()

    #expect(reasons == ["scroll"])
}

@MainActor
@Test
func subtitleTableHeightInvalidationSchedulerKeepsLatestReason() {
    var reasons: [String] = []
    let scheduler = SubtitleTableHeightInvalidationScheduler(delayNanoseconds: 10_000_000) { reason in
        reasons.append(reason)
    }

    scheduler.schedule(reason: "initial")
    scheduler.schedule(reason: "frame_changed")
    scheduler.schedule(reason: "scroll")

    scheduler.flushForTesting()

    #expect(reasons == ["scroll"])
}
