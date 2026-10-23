import AppKit
import CueSeekerCore
import SwiftUI

// MARK: - Container and header

final class SubtitleTableContainerView: NSView {
    var onLayout: (() -> Void)?

    /// The document, the header, the page chrome viewport and the menu overlay
    /// all measure downward from their top edge. The container was the one view
    /// left measuring upward, so every frame placed directly in it had to be
    /// mirrored by hand. It measures downward too now, and the whole table
    /// speaks one direction.
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyAppearanceColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        onLayout?()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearanceColors()
    }

    private func applyAppearanceColors() {
        guard let layer else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.cornerRadius = 0
            layer.borderWidth = 0
            layer.masksToBounds = false
            layer.backgroundColor = WorkbenchRedesignColors.NS.bgSurface.cgColor
        }
    }
}

final class SubtitleTablePageChromeViewportView: NSView {
    weak var scrollView: NSScrollView?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }

    override func scrollWheel(with event: NSEvent) {
        scrollView?.scrollWheel(with: event)
    }
}

final class SubtitleTableOutlineOverlayView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            super.draw(dirtyRect)
            guard let outlineRect = coordinator?.tableOutlineFrameInContainer(),
                  outlineRect.width > 1,
                  outlineRect.height > 1
            else {
                return
            }
            let radius = WorkbenchControlMetrics.redesignCornerRadius
            let borderWidth = WorkbenchControlMetrics.redesignControlBorderWidth

            let cornerMaskPath = NSBezierPath(rect: outlineRect)
            cornerMaskPath.append(
                NSBezierPath(
                    roundedRect: outlineRect,
                    xRadius: radius,
                    yRadius: radius
                )
            )
            cornerMaskPath.windingRule = .evenOdd
            WorkbenchRedesignColors.NS.bgSurface.setFill()
            cornerMaskPath.fill()

            let strokeRect = outlineRect.insetBy(
                dx: borderWidth / 2,
                dy: borderWidth / 2
            )
            let insetRadius = max(0, radius - borderWidth / 2)
            let borderPath = NSBezierPath(
                roundedRect: strokeRect,
                xRadius: insetRadius,
                yRadius: insetRadius
            )
            borderPath.lineWidth = borderWidth
            WorkbenchRedesignColors.NS.borderControl.setStroke()
            borderPath.stroke()
        }
    }
}

struct SubtitleTableScrollbarMetrics {
    typealias Axis = TableScrollbarAxis

    var viewportSize: CGSize
    var contentSize: CGSize
    var contentOffset: CGPoint

    var presentation: TableScrollbarPresentation {
        TableScrollbarPresentation(
            vertical: axisPresentation(for: .vertical),
            horizontal: axisPresentation(for: .horizontal)
        )
    }

    func isVisible(_ axis: Axis) -> Bool {
        contentLength(for: axis) > viewportLength(for: axis) + 0.5
    }

    func trackRect(for axis: Axis, in bounds: CGRect) -> CGRect? {
        TableScrollbarGeometry(presentation: presentation)
            .trackRect(for: axis, in: bounds)
    }

    func thumbRect(for axis: Axis, in bounds: CGRect) -> CGRect? {
        TableScrollbarGeometry(presentation: presentation)
            .thumbRect(for: axis, in: bounds)
    }

    func interactiveThumbRect(for axis: Axis, in bounds: CGRect) -> CGRect? {
        TableScrollbarGeometry(presentation: presentation)
            .interactiveThumbRect(for: axis, in: bounds)
    }

    func scrollOffset(
        for axis: Axis,
        thumbPosition: CGFloat,
        in bounds: CGRect
    ) -> CGFloat {
        let fraction = TableScrollbarGeometry(presentation: presentation)
            .positionFraction(
                for: axis,
                thumbPosition: thumbPosition,
                in: bounds
            )
        return scrollOffset(for: axis, positionFraction: fraction)
    }

    func scrollOffset(
        for axis: Axis,
        dragStartThumbOrigin: CGFloat,
        dragDelta: CGFloat,
        in bounds: CGRect
    ) -> CGFloat {
        let fraction = TableScrollbarGeometry(presentation: presentation)
            .positionFraction(
                for: axis,
                dragStartThumbOrigin: dragStartThumbOrigin,
                dragDelta: dragDelta,
                in: bounds
            )
        return scrollOffset(for: axis, positionFraction: fraction)
    }

