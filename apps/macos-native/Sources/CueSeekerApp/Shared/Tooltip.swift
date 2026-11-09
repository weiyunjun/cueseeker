import AppKit
import Combine
import SwiftUI

enum TooltipSurface: Equatable, Sendable {
    case main
    case settings
}

enum TooltipShortcut: Equatable, Sendable {
    case none
    case fixed(String)
    case action(PlaybackShortcutAction)

    private static let modifierCharacters: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]

    @MainActor
    func resolvedKeycaps(keymap: PlaybackShortcutKeymap) -> [PlaybackCueFooterKeycap] {
        switch self {
        case .none:
            return []
        case .fixed(let text):
            return Self.parseFixedKeycaps(text)
        case .action(let action):
            return keymap.effectiveKey(for: action)?.keycaps ?? []
        }
    }

    @MainActor
    func resolvedText(keymap: PlaybackShortcutKeymap) -> String? {
        let caps = resolvedKeycaps(keymap: keymap)
        guard !caps.isEmpty else {
            return nil
        }
        let text = caps.map { cap -> String in
            switch cap {
            case .text(let value):
                return value
            case .icon(.arrowElbowDownLeft):
                return "↩"
            case .icon:
                return ""
            }
        }.joined()
        return text.isEmpty ? nil : text
    }

    private static func parseFixedKeycaps(_ raw: String) -> [PlaybackCueFooterKeycap] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        var caps: [PlaybackCueFooterKeycap] = []
        var remainder = Substring(trimmed)
        while let first = remainder.first, modifierCharacters.contains(first) {
            caps.append(.text(String(first)))
            remainder = remainder.dropFirst()
        }
        let mainKey = String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
        if mainKey == "↩" {
            caps.append(.returnKey)
        } else if !mainKey.isEmpty {
            caps.append(.text(mainKey))
        }
        return caps
    }
}

extension PlaybackShortcutKey {
    @MainActor
    var tooltipDisplayText: String? {
        let caps = keycaps
        guard !caps.isEmpty else {
            return nil
        }
        let text = caps.map { cap -> String in
            switch cap {
            case .text(let value):
                return value
            case .icon(.arrowElbowDownLeft):
                return "↩"
            case .icon:
                return ""
            }
        }.joined()
        return text.isEmpty ? nil : text
    }
}

enum TooltipContent: Equatable {
    case standard(label: String, shortcut: TooltipShortcut, wrapsText: Bool)
    case cueState(SubtitleTableCueState)

    var isEmpty: Bool {
        switch self {
        case .standard(let label, _, _):
            return label.isEmpty
        case .cueState(let state):
            return state == .normal
        }
    }
}

struct TooltipActiveItem: Equatable {
    let targetID: UUID
    let surface: TooltipSurface
    let scenarioID: String
    var anchorRect: CGRect
    var content: TooltipContent
    var isPlayerChrome: Bool = false
}

enum TooltipGeometry {
    static let gap: CGFloat = WorkbenchControlMetrics.redesignSpacing2
    static let windowSafeMargin: CGFloat = WorkbenchControlMetrics.redesignSpacing2
    static let maxWidth: CGFloat = WorkbenchControlMetrics.redesignTooltipMaxWidth
    static let truncatedTextMaxWidth: CGFloat = max(
        0,
        maxWidth - WorkbenchControlMetrics.redesignControlPaddingX * 2
    )
    static let inlineShortcutSpacing: CGFloat = WorkbenchControlMetrics.redesignSpacing2
    static let keycapSpacing: CGFloat = WorkbenchControlMetrics.redesignSpacing1

    static func frame(
        anchor: CGRect,
        size: CGSize,
        visibleRect: CGRect
    ) -> CGRect {
        let minX = visibleRect.minX + windowSafeMargin
        let maxX = max(minX, visibleRect.maxX - windowSafeMargin - size.width)
        let minY = visibleRect.minY + windowSafeMargin
        let maxY = max(minY, visibleRect.maxY - windowSafeMargin - size.height)

        let preferredX = anchor.midX - size.width / 2
        let x = min(max(preferredX, minX), maxX)

        let preferredTopY = anchor.minY - gap - size.height
        let y: CGFloat
        if preferredTopY >= minY {
            y = min(preferredTopY, maxY)
        } else {
            let preferredBottomY = anchor.maxY + gap
            y = min(max(preferredBottomY, minY), maxY)
        }

        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    static func isTextTruncated(
        intrinsicWidth: CGFloat,
        renderedWidth: CGFloat
    ) -> Bool {
        renderedWidth > 0 && intrinsicWidth > renderedWidth + 0.5
    }
}

@MainActor
final class TooltipCenter: ObservableObject {
    static let shared = TooltipCenter(installEventMonitors: true)
    nonisolated static let defaultHoverDelay: TimeInterval =
        WorkbenchControlMetrics.redesignTooltipHoverDelay
    nonisolated static let defaultSkipWindowDelay: TimeInterval =
        WorkbenchControlMetrics.redesignTooltipSkipWindowDelay

