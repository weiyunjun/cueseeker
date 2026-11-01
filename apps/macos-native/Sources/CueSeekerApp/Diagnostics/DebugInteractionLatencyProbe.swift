import AppKit
import CueSeekerCore
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
    struct LoggedEvent: Equatable, Sendable {
        let domain: AppLogCategory
        let message: String
        let fields: [String: String]
    }

    #if DEBUG
    private struct PendingNavigationSession {
        let id: UUID
        let fromSurface: String
        var toSurface: String
        let trigger: String
        let startedAt: UInt64
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
        var lastOpenedMenuIDByOwner: [String: String] = [:]
        var pendingDialogOpens: [String: PendingDialogOpenSession] = [:]
        var pendingDialogTransitions: [UUID: PendingDialogTransitionSession] = [:]
        var onEventLoggedForTesting: (@Sendable (LoggedEvent) -> Void)?
    }

    private static let state = State()
    #endif

    static var isEnabled: Bool {
        #if DEBUG
        return AppBuildConfiguration.current == .debug
        #else
        return false
        #endif
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

    #if DEBUG
    static func setTestObserver(_ observer: (@Sendable (LoggedEvent) -> Void)?) {
        state.lock.lock()
        state.onEventLoggedForTesting = observer
        state.lock.unlock()
    }

    static func resetForTesting() {
        state.lock.lock()
        state.pendingNavigationsByDomain.removeAll()
        state.activeMenuContext = nil
        state.pendingMenuSessionsByOwner.removeAll()
        state.lastOpenedMenuIDByOwner.removeAll()
        state.pendingDialogOpens.removeAll()
        state.pendingDialogTransitions.removeAll()
        state.onEventLoggedForTesting = nil
        state.lock.unlock()
    }
    #endif

    // MARK: - Category 1: Page / View Navigation & Transitions

    static func beginNavigation(
        domain: String = "workbench",
        from fromSurface: String,
        to toSurface: String,
        trigger: String,
        startedAt: UInt64 = now()
    ) {
        #if DEBUG
        guard isEnabled else { return }
        AppPerformanceProbe.breadcrumb("nav:\(domain):\(trigger):\(fromSurface)->\(toSurface)")
        let session = PendingNavigationSession(
            id: UUID(),
            fromSurface: fromSurface,
            toSurface: toSurface,
            trigger: trigger,
            startedAt: startedAt
        )
        state.lock.lock()
        state.pendingNavigationsByDomain[domain] = session
        state.lock.unlock()
        #endif
    }

    static func markNavigationSyncPrepFinished(
        domain: String = "workbench",
        to toSurface: String? = nil,
        at timestamp: UInt64 = now()
    ) {
        #if DEBUG
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
        #endif
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
        #if DEBUG
        guard isEnabled else { return }
        state.lock.lock()
        var session = state.pendingNavigationsByDomain[domain]
        if session == nil {
            session = PendingNavigationSession(
                id: UUID(),
                fromSurface: fallbackFromSurface,
                toSurface: toSurface,
                trigger: fallbackTrigger,
                startedAt: preparationStartedAt
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
        #endif
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
        #if DEBUG
        guard isEnabled else { return }
        state.lock.lock()
        let existing = state.pendingNavigationsByDomain.removeValue(forKey: domain)
        state.lock.unlock()

        let effectiveStart = startedAt ?? existing?.startedAt ?? syncPrepFinishedAt
        let effectiveFrom = existing?.fromSurface ?? fromSurface
        let effectiveTrigger = existing?.trigger ?? trigger
        let syncPrepMs = existing?.syncPrepMilliseconds
            ?? elapsedMilliseconds(since: effectiveStart, now: syncPrepFinishedAt)
        let effectiveDataReadyAt = dataReadyAt ?? syncPrepFinishedAt
        let dataReadyMs = elapsedMilliseconds(since: effectiveStart, now: effectiveDataReadyAt)
        let containerWaitMs = elapsedMilliseconds(since: effectiveStart, now: syncPrepFinishedAt)

        AppPerformanceProbe.breadcrumb("nav:\(domain):\(effectiveTrigger):\(effectiveFrom)->\(toSurface)")

        DispatchQueue.main.async {
            let finishTime = now()
            let firstFrameMs = elapsedMilliseconds(since: effectiveStart, now: finishTime)
            emit(
                domain: logDomain(forNavigationDomain: domain),
                message: navigationMessage(forNavigationDomain: domain),
                fields: [
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
            )
        }
        #endif
    }

    #if DEBUG
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

        emit(
            domain: logDomain(forNavigationDomain: domain),
            message: navigationMessage(forNavigationDomain: domain),
            fields: [
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
    #endif

    // MARK: - Category 2: Popup Menus, Submenus & Popovers

    static func markMenuTriggerContext(
        menuID: String,
        trigger: String,
        kind: String = "floating_menu",
        startedAt: UInt64 = now(),
        measureMilliseconds: Double = 0
    ) {
        #if DEBUG
        guard isEnabled else { return }
        AppPerformanceProbe.breadcrumb("menu:\(menuID):\(trigger)")
        state.lock.lock()
        state.activeMenuContext = (
            menuID: menuID,
            trigger: trigger,
            kind: kind,
            startedAt: startedAt,
            measureMilliseconds: measureMilliseconds
        )
        state.lock.unlock()
        #endif
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
        #if DEBUG
        guard isEnabled else { return }
        state.lock.lock()
        defer { state.lock.unlock() }
        for key in state.pendingMenuSessionsByOwner.keys {
            if var session = state.pendingMenuSessionsByOwner[key] {
                session.measureAccumulatedNanoseconds &+= durationNanoseconds
                session.measurePasses += 1
                state.pendingMenuSessionsByOwner[key] = session
            }
        }
        #endif
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
        #if DEBUG
        guard isEnabled else { return }
        state.lock.lock()
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
            let firstFrameAt = now()
            let firstFrameMs = elapsedMilliseconds(since: startedAt, now: firstFrameAt)
            emit(
                domain: .system,
                message: "Menu open completed",
                fields: [
                    ("menu_id", menuID),
                    ("owner", owner),
                    ("kind", kind),
                    ("trigger", trigger),
                    ("prep_and_measure_ms", formatMilliseconds(prepAndMeasureMs)),
                    ("measure_passes", "\(totalPasses)"),
                    ("first_frame_ms", formatMilliseconds(firstFrameMs)),
                    ("total_ms", formatMilliseconds(firstFrameMs))
                ]
            )
        }
        #endif
    }

    static func recordPopoverOpen(
        menuID: String,
        owner: String = "popover",
        trigger: String = "button_click",
        startedAt: UInt64,
        prepFinishedAt: UInt64 = now()
    ) {
        #if DEBUG
        guard isEnabled else { return }
        AppPerformanceProbe.breadcrumb("popover:\(menuID):\(trigger)")
        let prepMs = elapsedMilliseconds(since: startedAt, now: prepFinishedAt)
        DispatchQueue.main.async {
            let firstFrameAt = now()
            let firstFrameMs = elapsedMilliseconds(since: startedAt, now: firstFrameAt)
            emit(
                domain: .system,
                message: "Menu open completed",
                fields: [
                    ("menu_id", menuID),
                    ("owner", owner),
                    ("kind", "popover"),
                    ("trigger", trigger),
                    ("prep_and_measure_ms", formatMilliseconds(prepMs)),
                    ("measure_passes", "1"),
                    ("first_frame_ms", formatMilliseconds(firstFrameMs)),
                    ("total_ms", formatMilliseconds(firstFrameMs))
                ]
            )
        }
        #endif
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
        #if DEBUG
        guard isEnabled else { return }
        AppPerformanceProbe.breadcrumb("menu_action:\(menuID):\(item)")
        let elapsedMs = elapsedMilliseconds(since: startedAt, now: finishedAt)
        emit(
            domain: .system,
            message: "Menu item action executed",
            fields: [
                ("menu_id", menuID),
                ("item", item),
                ("elapsed_ms", formatMilliseconds(elapsedMs))
            ]
        )
        #endif
    }

    static func measureMenuItemAction<T>(
        menuID: String,
        item: String,
        _ action: () throws -> T
    ) rethrows -> T {
        #if DEBUG
        guard isEnabled else {
            return try action()
        }
        let start = now()
        defer {
            recordMenuItemAction(menuID: menuID, item: item, startedAt: start, finishedAt: now())
        }
        return try action()
        #else
        return try action()
        #endif
    }

    // MARK: - Category 3: In-Window Dialogs, Internal Transitions & System File Panels

    static func beginDialogOpen(
        dialogID: String,
        trigger: String,
        startedAt: UInt64 = now(),
        syncPrepFinishedAt: UInt64? = nil,
        hasEntranceAnimation: Bool = true
    ) {
        #if DEBUG
        guard isEnabled else { return }
        AppPerformanceProbe.breadcrumb("dialog:\(dialogID):\(trigger)")
        let prepEnd = syncPrepFinishedAt ?? now()
        let syncPrepMs = elapsedMilliseconds(since: startedAt, now: prepEnd)
        let session = PendingDialogOpenSession(
            dialogID: dialogID,
            trigger: trigger,
            startedAt: startedAt,
            syncPrepMilliseconds: syncPrepMs
        )
        state.lock.lock()
        state.pendingDialogOpens[dialogID] = session
        state.lock.unlock()

        DispatchQueue.main.async {
            markDialogFirstFrame(dialogID: dialogID, hasEntranceAnimation: hasEntranceAnimation)
        }
        #endif
    }

    static func beginDialogOpenIfNeeded(
        dialogID: String,
        trigger: String = "dialog_layer"
    ) {
        #if DEBUG
        guard isEnabled else { return }
        state.lock.lock()
        let hasPending = !state.pendingDialogOpens.isEmpty
        state.lock.unlock()
        guard !hasPending else { return }
        beginDialogOpen(dialogID: dialogID, trigger: trigger)
        #endif
    }

    static func recordDialogAnimationFrame(
        dialogID: String? = nil,
        progress: CGFloat,
        isEntering: Bool = true
    ) {
        #if DEBUG
        guard isEnabled, isEntering else { return }
        let timestamp = now()
        var completedIDs: [String] = []
        state.lock.lock()
        let targetKeys: [String]
        if let dialogID {
            targetKeys = [dialogID]
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
        #endif
    }

    #if DEBUG
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
        emit(
            domain: .system,
            message: "Dialog open completed",
            fields: [
                ("dialog_id", session.dialogID),
                ("trigger", session.trigger),
                ("sync_prep_ms", formatMilliseconds(session.syncPrepMilliseconds)),
                ("first_frame_ms", formatMilliseconds(firstFrameMs)),
                ("anim_duration_ms", formatMilliseconds(animationDurationMilliseconds)),
                ("anim_frames", "\(session.animationFrameCount)"),
                ("max_frame_gap_ms", formatMilliseconds(session.maxFrameGapMilliseconds)),
                ("total_ms", formatMilliseconds(totalMs))
            ]
        )
    }
    #endif

    static func recordDialogInternalTransition(
        dialogID: String,
        transition: String,
        trigger: String,
        startedAt: UInt64,
        syncPrepFinishedAt: UInt64? = nil,
        asyncLoadFinishedAt: UInt64? = nil
    ) {
        #if DEBUG
        guard isEnabled else { return }
        AppPerformanceProbe.breadcrumb("dialog_step:\(dialogID):\(transition)")
        let syncEnd = syncPrepFinishedAt ?? asyncLoadFinishedAt ?? now()
        let asyncEnd = asyncLoadFinishedAt ?? syncEnd
        let syncPrepMs = elapsedMilliseconds(since: startedAt, now: syncEnd)
        let asyncLoadMs = elapsedMilliseconds(since: syncEnd, now: asyncEnd)

        DispatchQueue.main.async {
            let firstFrameAt = now()
            let firstFrameMs = elapsedMilliseconds(since: startedAt, now: firstFrameAt)
            emit(
                domain: .system,
                message: "Dialog internal transition completed",
                fields: [
                    ("dialog_id", dialogID),
                    ("transition", transition),
                    ("trigger", trigger),
                    ("sync_prep_ms", formatMilliseconds(syncPrepMs)),
                    ("async_load_ms", formatMilliseconds(asyncLoadMs)),
                    ("first_frame_ms", formatMilliseconds(firstFrameMs)),
                    ("total_ms", formatMilliseconds(firstFrameMs))
                ]
            )
        }
        #endif
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
        #if DEBUG
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
        #endif
    }

    // MARK: - Category 4: Main Thread Stall Monitoring (>= 32ms)

    static func recordMainThreadStall(
        stalledMilliseconds: Double,
        phase: String,
        lastAction: String,
        lastActionAgeMilliseconds: Double?
    ) {
        #if DEBUG
        guard isEnabled, stalledMilliseconds >= 32 else { return }
        let ageText = lastActionAgeMilliseconds.map { formatMilliseconds($0) } ?? "none"
        emit(
            domain: .system,
            message: "Main thread stall detected",
            fields: [
                ("stalled_ms", formatMilliseconds(stalledMilliseconds)),
                ("phase", phase),
                ("last_action", lastAction),
                ("last_action_age_ms", ageText)
            ]
        )
        #endif
    }

    #if DEBUG
    private static func emit(
        domain: AppLogCategory,
        message: String,
        fields: [(String, String)]
    ) {
        AppLogger.shared.debug(domain, message, fields: fields)
        state.lock.lock()
        let observer = state.onEventLoggedForTesting
        state.lock.unlock()
        if let observer {
            var dictionary: [String: String] = [:]
            for (key, value) in fields {
                dictionary[key] = value
            }
            observer(LoggedEvent(domain: domain, message: message, fields: dictionary))
        }
    }
    #endif
}