    func scrollOffset(
        for axis: Axis,
        positionFraction: CGFloat
    ) -> CGFloat {
        maxScroll(for: axis) * min(1, max(0, positionFraction))
    }

    private func axisPresentation(
        for axis: Axis
    ) -> TableScrollbarAxisPresentation? {
        guard isVisible(axis) else {
            return nil
        }
        let viewportLength = viewportLength(for: axis)
        let contentLength = contentLength(for: axis)
        let maxScroll = maxScroll(for: axis)
        let offset = axis == .vertical ? contentOffset.y : contentOffset.x
        return TableScrollbarAxisPresentation(
            visibleFraction: contentLength > 0 ? viewportLength / contentLength : 1,
            positionFraction: maxScroll > 0 ? offset / maxScroll : 0
        )
    }

    private func viewportLength(for axis: Axis) -> CGFloat {
        axis == .vertical ? viewportSize.height : viewportSize.width
    }

    private func contentLength(for axis: Axis) -> CGFloat {
        axis == .vertical ? contentSize.height : contentSize.width
    }

    private func maxScroll(for axis: Axis) -> CGFloat {
        max(0, contentLength(for: axis) - viewportLength(for: axis))
    }
}

final class SubtitleTableScrollbarOverlayView: TableScrollbarOverlayView {
    weak var scrollView: NSScrollView? {
        didSet {
            isPresented = scrollView != nil
            scrollbarMetricsDidChange()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        presentationProvider = { [weak self] in
            self?.metrics()?.presentation
        }
        onDrag = { [weak self] event in
            self?.handleDrag(event)
        }
        onScrollWheel = { [weak self] event in
            self?.scrollView?.scrollWheel(with: event)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func scrollMetricsDidChange() {
        scrollbarMetricsDidChange()
    }

    private func handleDrag(_ event: TableScrollbarDragEvent) {
        guard event.phase == .changed,
              let scrollView,
              let metrics = metrics()
        else {
            return
        }

        let nextOffset = metrics.scrollOffset(
            for: event.axis,
            positionFraction: event.positionFraction
        )
        var origin = scrollView.contentView.bounds.origin
        switch event.axis {
        case .vertical:
            origin.y = nextOffset
        case .horizontal:
            origin.x = nextOffset
        }
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        scrollbarMetricsDidChange()
    }

    private func metrics() -> SubtitleTableScrollbarMetrics? {
        guard let scrollView,
              let documentView = scrollView.documentView
        else {
            return nil
        }
        return SubtitleTableScrollbarMetrics(
            viewportSize: scrollView.contentView.bounds.size,
            contentSize: documentView.frame.size,
            contentOffset: scrollView.contentView.bounds.origin
        )
    }
}

final class SubtitleTableHeaderTextOverlayView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func resignFirstResponder() -> Bool {
        coordinator?.cancelPendingTextInteraction()
        return super.resignFirstResponder()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden,
              NSApp.currentEvent?.type == .leftMouseDown,
              let headerView = superview as? SubtitleVirtualTableHeaderView,
              headerView.shouldRouteTextSelectionMouseDown(
                  at: convert(point, to: headerView),
                  excluding: self
              )
        else {
            return nil
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if coordinator?.handleHeaderMouseDown(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if coordinator?.handleMouseDragged(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if coordinator?.handleMouseUp(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseUp(with: event)
    }

    @IBAction override func selectAll(_ sender: Any?) {
        coordinator?.selectAllTableText()
    }

    @IBAction func copy(_ sender: Any?) {
        coordinator?.copyTableTextSelection()
    }
}

final class SubtitleVirtualTableHeaderView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?

    private var indexHeaderHost: NSHostingView<AnyView>?
    private var dateAddedHeaderHost: NSHostingView<AnyView>?
    private var nameHeaderHost: NSHostingView<AnyView>?
    private var timeHeaderHost: NSHostingView<AnyView>?
    private var cuesHeaderHost: NSHostingView<AnyView>?
    private var languageHeaderHost: NSHostingView<AnyView>?
    private var textInteractionOverlay: SubtitleTableHeaderTextOverlayView?
    private var lastHeaderLayout: SubtitleTableColumnLayout?

    private var hoverTracking: NSTrackingArea?
    private var isHeaderHovered = false {
        didSet {
            guard isHeaderHovered != oldValue else { return }
            refreshIndexHeaderHost()
            needsDisplay = true
        }
    }
    private var isIndexHeaderHovered = false {
        didSet {
            guard isIndexHeaderHovered != oldValue else { return }
            refreshIndexHeaderHost()
        }
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Columns shift left with the table's horizontal offset; without this
        // they would draw over the page padding and the vertical Scrollbar.
        wantsLayer = true
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking {
            removeTrackingArea(hoverTracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTracking = area
        updateHoverState()
    }

    /// In Select mode the header is one big select-all target, so everything
    /// but the Checkbox itself routes here; the Checkbox keeps its own click,
    /// hover and focus handling.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        guard let hit,
              coordinator?.acceptsSelectModeHeaderClick == true
        else {
            return hit
        }
        if let checkboxHost = indexHeaderHost,
           !checkboxHost.isHidden,
           hit === checkboxHost || hit.isDescendant(of: checkboxHost) {
            return hit
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        // The action belongs to the release, the same commitment every other
        // control in the App makes.
        guard coordinator?.acceptsSelectModeHeaderClick == true else {
            super.mouseDown(with: event)
            return
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard coordinator?.acceptsSelectModeHeaderClick == true else {
            super.mouseUp(with: event)
            return
        }
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else {
            return
        }
        coordinator?.toggleAllRowSelection()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard let window,
              NSApp.isActive,
              window.isKeyWindow,
              !PointerHoverScrollState.shared.isScrolling
        else {
            return
        }
        updateHoverState(windowLocation: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard !PointerHoverScrollState.shared.isScrolling else {
            return
        }
        updateHoverState(windowLocation: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard let window,
              NSApp.isActive,
              window.isKeyWindow,
              !PointerHoverScrollState.shared.isScrolling
        else {
            return
        }
        updateHoverState(windowLocation: event.locationInWindow)
    }

    func clearHoverState() {
        guard coordinator?.isPointerFrozen != true else {
            return
        }
        isHeaderHovered = false
        isIndexHeaderHovered = false
    }

    func refreshHoverFromWindow() {
        guard !AppCursorVisibility.isCursorHidden,
              !PointerHoverScrollState.shared.isScrolling,
              let window
        else {
            clearHoverState()
            return
        }
        let isWindowFocused = (window as? CueSeekerWindow)?.isFocusedForHover
            ?? (NSApp.isActive && window.isKeyWindow)
        guard isWindowFocused else {
            clearHoverState()
            return
        }
        let isPointerOverWindow = (window as? CueSeekerWindow)?.isWindowFocusedOverrideForTesting != nil
            || NSWindow.windowNumber(
                at: NSEvent.mouseLocation,
                belowWindowWithWindowNumber: 0
            ) == window.windowNumber
        guard isPointerOverWindow else {
            clearHoverState()
            return
        }
        updateHoverState(windowLocation: window.mouseLocationOutsideOfEventStream)
    }

    private func updateHoverState(windowLocation: CGPoint? = nil) {
        guard window != nil || windowLocation != nil else {
            isHeaderHovered = false
            isIndexHeaderHovered = false
            return
        }
        if coordinator?.isCoveredByHigherLayer == true {
            isHeaderHovered = false
            isIndexHeaderHovered = false
            return
        }
        // A frozen header keeps the state it had: it neither follows the
        // pointer nor drops what was lit when the freeze began.
        if coordinator?.isPointerFrozen == true {
            return
        }
        if windowLocation == nil {
            guard !PointerHoverScrollState.shared.isScrolling else {
                return
            }
            guard let window else {
                isHeaderHovered = false
                isIndexHeaderHovered = false
                return
            }
            let isWindowFocused = (window as? CueSeekerWindow)?.isFocusedForHover
                ?? (NSApp.isActive && window.isKeyWindow)
            guard isWindowFocused else {
                isHeaderHovered = false
                isIndexHeaderHovered = false
                return
            }
        }
        guard let mouseLoc = windowLocation ?? window?.mouseLocationOutsideOfEventStream else {
            isHeaderHovered = false
            isIndexHeaderHovered = false
            return
        }
        let localLoc = convert(mouseLoc, from: nil)
        let isInside = bounds.contains(localLoc)
        isHeaderHovered = isInside
        let layout = currentHeaderLayout()
        isIndexHeaderHovered = isInside && layout.indexRect.contains(localLoc)
    }

    func handleHeaderHoverForTesting(windowPoint: CGPoint) {
        updateHoverState(windowLocation: windowPoint)
    }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            super.draw(dirtyRect)

            NSGraphicsContext.saveGraphicsState()
            let radius = WorkbenchControlMetrics.redesignCornerRadius
            NSBezierPath(
                roundedRect: CGRect(
                    x: bounds.minX,
                    y: bounds.minY,
                    width: bounds.width,
                    height: bounds.height + radius
                ),
                xRadius: radius,
                yRadius: radius
            ).addClip()
            (isHeaderHovered
                ? WorkbenchRedesignColors.NS.tableRowHover
                : WorkbenchRedesignColors.NS.bgSurface
            ).setFill()
            dirtyRect.intersection(bounds).fill()
            coordinator?.drawHeaderTextSelectionBackground(in: dirtyRect)
            WorkbenchRedesignColors.NS.borderDivider.setStroke()
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bounds.minX, y: bounds.maxY - 0.5))
            path.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY - 0.5))
            path.lineWidth = 1
            path.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    override func layout() {
        super.layout()
        textInteractionOverlay?.frame = bounds
        refreshHeaderHostsForLayoutChange()
    }

    func refreshHeaderHosts() {
        updateHoverState()

        let layout = currentHeaderLayout()
        refreshIndexHeaderHost(layout: layout)
        if let dateAddedRect = layout.dateAddedRect {
            updateHeaderHost(&dateAddedHeaderHost, title: coordinator?.dateAddedHeaderForRendering() ?? L("table.column.date_added"), frame: dateAddedRect)
        } else {
            dateAddedHeaderHost?.isHidden = true
        }
        if coordinator?.showsDisplayTitleColumnForRendering() ?? true {
            updateHeaderHost(&nameHeaderHost, title: coordinator?.displayTitleHeaderForRendering() ?? L("table.column.name"), frame: layout.nameRect)
        } else {
            nameHeaderHost?.isHidden = true
        }
        if let timeRect = layout.timeRect {
            updateHeaderHost(&timeHeaderHost, title: coordinator?.timeHeaderForRendering() ?? L("table.column.time_range"), frame: timeRect)
        } else {
            timeHeaderHost?.isHidden = true
        }
        updateHeaderHost(&cuesHeaderHost, title: coordinator?.cuesHeaderForRendering() ?? L("table.column.cues"), frame: layout.cuesRect)

        if let languageRect = layout.languageRect {
            updateHeaderHost(&languageHeaderHost, title: coordinator?.languageHeaderForRendering() ?? L("table.column.language"), frame: languageRect)
        } else {
            languageHeaderHost?.isHidden = true
        }

        updateHeaderKeyViewBridge()
        if coordinator?.isSelectionModeForRendering() == true {
            textInteractionOverlay?.isHidden = true
        } else {
            ensureTextInteractionOverlay()
        }
        lastHeaderLayout = layout
    }

    func refreshHeaderFramesForHorizontalScroll() {
        let layout = currentHeaderLayout()
        updateHeaderFrame(
            &indexHeaderHost,
            frame: layout.indexRect
        )
        updateHeaderFrame(&dateAddedHeaderHost, frame: layout.dateAddedRect)
        updateHeaderFrame(
            &nameHeaderHost,
            frame: coordinator?.showsDisplayTitleColumnForRendering() ?? true
                ? layout.nameRect
                : nil
        )
        updateHeaderFrame(&timeHeaderHost, frame: layout.timeRect)
        updateHeaderFrame(&cuesHeaderHost, frame: layout.cuesRect)
        updateHeaderFrame(&languageHeaderHost, frame: layout.languageRect)
        needsDisplay = true
        lastHeaderLayout = layout
    }

    private func ensureTextInteractionOverlay() {
        let overlay: SubtitleTableHeaderTextOverlayView
        if let textInteractionOverlay {
            overlay = textInteractionOverlay
        } else {
            overlay = SubtitleTableHeaderTextOverlayView(frame: bounds)
            overlay.autoresizingMask = [.width, .height]
            overlay.coordinator = coordinator
            textInteractionOverlay = overlay
        }
        overlay.frame = bounds
        overlay.isHidden = false
        if overlay.superview == nil {
            addSubview(overlay)
        } else {
            addSubview(overlay, positioned: .above, relativeTo: nil)
        }
        needsDisplay = true
    }

    func invalidateHeaderTextSelection() {
        needsDisplay = true
    }

    func textInteractionOverlayForTesting() -> SubtitleTableHeaderTextOverlayView? {
        textInteractionOverlay
    }

    private var showsSelectionHeaderCheckbox: Bool {
        coordinator?.isSelectionModeForRendering() == true
            || (isHeaderHovered && coordinator?.canToggleSelectionForRendering() == true)
    }

    func selectionHeaderIsVisibleForTesting() -> Bool {
        showsSelectionHeaderCheckbox
            && indexHeaderHost?.isHidden == false
    }

    func sequenceHeaderIsVisibleForTesting() -> Bool {
        !showsSelectionHeaderCheckbox
            && indexHeaderHost?.isHidden == false
    }

    func headerBackgroundColorForTesting() -> NSColor? {
        return isHeaderHovered
            ? WorkbenchRedesignColors.NS.tableRowHover
            : WorkbenchRedesignColors.NS.bgSurface
    }

    func shouldRouteTextSelectionMouseDownForTesting(at point: CGPoint) -> Bool {
        guard let textInteractionOverlay else { return false }
        return shouldRouteTextSelectionMouseDown(
            at: point,
            excluding: textInteractionOverlay
        )
    }

    func shouldRouteTextSelectionMouseDown(
        at point: CGPoint,
        excluding overlay: SubtitleTableHeaderTextOverlayView
    ) -> Bool {
        guard bounds.contains(point), !overlay.isHidden else { return false }
        if showsSelectionHeaderCheckbox,
           currentHeaderLayout().indexRect.contains(point)
        {
            return false
        }
        if coordinator?.isHeaderTextHitForInteraction(at: point) == true {
            return true
        }
        if SubtitleTableTextSelectionHitTesting.containsInteractiveRegion(
            atWindowPoint: convert(point, to: nil),
            in: self
        ) {
            return false
        }

        let wasHidden = overlay.isHidden
        overlay.isHidden = true
        defer { overlay.isHidden = wasHidden }
        return !SubtitleTableTextSelectionHitTesting.isInteractive(hitTest(point))
    }

    @IBAction override func selectAll(_ sender: Any?) {
        coordinator?.selectAllTableText()
    }

    @IBAction func copy(_ sender: Any?) {
        coordinator?.copyTableTextSelection()
    }

    private func refreshHeaderHostsForLayoutChange() {
        let layout = currentHeaderLayout()
        guard layout != lastHeaderLayout else { return }
        refreshHeaderHosts()
    }

    private func currentHeaderLayout() -> SubtitleTableColumnLayout {
        let M = SubtitleTableMetrics.self
        return coordinator?.headerColumnLayoutForRendering(
            viewportWidth: bounds.width,
            height: bounds.height
        ) ?? SubtitleTableColumnLayout.resolve(
            contentWidth: bounds.width,
            height: bounds.height,
            showsDateAddedColumn: false,
            showsDisplayTitleColumn: false,
            showsTimeColumn: false,
            showsLanguageColumn: false,
            cuesMinimumWidth: max(0, bounds.width - M.indexColumnWidth)
        )
    }

    private func refreshIndexHeaderHost(layout: SubtitleTableColumnLayout? = nil) {
        let currentLayout = layout ?? currentHeaderLayout()
        if showsSelectionHeaderCheckbox {
            updateSelectionHeaderHost(&indexHeaderHost, frame: currentLayout.indexRect)
        } else {
            updateHeaderHost(
                &indexHeaderHost,
                title: "#",
                frame: currentLayout.indexRect,
                alignment: .center
            )
        }
    }

    private func updateHeaderFrame(
        _ hostVar: inout NSHostingView<AnyView>?,
        frame: CGRect?
    ) {
        guard let frame else {
            hostVar?.isHidden = true
            return
        }
        hostVar?.frame = frame
        hostVar?.isHidden = false
    }

    private func updateSelectionHeaderHost(
        _ hostVar: inout NSHostingView<AnyView>?,
        frame: CGRect
    ) {
        guard let coordinator else { return }
        let checkboxView = WorkbenchCheckboxButton(
            state: coordinator.selectionHeaderStateForRendering(),
            isEnabled: coordinator.canToggleSelectionForRendering(),
            action: { [weak self] in
                self?.coordinator?.toggleAllRowSelection()
            }
        )
        let anyView = InterfaceLayerHosting.bridgedRootView(
            AnyView(checkboxView),
            layers: coordinator.interfaceLayers,
            context: coordinator.interfaceLayerContext
        )

        if let host = hostVar as? SubtitleTablePageChromeHostingView {
            host.coordinator = coordinator
            host.rootView = anyView
            host.frame = frame
            host.isHidden = false
        } else {
            hostVar?.removeFromSuperview()
            let host = SubtitleTablePageChromeHostingView(rootView: anyView)
            host.coordinator = coordinator
            host.wantsLayer = true
            host.layer?.masksToBounds = false
            addSubview(host)
            hostVar = host
            host.frame = frame
            host.isHidden = false
        }
    }

    private func updateHeaderHost(
        _ hostVar: inout NSHostingView<AnyView>?,
        title: String,
        frame: CGRect,
        alignment: Alignment = .leading
    ) {
        guard let coordinator else { return }
        let isEnabled = coordinator.isEnabled

        let cellView = SubtitleTableHeaderCellView(
            title: title,
            isEnabled: isEnabled,
            columnRect: frame,
            alignment: alignment
        )

        let anyView = InterfaceLayerHosting.bridgedRootView(
            AnyView(cellView),
            layers: coordinator.interfaceLayers,
            context: coordinator.interfaceLayerContext
        )

        if let host = hostVar, !(host is SubtitleTablePageChromeHostingView) {
            host.rootView = anyView
            host.frame = frame
            host.isHidden = false
        } else {
            hostVar?.removeFromSuperview()
            let host = NSHostingView(rootView: anyView)
            host.wantsLayer = true
            host.layer?.masksToBounds = false
            addSubview(host)
            hostVar = host
            host.frame = frame
            host.isHidden = false
        }
    }

    func isLastInteractiveHeaderResponder(_ responder: NSResponder?) -> Bool {
        guard let host = lastInteractiveHeaderHost(), let responderView = responder as? NSView else {
            return false
        }
        return responderView === host || responderView.isDescendant(of: host)
    }

    private func updateHeaderKeyViewBridge() {
        guard let lastHost = lastInteractiveHeaderHost(), let documentView = coordinator?.documentViewForKeyboardFocusBridge() else {
            return
        }
        lastHost.nextKeyView = documentView
    }

    private func lastInteractiveHeaderHost() -> NSView? {
        if let languageHeaderHost, !languageHeaderHost.isHidden {
            return languageHeaderHost
        }
        if let cuesHeaderHost, !cuesHeaderHost.isHidden {
            return cuesHeaderHost
        }
        if let timeHeaderHost, !timeHeaderHost.isHidden {
            return timeHeaderHost
        }
        if let nameHeaderHost, !nameHeaderHost.isHidden {
            return nameHeaderHost
        }
        if let dateAddedHeaderHost, !dateAddedHeaderHost.isHidden {
            return dateAddedHeaderHost
        }
        return nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - Virtual document view

final class SubtitleVirtualTableDocumentView: NSView, PointerShapeProviding {
    weak var coordinator: SubtitleTableView.Coordinator?
    private var hoverTracking: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        coordinator?.clearFocusedCheckbox()
        coordinator?.cancelPendingTextInteraction()
        return super.resignFirstResponder()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking {
            removeTrackingArea(hoverTracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTracking = area
    }

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: AppPointerShape.rectCursor)
    }

    func pointerShape(atWindowPoint point: CGPoint) -> PointerShape {
        coordinator?.pointerShape(atWindowPoint: point) ?? .arrow
    }

    override func mouseMoved(with event: NSEvent) {
        guard let window,
              NSApp.isActive,
              window.isKeyWindow,
              !PointerHoverScrollState.shared.isScrolling
        else {
            return
        }
        coordinator?.handleMouseHover(windowPoint: event.locationInWindow)
    }

    // Entering and leaving are not movement: AppKit synthesizes both for a
    // pointer that stayed put while the table scrolled or reflowed under it.
    // A real entry is followed by a real move, which places the hover; a
    // synthesized exit leaves the pointer where it was, so the hover stays.
    override func mouseEntered(with event: NSEvent) {}

    override func mouseExited(with event: NSEvent) {
        guard let window, !PointerHoverScrollState.shared.isScrolling else {
            return
        }
        coordinator?.clearHoverUnlessPointerInside(
            windowPoint: window.mouseLocationOutsideOfEventStream
        )
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if coordinator?.handleMouseDown(
            windowPoint: event.locationInWindow,
            isShiftPressed: event.modifierFlags.contains(.shift)
        ) == true {
            return
        }
        coordinator?.clearFocusedCheckbox()
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if coordinator?.handleMouseDragged(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if coordinator?.handleMouseUp(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        if coordinator?.handleRightMouseDown(windowPoint: event.locationInWindow) == true {
            return
        }
        super.rightMouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if coordinator?.handleKeyDown(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    @IBAction override func selectAll(_ sender: Any?) {
        coordinator?.selectAllTableText()
    }

    @IBAction func copy(_ sender: Any?) {
        coordinator?.copyTableTextSelection()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        coordinator?.drawRows(in: dirtyRect)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - SwiftUI bridge

typealias SubtitleTableTextCopyRowLoader = @MainActor (Range<Int>) async -> [SubtitleTableRow]?

struct SubtitleTablePageChrome {
    let scrollableHeader: AnyView
    let pinnedHeader: AnyView
    /// Resolved from the chrome's own content width, so a width-dependent
    /// scrollable header keeps the page scroll geometry in step with it.
    let scrollableHeaderHeight: (CGFloat) -> CGFloat
    let pinnedHeaderHeight: CGFloat
    let leadingInset: CGFloat
    let trailingInset: CGFloat
    let bottomInset: CGFloat
}

struct SubtitleTablePageScrollGeometry: Equatable {
    let scrollableHeaderHeight: CGFloat
    let pinnedHeaderHeight: CGFloat
    let tableHeaderHeight: CGFloat
    let bottomInset: CGFloat

    var rowsOriginY: CGFloat {
        scrollableHeaderHeight + pinnedHeaderHeight + tableHeaderHeight
    }

    func scrollableHeaderOriginY(scrollOffset: CGFloat) -> CGFloat {
        -max(0, scrollOffset)
    }

    func pinnedHeaderOriginY(scrollOffset: CGFloat) -> CGFloat {
        max(0, scrollableHeaderHeight - max(0, scrollOffset))
    }

    func tableBodyVisibleRect(
        scrollOffset: CGFloat,
        viewportSize: CGSize
    ) -> CGRect {
        let bodyOrigin = max(0, scrollOffset)
            + pinnedHeaderOriginY(scrollOffset: scrollOffset)
            + pinnedHeaderHeight
            + tableHeaderHeight
        return CGRect(
            x: 0,
            y: bodyOrigin,
            width: max(0, viewportSize.width),
            height: max(
                0,
                viewportSize.height
                    - pinnedHeaderOriginY(scrollOffset: scrollOffset)
                    - pinnedHeaderHeight
                    - tableHeaderHeight
            )
        )
    }

    func documentHeight(rowsHeight: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        max(1, viewportHeight, rowsOriginY + max(0, rowsHeight) + bottomInset)
    }

    func scrollOffsetForRow(localRowY: CGFloat, maximumOffset: CGFloat) -> CGFloat {
        min(
            max(0, maximumOffset),
            max(0, scrollableHeaderHeight + max(0, localRowY))
        )
    }
}

final class SubtitleTablePageChromeHostingView: CueSeekerHostingView<AnyView> {
    weak var scrollView: NSScrollView?
    weak var coordinator: SubtitleTableView.Coordinator?

    override var isHoverSyncSuppressedByCoveringLayer: Bool {
        coordinator?.isPointerFrozen == true
    }

    override func scrollWheel(with event: NSEvent) {
        scrollView?.scrollWheel(with: event)
    }
}

// MARK: - Header Cell View

struct SubtitleTableHeaderCellView: View {
    let title: String
    let isEnabled: Bool
    let columnRect: CGRect
    var alignment: Alignment = .leading

    var body: some View {
        Group {
            if alignment == .center {
                Text(title)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTableHeader, weight: .medium))
                    .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textSecondary : WorkbenchRedesignColors.textDisabled)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                HStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTableHeader, weight: .medium))
                        .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textSecondary : WorkbenchRedesignColors.textDisabled)
                        .lineLimit(1)
                        .padding(.horizontal, WorkbenchControlMetrics.redesignPaddingHeaderTriggerX)
                        .frame(maxHeight: .infinity, alignment: .center)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(width: columnRect.width, height: columnRect.height, alignment: .center)
    }
}
