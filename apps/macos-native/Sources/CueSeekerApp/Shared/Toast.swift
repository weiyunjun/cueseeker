import AppKit
import Combine
import SwiftUI

enum ToastPosition: Equatable {
    case appCenter
}

enum ToastAnimationStyle: Equatable {
    case `default`
}

enum ToastDuration {
    static let light: TimeInterval = 1.5
    static let alert: TimeInterval = 3.0
    static let playerHud: TimeInterval = 1.0
}

struct ToastRequest: Equatable {
    let scenarioID: String?
    let message: String
    let icon: AppIcon?
    let iconWeight: AppIconWeight?
    let duration: TimeInterval
    let position: ToastPosition
    let animation: ToastAnimationStyle

    init(
        scenarioID: String? = nil,
        message: String,
        icon: AppIcon? = nil,
        iconWeight: AppIconWeight? = nil,
        duration: TimeInterval = ToastDuration.light,
        position: ToastPosition = .appCenter,
        animation: ToastAnimationStyle = .default
    ) {
        self.scenarioID = scenarioID
        self.message = message
        self.icon = icon
        self.iconWeight = iconWeight
        self.duration = duration
        self.position = position
        self.animation = animation
    }
}

enum ExcerptToastRequest {
    private static func succeeded(_ scenarioID: String, _ message: String) -> ToastRequest {
        ToastRequest(
            scenarioID: scenarioID,
            message: message,
            icon: .bookmarkSimple,
            iconWeight: .fill,
            duration: ToastDuration.light
        )
    }

    private static func alert(_ scenarioID: String, _ message: String) -> ToastRequest {
        ToastRequest(
            scenarioID: scenarioID,
            message: message,
            icon: .warning,
            duration: ToastDuration.alert
        )
    }

    static func moveSucceeded(listName: String) -> ToastRequest {
        succeeded("excerpt.move.succeeded", L("toast.excerpt.moved", listName))
    }

    static func saveSucceeded(listName: String) -> ToastRequest {
        succeeded("excerpt.save.succeeded", L("toast.excerpt.saved", listName))
    }

    static func duplicateSucceeded(listName: String) -> ToastRequest {
        succeeded("excerpt.duplicate.succeeded", L("toast.excerpt.duplicated", listName))
    }

    static func destinationUnavailable(listName: String) -> ToastRequest {
        alert(
            "excerpt.destination.unavailable",
            L("toast.excerpt.destination_unavailable", listName)
        )
    }

    static var moveFailed: ToastRequest {
        alert("excerpt.move.failed", L("toast.excerpt.move_failed"))
    }

    static func saveFailed(listName: String) -> ToastRequest {
        alert("excerpt.save.failed", L("toast.excerpt.save_failed", listName))
    }

    static var duplicateFailed: ToastRequest {
        alert("excerpt.duplicate.failed", L("toast.excerpt.duplicate_failed"))
    }

    static func destinationAlreadyContainsCue(listName: String) -> ToastRequest {
        alert(
            "excerpt.destination.cue.already_exists",
            L("toast.excerpt.already_exists", listName)
        )
    }
}

enum TableToastRequest {
    private static func copy(_ scenarioID: String, _ message: String) -> ToastRequest {
        ToastRequest(
            scenarioID: scenarioID,
            message: message,
            icon: .copy,
            duration: ToastDuration.light
        )
    }

    static var copyCueText: ToastRequest {
        copy("table.row.copy_cue_text", L("toast.table.cue_text_copied"))
    }

    static var copyDeepLink: ToastRequest {
        copy("table.row.copy_deep_link", L("toast.table.deep_link_copied"))
    }

    static var copyCueGroupText: ToastRequest {
        copy("table.row.copy_cue_group_text", L("toast.table.cue_group_text_copied"))
    }

    static var copyTimeRange: ToastRequest {
        copy("table.row.copy_time_range", L("toast.table.time_range_copied"))
    }

    static var copyDeepLinks: ToastRequest {
        copy("table.selection.copy_deep_links", L("toast.table.deep_links_copied"))
    }

    static var copyTable: ToastRequest {
        copy("table.selection.copy_table", L("toast.table.table_copied"))
    }

    static var cueNotInLibrary: ToastRequest {
        ToastRequest(
            scenarioID: "cue_not_in_library",
            message: L("toast.cue_not_in_library"),
            icon: .warning,
            duration: ToastDuration.alert
        )
    }