    struct HoveredTarget: Equatable {
        let targetID: UUID
        let surface: TooltipSurface
        let scenarioID: String
        var anchorRect: CGRect
        var content: TooltipContent
        var hoverDelay: TimeInterval
        var isPlayerChrome: Bool = false
    }

    @Published private(set) var activeItem: TooltipActiveItem?
    private(set) var hoveredTarget: HoveredTarget?
    private(set) var suppressedTargetID: UUID?
    private(set) var lastHoverDismissedAt: Date?
    let skipWindowDelay: TimeInterval
    private let now: () -> Date
    private var hoverTask: Task<Void, Never>?
    private var localEventMonitor: Any?
    private var notificationObservers: [NSObjectProtocol] = []

    init(
        installEventMonitors: Bool = false,
        skipWindowDelay: TimeInterval = TooltipCenter.defaultSkipWindowDelay,
        now: @escaping () -> Date = Date.init
    ) {
        self.skipWindowDelay = skipWindowDelay
        self.now = now
        if installEventMonitors {
            setUpEventMonitors()
        }
    }

    private func isWithinSkipWindow(at date: Date) -> Bool {
        guard let lastHoverDismissedAt else {
            return false
        }
        let elapsed = date.timeIntervalSince(lastHoverDismissedAt)
        return elapsed >= 0 && elapsed <= skipWindowDelay
    }

    func hoverBegan(
        targetID: UUID,
        surface: TooltipSurface = .main,
        scenarioID: String,
        anchorRect: CGRect,
        content: TooltipContent,
        hoverDelay: TimeInterval = TooltipCenter.defaultHoverDelay,
        isPlayerChrome: Bool = false
    ) {
        guard !content.isEmpty, anchorRect.width > 0, anchorRect.height > 0 else {
            hoverEnded(targetID: targetID)
            return
        }

        if hoveredTarget?.targetID == targetID {
            updateTarget(
                targetID: targetID,
                surface: surface,
                scenarioID: scenarioID,
                anchorRect: anchorRect,
                content: content,
                hoverDelay: hoverDelay,
                isPlayerChrome: isPlayerChrome
            )
            return
        }

        hoverTask?.cancel()
        hoverTask = nil
        if suppressedTargetID != targetID {
            suppressedTargetID = nil
        }

        let target = HoveredTarget(
            targetID: targetID,
            surface: surface,
            scenarioID: scenarioID,
            anchorRect: anchorRect,
            content: content,
            hoverDelay: hoverDelay,
            isPlayerChrome: isPlayerChrome
        )
        hoveredTarget = target

        let shouldSkipDelay = activeItem != nil || isWithinSkipWindow(at: now())
        lastHoverDismissedAt = nil

        guard suppressedTargetID != targetID else {
            if activeItem != nil {
                activeItem = nil
            }
            return
        }

        if shouldSkipDelay {
            activeItem = TooltipActiveItem(
                targetID: target.targetID,
                surface: target.surface,
                scenarioID: target.scenarioID,
                anchorRect: target.anchorRect,
                content: target.content,
                isPlayerChrome: target.isPlayerChrome
            )
        } else {
            if activeItem != nil {
                activeItem = nil
            }
            scheduleShow(for: target)
        }
    }

    func updateAnchor(
        targetID: UUID,
        anchorRect: CGRect,
        content: TooltipContent
    ) {
        guard let current = hoveredTarget, current.targetID == targetID else {
            return
        }
        updateTarget(
            targetID: targetID,
            surface: current.surface,
            scenarioID: current.scenarioID,
            anchorRect: anchorRect,
            content: content,
            hoverDelay: current.hoverDelay,
            isPlayerChrome: current.isPlayerChrome
        )
    }

