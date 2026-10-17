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
}

extension ToastRequest {
    static var taskStatusChanged: ToastRequest {
        TaskToastRequest.taskStatusChanged
    }
}

struct ToastItem: Identifiable, Equatable {
    let id: UUID
    let request: ToastRequest
    let expiresAt: Date
}

@MainActor
final class ToastCenter: ObservableObject {
    static let maximumVisibleCount = 4
    static let motion = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.20)

    @Published private(set) var visibleItems: [ToastItem] = []
    private var expiryTask: Task<Void, Never>?

    func show(_ request: ToastRequest, now: Date = Date()) {
        // Reporting the same result again is the same message, not a second
        // one: it keeps its identity, takes the newest slot and starts its stay
        // over.
        let existingID = visibleItems.first {
            $0.request.scenarioID == request.scenarioID
                && $0.request.message == request.message
        }?.id
        let item = ToastItem(
            id: existingID ?? UUID(),
            request: request,
            expiresAt: now.addingTimeInterval(request.duration)
        )

        withAnimation(Self.motion) {
            visibleItems.removeAll { $0.id == item.id }
            visibleItems.append(item)
            // A message that has to wait its turn arrives after the user has
            // moved on, so the oldest one leaves instead of the newest waiting.
            if visibleItems.count > Self.maximumVisibleCount {
                visibleItems.removeFirst(visibleItems.count - Self.maximumVisibleCount)
            }
        }
        announce(request.message)
        scheduleExpiry()
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

private struct NewestToastHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ToastStackView: View {
    @ObservedObject var center: ToastCenter

    @State private var newestHeight: CGFloat = 0

    var body: some View {
        let newestHalfHeight = newestHeight / 2

        return VStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            ForEach(Array(center.visibleItems.enumerated()), id: \.element.id) { index, item in
                ToastView(item: item)
                    .background(
                        newestHeightReader(isNewest: index == center.visibleItems.count - 1)
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 8)),
                            removal: .opacity.combined(with: .offset(y: -8))
                        )
                    )
            }
        }
        // The message wraps at the smaller of its own ceiling and the space the
        // window leaves beside the viewport margin.
        .frame(maxWidth: WorkbenchControlMetrics.redesignToastMaxWidth)
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing6)
        // The newest toast holds the window's centre and older ones stack above
        // it, so the place the eye returns to never moves.
        .alignmentGuide(VerticalAlignment.center) { dimensions in
            dimensions[.bottom] - newestHalfHeight
        }
        .onPreferenceChange(NewestToastHeightKey.self) { height in
            newestHeight = height
        }
        .allowsHitTesting(false)
        .animation(ToastCenter.motion, value: center.visibleItems.map(\.id))
    }

    @ViewBuilder
    private func newestHeightReader(isNewest: Bool) -> some View {
        if isNewest {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: NewestToastHeightKey.self,
                    value: proxy.size.height
                )
            }
        }
    }
}

struct ToastView: View {
    let item: ToastItem

    var body: some View {
        HStack(
            alignment: .feedbackFirstLineCenter,
            spacing: WorkbenchControlMetrics.redesignSpacing3
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
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeToast,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .foregroundColor(WorkbenchRedesignColors.toastText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .alignmentGuide(.feedbackFirstLineCenter) { _ in
                    WorkbenchControlMetrics.firstLineCenter(
                        fontSize: WorkbenchControlMetrics.redesignFontSizeToast
                    )
                }
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing3)
        .background(surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.request.message)
    }

    static func iconColor(for request: ToastRequest) -> Color {
        .white
    }

    /// The unified Toast & Playback Feedback surface: dark translucent base with frosted glass and 1px border.
    private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: PlaybackChromeMetrics.feedbackRadius)

        return shape
            .fill(WorkbenchRedesignColors.toastBg)
            .background(
                shape
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                shape.strokeBorder(
                    WorkbenchRedesignColors.toastBorder,
                    lineWidth: 1
                )
            )
    }
}
