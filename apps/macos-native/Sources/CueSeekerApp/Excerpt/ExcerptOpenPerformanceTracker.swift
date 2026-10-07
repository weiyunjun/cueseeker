import Foundation
import os

public struct ExcerptOpenPerformanceReport: Equatable, Sendable {
    public let listID: Int64
    public let title: String
    public let count: Int
    public let totalDuration: Double      // ms
    public let dataReadyDuration: Double  // ms
    public let viewRenderDuration: Double // ms
    public let cacheHit: Bool

    public var logMessage: String {
        String(
            format: "[PERF_EXCERPT_OPEN] listID=%lld title=\"%@\" count=%d totalDuration=%.2fms (dataReady=%.2fms viewRender=%.2fms) cacheHit=%@",
            listID,
            title,
            count,
            totalDuration,
            dataReadyDuration,
            viewRenderDuration,
            cacheHit ? "true" : "false"
        )
    }
}

@MainActor
public enum ExcerptOpenPerformanceTracker {
    private static let logger = Logger(subsystem: "com.cueseeker.perf", category: "Excerpt")

    private struct PendingSession {
        let listID: Int64
        let title: String
        let startedAt: UInt64
        var dataReadyAt: UInt64?
        var count: Int?
        var cacheHit: Bool?
    }

    private static var currentSession: PendingSession?
    public private(set) static var lastReport: ExcerptOpenPerformanceReport?

    /// Optional callback hook for automated testing.
    public static var onReportEmitted: ((ExcerptOpenPerformanceReport) -> Void)?

    public static func beginOpen(listID: Int64, title: String) {
        currentSession = PendingSession(
            listID: listID,
            title: title,
            startedAt: DispatchTime.now().uptimeNanoseconds
        )
    }

    public static func recordDataReady(
        listID: Int64,
        count: Int,
        cacheHit: Bool
    ) {
        guard var session = currentSession, session.listID == listID else {
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        session.dataReadyAt = now
        session.count = count
        session.cacheHit = cacheHit

        if count == 0 {
            let totalDuration = Double(now - session.startedAt) / 1_000_000
            let dataReadyDuration = totalDuration
            let viewRenderDuration = 0.0
            let report = ExcerptOpenPerformanceReport(
                listID: session.listID,
                title: session.title,
                count: 0,
                totalDuration: totalDuration,
                dataReadyDuration: dataReadyDuration,
                viewRenderDuration: viewRenderDuration,
                cacheHit: cacheHit
            )
            emit(report)
            currentSession = nil
            return
        }

        currentSession = session
    }

    public static func recordVisibleRowsRendered(visibleRows: Range<Int>) {
        guard let session = currentSession,
              let dataReadyAt = session.dataReadyAt,
              let count = session.count,
              let cacheHit = session.cacheHit
        else {
            return
        }
        guard !visibleRows.isEmpty else {
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let totalDuration = Double(now - session.startedAt) / 1_000_000
        let dataReadyDuration = Double(dataReadyAt - session.startedAt) / 1_000_000
        let viewRenderDuration = Double(now - dataReadyAt) / 1_000_000

        let report = ExcerptOpenPerformanceReport(
            listID: session.listID,
            title: session.title,
            count: count,
            totalDuration: totalDuration,
            dataReadyDuration: dataReadyDuration,
            viewRenderDuration: viewRenderDuration,
            cacheHit: cacheHit
        )
        emit(report)
        currentSession = nil
    }

    public static func cancelOpen(listID: Int64? = nil) {
        if let listID {
            if currentSession?.listID == listID {
                currentSession = nil
            }
        } else {
            currentSession = nil
        }
    }

    public static func reset() {
        currentSession = nil
        lastReport = nil
        onReportEmitted = nil
    }

    private static func emit(_ report: ExcerptOpenPerformanceReport) {
        lastReport = report
        print(report.logMessage)
        logger.notice("\(report.logMessage, privacy: .public)")
        onReportEmitted?(report)
    }
}
