import AppKit
import SwiftUI

struct WorkbenchAdaptiveHeaderGeometry: Equatable {
    let leadingFrame: CGRect
    let centerFrame: CGRect
    let trailingFrame: CGRect

    static func resolve(
        containerSize: CGSize,
        leadingNaturalSize: CGSize,
        centerNaturalSize: CGSize,
        trailingNaturalSize: CGSize,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
        minimumGap: CGFloat = WorkbenchControlMetrics.redesignSpacing3
    ) -> WorkbenchAdaptiveHeaderGeometry {
        let containerWidth = max(0, containerSize.width)
        let containerHeight = max(0, containerSize.height)
        let resolvedLeadingInset = max(0, leadingInset)
        let resolvedTrailingInset = max(0, trailingInset)
        let resolvedGap = max(0, minimumGap)

        let leadingNaturalWidth = max(0, leadingNaturalSize.width)
        let centerWidth = max(0, centerNaturalSize.width)
        let trailingWidth = max(0, trailingNaturalSize.width)

        let trailingMinX = containerWidth - resolvedTrailingInset - trailingWidth
        let trailingY = (containerHeight - trailingNaturalSize.height) / 2
        let trailingFrame = CGRect(
            x: trailingMinX,
            y: trailingY,
            width: trailingWidth,
            height: trailingNaturalSize.height
        )

        let centerFrame: CGRect
        let leadingMaxWidth: CGFloat

        if centerWidth > 0 {
            let idealCenterMinX = (containerWidth - centerWidth) / 2
            let minCenterMinX = resolvedLeadingInset + leadingNaturalWidth + resolvedGap
            let maxCenterMinX = trailingMinX - resolvedGap - centerWidth
            let centerMinX = min(max(idealCenterMinX, minCenterMinX), maxCenterMinX)
            let centerY = (containerHeight - centerNaturalSize.height) / 2
            centerFrame = CGRect(
                x: centerMinX,
                y: centerY,
                width: centerWidth,
                height: centerNaturalSize.height
            )
            leadingMaxWidth = max(0, centerMinX - resolvedGap - resolvedLeadingInset)
        } else {
            centerFrame = CGRect(
                x: containerWidth / 2,
                y: containerHeight / 2,
                width: 0,
                height: 0
            )
            leadingMaxWidth = max(0, trailingMinX - resolvedGap - resolvedLeadingInset)
        }

        let leadingWidth = min(leadingNaturalWidth, leadingMaxWidth)
        let leadingY = (containerHeight - leadingNaturalSize.height) / 2
        let leadingFrame = CGRect(
            x: resolvedLeadingInset,
            y: leadingY,
            width: leadingWidth,
            height: leadingNaturalSize.height
        )

        return WorkbenchAdaptiveHeaderGeometry(
            leadingFrame: leadingFrame,
            centerFrame: centerFrame,
            trailingFrame: trailingFrame
        )
    }
}

struct WorkbenchAdaptiveHeaderBarLayout: Layout {
    let leadingInset: CGFloat
    let trailingInset: CGFloat
    var minimumGap: CGFloat = WorkbenchControlMetrics.redesignSpacing3

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let naturalHeight = subviews.reduce(CGFloat.zero) { current, subview in
            max(current, subview.sizeThatFits(.unspecified).height)
        }
        return CGSize(
            width: proposal.width ?? 0,
            height: proposal.height ?? naturalHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 3 else {
            return
        }

        let leadingNaturalSize = subviews[0].sizeThatFits(.unspecified)
        let centerNaturalSize = subviews[1].sizeThatFits(.unspecified)
        let trailingNaturalSize = subviews[2].sizeThatFits(.unspecified)

        let geometry = WorkbenchAdaptiveHeaderGeometry.resolve(
            containerSize: bounds.size,
            leadingNaturalSize: leadingNaturalSize,
            centerNaturalSize: centerNaturalSize,
            trailingNaturalSize: trailingNaturalSize,
            leadingInset: leadingInset,
            trailingInset: trailingInset,
            minimumGap: minimumGap
        )

        let leadingProposal = ProposedViewSize(
            width: geometry.leadingFrame.width,
            height: leadingNaturalSize.height
        )
        let leadingFittedHeight = subviews[0].sizeThatFits(leadingProposal).height
        let leadingY = bounds.minY + (bounds.height - leadingFittedHeight) / 2
        subviews[0].place(
            at: CGPoint(
                x: bounds.minX + geometry.leadingFrame.minX,
                y: leadingY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: geometry.leadingFrame.width,
                height: leadingFittedHeight
            )
        )

        subviews[1].place(
            at: CGPoint(
                x: bounds.minX + geometry.centerFrame.minX,
                y: bounds.minY + geometry.centerFrame.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: geometry.centerFrame.width,
                height: centerNaturalSize.height
            )
        )

        subviews[2].place(
            at: CGPoint(
                x: bounds.minX + geometry.trailingFrame.minX,
                y: bounds.minY + geometry.trailingFrame.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: geometry.trailingFrame.width,
                height: trailingNaturalSize.height
            )
        )
    }
}

