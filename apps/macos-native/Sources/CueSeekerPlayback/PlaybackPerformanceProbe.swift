import CASSRendering
import CNativePlayback
import CueSeekerCore
import Foundation
import QuartzCore
import os

struct PlaybackSubtitleTelemetryCounters: Sendable {
    var subtitleTicks: UInt64 = 0
    var assWorkerDispatches: UInt64 = 0
    var assLayerUpdates: UInt64 = 0
    var srtUpdateCalls: UInt64 = 0
    var srtBitmapRenders: UInt64 = 0
}

private final class PlaybackPerformanceProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var counters: [String: UInt64] = [:]
    private var subtitleCounters = PlaybackSubtitleTelemetryCounters()

    func increment(_ name: String) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        let nextCount = (counters[name] ?? 0) + 1
        counters[name] = nextCount
        return nextCount
    }

    func recordSubtitleTick() {
        lock.lock()
        subtitleCounters.subtitleTicks &+= 1
        lock.unlock()
    }

    func recordASSWorkerDispatch() {
        lock.lock()
        subtitleCounters.assWorkerDispatches &+= 1
        lock.unlock()
    }

    func recordASSLayerUpdate() {
        lock.lock()
        subtitleCounters.assLayerUpdates &+= 1
        lock.unlock()
    }

    func recordSRTUpdateCall() {
        lock.lock()
        subtitleCounters.srtUpdateCalls &+= 1
        lock.unlock()
    }

    func recordSRTBitmapRender() {
        lock.lock()
        subtitleCounters.srtBitmapRenders &+= 1
        lock.unlock()
    }

    func subtitleCountersSnapshot() -> PlaybackSubtitleTelemetryCounters {
        lock.lock()
        defer { lock.unlock() }
        return subtitleCounters
    }
}

enum PlaybackPerformanceProbe {
    private static let logger = Logger(subsystem: "com.cueseeker.perf", category: "Playback")
    private static let isEnabled = diagnosticFlag("CUESEEKER_PERF_PLAYBACK")
    private static let isUIInvalidationEnabled = diagnosticFlag("CUESEEKER_PERF_UI")
    private static let state = PlaybackPerformanceProbeState()

    static func now() -> UInt64 {
        guard isEnabled else {
            return 0
        }

        return DispatchTime.now().uptimeNanoseconds
    }

    static func recordSubtitleTick() {
        state.recordSubtitleTick()
    }

    static func recordASSWorkerDispatch() {
        state.recordASSWorkerDispatch()
    }

    static func recordASSLayerUpdate() {
        state.recordASSLayerUpdate()
    }

    static func recordSRTUpdateCall() {
        state.recordSRTUpdateCall()
    }

    static func recordSRTBitmapRender() {
        state.recordSRTBitmapRender()
    }

    static func subtitleCountersSnapshot() -> PlaybackSubtitleTelemetryCounters {
        state.subtitleCountersSnapshot()
    }

    @discardableResult
    static func measure<T>(
        _ name: String,
        thresholdMilliseconds: Double = 16,
        _ block: () throws -> T
    ) rethrows -> T {
        guard isEnabled else {
            return try block()
        }

        let start = now()
        defer {
            logElapsed(name, since: start, thresholdMilliseconds: thresholdMilliseconds)
        }
        return try block()
    }

    static func logElapsed(
        _ name: String,
        since start: UInt64,
        thresholdMilliseconds: Double = 16
    ) {
        guard isEnabled else {
            return
        }

        let elapsedMilliseconds = Double(now() - start) / 1_000_000
        guard elapsedMilliseconds >= thresholdMilliseconds else {
            return
        }

        logger.warning("\(message(name: name, elapsedMilliseconds: elapsedMilliseconds), privacy: .public)")
    }

    @discardableResult
    static func countUI(_ name: String, details: String? = nil) -> UInt64 {
        guard isUIInvalidationEnabled else {
            return 0
        }

        let nextCount = state.increment(name)

        if let details, !details.isEmpty {
            logger.warning("COUNT \(name, privacy: .public) \(nextCount) \(details, privacy: .public)")
        } else {
            logger.warning("COUNT \(name, privacy: .public) \(nextCount)")
        }

        return nextCount
    }

    private static func message(name: String, elapsedMilliseconds: Double) -> String {
        String(format: "SLOW %@ %.2fms", name, elapsedMilliseconds)
    }

