import AppKit
import CueSeekerCore
import Darwin
import Foundation

struct LibraryCoverPrewarmStats: Equatable, Sendable {
    static let zero = LibraryCoverPrewarmStats(
        totalCount: 0,
        cacheHitCount: 0,
        decodedCount: 0,
        elapsedMilliseconds: 0
    )

    let totalCount: Int
    let cacheHitCount: Int
    let decodedCount: Int
    let elapsedMilliseconds: Double
}

enum DebugInteractionLatencyProbe {
    static let slowMenuThresholdMilliseconds: Double = 100
    static let mainThreadStallThresholdMilliseconds: Double = 200

    struct LoggedEvent: Equatable, Sendable {
        let level: AppLogLevel
        let domain: AppLogCategory
        let message: String
        let fields: [String: String]

        init(
            level: AppLogLevel = .debug,
            domain: AppLogCategory,
            message: String,
            fields: [String: String]
        ) {
            self.level = level
            self.domain = domain
            self.message = message
            self.fields = fields
        }
    }

    private struct PendingNavigationSession {
        let id: UUID
        let fromSurface: String
        var toSurface: String
        let trigger: String
        let startedAt: UInt64
        let startFootprintBytes: UInt64
        var syncPrepMilliseconds: Double?
        var dataReadyMilliseconds: Double?
        var coverStats: LibraryCoverPrewarmStats = .zero
        var containerWaitMilliseconds: Double?
    }

    private struct PendingMenuOpenSession {
        let id: UUID
        var menuID: String
        var owner: String
        var kind: String
        var trigger: String
        let startedAt: UInt64
        var measureStartedAt: UInt64?
        var measureAccumulatedNanoseconds: UInt64 = 0
        var measurePasses: Int = 0
        var prepAndMeasureMilliseconds: Double?
    }

    private struct PendingDialogOpenSession {
        let dialogID: String
        let trigger: String
        let startedAt: UInt64
        let startFootprintBytes: UInt64
        var syncPrepMilliseconds: Double
        var firstFrameMilliseconds: Double?
        var animationStartedAt: UInt64?
        var lastFrameTimestamp: UInt64?
        var animationFrameCount: Int = 0
        var maxFrameGapMilliseconds: Double = 0
        var didComplete: Bool = false
    }