    static var cuesNotInLibrary: ToastRequest {
        ToastRequest(
            scenarioID: "cues_not_in_library",
            message: L("toast.cues_not_in_library"),
            icon: .warning,
            duration: ToastDuration.alert
        )
    }

    static func cueNotInLibrary(count: Int) -> ToastRequest {
        count > 1 ? cuesNotInLibrary : cueNotInLibrary
    }
}

enum LibraryToastRequest {
    static var folderNotInLibrary: ToastRequest {
        ToastRequest(
            scenarioID: "library.folder.not_in_library",
            message: L("toast.library.folder_not_in_library"),
            icon: .warning,
            duration: ToastDuration.alert
        )
    }
}

enum TaskToastRequest {
    static var taskStatusChanged: ToastRequest {
        ToastRequest(
            scenarioID: "task.action.status_changed",
            message: L("toast.task_status_changed"),
            icon: .warning,
            duration: ToastDuration.alert
        )
    }

    static var taskRecordNotFound: ToastRequest {
        ToastRequest(
            scenarioID: "task.detail.record_not_found",
            message: L("toast.task_record_not_found"),
            icon: .warning,
            duration: ToastDuration.alert
        )
    }
}

enum PlaybackToastRequest {
    private static func copy(_ scenarioID: String, _ message: String) -> ToastRequest {
        ToastRequest(
            scenarioID: scenarioID,
            message: message,
            icon: .copy,
            duration: ToastDuration.light
        )
    }

    private static func alert(_ scenarioID: String, _ message: String) -> ToastRequest {
        ToastRequest(
            scenarioID: scenarioID,
            message: message,
            icon: .warning,
            duration: ToastDuration.alert
        )
    }

    static var cueTextCopied: ToastRequest {
        copy("playback.feedback.cue_text_copied", L("playback.hud.cue_text_copied"))
    }

    static var deepLinkCopied: ToastRequest {
        copy("playback.feedback.deep_link_copied", L("playback.hud.deep_link_copied"))
    }

    static var selectedTextCopied: ToastRequest {
        copy("playback.feedback.selected_text_copied", L("playback.hud.selected_text_copied"))
    }

    static var collageCopied: ToastRequest {
        copy("playback.feedback.collage_copied", L("playback.hud.collage_copied"))
    }

    static var collageExported: ToastRequest {
        ToastRequest(
            scenarioID: "playback.feedback.collage_exported",
            message: L("playback.hud.collage_exported"),
            icon: .export,
            duration: ToastDuration.light
        )
    }

    static var noSubtitle: ToastRequest {
        alert("playback.feedback.no_subtitle", L("playback.hud.no_subtitle"))
    }

    static var copyFailed: ToastRequest {
        alert("playback.feedback.copy_failed", L("playback.hud.copy_failed"))
    }

    static var exportFailed: ToastRequest {
        alert("playback.feedback.export_failed", L("playback.hud.export_failed"))
    }

    static var collageNotReady: ToastRequest {
        alert("playback.feedback.collage_not_ready", L("playback.hud.collage_not_ready"))
    }

    static var collageNoCueSelected: ToastRequest {
        alert(
            "playback.feedback.collage_no_cue_selected",
            L("playback.hud.collage_no_cue_selected")
        )
    }

    static var cueNotInLibrary: ToastRequest {
        alert("playback.feedback.not_in_library", L("playback.hud.not_in_library"))
    }

    static var noAvailableResults: ToastRequest {
        alert("playback.hud.no_available_results", L("playback.hud.no_available_results"))
    }

    static var noAvailableExcerpts: ToastRequest {
        alert("playback.hud.no_available_excerpts", L("playback.hud.no_available_excerpts"))
    }

    static func subtitleCopy(copied: Bool) -> ToastRequest {
        copied ? cueTextCopied : noSubtitle
    }

    static func subtitleMarkdownLinkCopy(copied: Bool) -> ToastRequest {
        copied ? deepLinkCopied : noSubtitle
    }

    static func selectedTextCopy(copied: Bool) -> ToastRequest {
        copied ? selectedTextCopied : copyFailed
    }