    func updateTarget(
        targetID: UUID,
        surface: TooltipSurface = .main,
        scenarioID: String,
        anchorRect: CGRect,
        content: TooltipContent,
        hoverDelay: TimeInterval = TooltipCenter.defaultHoverDelay,
        isPlayerChrome: Bool = false
    ) {
        guard hoveredTarget?.targetID == targetID else {
            return
        }
        guard !content.isEmpty, anchorRect.width > 0, anchorRect.height > 0 else {
            hoverEnded(targetID: targetID)
            return
        }

        hoveredTarget = HoveredTarget(
            targetID: targetID,
            surface: surface,
            scenarioID: scenarioID,
            anchorRect: anchorRect,
            content: content,
            hoverDelay: hoverDelay,
            isPlayerChrome: isPlayerChrome
        )

        if activeItem?.targetID == targetID {
            activeItem = TooltipActiveItem(
                targetID: targetID,
                surface: surface,
                scenarioID: scenarioID,
                anchorRect: anchorRect,
                content: content,
                isPlayerChrome: isPlayerChrome
            )
        }
    }

    func hoverEnded(targetID: UUID, allowSkipWindow: Bool = true) {
        if suppressedTargetID == targetID {
            suppressedTargetID = nil
        }
        if hoveredTarget?.targetID == targetID {
            hoverTask?.cancel()
            hoverTask = nil
            hoveredTarget = nil
        }
        if activeItem?.targetID == targetID {
            activeItem = nil
            lastHoverDismissedAt = allowSkipWindow ? now() : nil
        }
    }

    func hideImmediately() {
        hoverTask?.cancel()
        hoverTask = nil
        lastHoverDismissedAt = nil
        if let currentTargetID = hoveredTarget?.targetID {
            suppressedTargetID = currentTargetID
        }
        if activeItem != nil {
            activeItem = nil
        }
    }

    func dismissFromUserInteraction() {
        hideImmediately()
    }

    func dismiss() {
        hoverTask?.cancel()
        hoverTask = nil
        hoveredTarget = nil
        suppressedTargetID = nil
        lastHoverDismissedAt = nil
        if activeItem != nil {
            activeItem = nil
        }
    }

    /// Immediately reveals the pending hovered target if its delay has elapsed (used in deterministic tests).
    func revealPendingNowForTesting() {
        guard let target = hoveredTarget,
              suppressedTargetID != target.targetID
        else {
            return
        }
        hoverTask?.cancel()
        hoverTask = nil
        lastHoverDismissedAt = nil
        activeItem = TooltipActiveItem(
            targetID: target.targetID,
            surface: target.surface,
            scenarioID: target.scenarioID,
            anchorRect: target.anchorRect,
            content: target.content,
            isPlayerChrome: target.isPlayerChrome
        )
    }

    private func scheduleShow(for target: HoveredTarget) {
        let delayNanoseconds = UInt64(max(0, target.hoverDelay) * 1_000_000_000)
        let targetID = target.targetID
        hoverTask = Task { [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else {
                return
            }
            guard let self,
                  let current = self.hoveredTarget,
                  current.targetID == targetID,
                  self.suppressedTargetID != targetID
            else {
                return
            }
            self.activeItem = TooltipActiveItem(
                targetID: current.targetID,
                surface: current.surface,
                scenarioID: current.scenarioID,
                anchorRect: current.anchorRect,
                content: current.content,
                isPlayerChrome: current.isPlayerChrome
            )
        }
    }

    private func setUpEventMonitors() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .leftMouseDown,
                .rightMouseDown,
                .otherMouseDown,
                .scrollWheel,
                .keyDown,
            ]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.dismissFromUserInteraction()
            }
            return event
        }

        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didResignKeyNotification,
            NSWindow.willCloseNotification,
            NSApplication.didResignActiveNotification,
        ]
        for name in names {
            let token = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.dismiss()
                }
            }
            notificationObservers.append(token)
        }
    }
}

private struct IsPlayerUIVisibleKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isPlayerUIVisible: Bool {
        get { self[IsPlayerUIVisibleKey.self] }
        set { self[IsPlayerUIVisibleKey.self] = newValue }
    }
}

private struct TooltipMeasuredSizeKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0 && next.height > 0 {
            value = next
        }
    }
}

struct TooltipOverlayView: View {
    let surface: TooltipSurface
    @ObservedObject var center: TooltipCenter = .shared
    @EnvironmentObject private var shortcuts: PlaybackShortcutStore
    @EnvironmentObject private var localization: AppLocalizationStore