    private struct PendingDialogTransitionSession {
        let id: UUID
        let dialogID: String
        let transition: String
        let trigger: String
        let startedAt: UInt64
        var syncPrepMilliseconds: Double = 0
        var asyncLoadMilliseconds: Double = 0
    }

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var pendingNavigationsByDomain: [String: PendingNavigationSession] = [:]
        var activeMenuContext: (
            menuID: String,
            trigger: String,
            kind: String,
            startedAt: UInt64,
            measureMilliseconds: Double
        )?
        var pendingMenuSessionsByOwner: [String: PendingMenuOpenSession] = [:]
        var inFlightMenuOpenOwners: Set<String> = []
        var lastOpenedMenuIDByOwner: [String: String] = [:]
        var pendingDialogOpens: [String: PendingDialogOpenSession] = [:]
        var pendingDialogTransitions: [UUID: PendingDialogTransitionSession] = [:]
        var peakFootprintBytes: UInt64 = 0
        var buildConfigurationOverrideForTesting: AppBuildConfiguration?
        var onEventLoggedForTesting: (@Sendable (LoggedEvent) -> Void)?
    }

    private static let state = State()

    private static var effectiveBuildConfiguration: AppBuildConfiguration {
        state.lock.lock()
        let override = state.buildConfigurationOverrideForTesting
        state.lock.unlock()
        return override ?? AppBuildConfiguration.current
    }

    static var isEnabled: Bool {
        AppLogger.isDiagnosticTelemetryEnabled(
            for: effectiveBuildConfiguration,
            mode: AppDiagnosticTelemetryCollectionMode.current
        )
    }

    static func normalizedDialogID(_ rawDialogID: String) -> String {
        let trimmed = rawDialogID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let colonIndex = trimmed.firstIndex(of: ":") {
            let prefix = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty {
                return prefix
            }
        }
        if UUID(uuidString: trimmed) != nil {
            return "dialog"
        }
        return trimmed.isEmpty ? "dialog" : trimmed
    }

    static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    static func elapsedMilliseconds(since start: UInt64, now end: UInt64 = now()) -> Double {
        guard end >= start else { return 0 }
        return Double(end - start) / 1_000_000
    }

    static func formatMilliseconds(_ value: Double) -> String {
        String(format: "%.2f", max(0, value))
    }

    static func formatMegabytes(_ value: Double) -> String {
        String(format: "%.2f", max(0, value))
    }

    static func formatSignedMegabytes(_ value: Double) -> String {
        let normalized = abs(value) < 0.005 ? 0 : value
        return String(format: "%+.2f", normalized)
    }

    private static func currentPhysicalFootprintBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return 0
        }
        return UInt64(info.phys_footprint)
    }

    private static func sampleMemoryFootprintBytes() -> UInt64 {
        let footprint = currentPhysicalFootprintBytes()
        state.lock.lock()
        if footprint > state.peakFootprintBytes {
            state.peakFootprintBytes = footprint
        }
        state.lock.unlock()
        return footprint
    }

    private static func memoryTelemetryFields(
        startFootprintBytes: UInt64
    ) -> [(String, String)] {
        let currentFootprintBytes = currentPhysicalFootprintBytes()
        state.lock.lock()
        let peakFootprintBytes = max(
            state.peakFootprintBytes,
            max(startFootprintBytes, currentFootprintBytes)
        )
        state.peakFootprintBytes = peakFootprintBytes
        state.lock.unlock()

        let (coverCostBytes, coverCount) = LibraryCoverImagePipeline.shared.memoryCacheUsageSnapshot
        let bytesPerMegabyte = Double(1_024 * 1_024)
        let memoryMB = Double(currentFootprintBytes) / bytesPerMegabyte
        let deltaBytes = Int64(bitPattern: currentFootprintBytes) - Int64(bitPattern: startFootprintBytes)
        let deltaMB = Double(deltaBytes) / bytesPerMegabyte
        let peakMB = Double(peakFootprintBytes) / bytesPerMegabyte
        let coverCacheMB = Double(max(0, coverCostBytes)) / bytesPerMegabyte

        return [
            ("memory_mb", formatMegabytes(memoryMB)),
            ("memory_delta_mb", formatSignedMegabytes(deltaMB)),
            ("peak_memory_mb", formatMegabytes(peakMB)),
            ("cover_cache_mb", formatMegabytes(coverCacheMB)),
            ("cover_cache_count", "\(max(0, coverCount))")
        ]
    }

    static func setTestObserver(_ observer: (@Sendable (LoggedEvent) -> Void)?) {
        state.lock.lock()
        state.onEventLoggedForTesting = observer
        state.lock.unlock()
    }

    static func setBuildConfigurationForTesting(_ configuration: AppBuildConfiguration?) {
        state.lock.lock()
        state.buildConfigurationOverrideForTesting = configuration
        state.lock.unlock()
    }

    static func resetForTesting() {
        state.lock.lock()
        state.pendingNavigationsByDomain.removeAll()
        state.activeMenuContext = nil
        state.pendingMenuSessionsByOwner.removeAll()
        state.inFlightMenuOpenOwners.removeAll()
        state.lastOpenedMenuIDByOwner.removeAll()
        state.pendingDialogOpens.removeAll()
        state.pendingDialogTransitions.removeAll()
        state.peakFootprintBytes = 0
        state.buildConfigurationOverrideForTesting = nil
        state.onEventLoggedForTesting = nil
        state.lock.unlock()
    }

    // MARK: - Category 1: Page / View Navigation & Transitions

    static func beginNavigation(
        domain: String = "workbench",
        from fromSurface: String,
        to toSurface: String,
        trigger: String,
        startedAt: UInt64 = now()
    ) {
        guard isEnabled else { return }
        AppPerformanceProbe.breadcrumb("nav:\(domain):\(trigger):\(fromSurface)->\(toSurface)")
        let startFootprintBytes = sampleMemoryFootprintBytes()
        let session = PendingNavigationSession(
            id: UUID(),
            fromSurface: fromSurface,
            toSurface: toSurface,
            trigger: trigger,
            startedAt: startedAt,
            startFootprintBytes: startFootprintBytes
        )
        state.lock.lock()
        state.pendingNavigationsByDomain[domain] = session
        state.lock.unlock()
    }

    static func markNavigationSyncPrepFinished(
        domain: String = "workbench",
        to toSurface: String? = nil,
        at timestamp: UInt64 = now()
    ) {
        guard isEnabled else { return }
        state.lock.lock()
        if var session = state.pendingNavigationsByDomain[domain] {
            if let toSurface {
                session.toSurface = toSurface
            }
            if session.syncPrepMilliseconds == nil {
                session.syncPrepMilliseconds = elapsedMilliseconds(since: session.startedAt, now: timestamp)
            }
            state.pendingNavigationsByDomain[domain] = session
        }
        state.lock.unlock()
    }

    static func hasPendingNavigation(domain: String = "workbench") -> Bool {
        guard isEnabled else { return false }
        state.lock.lock()
        let hasPending = state.pendingNavigationsByDomain[domain] != nil
        state.lock.unlock()
        return hasPending
    }

    static func cancelPendingNavigation(domain: String = "workbench") {
        guard isEnabled else { return }
        state.lock.lock()
        state.pendingNavigationsByDomain.removeValue(forKey: domain)
        state.lock.unlock()
    }

    static func recordNavigationPreparation(
        domain: String = "workbench",
        from fallbackFromSurface: String,
        to toSurface: String,
        fallbackTrigger: String = "state_change",
        preparationStartedAt: UInt64,
        dataReadyAt: UInt64,
        coverStats: LibraryCoverPrewarmStats,
        containerSwapAt: UInt64 = now()
    ) {
        guard isEnabled else { return }
        let fallbackFootprintBytes = sampleMemoryFootprintBytes()
        state.lock.lock()
        var session = state.pendingNavigationsByDomain[domain]
        if session == nil {
            session = PendingNavigationSession(
                id: UUID(),
                fromSurface: fallbackFromSurface,
                toSurface: toSurface,
                trigger: fallbackTrigger,
                startedAt: preparationStartedAt,
                startFootprintBytes: fallbackFootprintBytes
            )
        }
        guard var activeSession = session else {
            state.lock.unlock()
            return
        }
        activeSession.toSurface = toSurface
        if activeSession.syncPrepMilliseconds == nil {
            activeSession.syncPrepMilliseconds = elapsedMilliseconds(
                since: activeSession.startedAt,
                now: preparationStartedAt
            )
        }
        activeSession.dataReadyMilliseconds = elapsedMilliseconds(
            since: activeSession.startedAt,
            now: dataReadyAt
        )
        activeSession.coverStats = coverStats
        activeSession.containerWaitMilliseconds = elapsedMilliseconds(
            since: activeSession.startedAt,
            now: containerSwapAt
        )
        let sessionID = activeSession.id
        state.pendingNavigationsByDomain[domain] = activeSession
        state.lock.unlock()

        DispatchQueue.main.async {
            completeNavigationOnNextFrame(domain: domain, sessionID: sessionID)
        }
    }

    static func completeImmediateNavigation(
        domain: String = "workbench",
        from fromSurface: String,
        to toSurface: String,
        trigger: String,
        startedAt: UInt64? = nil,
        syncPrepFinishedAt: UInt64 = now(),
        dataReadyAt: UInt64? = nil,
        coverStats: LibraryCoverPrewarmStats = .zero
    ) {
        guard isEnabled else { return }
        state.lock.lock()
        let existing = state.pendingNavigationsByDomain.removeValue(forKey: domain)
        state.lock.unlock()

        let matchingExisting = existing?.toSurface == toSurface ? existing : nil
        let effectiveStart = startedAt ?? matchingExisting?.startedAt ?? syncPrepFinishedAt
        let startFootprintBytes = matchingExisting?.startFootprintBytes ?? sampleMemoryFootprintBytes()
        let effectiveFrom = matchingExisting?.fromSurface ?? fromSurface
        let effectiveTrigger = matchingExisting?.trigger ?? trigger
        let syncPrepMs = matchingExisting?.syncPrepMilliseconds
            ?? elapsedMilliseconds(since: effectiveStart, now: syncPrepFinishedAt)
        let effectiveDataReadyAt = dataReadyAt ?? syncPrepFinishedAt
        let dataReadyMs = elapsedMilliseconds(since: effectiveStart, now: effectiveDataReadyAt)
        let containerWaitMs = elapsedMilliseconds(since: effectiveStart, now: syncPrepFinishedAt)

        AppPerformanceProbe.breadcrumb("nav:\(domain):\(effectiveTrigger):\(effectiveFrom)->\(toSurface)")

        DispatchQueue.main.async {
            let finishTime = now()
            let firstFrameMs = elapsedMilliseconds(since: effectiveStart, now: finishTime)
            var fields: [(String, String)] = [
                ("domain", domain),
                ("from", effectiveFrom),
                ("to", toSurface),
                ("trigger", effectiveTrigger),
                ("sync_prep_ms", formatMilliseconds(syncPrepMs)),
                ("data_ready_ms", formatMilliseconds(dataReadyMs)),
                ("cover_prewarm_ms", formatMilliseconds(coverStats.elapsedMilliseconds)),
                ("cover_total", "\(coverStats.totalCount)"),
                ("cover_hit", "\(coverStats.cacheHitCount)"),
                ("cover_decoded", "\(coverStats.decodedCount)"),
                ("container_wait_ms", formatMilliseconds(containerWaitMs)),
                ("first_frame_ms", formatMilliseconds(firstFrameMs)),
                ("total_ms", formatMilliseconds(firstFrameMs))
            ]
            fields.append(contentsOf: memoryTelemetryFields(startFootprintBytes: startFootprintBytes))
            emit(
                domain: logDomain(forNavigationDomain: domain),
                message: navigationMessage(forNavigationDomain: domain),
                fields: fields
            )
        }
    }

    private static func completeNavigationOnNextFrame(domain: String, sessionID: UUID) {
        state.lock.lock()
        guard let session = state.pendingNavigationsByDomain[domain],
              session.id == sessionID
        else {
            state.lock.unlock()
            return
        }
        state.pendingNavigationsByDomain.removeValue(forKey: domain)
        state.lock.unlock()

        let finishTime = now()
        let firstFrameMs = elapsedMilliseconds(since: session.startedAt, now: finishTime)
        let syncPrepMs = session.syncPrepMilliseconds ?? 0
        let dataReadyMs = session.dataReadyMilliseconds ?? syncPrepMs
        let containerWaitMs = session.containerWaitMilliseconds ?? dataReadyMs
        let coverStats = session.coverStats

        var fields: [(String, String)] = [
            ("domain", domain),
            ("from", session.fromSurface),
            ("to", session.toSurface),
            ("trigger", session.trigger),
            ("sync_prep_ms", formatMilliseconds(syncPrepMs)),
            ("data_ready_ms", formatMilliseconds(dataReadyMs)),
            ("cover_prewarm_ms", formatMilliseconds(coverStats.elapsedMilliseconds)),
            ("cover_total", "\(coverStats.totalCount)"),
            ("cover_hit", "\(coverStats.cacheHitCount)"),
            ("cover_decoded", "\(coverStats.decodedCount)"),
            ("container_wait_ms", formatMilliseconds(containerWaitMs)),
            ("first_frame_ms", formatMilliseconds(firstFrameMs)),
            ("total_ms", formatMilliseconds(firstFrameMs))
        ]
        fields.append(contentsOf: memoryTelemetryFields(startFootprintBytes: session.startFootprintBytes))
        emit(
            domain: logDomain(forNavigationDomain: domain),
            message: navigationMessage(forNavigationDomain: domain),
            fields: fields
        )
    }

    private static func logDomain(forNavigationDomain domain: String) -> AppLogCategory {
        switch domain {
        case "playback", "playback_overlay", "command_panel":
            return .playback
        default:
            return .system
        }
    }

    private static func navigationMessage(forNavigationDomain domain: String) -> String {
        switch domain {
        case "playback":
            return "Playback transition completed"
        case "playback_overlay":
            return "Overlay module transition completed"
        case "command_panel":
            return "Command panel page transition completed"
        case "settings":
            return "Settings navigation completed"
        default:
            return "Workbench navigation completed"
        }
    }

    // MARK: - Category 2: Popup Menus, Submenus & Popovers

    static func markMenuTriggerContext(
        menuID: String,
        trigger: String,
        kind: String = "floating_menu",
        startedAt: UInt64 = now(),
        measureMilliseconds: Double = 0
    ) {
        AppPerformanceProbe.breadcrumb("menu:\(menuID):\(trigger)")
        state.lock.lock()
        if let existing = state.activeMenuContext, existing.menuID == menuID {
            state.activeMenuContext = (
                menuID: menuID,
                trigger: existing.trigger,
                kind: kind,
                startedAt: min(existing.startedAt, startedAt),
                measureMilliseconds: max(existing.measureMilliseconds, measureMilliseconds)
            )
        } else {
            state.activeMenuContext = (
                menuID: menuID,
                trigger: trigger,
                kind: kind,
                startedAt: startedAt,
                measureMilliseconds: measureMilliseconds
            )
        }
        state.lock.unlock()
    }

    static func clearActiveMenuContext(menuID: String? = nil) {
        state.lock.lock()
        if let menuID {
            if state.activeMenuContext?.menuID == menuID {
                state.activeMenuContext = nil
            }
        } else {
            state.activeMenuContext = nil
        }
        state.lock.unlock()
    }

    static func markMenuTriggerContext(
        menuID: String,
        trigger: String,
        kind: String = "floating_menu",
        startedAt: TimeInterval,
        measureMs: Double
    ) {
        let elapsedSeconds = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
        let currentNanoseconds = now()
        let elapsedNanoseconds = UInt64(elapsedSeconds * 1_000_000_000)
        let startNanoseconds = currentNanoseconds >= elapsedNanoseconds
            ? currentNanoseconds - elapsedNanoseconds
            : 0
        markMenuTriggerContext(
            menuID: menuID,
            trigger: trigger,
            kind: kind,
            startedAt: startNanoseconds,
            measureMilliseconds: measureMs
        )
    }

    static func recordLayoutMeasurementPass(durationNanoseconds: UInt64) {
        state.lock.lock()
        defer { state.lock.unlock() }
        for key in state.pendingMenuSessionsByOwner.keys {
            if var session = state.pendingMenuSessionsByOwner[key] {
                session.measureAccumulatedNanoseconds &+= durationNanoseconds
                session.measurePasses += 1
                state.pendingMenuSessionsByOwner[key] = session
            }
        }
    }

    static func recordMenuGateOpen(
        kind: String,
        owner: String
    ) {
        recordMenuGateOpen(
            owner: owner,
            fallbackMenuID: kind,
            fallbackKind: kind,
            fallbackTrigger: "open"
        )
    }

    static func recordMenuGateOpen(
        owner: String,
        fallbackMenuID: String? = nil,
        fallbackKind: String = "floating_menu",
        fallbackTrigger: String = "open",
        measureMilliseconds: Double = 0,
        measurePasses: Int = 1,
        openedAt: UInt64 = now()
    ) {
        let inFlightKey = "\(owner):\(fallbackMenuID ?? owner)"
        state.lock.lock()
        if state.inFlightMenuOpenOwners.contains(inFlightKey) {
            state.lock.unlock()
            return
        }
        state.inFlightMenuOpenOwners.insert(inFlightKey)
        let context = state.activeMenuContext
        state.activeMenuContext = nil
        let existing = state.pendingMenuSessionsByOwner.removeValue(forKey: owner)

        let startedAt = existing?.startedAt ?? context?.startedAt ?? openedAt
        let menuID = existing?.menuID ?? context?.menuID ?? fallbackMenuID ?? owner
        let kind = existing?.kind ?? context?.kind ?? fallbackKind
        let trigger = existing?.trigger ?? context?.trigger ?? fallbackTrigger
        let prepAndMeasureMs = max(
            max(measureMilliseconds, context?.measureMilliseconds ?? 0),
            elapsedMilliseconds(since: startedAt, now: openedAt)
        )
        let totalPasses = max(measurePasses, existing?.measurePasses ?? 1)
        state.lastOpenedMenuIDByOwner[owner] = menuID
        state.lock.unlock()

        AppPerformanceProbe.breadcrumb("menu:\(menuID):\(trigger)")

        DispatchQueue.main.async {
            state.lock.lock()
            state.inFlightMenuOpenOwners.remove(inFlightKey)
            state.lock.unlock()

            let firstFrameAt = now()
            let firstFrameMs = elapsedMilliseconds(since: startedAt, now: firstFrameAt)
            let isSlowMenu = firstFrameMs >= slowMenuThresholdMilliseconds
            guard isSlowMenu || effectiveBuildConfiguration == .debug else {
                return
            }
            var fields: [(String, String)] = [
                ("menu_id", menuID),
                ("owner", owner),
                ("kind", kind),
                ("trigger", trigger),
                ("prep_and_measure_ms", formatMilliseconds(prepAndMeasureMs)),
                ("measure_passes", "\(totalPasses)"),
                ("first_frame_ms", formatMilliseconds(firstFrameMs)),
                ("total_ms", formatMilliseconds(firstFrameMs))
            ]
            if isSlowMenu {
                fields.append(("slow_menu", "true"))
            }
            emit(
                level: isSlowMenu ? .warn : .debug,
                domain: .system,
                message: "Menu open completed",
                fields: fields
            )
        }
    }

    static func recordPopoverOpen(
        menuID: String,
        owner: String = "popover",
        trigger: String = "button_click",
        startedAt: UInt64,
        prepFinishedAt: UInt64 = now()
    ) {
        AppPerformanceProbe.breadcrumb("popover:\(menuID):\(trigger)")
        let prepMs = elapsedMilliseconds(since: startedAt, now: prepFinishedAt)
        DispatchQueue.main.async {
            let firstFrameAt = now()
            let firstFrameMs = elapsedMilliseconds(since: startedAt, now: firstFrameAt)
            let isSlowMenu = firstFrameMs >= slowMenuThresholdMilliseconds
            guard isSlowMenu || effectiveBuildConfiguration == .debug else {
                return
            }
            var fields: [(String, String)] = [
                ("menu_id", menuID),
                ("owner", owner),
                ("kind", "popover"),
                ("trigger", trigger),
                ("prep_and_measure_ms", formatMilliseconds(prepMs)),
                ("measure_passes", "1"),
                ("first_frame_ms", formatMilliseconds(firstFrameMs)),
                ("total_ms", formatMilliseconds(firstFrameMs))
            ]
            if isSlowMenu {
                fields.append(("slow_menu", "true"))
            }
            emit(
                level: isSlowMenu ? .warn : .debug,
                domain: .system,
                message: "Menu open completed",
                fields: fields
            )
        }
    }

    static func recordPopoverOpen(
        menuID: String,
        owner: String = "popover",
        trigger: String = "button_click",
        startedAt: TimeInterval
    ) {
        let elapsedSeconds = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
        let currentNanoseconds = now()
        let elapsedNanoseconds = UInt64(elapsedSeconds * 1_000_000_000)
        let startNanoseconds = currentNanoseconds >= elapsedNanoseconds
            ? currentNanoseconds - elapsedNanoseconds
            : 0
        recordPopoverOpen(
            menuID: menuID,
            owner: owner,
            trigger: trigger,
            startedAt: startNanoseconds,
            prepFinishedAt: currentNanoseconds
        )
    }

    static func recordMenuItemAction(
        menuID: String,
        item: String,
        startedAt: UInt64,
        finishedAt: UInt64 = now()
    ) {
        AppPerformanceProbe.breadcrumb("menu_action:\(menuID):\(item)")
        let elapsedMs = elapsedMilliseconds(since: startedAt, now: finishedAt)
        let isSlowMenu = elapsedMs >= slowMenuThresholdMilliseconds
        guard isSlowMenu || effectiveBuildConfiguration == .debug else {
            return
        }
        var fields: [(String, String)] = [
            ("menu_id", menuID),
            ("item", item),
            ("elapsed_ms", formatMilliseconds(elapsedMs))
        ]
        if isSlowMenu {
            fields.append(("slow_menu", "true"))
        }
        emit(
            level: isSlowMenu ? .warn : .debug,
            domain: .system,
            message: "Menu item action executed",
            fields: fields
        )
    }

    static func measureMenuItemAction<T>(
        menuID: String,
        item: String,
        _ action: () throws -> T
    ) rethrows -> T {
        let start = now()
        defer {
            recordMenuItemAction(menuID: menuID, item: item, startedAt: start, finishedAt: now())
        }
        return try action()
    }

    // MARK: - Category 3: In-Window Dialogs, Internal Transitions & System File Panels

    static func beginDialogOpen(
        dialogID: String,
        trigger: String,
        startedAt: UInt64 = now(),
        syncPrepFinishedAt: UInt64? = nil,
        hasEntranceAnimation: Bool = true
    ) {
        guard isEnabled else { return }
        let normalizedID = normalizedDialogID(dialogID)
        AppPerformanceProbe.breadcrumb("dialog:\(normalizedID):\(trigger)")
        let startFootprintBytes = sampleMemoryFootprintBytes()
        let prepEnd = syncPrepFinishedAt ?? now()
        let syncPrepMs = elapsedMilliseconds(since: startedAt, now: prepEnd)
        let session = PendingDialogOpenSession(
            dialogID: normalizedID,
            trigger: trigger,
            startedAt: startedAt,
            startFootprintBytes: startFootprintBytes,
            syncPrepMilliseconds: syncPrepMs
        )
        state.lock.lock()
        state.pendingDialogOpens[normalizedID] = session
        state.lock.unlock()

        DispatchQueue.main.async {
            markDialogFirstFrame(dialogID: normalizedID, hasEntranceAnimation: hasEntranceAnimation)
        }
    }

    static func beginDialogOpenIfNeeded(
        dialogID: String,
        trigger: String = "dialog_layer"
    ) {
        guard isEnabled else { return }
        state.lock.lock()
        let hasPending = !state.pendingDialogOpens.isEmpty
        state.lock.unlock()
        guard !hasPending else { return }
        beginDialogOpen(dialogID: normalizedDialogID(dialogID), trigger: trigger)
    }

    static func recordDialogAnimationFrame(
        dialogID: String? = nil,
        progress: CGFloat,
        isEntering: Bool = true
    ) {
        guard isEnabled, isEntering else { return }
        let timestamp = now()
        var completedIDs: [String] = []
        state.lock.lock()
        let targetKeys: [String]
        if let dialogID {
            targetKeys = [normalizedDialogID(dialogID)]
        } else {
            targetKeys = Array(state.pendingDialogOpens.keys)
        }
        for key in targetKeys {
            if var session = state.pendingDialogOpens[key], !session.didComplete {
                if session.firstFrameMilliseconds == nil {
                    session.firstFrameMilliseconds = elapsedMilliseconds(since: session.startedAt, now: timestamp)
                    session.animationStartedAt = timestamp
                }
                if let lastFrame = session.lastFrameTimestamp {
                    let gapMs = elapsedMilliseconds(since: lastFrame, now: timestamp)
                    if gapMs > session.maxFrameGapMilliseconds {
                        session.maxFrameGapMilliseconds = gapMs
                    }
                }
                session.lastFrameTimestamp = timestamp
                session.animationFrameCount += 1
                if progress >= 0.999 {
                    session.didComplete = true
                    completedIDs.append(key)
                }
                state.pendingDialogOpens[key] = session
            }
        }
        state.lock.unlock()

        for id in completedIDs {
            completeDialogOpenIfNeeded(dialogID: id, animationDurationMilliseconds: 270)
        }
    }

    private static func markDialogFirstFrame(dialogID: String, hasEntranceAnimation: Bool) {
        let timestamp = now()
        state.lock.lock()
        guard var session = state.pendingDialogOpens[dialogID] else {
            state.lock.unlock()
            return
        }
        if session.firstFrameMilliseconds == nil {
            session.firstFrameMilliseconds = elapsedMilliseconds(since: session.startedAt, now: timestamp)
            session.animationStartedAt = timestamp
            session.lastFrameTimestamp = timestamp
        }
        state.pendingDialogOpens[dialogID] = session
        state.lock.unlock()

        if !hasEntranceAnimation {
            completeDialogOpenIfNeeded(dialogID: dialogID, animationDurationMilliseconds: 0)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(310)) {
                completeDialogOpenIfNeeded(dialogID: dialogID, animationDurationMilliseconds: 270)
            }
        }
    }

    private static func completeDialogOpenIfNeeded(
        dialogID: String,
        animationDurationMilliseconds: Double
    ) {
        state.lock.lock()
        guard let session = state.pendingDialogOpens.removeValue(forKey: dialogID) else {
            state.lock.unlock()
            return
        }
        state.lock.unlock()

        let finishAt = now()
        let firstFrameMs = session.firstFrameMilliseconds
            ?? elapsedMilliseconds(since: session.startedAt, now: finishAt)
        let totalMs = elapsedMilliseconds(since: session.startedAt, now: finishAt)
        var fields: [(String, String)] = [
            ("dialog_id", session.dialogID),
            ("trigger", session.trigger),
            ("sync_prep_ms", formatMilliseconds(session.syncPrepMilliseconds)),
            ("first_frame_ms", formatMilliseconds(firstFrameMs)),
            ("anim_duration_ms", formatMilliseconds(animationDurationMilliseconds)),
            ("anim_frames", "\(session.animationFrameCount)"),
            ("max_frame_gap_ms", formatMilliseconds(session.maxFrameGapMilliseconds)),
            ("total_ms", formatMilliseconds(totalMs))
        ]
        fields.append(contentsOf: memoryTelemetryFields(startFootprintBytes: session.startFootprintBytes))
        emit(
            domain: .system,
            message: "Dialog open completed",
            fields: fields
        )
    }

    static func recordDialogInternalTransition(
        dialogID: String,
        transition: String,
        trigger: String,
        startedAt: UInt64,
        syncPrepFinishedAt: UInt64? = nil,
        asyncLoadFinishedAt: UInt64? = nil
    ) {
        guard isEnabled else { return }
        let normalizedID = normalizedDialogID(dialogID)
        AppPerformanceProbe.breadcrumb("dialog_step:\(normalizedID):\(transition)")
        let startFootprintBytes = sampleMemoryFootprintBytes()
        let syncEnd = syncPrepFinishedAt ?? asyncLoadFinishedAt ?? now()
        let asyncEnd = asyncLoadFinishedAt ?? syncEnd
        let syncPrepMs = elapsedMilliseconds(since: startedAt, now: syncEnd)
        let asyncLoadMs = elapsedMilliseconds(since: syncEnd, now: asyncEnd)

        DispatchQueue.main.async {
            let firstFrameAt = now()
            let firstFrameMs = elapsedMilliseconds(since: startedAt, now: firstFrameAt)
            var fields: [(String, String)] = [
                ("dialog_id", normalizedID),
                ("transition", transition),
                ("trigger", trigger),
                ("sync_prep_ms", formatMilliseconds(syncPrepMs)),
                ("async_load_ms", formatMilliseconds(asyncLoadMs)),
                ("first_frame_ms", formatMilliseconds(firstFrameMs)),
                ("total_ms", formatMilliseconds(firstFrameMs))
            ]
            fields.append(contentsOf: memoryTelemetryFields(startFootprintBytes: startFootprintBytes))
            emit(
                domain: .system,
                message: "Dialog internal transition completed",
                fields: fields
            )
        }
    }

    static func recordDialogInternalTransition(
        dialogID: String,
        action: String,
        startedAt: TimeInterval,
        itemCount: Int? = nil
    ) {
        let elapsedSeconds = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
        let currentNanoseconds = now()
        let elapsedNanoseconds = UInt64(elapsedSeconds * 1_000_000_000)
        let startNanoseconds = currentNanoseconds >= elapsedNanoseconds
            ? currentNanoseconds - elapsedNanoseconds
            : 0
        let trigger = itemCount.map { "items_\($0)" } ?? "user_action"
        recordDialogInternalTransition(
            dialogID: dialogID,
            transition: action,
            trigger: trigger,
            startedAt: startNanoseconds,
            syncPrepFinishedAt: currentNanoseconds
        )
    }

    static func recordSystemFilePanel(
        panelType: String,
        trigger: String,
        mode: String,
        startedAt: UInt64,
        panelPresentedAt: UInt64,
        completedAt: UInt64 = now(),
        didSelect: Bool
    ) {
        guard isEnabled else { return }
        AppPerformanceProbe.breadcrumb("file_panel:\(panelType):\(trigger)")
        let panelOpenMs = elapsedMilliseconds(since: startedAt, now: panelPresentedAt)
        let userSelectionMs = elapsedMilliseconds(since: panelPresentedAt, now: completedAt)
        emit(
            domain: .system,
            message: "System file panel completed",
            fields: [
                ("panel_type", panelType),
                ("trigger", trigger),
                ("mode", mode),
                ("panel_open_ms", formatMilliseconds(panelOpenMs)),
                ("user_selection_ms", formatMilliseconds(userSelectionMs)),
                ("result", didSelect ? "selected" : "cancelled")
            ]
        )
    }

    // MARK: - Category 4: Main Thread Stall Monitoring (>= 200ms)

    static func recordMainThreadStall(
        stalledMilliseconds: Double,
        phase: String,
        lastAction: String,
        lastActionAgeMilliseconds: Double?
    ) {
        guard stalledMilliseconds >= mainThreadStallThresholdMilliseconds,
              !phase.hasPrefix("beforeWaiting->"),
              phase != "exit->entry"
        else {
            return
        }
        let ageText = lastActionAgeMilliseconds.map { formatMilliseconds($0) } ?? "none"
        emit(
            level: .warn,
            domain: .system,
            message: "Main thread stall detected",
            fields: [
                ("stalled_ms", formatMilliseconds(stalledMilliseconds)),
                ("phase", phase),
                ("last_action", lastAction),
                ("last_action_age_ms", ageText)
            ]
        )
    }

    private static func emit(
        level: AppLogLevel = .debug,
        domain: AppLogCategory,
        message: String,
        fields: [(String, String)]
    ) {
        AppLogger.shared.log(
            level: level,
            category: domain,
            message: message,
            details: AppLogger.formatFields(fields.map { ($0.0, Optional($0.1)) })
        )
        state.lock.lock()
        let observer = state.onEventLoggedForTesting
        state.lock.unlock()
        if let observer {
            var dictionary: [String: String] = [:]
            for (key, value) in fields {
                dictionary[key] = value
            }
            observer(LoggedEvent(level: level, domain: domain, message: message, fields: dictionary))
        }
    }
}