    private static func diagnosticFlag(_ name: String) -> Bool {
        let argumentName = "--" + name.lowercased().replacingOccurrences(of: "_", with: "-")
        if ProcessInfo.processInfo.arguments.contains(argumentName) {
            return true
        }

        let value = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()

        switch value {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}

final class PlaybackRuntimeTelemetryTracker: @unchecked Sendable {
    private struct PointSnapshot {
        let wallSeconds: Double
        let mediaSeconds: Double
        let native: SFXNativePlaybackRuntimeTelemetry
        let ass: SFXASSRuntimeTelemetry
        let sub: PlaybackSubtitleTelemetryCounters
    }

    private struct AccumulatedDelta {
        var wallSeconds: Double = 0
        var mediaSeconds: Double = 0

        var userCPUSeconds: Double = 0
        var systemCPUSeconds: Double = 0
        var instructions: UInt64 = 0
        var cycles: UInt64 = 0
        var interruptWakeups: UInt64 = 0
        var latestPhysFootprintBytes: UInt64 = 0

        var videoDecodedFrames: UInt64 = 0
        var videoSubmittedFrames: UInt64 = 0
        var videoDecodeMicroseconds: UInt64 = 0
        var videoPixelTransferMicroseconds: UInt64 = 0
        var videoSubmissionMicroseconds: UInt64 = 0
        var videoFormatDescCreateCalls: UInt64 = 0
        var videoWaitIterations: UInt64 = 0

        var audioDecodedFrames: UInt64 = 0
        var audioScheduledBuffers: UInt64 = 0
        var audioCompletionCallbacks: UInt64 = 0
        var audioDecodeAndResampleMicroseconds: UInt64 = 0
        var audioScheduleMicroseconds: UInt64 = 0
        var timePitchBypassed: Bool = true

        var subtitleTicks: UInt64 = 0
        var assWorkerDispatches: UInt64 = 0
        var assRenderFrameCalls: UInt64 = 0
        var assRenderFrameMicroseconds: UInt64 = 0
        var assSilentOrUnchangedSkips: UInt64 = 0
        var assCompositeCalls: UInt64 = 0
        var assCompositeMicroseconds: UInt64 = 0
        var assLayerUpdates: UInt64 = 0
        var srtUpdateCalls: UInt64 = 0
        var srtBitmapRenders: UInt64 = 0

        mutating func add(from previous: PointSnapshot, to current: PointSnapshot) {
            wallSeconds += max(0, current.wallSeconds - previous.wallSeconds)
            mediaSeconds += max(0, current.mediaSeconds - previous.mediaSeconds)

            userCPUSeconds += max(0, current.native.userCPUSeconds - previous.native.userCPUSeconds)
            systemCPUSeconds += max(0, current.native.systemCPUSeconds - previous.native.systemCPUSeconds)
            instructions &+= current.native.instructions &- previous.native.instructions
            cycles &+= current.native.cycles &- previous.native.cycles
            interruptWakeups &+= current.native.interruptWakeups &- previous.native.interruptWakeups
            latestPhysFootprintBytes = current.native.physFootprintBytes

            videoDecodedFrames &+= current.native.videoDecodedFrames &- previous.native.videoDecodedFrames
            videoSubmittedFrames &+= current.native.videoSubmittedFrames &- previous.native.videoSubmittedFrames
            videoDecodeMicroseconds &+= current.native.videoDecodeMicroseconds &- previous.native.videoDecodeMicroseconds
            videoPixelTransferMicroseconds &+= current.native.videoPixelTransferMicroseconds &- previous.native.videoPixelTransferMicroseconds
            videoSubmissionMicroseconds &+= current.native.videoSubmissionMicroseconds &- previous.native.videoSubmissionMicroseconds
            videoFormatDescCreateCalls &+= current.native.videoFormatDescCreateCalls &- previous.native.videoFormatDescCreateCalls
            videoWaitIterations &+= current.native.videoWaitIterations &- previous.native.videoWaitIterations

            audioDecodedFrames &+= current.native.audioDecodedFrames &- previous.native.audioDecodedFrames
            audioScheduledBuffers &+= current.native.audioScheduledBuffers &- previous.native.audioScheduledBuffers
            audioCompletionCallbacks &+= current.native.audioCompletionCallbacks &- previous.native.audioCompletionCallbacks
            audioDecodeAndResampleMicroseconds &+= current.native.audioDecodeAndResampleMicroseconds &- previous.native.audioDecodeAndResampleMicroseconds
            audioScheduleMicroseconds &+= current.native.audioScheduleMicroseconds &- previous.native.audioScheduleMicroseconds
            timePitchBypassed = current.native.timePitchBypassed.boolValue

            subtitleTicks &+= current.sub.subtitleTicks &- previous.sub.subtitleTicks
            assWorkerDispatches &+= current.sub.assWorkerDispatches &- previous.sub.assWorkerDispatches
            assRenderFrameCalls &+= current.ass.renderFrameCalls &- previous.ass.renderFrameCalls
            assRenderFrameMicroseconds &+= current.ass.renderFrameMicroseconds &- previous.ass.renderFrameMicroseconds
            assSilentOrUnchangedSkips &+= current.ass.silentOrUnchangedSkips &- previous.ass.silentOrUnchangedSkips
            assCompositeCalls &+= current.ass.compositeCalls &- previous.ass.compositeCalls
            assCompositeMicroseconds &+= current.ass.compositeMicroseconds &- previous.ass.compositeMicroseconds
            assLayerUpdates &+= current.sub.assLayerUpdates &- previous.sub.assLayerUpdates
            srtUpdateCalls &+= current.sub.srtUpdateCalls &- previous.sub.srtUpdateCalls
            srtBitmapRenders &+= current.sub.srtBitmapRenders &- previous.sub.srtBitmapRenders
        }
    }

    private let lock = NSLock()
    private var videoName: String = "unknown"
    private var subtitleFormatDescription: String = "none"
    private var activeGeneration: UInt?
    private var lastWindowSnapshot: PointSnapshot?
    private var windowIndex: Int = 0
    private var accumulatedTotal = AccumulatedDelta()
    private var didLog60SecondSummary = false

    func startPresentation(
        generation: UInt,
        videoURL: URL?,
        subtitleSource: PlaybackSubtitleSource?,
        subtitlesVisible: Bool,
        startMilliseconds: Int,
        playing: Bool,
        nativePlayer: SFXNativePlaybackPlayer
    ) {
        lock.lock()
        defer { lock.unlock() }

        videoName = videoURL?.lastPathComponent ?? (nativePlayer.currentPath as NSString?)?.lastPathComponent ?? "unknown"
        if let subtitleSource {
            let vis = subtitlesVisible ? "on" : "off"
            subtitleFormatDescription = "\(subtitleSource.format.rawValue)(\(vis))"
        } else {
            subtitleFormatDescription = "none"
        }
        activeGeneration = generation
        windowIndex = 0
        accumulatedTotal = AccumulatedDelta()
        didLog60SecondSummary = false

        let initialMediaSeconds = Double(max(0, startMilliseconds)) / 1000.0
        if playing {
            lastWindowSnapshot = takeSnapshot(mediaSeconds: initialMediaSeconds, nativePlayer: nativePlayer)
        } else {
            lastWindowSnapshot = nil
        }

        let decodePipeline = nativePlayer.usingHardwareDecode ? "HW(VideoToolbox)" : "SW(FFmpeg)"
        let codecName = nativePlayer.activeVideoCodecName ?? "unknown"
        let pixFmt = nativePlayer.activeOutputPixelFormatName ?? "unknown"
        let timePitchBypassed = nativePlayer.runtimeTelemetrySnapshot().timePitchBypassed.boolValue ? 1 : 0

        NSLog(
            "[PERF_PLAYBACK_START] gen=%lu video=%@ res=%ldx%ld codec=%@ decode=%@ pixFmt=%@ sub=%@ rate=%.2f timePitchBypass=%d startMs=%ld playing=%d",
            generation,
            videoName,
            nativePlayer.videoWidth,
            nativePlayer.videoHeight,
            codecName,
            decodePipeline,
            pixFmt,
            subtitleFormatDescription,
            nativePlayer.playbackRate,
            timePitchBypassed,
            startMilliseconds,
            playing ? 1 : 0
        )
    }

    func updateSubtitleSource(_ subtitleSource: PlaybackSubtitleSource?, subtitlesVisible: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if let subtitleSource {
            let vis = subtitlesVisible ? "on" : "off"
            subtitleFormatDescription = "\(subtitleSource.format.rawValue)(\(vis))"
        } else {
            subtitleFormatDescription = "none"
        }
    }

    func didUpdateTime(
        mediaSeconds: Double,
        playing: Bool,
        generation: UInt,
        nativePlayer: SFXNativePlaybackPlayer
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard activeGeneration == generation else {
            return
        }

        if !playing {
            flushActiveSegmentAndLogStopIfNeededLocked(
                reason: "pause",
                mediaSeconds: mediaSeconds,
                nativePlayer: nativePlayer
            )
            return
        }

        guard let previous = lastWindowSnapshot else {
            lastWindowSnapshot = takeSnapshot(mediaSeconds: mediaSeconds, nativePlayer: nativePlayer)
            return
        }

        let now = CACurrentMediaTime()
        let windowWallElapsed = now - previous.wallSeconds
        guard windowWallElapsed >= 10.0 else {
            return
        }

        let current = takeSnapshot(mediaSeconds: mediaSeconds, nativePlayer: nativePlayer)
        var windowDelta = AccumulatedDelta()
        windowDelta.add(from: previous, to: current)
        accumulatedTotal.add(from: previous, to: current)
        windowIndex += 1
        lastWindowSnapshot = current

        logDeltaLocked(
            tag: "[PERF_PLAYBACK_WINDOW]",
            headerExtra: String(
                format: "win=#%d totalWall=%.2fs",
                windowIndex,
                accumulatedTotal.wallSeconds
            ),
            delta: windowDelta,
            nativePlayer: nativePlayer
        )

        if !didLog60SecondSummary && accumulatedTotal.wallSeconds >= 59.5 && windowIndex >= 6 {
            didLog60SecondSummary = true
            logDeltaLocked(
                tag: "[PERF_PLAYBACK_60S_SUMMARY]",
                headerExtra: String(format: "windows=%d", windowIndex),
                delta: accumulatedTotal,
                nativePlayer: nativePlayer
            )
        }
    }

    func finishOrStop(reason: String, nativePlayer: SFXNativePlaybackPlayer) {
        lock.lock()
        defer { lock.unlock() }

        flushActiveSegmentAndLogStopIfNeededLocked(
            reason: reason,
            mediaSeconds: nativePlayer.currentTime,
            nativePlayer: nativePlayer
        )
    }

    private func flushActiveSegmentAndLogStopIfNeededLocked(
        reason: String,
        mediaSeconds: Double,
        nativePlayer: SFXNativePlaybackPlayer
    ) {
        if let previous = lastWindowSnapshot {
            let current = takeSnapshot(mediaSeconds: mediaSeconds, nativePlayer: nativePlayer)
            if current.wallSeconds - previous.wallSeconds > 0.05 {
                accumulatedTotal.add(from: previous, to: current)
            }
            lastWindowSnapshot = nil
        } else {
            return
        }

        guard accumulatedTotal.wallSeconds >= 1.0 else {
            return
        }

        logDeltaLocked(
            tag: "[PERF_PLAYBACK_STOP_SUMMARY]",
            headerExtra: String(format: "reason=%@ windows=%d", reason, windowIndex),
            delta: accumulatedTotal,
            nativePlayer: nativePlayer
        )
    }

    private func takeSnapshot(
        mediaSeconds: Double,
        nativePlayer: SFXNativePlaybackPlayer
    ) -> PointSnapshot {
        PointSnapshot(
            wallSeconds: CACurrentMediaTime(),
            mediaSeconds: max(0, mediaSeconds),
            native: nativePlayer.runtimeTelemetrySnapshot(),
            ass: SFXASSRenderer.runtimeTelemetrySnapshot(),
            sub: PlaybackPerformanceProbe.subtitleCountersSnapshot()
        )
    }

    private func logDeltaLocked(
        tag: String,
        headerExtra: String,
        delta: AccumulatedDelta,
        nativePlayer: SFXNativePlaybackPlayer
    ) {
        let wall = max(delta.wallSeconds, 0.0001)
        let totalCPU = delta.userCPUSeconds + delta.systemCPUSeconds
        let cpuPct = (totalCPU / wall) * 100.0
        let userPct = (delta.userCPUSeconds / wall) * 100.0
        let sysPct = (delta.systemCPUSeconds / wall) * 100.0
        let gips = (Double(delta.instructions) / 1_000_000_000.0) / wall
        let gcyclesPerSec = (Double(delta.cycles) / 1_000_000_000.0) / wall
        let wakeupsPerSec = Double(delta.interruptWakeups) / wall
        let memMB = Double(delta.latestPhysFootprintBytes) / (1024.0 * 1024.0)

        let submittedFPS = Double(delta.videoSubmittedFrames) / wall
        let decodedFrames = max(delta.videoDecodedFrames, 1)
        let submittedFrames = max(delta.videoSubmittedFrames, 1)
        let vDecMsPerFrame = (Double(delta.videoDecodeMicroseconds) / 1000.0) / Double(decodedFrames)
        let vXferMsPerFrame = (Double(delta.videoPixelTransferMicroseconds) / 1000.0) / Double(decodedFrames)
        let vSubMsPerFrame = (Double(delta.videoSubmissionMicroseconds) / 1000.0) / Double(submittedFrames)
        let vDecTotalMs = Double(delta.videoDecodeMicroseconds) / 1000.0
        let vXferTotalMs = Double(delta.videoPixelTransferMicroseconds) / 1000.0
        let vSubTotalMs = Double(delta.videoSubmissionMicroseconds) / 1000.0

        let aDecTotalMs = Double(delta.audioDecodeAndResampleMicroseconds) / 1000.0
        let aSchedTotalMs = Double(delta.audioScheduleMicroseconds) / 1000.0

        let subTicksPerSec = Double(delta.subtitleTicks) / wall
        let assRenderTotalMs = Double(delta.assRenderFrameMicroseconds) / 1000.0
        let assCompTotalMs = Double(delta.assCompositeMicroseconds) / 1000.0

        let decodePipeline = nativePlayer.usingHardwareDecode ? "HW" : "SW"
        let pixFmt = nativePlayer.activeOutputPixelFormatName ?? "unknown"

        NSLog(
            "%@ %@ video=%@ decode=%@ pixFmt=%@ sub=%@ rate=%.2f | wall=%.2fs media=%.2fs | CPU=%.2f%% (user=%.2f%% sys=%.2f%% cpuSec=%.3fs) | PMU_inst=%.3fG (%.3fG/s) PMU_cyc=%.3fG (%.3fG/s) wakeups=%llu (%.1f/s) mem=%.1fMB | VIDEO dec=%llu sub=%llu (%.1ffps) fmtDesc=%llu waits=%llu decMs=%.1fms(%.2fms/f) xferMs=%.1fms(%.2fms/f) subMs=%.1fms(%.2fms/f) | AUDIO dec=%llu sched=%llu cb=%llu decResampleMs=%.1fms schedMs=%.1fms tpBypass=%d | SUB ticks=%llu(%.1f/s) assDisp=%llu assRender=%llu(%.1fms) assSkip=%llu assComp=%llu(%.1fms) assLayer=%llu srtUpd=%llu srtBmp=%llu",
            tag,
            headerExtra,
            videoName,
            decodePipeline,
            pixFmt,
            subtitleFormatDescription,
            nativePlayer.playbackRate,
            delta.wallSeconds,
            delta.mediaSeconds,
            cpuPct,
            userPct,
            sysPct,
            totalCPU,
            Double(delta.instructions) / 1_000_000_000.0,
            gips,
            Double(delta.cycles) / 1_000_000_000.0,
            gcyclesPerSec,
            delta.interruptWakeups,
            wakeupsPerSec,
            memMB,
            delta.videoDecodedFrames,
            delta.videoSubmittedFrames,
            submittedFPS,
            delta.videoFormatDescCreateCalls,
            delta.videoWaitIterations,
            vDecTotalMs,
            vDecMsPerFrame,
            vXferTotalMs,
            vXferMsPerFrame,
            vSubTotalMs,
            vSubMsPerFrame,
            delta.audioDecodedFrames,
            delta.audioScheduledBuffers,
            delta.audioCompletionCallbacks,
            aDecTotalMs,
            aSchedTotalMs,
            delta.timePitchBypassed ? 1 : 0,
            delta.subtitleTicks,
            subTicksPerSec,
            delta.assWorkerDispatches,
            delta.assRenderFrameCalls,
            assRenderTotalMs,
            delta.assSilentOrUnchangedSkips,
            delta.assCompositeCalls,
            assCompTotalMs,
            delta.assLayerUpdates,
            delta.srtUpdateCalls,
            delta.srtBitmapRenders
        )
    }
}