    var body: some View {
        GeometryReader { proxy in
            if let item = center.activeItem, item.surface == surface {
                TooltipActiveBubbleView(
                    item: item,
                    visibleSize: proxy.size,
                    keymap: shortcuts.keymap
                )
                .id(item.targetID)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct TooltipActiveBubbleView: View {
    let item: TooltipActiveItem
    let visibleSize: CGSize
    let keymap: PlaybackShortcutKeymap
    @State private var measuredSize: CGSize = .zero

    var body: some View {
        let frame = TooltipGeometry.frame(
            anchor: item.anchorRect,
            size: measuredSize,
            visibleRect: CGRect(origin: .zero, size: visibleSize)
        )

        tooltipContent
            .background(
                GeometryReader { bubbleProxy in
                    Color.clear.preference(
                        key: TooltipMeasuredSizeKey.self,
                        value: bubbleProxy.size
                    )
                }
            )
            .onPreferenceChange(TooltipMeasuredSizeKey.self) { newSize in
                if newSize.width > 0 && newSize.height > 0 && measuredSize != newSize {
                    measuredSize = newSize
                }
            }
            .position(x: frame.midX, y: frame.midY)
            .opacity(measuredSize.width > 0 && measuredSize.height > 0 ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("workbench-tooltip-\(item.scenarioID)")
    }

    @ViewBuilder
    private var tooltipContent: some View {
        switch item.content {
        case .standard(let label, let shortcut, let wrapsText):
            TooltipStandardBubbleView(
                label: label,
                keycaps: shortcut.resolvedKeycaps(keymap: keymap),
                wrapsText: wrapsText,
                isPlayerChrome: item.isPlayerChrome
            )
        case .cueState(let state):
            TooltipStandardBubbleView(
                label: state.tooltipMessage ?? "",
                keycaps: [],
                wrapsText: false,
                isPlayerChrome: item.isPlayerChrome
            )
        }
    }
}

private struct TooltipWrappingTextLayout: Layout {
    let maxWidth: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return .zero
        }
        let naturalSize = subview.sizeThatFits(.unspecified)
        let allowedWidth = min(maxWidth, proposal.width ?? maxWidth)
        guard naturalSize.width > allowedWidth, allowedWidth > 0 else {
            return naturalSize
        }
        let wrappedSize = subview.sizeThatFits(
            ProposedViewSize(width: allowedWidth, height: nil)
        )
        return CGSize(width: allowedWidth, height: wrappedSize.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else {
            return
        }
        subview.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}

struct TooltipStandardBubbleView: View {
    let label: String
    let keycaps: [PlaybackCueFooterKeycap]
    let wrapsText: Bool
    let isPlayerChrome: Bool

    init(
        label: String,
        keycaps: [PlaybackCueFooterKeycap] = [],
        wrapsText: Bool,
        isPlayerChrome: Bool = false
    ) {
        self.label = label
        self.keycaps = keycaps
        self.wrapsText = wrapsText
        self.isPlayerChrome = isPlayerChrome
    }

    var resolvedLabelColor: Color {
        isPlayerChrome ? PlaybackTheme.textPrimary : WorkbenchRedesignColors.tooltipText
    }

    var resolvedKeycapBackground: Color {
        isPlayerChrome ? PlaybackTheme.keycapBackground : WorkbenchRedesignColors.popoverSurfaceKeycapBg
    }

    var resolvedKeycapForeground: Color {
        isPlayerChrome ? PlaybackTheme.textPrimary : WorkbenchRedesignColors.textMuted
    }

    var showsSurfaceBorder: Bool {
        !isPlayerChrome
    }

    var body: some View {
        Group {
            if wrapsText {
                TooltipWrappingTextLayout(maxWidth: TooltipGeometry.truncatedTextMaxWidth) {
                    Text(label)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeControl,
                            weight: WorkbenchControlMetrics.redesignFontWeightControl
                        ))
                        .foregroundStyle(resolvedLabelColor)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
                .padding(.vertical, WorkbenchControlMetrics.redesignTooltipVerticalPadding)
            } else {
                HStack(spacing: TooltipGeometry.inlineShortcutSpacing) {
                    Text(label)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeControl,
                            weight: WorkbenchControlMetrics.redesignFontWeightControl
                        ))
                        .foregroundStyle(resolvedLabelColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    if !keycaps.isEmpty {
                        HStack(spacing: TooltipGeometry.keycapSpacing) {
                            ForEach(keycaps.indices, id: \.self) { index in
                                PlaybackCueFooterKeycapView(
                                    keycap: keycaps[index],
                                    background: resolvedKeycapBackground
                                )
                            }
                        }
                        .foregroundStyle(resolvedKeycapForeground)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
                .frame(height: WorkbenchControlMetrics.redesignHeight)
            }
        }
        .background(
            TooltipSurfaceBackground(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                isPlayerChrome: isPlayerChrome
            )
        )
    }
}

struct TooltipSurfaceBackground: View {
    let cornerRadius: CGFloat
    var isPlayerChrome = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if isPlayerChrome {
            shape
                .fill(PlaybackTheme.menuBackground)
                .shadow(
                    color: PlaybackTheme.overlayShadowColor,
                    radius: PlaybackTheme.overlayShadowRadius,
                    y: PlaybackTheme.overlayShadowYOffset
                )
        } else {
            shape
                .fill(WorkbenchRedesignColors.tooltipBg)
                .shadowToken(
                    WorkbenchRedesignColors.shadowPopover,
                    cornerRadius: cornerRadius
                )
                .overlay(
                    shape.strokeBorder(
                        WorkbenchRedesignColors.tooltipBorder,
                        lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                    )
                )
        }
    }
}

private struct TooltipModifier: ViewModifier {
    let scenarioID: String
    let surface: TooltipSurface
    let isActive: Bool
    let content: TooltipContent
    let hoverDelay: TimeInterval

    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.isPlayerUIVisible) private var isPlayerUIVisible
    @State private var targetID = UUID()

    private var effectiveIsActive: Bool {
        isActive
            && !content.isEmpty
            && !layerContext.isFrozen
            && isPlayerUIVisible
    }

    func body(content viewContent: Content) -> some View {
        viewContent.background(
            TooltipTrackingRepresentable(
                targetID: targetID,
                surface: surface,
                scenarioID: scenarioID,
                isActive: effectiveIsActive,
                content: content,
                hoverDelay: hoverDelay,
                isPlayerChrome: layerContext.layer == .playbackPage
            )
        )
    }
}

private struct TooltipTrackingRepresentable: NSViewRepresentable {
    let targetID: UUID
    let surface: TooltipSurface
    let scenarioID: String
    let isActive: Bool
    let content: TooltipContent
    let hoverDelay: TimeInterval
    let isPlayerChrome: Bool

    func makeNSView(context: Context) -> TooltipTrackingNSView {
        let view = TooltipTrackingNSView()
        view.configure(
            targetID: targetID,
            surface: surface,
            scenarioID: scenarioID,
            isActive: isActive,
            content: content,
            hoverDelay: hoverDelay,
            isPlayerChrome: isPlayerChrome
        )
        return view
    }

    func updateNSView(_ nsView: TooltipTrackingNSView, context: Context) {
        nsView.configure(
            targetID: targetID,
            surface: surface,
            scenarioID: scenarioID,
            isActive: isActive,
            content: content,
            hoverDelay: hoverDelay,
            isPlayerChrome: isPlayerChrome
        )
    }

    static func dismantleNSView(_ nsView: TooltipTrackingNSView, coordinator: ()) {
        let id = nsView.targetID
        MainActor.assumeIsolated {
            TooltipCenter.shared.hoverEnded(targetID: id, allowSkipWindow: false)
        }
    }
}

final class TooltipTrackingNSView: NSView {
    private(set) var targetID = UUID()
    private var surface: TooltipSurface = .main
    private var scenarioID = ""
    private var isActive = false
    private var content: TooltipContent = .standard(label: "", shortcut: .none, wrapsText: false)
    private var hoverDelay: TimeInterval = TooltipCenter.defaultHoverDelay
    private var isPlayerChrome = false
    private var trackingAreaRef: NSTrackingArea?
    private var isPointerInside = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func configure(
        targetID: UUID,
        surface: TooltipSurface,
        scenarioID: String,
        isActive: Bool,
        content: TooltipContent,
        hoverDelay: TimeInterval,
        isPlayerChrome: Bool = false
    ) {
        self.targetID = targetID
        self.surface = surface
        self.scenarioID = scenarioID
        self.isActive = isActive
        self.content = content
        self.hoverDelay = hoverDelay
        self.isPlayerChrome = isPlayerChrome

        guard isActive, window != nil else {
            if isPointerInside {
                isPointerInside = false
            }
            TooltipCenter.shared.hoverEnded(targetID: targetID, allowSkipWindow: false)
            return
        }

        if isPointerInside, let anchorRect = anchorRectInWindow() {
            TooltipCenter.shared.updateTarget(
                targetID: targetID,
                surface: surface,
                scenarioID: scenarioID,
                anchorRect: anchorRect,
                content: content,
                hoverDelay: hoverDelay,
                isPlayerChrome: isPlayerChrome
            )
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [
                .mouseEnteredAndExited,
                .activeInKeyWindow,
                .inVisibleRect,
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            isPointerInside = false
            TooltipCenter.shared.hoverEnded(targetID: targetID, allowSkipWindow: false)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isPointerInside = true
        guard isActive, let anchorRect = anchorRectInWindow() else {
            return
        }
        TooltipCenter.shared.hoverBegan(
            targetID: targetID,
            surface: surface,
            scenarioID: scenarioID,
            anchorRect: anchorRect,
            content: content,
            hoverDelay: hoverDelay,
            isPlayerChrome: isPlayerChrome
        )
    }

    override func mouseExited(with event: NSEvent) {
        isPointerInside = false
        TooltipCenter.shared.hoverEnded(targetID: targetID)
    }

    func anchorRectInWindow() -> CGRect? {
        guard let window,
              let contentView = window.contentView,
              bounds.width > 0,
              bounds.height > 0
        else {
            return nil
        }
        let rectInWindow = convert(bounds, to: nil)
        let contentHeight = contentView.bounds.height
        return CGRect(
            x: rectInWindow.minX,
            y: contentHeight - rectInWindow.maxY,
            width: rectInWindow.width,
            height: rectInWindow.height
        )
    }
}

private struct TruncatedTextRenderedWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TruncatedTextIntrinsicWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TextTruncationObserverModifier: ViewModifier {
    let text: String
    let font: Font
    let onChange: (Bool) -> Void

    @State private var renderedWidth: CGFloat = 0
    @State private var intrinsicWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TruncatedTextRenderedWidthKey.self,
                        value: proxy.size.width
                    )
                }
            )
            .background(
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TruncatedTextIntrinsicWidthKey.self,
                                value: proxy.size.width
                            )
                        }
                    )
            )
            .onPreferenceChange(TruncatedTextRenderedWidthKey.self) { width in
                renderedWidth = width
                reportTruncation()
            }
            .onPreferenceChange(TruncatedTextIntrinsicWidthKey.self) { width in
                intrinsicWidth = width
                reportTruncation()
            }
    }

    private func reportTruncation() {
        onChange(
            TooltipGeometry.isTextTruncated(
                intrinsicWidth: intrinsicWidth,
                renderedWidth: renderedWidth
            )
        )
    }
}

