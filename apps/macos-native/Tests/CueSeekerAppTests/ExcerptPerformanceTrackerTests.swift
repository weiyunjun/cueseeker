import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Suite(.serialized)
struct ExcerptPerformanceTrackerTests {
    @Test
    func coldOpenRecordsPerformanceReportWhenVisibleRowsRendered() {
        let listID: Int64 = 9001
        ExcerptOpenPerformanceTracker.reset(listID: listID)
        defer { ExcerptOpenPerformanceTracker.reset(listID: listID) }

        var emittedReports: [ExcerptOpenPerformanceReport] = []
        ExcerptOpenPerformanceTracker.onReportEmitted = { report in
            if report.listID == listID {
                emittedReports.append(report)
            }
        }
        defer { ExcerptOpenPerformanceTracker.onReportEmitted = nil }

        ExcerptOpenPerformanceTracker.beginOpen(listID: listID, title: "我喜欢的字幕")
        #expect(ExcerptOpenPerformanceTracker.lastReport(forListID: listID) == nil)

        ExcerptOpenPerformanceTracker.recordDataReady(listID: listID, count: 396, cacheHit: false)
        #expect(ExcerptOpenPerformanceTracker.lastReport(forListID: listID) == nil)

        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(listID: listID, visibleRows: 0..<15)

        #expect(emittedReports.count == 1)
        let report = ExcerptOpenPerformanceTracker.lastReport(forListID: listID)
        #expect(report?.listID == listID)
        #expect(report?.title == "我喜欢的字幕")
        #expect(report?.count == 396)
        #expect(report?.cacheHit == false)
        #expect((report?.totalDuration ?? -1) >= 0)
        #expect((report?.dataReadyDuration ?? -1) >= 0)
        #expect((report?.viewRenderDuration ?? -1) >= 0)

        let log = report?.logMessage ?? ""
        #expect(log.contains("[PERF_EXCERPT_OPEN]"))
        #expect(log.contains("listID=9001"))
        #expect(log.contains("title=\"我喜欢的字幕\""))
        #expect(log.contains("count=396"))
        #expect(log.contains("cacheHit=false"))
    }

    @Test
    func cacheHitRecordsPerformanceReport() {
        let listID: Int64 = 9002
        ExcerptOpenPerformanceTracker.reset(listID: listID)
        defer { ExcerptOpenPerformanceTracker.reset(listID: listID) }

        var emittedReports: [ExcerptOpenPerformanceReport] = []
        ExcerptOpenPerformanceTracker.onReportEmitted = { report in
            if report.listID == listID {
                emittedReports.append(report)
            }
        }
        defer { ExcerptOpenPerformanceTracker.onReportEmitted = nil }

        ExcerptOpenPerformanceTracker.beginOpen(listID: listID, title: "日常会话")
        ExcerptOpenPerformanceTracker.recordDataReady(listID: listID, count: 50, cacheHit: true)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(listID: listID, visibleRows: 0..<10)

        #expect(emittedReports.count == 1)
        let report = ExcerptOpenPerformanceTracker.lastReport(forListID: listID)
        #expect(report?.listID == listID)
        #expect(report?.title == "日常会话")
        #expect(report?.count == 50)
        #expect(report?.cacheHit == true)
        #expect(report?.logMessage.contains("cacheHit=true") == true)
    }

    @Test
    func emptyListCompletesImmediatelyWithoutWaitingForVisibleRows() {
        let listID: Int64 = 9099
        ExcerptOpenPerformanceTracker.reset(listID: listID)
        defer { ExcerptOpenPerformanceTracker.reset(listID: listID) }

        var emittedReports: [ExcerptOpenPerformanceReport] = []
        ExcerptOpenPerformanceTracker.onReportEmitted = { report in
            if report.listID == listID {
                emittedReports.append(report)
            }
        }
        defer { ExcerptOpenPerformanceTracker.onReportEmitted = nil }

        ExcerptOpenPerformanceTracker.beginOpen(listID: listID, title: "空列表")
        #expect(ExcerptOpenPerformanceTracker.lastReport(forListID: listID) == nil)

        ExcerptOpenPerformanceTracker.recordDataReady(listID: listID, count: 0, cacheHit: false)

        #expect(emittedReports.count == 1)
        let report = ExcerptOpenPerformanceTracker.lastReport(forListID: listID)
        #expect(report?.listID == listID)
        #expect(report?.title == "空列表")
        #expect(report?.count == 0)
        #expect(report?.viewRenderDuration == 0.0)
    }