    static func collage(_ event: PlaybackCollageFeedbackEvent) -> ToastRequest {
        switch event {
        case .noCueSelected:
            collageNoCueSelected
        case .notReady:
            collageNotReady
        case .copyFailed:
            copyFailed
        case .exportFailed:
            exportFailed
        case .copySucceeded:
            collageCopied
        case .exportSucceeded:
            collageExported
        }
    }
}

extension ToastRequest {
    static var taskStatusChanged: ToastRequest {
        TaskToastRequest.taskStatusChanged
    }

    static var taskRecordNotFound: ToastRequest {
        TaskToastRequest.taskRecordNotFound
    }
}

struct ToastItem: Identifiable, Equatable {
    let id: UUID
    let request: ToastRequest
    let expiresAt: Date
    var sequence: Int = 0
    var stackIndex: Int = 0
    var isLimited: Bool = false
    var isEnding: Bool = false

    init(
        id: UUID,
        request: ToastRequest,
        expiresAt: Date,
        sequence: Int = 0,
        stackIndex: Int = 0,
        isLimited: Bool = false,
        isEnding: Bool = false
    ) {
        self.id = id
        self.request = request
        self.expiresAt = expiresAt
        self.sequence = sequence
        self.stackIndex = stackIndex
        self.isLimited = isLimited
        self.isEnding = isEnding
    }
}

@MainActor
final class ToastCenter: ObservableObject {
    static let maximumVisibleCount = 3
    static let motion = Animation.timingCurve(
        0.22,
        1,
        0.36,
        1,
        duration: WorkbenchControlMetrics.redesignToastMotionDuration
    )
    static let contentMotion = Animation.timingCurve(
        0.22,
        1,
        0.36,
        1,
        duration: WorkbenchControlMetrics.redesignToastContentMotionDuration
    )
    static let heightMotion = Animation.timingCurve(
        0.22,
        1,
        0.36,
        1,
        duration: WorkbenchControlMetrics.redesignToastHeightMotionDuration
    )

    @Published private(set) var visibleItems: [ToastItem] = []
    @Published private(set) var renderedItems: [ToastItem] = []
    @Published private(set) var cueFooterHeightsBySurface: [PlaybackCueFooterSurface: CGFloat] = [:]
    private var nextSequence: Int = 1
    private var expiryTask: Task<Void, Never>?
    private var cleanupTasksByID: [UUID: Task<Void, Never>] = [:]

    func setCueFooterHeight(_ height: CGFloat, for surface: PlaybackCueFooterSurface) {
        let resolved = max(PlaybackCueFooterMetrics.minimumHeight, height)
        guard abs((cueFooterHeightsBySurface[surface] ?? 0) - resolved) > 0.5 else {
            return
        }
        cueFooterHeightsBySurface[surface] = resolved
    }

    func cueFooterHeight(for surface: PlaybackCueFooterSurface) -> CGFloat {
        cueFooterHeightsBySurface[surface] ?? PlaybackCueFooterMetrics.minimumHeight
    }

    func show(_ request: ToastRequest, now: Date = Date()) {
        // Every trigger pushes a new toast onto the folded stack rather than
        // merging into an existing one; once more than 3 are up, the oldest is
        // evicted from visibleItems immediately while animating out as limited
        // in renderedItems.
        let sequence = nextSequence
        nextSequence += 1

        let item = ToastItem(
            id: UUID(),
            request: request,
            expiresAt: now.addingTimeInterval(request.duration),
            sequence: sequence
        )

        var evictedIDs: [UUID] = []
        withAnimation(Self.motion) {
            visibleItems.append(item)
            if visibleItems.count > Self.maximumVisibleCount {
                let overflowCount = visibleItems.count - Self.maximumVisibleCount
                evictedIDs = Array(visibleItems.prefix(overflowCount)).map(\.id)
                visibleItems.removeFirst(overflowCount)
            }

            renderedItems.append(item)
            for id in evictedIDs {
                if let index = renderedItems.firstIndex(where: { $0.id == id }) {
                    renderedItems[index].isLimited = true
                    renderedItems[index].stackIndex = Self.maximumVisibleCount
                }
            }
            recomputeActiveStackIndices()
        }

        for id in evictedIDs {
            scheduleCleanup(for: id)
        }
        announce(request.message)
        scheduleExpiry()
    }