private struct TruncatedTextTooltipModifier: ViewModifier {
    let scenarioID: String
    let surface: TooltipSurface
    let text: String
    let font: Font

    @State private var isTruncated = false

    func body(content: Content) -> some View {
        content
            .onTextTruncationChange(text: text, font: font) { truncated in
                if isTruncated != truncated {
                    isTruncated = truncated
                }
            }
            .workbenchTooltip(
                scenarioID: scenarioID,
                surface: surface,
                isActive: isTruncated,
                label: text,
                wrapsText: true
            )
    }
}

extension View {
    func workbenchTooltip(
        scenarioID: String,
        surface: TooltipSurface = .main,
        isActive: Bool = true,
        label: String,
        shortcut: TooltipShortcut = .none,
        wrapsText: Bool = false,
        hoverDelay: TimeInterval = TooltipCenter.defaultHoverDelay
    ) -> some View {
        modifier(
            TooltipModifier(
                scenarioID: scenarioID,
                surface: surface,
                isActive: isActive,
                content: .standard(
                    label: label,
                    shortcut: shortcut,
                    wrapsText: wrapsText
                ),
                hoverDelay: hoverDelay
            )
        )
    }

    func onTextTruncationChange(
        text: String,
        font: Font,
        perform action: @escaping (Bool) -> Void
    ) -> some View {
        modifier(
            TextTruncationObserverModifier(
                text: text,
                font: font,
                onChange: action
            )
        )
    }

    func workbenchTruncatedTextTooltip(
        scenarioID: String,
        surface: TooltipSurface = .main,
        text: String,
        font: Font
    ) -> some View {
        modifier(
            TruncatedTextTooltipModifier(
                scenarioID: scenarioID,
                surface: surface,
                text: text,
                font: font
            )
        )
    }
}
