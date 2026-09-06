import AppKit
import Combine
import SwiftUI

enum ToastPosition: Equatable {
    case appCenter
}

enum ToastAnimationStyle: Equatable {
    case `default`
}

struct ToastRequest: Equatable {
    let scenarioID: String?
    let message: String
    let duration: TimeInterval
    let position: ToastPosition
    let animation: ToastAnimationStyle

    init(
        scenarioID: String? = nil,
        message: String,
        duration: TimeInterval = 5,
        position: ToastPosition = .appCenter,
        animation: ToastAnimationStyle = .default
    ) {
        self.scenarioID = scenarioID
        self.message = message
        self.duration = duration
        self.position = position
        self.animation = animation
    }
}

enum ShioriToastRequest {
    static func moveSucceeded(listName: String) -> ToastRequest {
        ToastRequest(
            scenarioID: "shiori.move.succeeded",
            message: L("toast.shiori.moved", listName)
        )
    }

    static func saveSucceeded(listName: String) -> ToastRequest {
        ToastRequest(
            scenarioID: "shiori.save.succeeded",
            message: L("toast.shiori.saved", listName)
        )
    }

    static func duplicateSucceeded(listName: String) -> ToastRequest {
        ToastRequest(
            scenarioID: "shiori.duplicate.succeeded",
            message: L("toast.shiori.duplicated", listName)
        )
    }

    static var destinationUnavailable: ToastRequest {
        ToastRequest(
            scenarioID: "shiori.destination.unavailable",
            message: L("toast.shiori.destination_unavailable")
        )
    }

    static var moveFailed: ToastRequest {
        ToastRequest(
            scenarioID: "shiori.move.failed",
            message: L("toast.shiori.move_failed")
        )
    }

    static var saveFailed: ToastRequest {
        ToastRequest(
            scenarioID: "shiori.save.failed",
            message: L("toast.shiori.save_failed")
        )
    }

    static var duplicateFailed: ToastRequest {
        ToastRequest(
            scenarioID: "shiori.duplicate.failed",
            message: L("toast.shiori.duplicate_failed")
        )
    }

    static func destinationAlreadyContainsCue(listName: String) -> ToastRequest {
        ToastRequest(
            scenarioID: "shiori.destination.cue.already_exists",
            message: L("toast.shiori.already_exists", listName)
        )
    }
}

struct ToastItem: Identifiable, Equatable {
    let id: UUID
    let request: ToastRequest
}

@MainActor
final class ToastCenter: ObservableObject {
    static let maximumVisibleCount = 4
    static let motion = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.20)

    @Published private(set) var visibleItems: [ToastItem] = []
    private var queuedItems: [ToastItem] = []
    private var remainingDurationByID: [UUID: TimeInterval] = [:]
    private var hoveredIDs: Set<UUID> = []
    private var isAppActive = true

    var queuedCount: Int {
        queuedItems.count
    }

    func show(_ request: ToastRequest) {
        let item = ToastItem(id: UUID(), request: request)
        guard visibleItems.count < Self.maximumVisibleCount else {
            queuedItems.append(item)
            return
        }
        withAnimation(Self.motion) {
            makeVisible(item)
        }
    }

    func setHovered(_ isHovered: Bool, itemID: UUID) {
        if isHovered {
            hoveredIDs.insert(itemID)
        } else {
            hoveredIDs.remove(itemID)
        }
    }

    func setAppActive(_ isActive: Bool) {
        isAppActive = isActive
    }

    func advance(by elapsed: TimeInterval) {
        guard elapsed > 0, isAppActive else {
            return
        }

        for item in visibleItems where !hoveredIDs.contains(item.id) {
            remainingDurationByID[item.id, default: item.request.duration] -= elapsed
        }
        let expiredIDs = Set(
            visibleItems
                .filter { remainingDurationByID[$0.id, default: $0.request.duration] <= 0 }
                .map(\.id)
        )
        guard !expiredIDs.isEmpty else {
            return
        }

        withAnimation(Self.motion) {
            visibleItems.removeAll { expiredIDs.contains($0.id) }
            for id in expiredIDs {
                remainingDurationByID.removeValue(forKey: id)
                hoveredIDs.remove(id)
            }
            promoteQueuedItems()
        }
    }

    private func promoteQueuedItems() {
        while visibleItems.count < Self.maximumVisibleCount, !queuedItems.isEmpty {
            makeVisible(queuedItems.removeFirst())
        }
    }

    private func makeVisible(_ item: ToastItem) {
        remainingDurationByID[item.id] = max(0, item.request.duration)
        visibleItems.append(item)
        announce(item.request.message)
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

    private let timer = Timer.publish(
        every: 0.1,
        on: .main,
        in: .common
    ).autoconnect()
    @State private var lastTick = Date()

    var body: some View {
        VStack(spacing: 16) {
            ForEach(center.visibleItems) { item in
                ToastView(item: item, center: center)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 8)),
                            removal: .opacity.combined(with: .offset(y: -8))
                        )
                    )
            }
        }
        .padding(.horizontal, 24)
        .alignmentGuide(VerticalAlignment.center) { dimensions in
            dimensions[.bottom]
        }
        .animation(ToastCenter.motion, value: center.visibleItems.map(\.id))
        .onAppear {
            lastTick = Date()
            center.setAppActive(NSApp?.isActive ?? true)
        }
        .onReceive(timer) { date in
            let elapsed = date.timeIntervalSince(lastTick)
            lastTick = date
            center.advance(by: elapsed)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didResignActiveNotification
        )) { _ in
            center.setAppActive(false)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            lastTick = Date()
            center.setAppActive(true)
        }
    }
}

private struct ToastView: View {
    let item: ToastItem
    @ObservedObject var center: ToastCenter

    var body: some View {
        Text(item.request.message)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .regular
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            // The shadow belongs to the toast's shape, not to the toast.
            // Applied to the whole surface it is cast by every leaf inside it,
            // which haloes the message text.
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                    style: .continuous
                )
                .fill(WorkbenchRedesignColors.bgPopover)
                .shadowToken(WorkbenchRedesignColors.shadowPopover)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                    style: .continuous
                )
                .strokeBorder(WorkbenchRedesignColors.borderMuted, lineWidth: 1)
            )
            .onHover { isHovered in
                center.setHovered(isHovered, itemID: item.id)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.request.message)
    }
}
