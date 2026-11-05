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

    @Published private(set) var visibleItems: [ToastItem] = []
    @Published private(set) var cueFooterHeightsBySurface: [PlaybackCueFooterSurface: CGFloat] = [:]
    private var expiryTask: Task<Void, Never>?

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
        // evicted immediately.
        let item = ToastItem(
            id: UUID(),
            request: request,
            expiresAt: now.addingTimeInterval(request.duration)
        )

        withAnimation(Self.motion) {
            visibleItems.append(item)
            if visibleItems.count > Self.maximumVisibleCount {
                visibleItems.removeFirst(visibleItems.count - Self.maximumVisibleCount)
            }
        }
        announce(request.message)
        scheduleExpiry()
    }

    func dismissAll() {
        expiryTask?.cancel()
        expiryTask = nil
        if !visibleItems.isEmpty {
            visibleItems.removeAll()
        }
    }

    func removeExpired(at now: Date = Date()) {
        if visibleItems.contains(where: { $0.expiresAt <= now }) {
            withAnimation(Self.motion) {
                visibleItems.removeAll { $0.expiresAt <= now }
            }
        }
        scheduleExpiry()
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
        let items = center.visibleItems
        let frontmostItem = items.last

        ZStack(alignment: .bottomTrailing) {
            Color.clear

            if let frontmostItem {
                ZStack(alignment: .top) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let depth = max(0, items.count - 1 - index)
                        let isFrontmost = depth == 0
                        let scale = max(
                            0,
                            1 - CGFloat(depth) * WorkbenchControlMetrics.redesignToastStackScaleStep
                        )
                        let verticalOffset = -CGFloat(depth) * WorkbenchControlMetrics.redesignToastStackOffset

                        ToastView(
                            item: item,
                            sizingItem: isFrontmost ? item : frontmostItem,
                            showsContent: isFrontmost
                        )
                        .scaleEffect(scale, anchor: .top)
                        .offset(y: verticalOffset)
                        .zIndex(Double(ToastCenter.maximumVisibleCount - depth))
                        .transition(
                            .asymmetric(
                                insertion: .offset(
                                    y: WorkbenchControlMetrics.redesignToastMotionDistance
                                )
                                .combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }
                }
                .padding(.trailing, trailingPadding)
                .padding(.bottom, bottomPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(false)
        .animation(ToastCenter.motion, value: items.map(\.id))
    }
}

struct ToastView: View {
    let item: ToastItem
    var sizingItem: ToastItem?
    var showsContent: Bool = true

    var body: some View {
        let effectiveItem = sizingItem ?? item

        HStack(
            alignment: .feedbackFirstLineCenter,
            spacing: WorkbenchControlMetrics.redesignSpacing2
        ) {
            if let icon = effectiveItem.request.icon {
                AppIconImage(
                    icon,
                    size: WorkbenchControlMetrics.redesignToastIconSize,
                    weight: effectiveItem.request.iconWeight
                )
                .foregroundColor(Self.iconColor(for: effectiveItem.request))
                .alignmentGuide(.feedbackFirstLineCenter) { dimensions in
                    dimensions[VerticalAlignment.center]
                }
            }

            Text(effectiveItem.request.message)
                .font(
                    .system(
                        size: WorkbenchControlMetrics.redesignFontSizeToast,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
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
        .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
        .frame(
            width: WorkbenchControlMetrics.redesignToastWidth,
            alignment: .leading
        )
        .background(surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.request.message)
        .accessibilityHidden(!showsContent)
    }

    static func iconColor(for request: ToastRequest) -> Color {
        WorkbenchRedesignColors.textPrimary
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