    func dismissAll() {
        expiryTask?.cancel()
        expiryTask = nil
        for task in cleanupTasksByID.values {
            task.cancel()
        }
        cleanupTasksByID.removeAll()
        if !visibleItems.isEmpty {
            visibleItems.removeAll()
        }
        if !renderedItems.isEmpty {
            renderedItems.removeAll()
        }
    }

    func removeExpired(at now: Date = Date()) {
        let expiredIDs = visibleItems
            .filter { $0.expiresAt <= now }
            .map(\.id)

        if !expiredIDs.isEmpty {
            withAnimation(Self.motion) {
                visibleItems.removeAll { $0.expiresAt <= now }
                for id in expiredIDs {
                    if let index = renderedItems.firstIndex(where: { $0.id == id }) {
                        renderedItems[index].isEnding = true
                    }
                }
                recomputeActiveStackIndices()
            }
            for id in expiredIDs {
                scheduleCleanup(for: id)
            }
        }
        scheduleExpiry()
    }

    private func recomputeActiveStackIndices() {
        let activeIndices = renderedItems.indices.filter {
            !renderedItems[$0].isLimited && !renderedItems[$0].isEnding
        }
        let activeCount = activeIndices.count
        for (offset, itemIndex) in activeIndices.enumerated() {
            let stackIndex = max(0, activeCount - 1 - offset)
            renderedItems[itemIndex].stackIndex = stackIndex
            if let visibleIndex = visibleItems.firstIndex(where: { $0.id == renderedItems[itemIndex].id }) {
                visibleItems[visibleIndex].stackIndex = stackIndex
            }
        }
    }

    private func scheduleCleanup(for id: UUID) {
        cleanupTasksByID[id]?.cancel()
        let duration = WorkbenchControlMetrics.redesignToastMotionDuration
        cleanupTasksByID[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }
            self?.finishCleanup(for: id)
        }
    }

    private func finishCleanup(for id: UUID) {
        cleanupTasksByID[id] = nil
        renderedItems.removeAll { $0.id == id && ($0.isLimited || $0.isEnding) }
    }

    /// A toast stays for its own duration measured on the wall clock. Nothing
    /// the user does elsewhere — leaving the app, resting the pointer on it —
    /// holds it on screen.
    private func scheduleExpiry() {
        expiryTask?.cancel()
        guard let next = visibleItems.map(\.expiresAt).min() else {
            expiryTask = nil
            return
        }
        let delay = max(0, next.timeIntervalSinceNow)
        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }
            self?.removeExpired()
        }
    }

    private func announce(_ message: String) {
        guard NSApp != nil else {
            return
        }
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ]
        )
    }
}

struct ToastStackView: View {
    @ObservedObject var center: ToastCenter
    var trailingPadding: CGFloat = WorkbenchControlMetrics.redesignSpacing6
    var bottomPadding: CGFloat = WorkbenchControlMetrics.redesignSpacing6

    var body: some View {
        let items = center.renderedItems
        let frontmostItem = center.visibleItems.last ?? items.last
        let frontmostHeight = frontmostItem.map { ToastView.estimatedHeight(for: $0.request) }

        ZStack(alignment: .bottomTrailing) {
            Color.clear

            ZStack(alignment: .bottom) {
                ForEach(items) { item in
                    ToastCardContainer(
                        item: item,
                        frontmostHeight: frontmostHeight
                    )
                    .zIndex(Double(item.sequence))
                }
            }
            .padding(.trailing, trailingPadding)
            .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(false)
    }
}

private struct ToastCardContainer: View {
    let item: ToastItem
    let frontmostHeight: CGFloat?

    @State private var isStarting = true

    var body: some View {
        let naturalHeight = ToastView.estimatedHeight(for: item.request)
        let cardHeight = frontmostHeight ?? naturalHeight
        let isFrontmost = !item.isLimited && !item.isEnding && item.stackIndex == 0
        let scale = max(
            0,
            1 - CGFloat(item.stackIndex) * WorkbenchControlMetrics.redesignToastStackScaleStep
        )
        let shrink = 1 - scale
        let stackedOffsetY =
            -CGFloat(item.stackIndex) * WorkbenchControlMetrics.redesignToastStackOffset
            - shrink * cardHeight
        let exitOrEnterOffsetY = cardHeight * WorkbenchControlMetrics.redesignToastMotionDistanceRatio
        let verticalOffset: CGFloat =
            (isStarting || (item.isEnding && !item.isLimited))
            ? exitOrEnterOffsetY
            : stackedOffsetY
        let opacity: Double = (item.isLimited || item.isEnding) ? 0 : 1

        ToastView(
            item: item,
            cardHeight: cardHeight,
            showsContent: isFrontmost
        )
        .scaleEffect(scale, anchor: .bottom)
        .offset(y: verticalOffset)
        .opacity(opacity)
        .onAppear {
            withAnimation(ToastCenter.motion) {
                isStarting = false
            }
        }
    }
}

struct ToastView: View {
    let item: ToastItem
    var cardHeight: CGFloat?
    var showsContent: Bool = true