struct WorkbenchAdaptiveHeaderBar<
    Leading: View,
    Center: View,
    Trailing: View
>: View {
    let leadingInset: CGFloat
    let trailingInset: CGFloat
    var minimumGap: CGFloat = WorkbenchControlMetrics.redesignSpacing3
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let center: () -> Center
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        WorkbenchAdaptiveHeaderBarLayout(
            leadingInset: leadingInset,
            trailingInset: trailingInset,
            minimumGap: minimumGap
        ) {
            HStack(spacing: 0) {
                leading()
            }
            HStack(spacing: 0) {
                center()
            }
            HStack(spacing: 0) {
                trailing()
            }
        }
    }
}

struct AppTopbarLayout<
    Content: View,
    TrailingContent: View,
    SidebarToggle: View,
    CenterContent: View,
    OverlaySidebarContent: View
>: View {
    let isDockedSidebarVisible: Bool
    let isOverlaySidebarVisible: Bool
    let isAppFullscreen: Bool
    let onDoubleClickZoom: (NSWindow) -> Bool
    @ViewBuilder let content: () -> Content
    /// The trailing function region. It holds what belongs to the App rather
    /// than to the page below, so it is the same in every workbench page.
    @ViewBuilder let trailingContent: () -> TrailingContent
    @ViewBuilder let centerContent: () -> CenterContent
    @ViewBuilder let sidebarToggle: () -> SidebarToggle
    @ViewBuilder let overlaySidebar: () -> OverlaySidebarContent

    init(
        isDockedSidebarVisible: Bool,
        isOverlaySidebarVisible: Bool = false,
        isAppFullscreen: Bool,
        onDoubleClickZoom: @escaping (NSWindow) -> Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent,
        @ViewBuilder centerContent: @escaping () -> CenterContent,
        @ViewBuilder sidebarToggle: @escaping () -> SidebarToggle,
        @ViewBuilder overlaySidebar: @escaping () -> OverlaySidebarContent = { EmptyView() }
    ) {
        self.isDockedSidebarVisible = isDockedSidebarVisible
        self.isOverlaySidebarVisible = isOverlaySidebarVisible
        self.isAppFullscreen = isAppFullscreen
        self.onDoubleClickZoom = onDoubleClickZoom
        self.content = content
        self.trailingContent = trailingContent
        self.centerContent = centerContent
        self.sidebarToggle = sidebarToggle
        self.overlaySidebar = overlaySidebar
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            topbarBand

            ZStack(alignment: .topLeading) {
                if isOverlaySidebarVisible {
                    overlaySidebar()
                        .frame(width: AppShellLayout.sidebarWidth)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(isOverlaySidebarVisible)

            leadingControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LayoutPerformanceProbe(name: "AppTopbarLayout.layout"))
    }

    private var topbarBand: some View {
        TitlebarBackgroundView(
            backgroundColor: WorkbenchRedesignColors.NS.appTopbarBg,
            onDoubleClickZoom: onDoubleClickZoom
        )
        .overlay(alignment: .leading) {
            if isDockedSidebarVisible {
                WorkbenchRedesignColors.appSidebarBg
                    .frame(width: AppShellLayout.sidebarWidth)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            functionRegion
        }
        .frame(height: WorkbenchControlMetrics.redesignWorkbenchTopbarHeight)
        .simultaneousGesture(
            TapGesture().onEnded {
                NotificationCenter.default.post(name: .topbarDismissMenusRequested, object: nil)
            }
        )
    }

    private var functionRegion: some View {
        GeometryReader { proxy in
            let regionWidth = max(0, proxy.size.width - regionLeadingEdge)

            WorkbenchAdaptiveHeaderBar(
                leadingInset: rowLeadingInset,
                trailingInset: WorkbenchControlMetrics.redesignAppTopbarContentTrailingPadding,
                minimumGap: WorkbenchControlMetrics.redesignSpacing3,
                leading: content,
                center: centerContent,
                trailing: trailingContent
            )
            .frame(width: regionWidth, height: proxy.size.height, alignment: .leading)
            .clipped()
            .offset(x: regionLeadingEdge)
        }
    }

    private var leadingControls: some View {
        sidebarToggle()
            .frame(
                width: AppShellLayout.sidebarToggleSize,
                height: AppShellLayout.sidebarToggleSize
            )
            // On the window controls' centre line, not the taller bar's.
            .padding(.leading, sidebarToggleHandleX)
            .padding(
                .top,
                (WorkbenchControlMetrics.redesignWindowControlsBandHeight - AppShellLayout.sidebarToggleSize) / 2
            )
    }

    /// Where the function region starts: after the docked sidebar segment, or
    /// at the window's leading edge when the sidebar is collapsed or overlaid.
    private var regionLeadingEdge: CGFloat {
        isDockedSidebarVisible ? AppShellLayout.sidebarWidth : 0
    }

    private var rowLeadingInset: CGFloat {
        if isDockedSidebarVisible {
            return WorkbenchControlMetrics.redesignAppTopbarContentHorizontalPadding
        }

        return max(
            WorkbenchControlMetrics.redesignAppTopbarContentHorizontalPadding,
            sidebarToggleHandleX
                + AppShellLayout.sidebarToggleSize
                + WorkbenchControlMetrics.redesignAppTopbarContentAfterToggleGap
        )
    }

    private var sidebarToggleHandleX: CGFloat {
        let collapsedX = isAppFullscreen
            ? AppShellLayout.modeControlsOuterPadding
            : AppShellLayout.collapsedLeadingToggleX

        guard isDockedSidebarVisible else {
            return collapsedX
        }

        return max(
            collapsedX,
            AppShellLayout.sidebarWidth
                - AppShellLayout.modeControlsOuterPadding
                - AppShellLayout.sidebarToggleSize
        )
    }
}

struct OverlaySidebarPointerMonitorView: NSViewRepresentable {
    let onMouseLeave: () -> Void

    func makeNSView(context: Context) -> OverlaySidebarPointerMonitorNSView {
        let view = OverlaySidebarPointerMonitorNSView()
        view.onMouseLeave = onMouseLeave
        return view
    }

    func updateNSView(_ nsView: OverlaySidebarPointerMonitorNSView, context: Context) {
        nsView.onMouseLeave = onMouseLeave
    }
}

final class OverlaySidebarPointerMonitorNSView: NSView {
    var onMouseLeave: (() -> Void)?
    var entranceCooldownDuration: TimeInterval = AppShellLayout.sidePanelAnimationDuration
    private var trackingAreaRef: NSTrackingArea?
    private var localEventMonitor: Any?
    private var activatedUptime: TimeInterval?
    private var cooldownWorkItem: DispatchWorkItem?
    private var hasTriggeredCollapse = false

    static func shouldCollapseForPointerLocation(
        _ pointInSidebar: CGPoint,
        sidebarBounds: CGRect,
        isWithinEntranceCooldown: Bool = false
    ) -> Bool {
        guard !isWithinEntranceCooldown,
              sidebarBounds.width > 0,
              sidebarBounds.height > 0
        else {
            return false
        }
        return pointInSidebar.x > sidebarBounds.maxX
    }

    var isWithinEntranceCooldown: Bool {
        guard let activatedUptime, entranceCooldownDuration > 0 else {
            return false
        }
        return ProcessInfo.processInfo.systemUptime - activatedUptime < entranceCooldownDuration
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
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
                .mouseMoved,
                .activeAlways,
                .assumeInside,
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            hasTriggeredCollapse = false
            activatedUptime = ProcessInfo.processInfo.systemUptime
            installEventMonitorIfNeeded()
            scheduleCooldownCompletionCheck()
        } else {
            cooldownWorkItem?.cancel()
            cooldownWorkItem = nil
            activatedUptime = nil
            removeEventMonitor()
        }
    }

    deinit {
        cooldownWorkItem?.cancel()
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        evaluatePointerEvent(event)
    }

    override func mouseExited(with event: NSEvent) {
        evaluatePointerEvent(event)
    }

    func evaluatePointerLocationInWindow(_ locationInWindow: CGPoint) {
        guard !hasTriggeredCollapse else {
            return
        }
        let point = convert(locationInWindow, from: nil)
        if Self.shouldCollapseForPointerLocation(
            point,
            sidebarBounds: bounds,
            isWithinEntranceCooldown: isWithinEntranceCooldown
        ) {
            hasTriggeredCollapse = true
            onMouseLeave?()
        }
    }

    private func evaluatePointerEvent(_ event: NSEvent) {
        guard let window, event.window === window else {
            return
        }
        evaluatePointerLocationInWindow(event.locationInWindow)
    }

    private func scheduleCooldownCompletionCheck() {
        cooldownWorkItem?.cancel()
        guard entranceCooldownDuration > 0 else {
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let window = self.window else {
                return
            }
            self.evaluatePointerLocationInWindow(window.mouseLocationOutsideOfEventStream)
        }
        cooldownWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + entranceCooldownDuration,
            execute: workItem
        )
    }

    private func installEventMonitorIfNeeded() {
        guard localEventMonitor == nil else {
            return
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.evaluatePointerEvent(event)
            return event
        }
    }

    private func removeEventMonitor() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }
}

