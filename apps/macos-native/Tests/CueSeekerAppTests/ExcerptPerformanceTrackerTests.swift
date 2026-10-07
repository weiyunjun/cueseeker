import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
struct ExcerptPerformanceTrackerTests {
    @Test
    func coldOpenRecordsPerformanceReportWhenVisibleRowsRendered() {
        ExcerptOpenPerformanceTracker.reset()
        var emittedReports: [ExcerptOpenPerformanceReport] = []
        ExcerptOpenPerformanceTracker.onReportEmitted = { report in
            emittedReports.append(report)
        }

        ExcerptOpenPerformanceTracker.beginOpen(listID: 1, title: "我喜欢的字幕")
        #expect(ExcerptOpenPerformanceTracker.lastReport == nil)

        ExcerptOpenPerformanceTracker.recordDataReady(listID: 1, count: 396, cacheHit: false)
        #expect(ExcerptOpenPerformanceTracker.lastReport == nil)

        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(visibleRows: 0..<15)

        #expect(emittedReports.count == 1)
        let report = ExcerptOpenPerformanceTracker.lastReport
        #expect(report?.listID == 1)
        #expect(report?.title == "我喜欢的字幕")
        #expect(report?.count == 396)
        #expect(report?.cacheHit == false)
        #expect((report?.totalDuration ?? -1) >= 0)
        #expect((report?.dataReadyDuration ?? -1) >= 0)
        #expect((report?.viewRenderDuration ?? -1) >= 0)

        let log = report?.logMessage ?? ""
        #expect(log.contains("[PERF_EXCERPT_OPEN]"))
        #expect(log.contains("listID=1"))
        #expect(log.contains("title=\"我喜欢的字幕\""))
        #expect(log.contains("count=396"))
        #expect(log.contains("cacheHit=false"))

        ExcerptOpenPerformanceTracker.reset()
    }

    @Test
    func cacheHitRecordsPerformanceReport() {
        ExcerptOpenPerformanceTracker.reset()
        var emittedReports: [ExcerptOpenPerformanceReport] = []
        ExcerptOpenPerformanceTracker.onReportEmitted = { report in
            emittedReports.append(report)
        }

        ExcerptOpenPerformanceTracker.beginOpen(listID: 2, title: "日常会话")
        ExcerptOpenPerformanceTracker.recordDataReady(listID: 2, count: 50, cacheHit: true)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(visibleRows: 0..<10)

        #expect(emittedReports.count == 1)
        let report = ExcerptOpenPerformanceTracker.lastReport
        #expect(report?.listID == 2)
        #expect(report?.title == "日常会话")
        #expect(report?.count == 50)
        #expect(report?.cacheHit == true)
        #expect(report?.logMessage.contains("cacheHit=true") == true)

        ExcerptOpenPerformanceTracker.reset()
    }

    @Test
    func emptyListCompletesImmediatelyWithoutWaitingForVisibleRows() {
        ExcerptOpenPerformanceTracker.reset()
        var emittedReports: [ExcerptOpenPerformanceReport] = []
        ExcerptOpenPerformanceTracker.onReportEmitted = { report in
            emittedReports.append(report)
        }

        ExcerptOpenPerformanceTracker.beginOpen(listID: 99, title: "空列表")
        #expect(ExcerptOpenPerformanceTracker.lastReport == nil)

        ExcerptOpenPerformanceTracker.recordDataReady(listID: 99, count: 0, cacheHit: false)

        #expect(emittedReports.count == 1)
        let report = ExcerptOpenPerformanceTracker.lastReport
        #expect(report?.listID == 99)
        #expect(report?.title == "空列表")
        #expect(report?.count == 0)
        #expect(report?.viewRenderDuration == 0.0)

        ExcerptOpenPerformanceTracker.reset()
    }

    @Test
    func scrollingVisibleRowsDoesNotReemitReport() {
        ExcerptOpenPerformanceTracker.reset()
        var count = 0
        ExcerptOpenPerformanceTracker.onReportEmitted = { _ in
            count += 1
        }

        ExcerptOpenPerformanceTracker.beginOpen(listID: 1, title: "Test")
        ExcerptOpenPerformanceTracker.recordDataReady(listID: 1, count: 100, cacheHit: false)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(visibleRows: 0..<15)
        #expect(count == 1)

        // Subsequent scroll events
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(visibleRows: 15..<30)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(visibleRows: 30..<45)
        #expect(count == 1)

        ExcerptOpenPerformanceTracker.reset()
    }

    @Test
    func prematureVisibleRowsBeforeDataReadyAreIgnored() {
        ExcerptOpenPerformanceTracker.reset()
        ExcerptOpenPerformanceTracker.beginOpen(listID: 1, title: "Test")

        // Spurious visible rows notification from old view
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(visibleRows: 0..<15)
        #expect(ExcerptOpenPerformanceTracker.lastReport == nil)

        // Now data ready
        ExcerptOpenPerformanceTracker.recordDataReady(listID: 1, count: 10, cacheHit: false)
        #expect(ExcerptOpenPerformanceTracker.lastReport == nil)

        // Real visible rows
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(visibleRows: 0..<10)
        #expect(ExcerptOpenPerformanceTracker.lastReport?.count == 10)

        ExcerptOpenPerformanceTracker.reset()
    }

    @Test
    func newOpenSupersedesPreviousInFlightSession() {
        ExcerptOpenPerformanceTracker.reset()
        ExcerptOpenPerformanceTracker.beginOpen(listID: 1, title: "First")

        // Switch list before First finishes
        ExcerptOpenPerformanceTracker.beginOpen(listID: 2, title: "Second")

        // Data ready for Second
        ExcerptOpenPerformanceTracker.recordDataReady(listID: 2, count: 20, cacheHit: false)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(visibleRows: 0..<10)

        #expect(ExcerptOpenPerformanceTracker.lastReport?.listID == 2)
        #expect(ExcerptOpenPerformanceTracker.lastReport?.title == "Second")

        ExcerptOpenPerformanceTracker.reset()
    }

    @Test
    func cancelOpenCleansUpPendingSession() {
        ExcerptOpenPerformanceTracker.reset()
        ExcerptOpenPerformanceTracker.beginOpen(listID: 5, title: "Cancelled")
        ExcerptOpenPerformanceTracker.cancelOpen(listID: 5)

        ExcerptOpenPerformanceTracker.recordDataReady(listID: 5, count: 10, cacheHit: false)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(visibleRows: 0..<10)

        #expect(ExcerptOpenPerformanceTracker.lastReport == nil)
        ExcerptOpenPerformanceTracker.reset()
    }
}