    var body: some View {
        let resolvedHeight = cardHeight ?? Self.estimatedHeight(for: item.request)

        HStack(
            alignment: .feedbackFirstLineCenter,
            spacing: WorkbenchControlMetrics.redesignSpacing2
        ) {
            if let icon = item.request.icon {
                AppIconImage(
                    icon,
                    size: WorkbenchControlMetrics.redesignToastIconSize,
                    weight: item.request.iconWeight
                )
                .foregroundColor(Self.iconColor(for: item.request))
                .alignmentGuide(.feedbackFirstLineCenter) { dimensions in
                    dimensions[VerticalAlignment.center]
                }
            }

            Text(item.request.message)
                .font(
                    .system(
                        size: WorkbenchControlMetrics.redesignFontSizeToast,
                        weight: WorkbenchControlMetrics.redesignFontWeightToast
                    )
                    .monospacedDigit()
                )
                .lineSpacing(WorkbenchControlMetrics.redesignToastLeading)
                .padding(.vertical, WorkbenchControlMetrics.redesignToastLeading / 2)
                .foregroundColor(WorkbenchRedesignColors.toastText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .alignmentGuide(.feedbackFirstLineCenter) { _ in
                    WorkbenchControlMetrics.redesignLineHeightToast / 2
                }
        }
        .opacity(showsContent ? 1 : 0)
        .animation(ToastCenter.contentMotion, value: showsContent)
        .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing4)
        .frame(
            width: WorkbenchControlMetrics.redesignToastWidth,
            height: resolvedHeight,
            alignment: .topLeading
        )
        .clipped()
        .animation(ToastCenter.heightMotion, value: resolvedHeight)
        .background(surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.request.message)
        .accessibilityHidden(!showsContent)
    }

    static func iconColor(for request: ToastRequest) -> Color {
        WorkbenchRedesignColors.textSecondary
    }

    static func estimatedHeight(for request: ToastRequest) -> CGFloat {
        let horizontalPadding = WorkbenchControlMetrics.redesignControlPaddingX * 2
        let iconFootprint: CGFloat =
            request.icon != nil
            ? (WorkbenchControlMetrics.redesignToastIconSize + WorkbenchControlMetrics.redesignSpacing2)
            : 0
        let availableTextWidth = max(
            1,
            WorkbenchControlMetrics.redesignToastWidth - horizontalPadding - iconFootprint
        )

        let font = NSFont.monospacedDigitSystemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeToast,
            weight: WorkbenchControlMetrics.redesignNSFontWeightToast
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = WorkbenchControlMetrics.redesignLineHeightToast
        paragraphStyle.maximumLineHeight = WorkbenchControlMetrics.redesignLineHeightToast
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributed = NSAttributedString(
            string: request.message,
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle,
            ]
        )
        let boundingRect = attributed.boundingRect(
            with: NSSize(width: availableTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let lineCount = max(
            1,
            Int(ceil(boundingRect.height / WorkbenchControlMetrics.redesignLineHeightToast - 0.001))
        )
        let textHeight = CGFloat(lineCount) * WorkbenchControlMetrics.redesignLineHeightToast
        let verticalPadding = WorkbenchControlMetrics.redesignSpacing4 * 2
        return textHeight + verticalPadding
    }

    private var surface: some View {
        let shape = RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignToastRadius,
            style: .continuous
        )

        return shape
            .fill(WorkbenchRedesignColors.toastBg)
            .shadowToken(
                WorkbenchRedesignColors.shadowPopover,
                cornerRadius: WorkbenchControlMetrics.redesignToastRadius
            )
            .overlay(
                shape.strokeBorder(
                    WorkbenchRedesignColors.toastBorder,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
            )
    }
}