    @Test
    func scrollingVisibleRowsDoesNotReemitReport() {
        let listID: Int64 = 9003
        ExcerptOpenPerformanceTracker.reset(listID: listID)
        defer { ExcerptOpenPerformanceTracker.reset(listID: listID) }

        var count = 0
        ExcerptOpenPerformanceTracker.onReportEmitted = { report in
            if report.listID == listID {
                count += 1
            }
        }
        defer { ExcerptOpenPerformanceTracker.onReportEmitted = nil }

        ExcerptOpenPerformanceTracker.beginOpen(listID: listID, title: "Test")
        ExcerptOpenPerformanceTracker.recordDataReady(listID: listID, count: 100, cacheHit: false)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(listID: listID, visibleRows: 0..<15)
        #expect(count == 1)

        // Subsequent scroll events
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(listID: listID, visibleRows: 15..<30)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(listID: listID, visibleRows: 30..<45)
        #expect(count == 1)
    }

    @Test
    func prematureVisibleRowsBeforeDataReadyAreIgnored() {
        let listID: Int64 = 9004
        ExcerptOpenPerformanceTracker.reset(listID: listID)
        defer { ExcerptOpenPerformanceTracker.reset(listID: listID) }

        ExcerptOpenPerformanceTracker.beginOpen(listID: listID, title: "Test")

        // Spurious visible rows notification from old view
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(listID: listID, visibleRows: 0..<15)
        #expect(ExcerptOpenPerformanceTracker.lastReport(forListID: listID) == nil)

        // Now data ready
        ExcerptOpenPerformanceTracker.recordDataReady(listID: listID, count: 10, cacheHit: false)
        #expect(ExcerptOpenPerformanceTracker.lastReport(forListID: listID) == nil)

        // Real visible rows
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(listID: listID, visibleRows: 0..<10)
        #expect(ExcerptOpenPerformanceTracker.lastReport(forListID: listID)?.count == 10)
    }

    @Test
    func newOpenSupersedesPreviousInFlightSession() {
        let listID1: Int64 = 9005
        let listID2: Int64 = 9006
        ExcerptOpenPerformanceTracker.reset(listID: listID1)
        ExcerptOpenPerformanceTracker.reset(listID: listID2)
        defer {
            ExcerptOpenPerformanceTracker.reset(listID: listID1)
            ExcerptOpenPerformanceTracker.reset(listID: listID2)
        }

        ExcerptOpenPerformanceTracker.beginOpen(listID: listID1, title: "First")

        // Switch list before First finishes
        ExcerptOpenPerformanceTracker.beginOpen(listID: listID2, title: "Second")

        // Data ready for Second
        ExcerptOpenPerformanceTracker.recordDataReady(listID: listID2, count: 20, cacheHit: false)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(listID: listID2, visibleRows: 0..<10)

        #expect(ExcerptOpenPerformanceTracker.lastReport(forListID: listID2)?.listID == listID2)
        #expect(ExcerptOpenPerformanceTracker.lastReport(forListID: listID2)?.title == "Second")
    }

    @Test
    func cancelOpenCleansUpPendingSession() {
        let listID: Int64 = 9007
        ExcerptOpenPerformanceTracker.reset(listID: listID)
        defer { ExcerptOpenPerformanceTracker.reset(listID: listID) }

        ExcerptOpenPerformanceTracker.beginOpen(listID: listID, title: "Cancelled")
        ExcerptOpenPerformanceTracker.cancelOpen(listID: listID)

        ExcerptOpenPerformanceTracker.recordDataReady(listID: listID, count: 10, cacheHit: false)
        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(listID: listID, visibleRows: 0..<10)

        #expect(ExcerptOpenPerformanceTracker.lastReport(forListID: listID) == nil)
    }
}
