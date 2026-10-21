import AppKit

enum TableScrollbarAxis: CaseIterable, Equatable, Hashable {
    case vertical
    case horizontal
}

struct TableScrollbarAxisPresentation: Equatable {
    let visibleFraction: CGFloat
    let positionFraction: CGFloat

    init(visibleFraction: CGFloat, positionFraction: CGFloat) {
        self.visibleFraction = Self.clamp(visibleFraction)
        self.positionFraction = Self.clamp(positionFraction)
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else {
            return 0
        }
        return min(1, max(0, value))
    }
}

struct TableScrollbarPresentation: Equatable {
    let vertical: TableScrollbarAxisPresentation?
    let horizontal: TableScrollbarAxisPresentation?

    init(
        vertical: TableScrollbarAxisPresentation? = nil,
        horizontal: TableScrollbarAxisPresentation? = nil
    ) {
        self.vertical = vertical
        self.horizontal = horizontal
    }

    subscript(axis: TableScrollbarAxis) -> TableScrollbarAxisPresentation? {
        switch axis {
        case .vertical:
            return vertical
        case .horizontal:
            return horizontal
        }
    }
}

enum TableScrollbarPrimitiveMetrics {
    static let size: CGFloat = 8
    static let inset: CGFloat = 4
    static let minimumThumbLength: CGFloat = 24
    static let hitSlop: CGFloat = 6
}

struct TableScrollbarGeometry: Equatable {
    let presentation: TableScrollbarPresentation
    /// What the track keeps clear of its bounds on every side. Menus widen to
    /// make room for their scrollbar rather than borrowing the padding around
    /// their items, so they ask for a wider one than tables do.
    var inset: CGFloat = TableScrollbarPrimitiveMetrics.inset

    func trackRect(
        for axis: TableScrollbarAxis,
        in bounds: CGRect
    ) -> CGRect? {
        guard presentation[axis] != nil else {
            return nil
        }
        let size = TableScrollbarPrimitiveMetrics.size
        let verticalReserve = presentation.vertical == nil ? 0 : size + inset
        let horizontalReserve = presentation.horizontal == nil ? 0 : size + inset

        switch axis {
        case .vertical:
            let height = bounds.height - 2 * inset - horizontalReserve
            guard height > 0 else {
                return nil
            }
            return CGRect(
                x: bounds.maxX - inset - size,
                y: bounds.minY + inset,
                width: size,
                height: height
            )
        case .horizontal:
            let width = bounds.width - 2 * inset - verticalReserve
            guard width > 0 else {
                return nil
            }
            return CGRect(
                x: bounds.minX + inset,
                y: bounds.maxY - inset - size,
                width: width,
                height: size
            )
        }
    }

    func thumbRect(
        for axis: TableScrollbarAxis,
        in bounds: CGRect
    ) -> CGRect? {
        guard let axisPresentation = presentation[axis],
              let track = trackRect(for: axis, in: bounds)
        else {
            return nil
        }

        let trackLength = axis == .vertical ? track.height : track.width
        guard trackLength > 0 else {
            return nil
        }
        let thumbLength = min(
            trackLength,
            max(
                TableScrollbarPrimitiveMetrics.minimumThumbLength,
                trackLength * axisPresentation.visibleFraction
            )
        )
        let travelLength = max(0, trackLength - thumbLength)
        let thumbOffset = travelLength * axisPresentation.positionFraction

        switch axis {
        case .vertical:
            return CGRect(
                x: track.minX,
                y: track.minY + thumbOffset,
                width: track.width,
                height: thumbLength
            )
        case .horizontal:
            return CGRect(
                x: track.minX + thumbOffset,
                y: track.minY,
                width: thumbLength,
                height: track.height
            )
        }
    }

    func interactiveThumbRect(
        for axis: TableScrollbarAxis,
        in bounds: CGRect
    ) -> CGRect? {
        guard let thumb = thumbRect(for: axis, in: bounds) else {
            return nil
        }
        switch axis {
        case .vertical:
            return thumb.insetBy(
                dx: -TableScrollbarPrimitiveMetrics.hitSlop,
                dy: -2
            )
        case .horizontal:
            return thumb.insetBy(
                dx: -2,
                dy: -TableScrollbarPrimitiveMetrics.hitSlop
            )
        }
    }

    func positionFraction(
        for axis: TableScrollbarAxis,
        thumbPosition: CGFloat,
        in bounds: CGRect
    ) -> CGFloat {
        guard let track = trackRect(for: axis, in: bounds),
              let thumb = thumbRect(for: axis, in: bounds)
        else {
            return 0
        }
        let trackStart = axis == .vertical ? track.minY : track.minX
        let trackLength = axis == .vertical ? track.height : track.width
        let thumbLength = axis == .vertical ? thumb.height : thumb.width
        let travelLength = max(0, trackLength - thumbLength)
        guard travelLength > 0 else {
            return 0
        }
        let thumbTravel = min(
            travelLength,
            max(0, thumbPosition - trackStart)
        )
        return thumbTravel / travelLength
    }

    func positionFraction(
        for axis: TableScrollbarAxis,
        dragStartThumbOrigin: CGFloat,
        dragDelta: CGFloat,
        in bounds: CGRect
    ) -> CGFloat {
        positionFraction(
            for: axis,
            thumbPosition: dragStartThumbOrigin + dragDelta,
            in: bounds
        )
    }
}

enum TableScrollbarDragPhase: Equatable {
    case began
    case changed
    case ended
    case cancelled
}

struct TableScrollbarDragEvent: Equatable {
    let axis: TableScrollbarAxis
    let phase: TableScrollbarDragPhase
    let positionFraction: CGFloat
}

enum TableScrollbarAppearanceMode: Equatable {
    case inherited
    case fixedDark
}

class TableScrollbarOverlayView: NSView {
    var presentationProvider: () -> TableScrollbarPresentation? = { nil }
    var onDrag: (TableScrollbarDragEvent) -> Void = { _ in }
    var onDragStateChanged: ((Bool) -> Void)?
    var onScrollWheel: ((NSEvent) -> Void)?
    var appearanceMode: TableScrollbarAppearanceMode = .inherited {
        didSet {
            needsDisplay = true
        }
    }
    /// Axes this Overlay is responsible for. One scroll container can be shared
    /// by several Overlays, each drawing a different axis.
    var visibleAxes: Set<TableScrollbarAxis> = Set(TableScrollbarAxis.allCases) {
        didSet {
            guard visibleAxes != oldValue else { return }
            lastPresentation = nil
            needsDisplay = true
        }
    }
    /// Height kept free at the bottom so an outer Scrollbar can take that place.
    var bottomReserve: CGFloat = 0 {
        didSet {
            guard bottomReserve != oldValue else { return }
            lastPresentation = nil
            needsDisplay = true
        }
    }
    /// Width kept free at the trailing edge so a Scrollbar drawn by another
    /// Overlay on the crossing axis does not collide with this one.
    var trailingReserve: CGFloat = 0 {
        didSet {
            guard trailingReserve != oldValue else { return }
            lastPresentation = nil
            needsDisplay = true
        }
    }
    var showsInteractiveThumb = false {
        didSet {
            guard showsInteractiveThumb != oldValue else { return }
            needsDisplay = true
        }
    }
    /// Set while a menu is open over this Scrollbar's layer, or while a higher
    /// layer covers it. The Scrollbar then keeps the picture it had: the
    /// pointer moving over it no longer lights the thumb, and moving off no
    /// longer puts it out. Presses and the wheel are already withheld by the
    /// menu gate before they reach here.
    var isInteractionFrozen = false
    /// What this Overlay's scrollbar keeps clear of its own edge. Tables use
    /// the shared default; a menu passes its own so the scrollbar lands in the
    /// strip the menu widened by rather than over its items.
    var edgeInset: CGFloat = TableScrollbarPrimitiveMetrics.inset {
        didSet {
            guard edgeInset != oldValue else { return }
            lastPresentation = nil
            needsDisplay = true
        }
    }
    var isPresented = false {
        didSet {
            guard isPresented != oldValue else {
                return
            }
            isHidden = !isPresented
            if !isPresented {
                cancelActiveDrag()
            }
            lastPresentation = nil
            needsDisplay = true
        }
    }

    /// Bounds the tracks are laid out in, after the bottom reserve.
    var geometryBounds: CGRect {
        CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: max(0, bounds.width - trailingReserve),
            height: max(0, bounds.height - bottomReserve)
        )
    }

    func currentPresentation() -> TableScrollbarPresentation? {
        guard let presentation = presentationProvider() else { return nil }
        let vertical = visibleAxes.contains(.vertical) ? presentation.vertical : nil
        let horizontal = visibleAxes.contains(.horizontal) ? presentation.horizontal : nil
        guard vertical != nil || horizontal != nil else { return nil }
        return TableScrollbarPresentation(
            vertical: vertical,
            horizontal: horizontal
        )
    }

    private var trackingArea: NSTrackingArea?
    private var hoveredAxis: TableScrollbarAxis? {
        didSet {
            guard hoveredAxis != oldValue else {
                return
            }
            invalidateInteractiveStateChange(from: oldValue, to: hoveredAxis)
        }
    }
    private var draggingAxis: TableScrollbarAxis? {
        didSet {
            guard draggingAxis != oldValue else {
                return
            }
            invalidateInteractiveStateChange(from: oldValue, to: draggingAxis)
            if (oldValue == nil) != (draggingAxis == nil) {
                onDragStateChanged?(draggingAxis != nil)
            }
        }
    }
    private var dragStartPoint: CGPoint = .zero
    private var dragStartThumbOrigin: CGFloat = 0
    private var lastDragPositionFraction: CGFloat = 0
    private var lastPresentation: TableScrollbarPresentation?
    nonisolated(unsafe) private var focusObserverTokens: [NSObjectProtocol] = []

    deinit {
        for token in focusObserverTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isHidden = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeFocusObservers()
        if window == nil {
            cancelActiveDrag()
        } else {
            installFocusObservers()
        }
    }

    private func installFocusObservers() {
        let center = NotificationCenter.default
        for name in [
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
        ] {
            let token = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleFocusNotification(notification)
                }
            }
            focusObserverTokens.append(token)
        }
    }

    private func removeFocusObservers() {
        for token in focusObserverTokens {
            NotificationCenter.default.removeObserver(token)
        }
        focusObserverTokens.removeAll()
    }

    private func handleFocusNotification(_ notification: Notification) {
        guard let window else {
            return
        }
        if let notificationWindow = notification.object as? NSWindow,
           notificationWindow !== window {
            return
        }
        guard draggingAxis == nil, !isInteractionFrozen else {
            return
        }
        if NSApp.isActive && window.isKeyWindow {
            guard !AppCursorVisibility.isCursorHidden,
                  !PointerHoverScrollState.shared.isScrolling,
                  NSWindow.windowNumber(
                      at: NSEvent.mouseLocation,
                      belowWindowWithWindowNumber: 0
                  ) == window.windowNumber
            else {
                hoveredAxis = nil
                return
            }
            hoveredAxis = axis(at: convert(window.mouseLocationOutsideOfEventStream, from: nil))
        } else {
            hoveredAxis = nil
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = superview.map { convert(point, from: $0) } ?? point
        guard isPresented,
              !isHidden,
              axis(at: localPoint) != nil
        else {
            return nil
        }
        return self
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isPresented,
              let presentation = currentPresentation()
        else {
            lastPresentation = nil
            return
        }
        lastPresentation = presentation
        let draw = {
            let geometry = TableScrollbarGeometry(
                presentation: presentation,
                inset: self.edgeInset
            )
            self.drawThumb(axis: .vertical, geometry: geometry)
            self.drawThumb(axis: .horizontal, geometry: geometry)
        }
        switch appearanceMode {
        case .inherited:
            effectiveAppearance.performAsCurrentDrawingAppearance(draw)
        case .fixedDark:
            (NSAppearance(named: .darkAqua) ?? effectiveAppearance)
                .performAsCurrentDrawingAppearance(draw)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard let window, NSApp.isActive, window.isKeyWindow, !isInteractionFrozen else {
            return
        }
        hoveredAxis = axis(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard draggingAxis == nil, !isInteractionFrozen else {
            return
        }
        hoveredAxis = nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let axis = axis(at: point),
              let geometry = geometry(),
              let track = geometry.trackRect(for: axis, in: geometryBounds),
              let thumb = geometry.thumbRect(for: axis, in: geometryBounds),
              let axisPresentation = geometry.presentation[axis],
              (axis == .vertical ? track.height - thumb.height : track.width - thumb.width) > 0
        else {
            return
        }
        draggingAxis = axis
        hoveredAxis = axis
        dragStartPoint = point
        dragStartThumbOrigin = axis == .vertical ? thumb.minY : thumb.minX
        lastDragPositionFraction = axisPresentation.positionFraction
        onDrag(TableScrollbarDragEvent(
            axis: axis,
            phase: .began,
            positionFraction: lastDragPositionFraction
        ))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let draggingAxis,
              let geometry = geometry()
        else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let dragDelta = draggingAxis == .vertical
            ? point.y - dragStartPoint.y
            : point.x - dragStartPoint.x
        lastDragPositionFraction = geometry.positionFraction(
            for: draggingAxis,
            dragStartThumbOrigin: dragStartThumbOrigin,
            dragDelta: dragDelta,
            in: geometryBounds
        )
        onDrag(TableScrollbarDragEvent(
            axis: draggingAxis,
            phase: .changed,
            positionFraction: lastDragPositionFraction
        ))
        scrollbarMetricsDidChange()
    }

    override func mouseUp(with event: NSEvent) {
        guard let draggingAxis else {
            super.mouseUp(with: event)
            return
        }
        if let geometry = geometry() {
            let point = convert(event.locationInWindow, from: nil)
            let dragDelta = draggingAxis == .vertical
                ? point.y - dragStartPoint.y
                : point.x - dragStartPoint.x
            lastDragPositionFraction = geometry.positionFraction(
                for: draggingAxis,
                dragStartThumbOrigin: dragStartThumbOrigin,
                dragDelta: dragDelta,
                in: geometryBounds
            )
        }
        onDrag(TableScrollbarDragEvent(
            axis: draggingAxis,
            phase: .ended,
            positionFraction: lastDragPositionFraction
        ))
        self.draggingAxis = nil
        hoveredAxis = axis(at: convert(event.locationInWindow, from: nil))
        super.mouseUp(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        if let onScrollWheel {
            onScrollWheel(event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    func scrollbarMetricsDidChange() {
        guard isPresented else {
            return
        }
        let newPresentation = currentPresentation()
        invalidateThumbs(
            oldPresentation: lastPresentation,
            newPresentation: newPresentation
        )
        lastPresentation = newPresentation
    }

    private func cancelActiveDrag() {
        guard let draggingAxis else {
            return
        }
        onDrag(TableScrollbarDragEvent(
            axis: draggingAxis,
            phase: .cancelled,
            positionFraction: lastDragPositionFraction
        ))
        self.draggingAxis = nil
        hoveredAxis = nil
    }

    private func geometry() -> TableScrollbarGeometry? {
        guard let presentation = currentPresentation() else {
            return nil
        }
        return TableScrollbarGeometry(
            presentation: presentation,
            inset: edgeInset
        )
    }

    private func axis(at point: CGPoint) -> TableScrollbarAxis? {
        guard let geometry = geometry() else {
            return nil
        }
        if let verticalThumb = geometry.interactiveThumbRect(for: .vertical, in: geometryBounds),
           verticalThumb.contains(point) {
            return .vertical
        }
        if let horizontalThumb = geometry.interactiveThumbRect(for: .horizontal, in: geometryBounds),
           horizontalThumb.contains(point) {
            return .horizontal
        }
        return nil
    }

    private func invalidateInteractiveStateChange(
        from oldAxis: TableScrollbarAxis?,
        to newAxis: TableScrollbarAxis?
    ) {
        guard isPresented else {
            return
        }
        var axes: [TableScrollbarAxis] = []
        if let oldAxis {
            axes.append(oldAxis)
        }
        if let newAxis, newAxis != oldAxis {
            axes.append(newAxis)
        }
        guard !axes.isEmpty else {
            return
        }
        invalidateThumbs(
            oldPresentation: currentPresentation(),
            newPresentation: currentPresentation(),
            axes: axes
        )
    }

    private func invalidateThumbs(
        oldPresentation: TableScrollbarPresentation?,
        newPresentation: TableScrollbarPresentation?,
        axes: [TableScrollbarAxis] = TableScrollbarAxis.allCases
    ) {
        var dirtyRect = CGRect.null
        for axis in axes {
            if let oldPresentation,
               let oldRect = TableScrollbarGeometry(
                   presentation: oldPresentation,
                   inset: edgeInset
               ).thumbRect(for: axis, in: geometryBounds) {
                dirtyRect = dirtyRect.union(oldRect)
            }
            if let newPresentation,
               let newRect = TableScrollbarGeometry(
                   presentation: newPresentation,
                   inset: edgeInset
               ).thumbRect(for: axis, in: geometryBounds) {
                dirtyRect = dirtyRect.union(newRect)
            }
        }
        guard !dirtyRect.isNull else {
            return
        }
        setNeedsDisplay(dirtyRect.insetBy(dx: -2, dy: -2))
    }

    private func drawThumb(
        axis: TableScrollbarAxis,
        geometry: TableScrollbarGeometry
    ) {
        guard let rect = geometry.thumbRect(for: axis, in: geometryBounds) else {
            return
        }
        let isInteractive = showsInteractiveThumb
            || hoveredAxis == axis
            || draggingAxis == axis
        let color = isInteractive
            ? WorkbenchRedesignColors.NS.scrollbarThumbInteractive
            : WorkbenchRedesignColors.NS.scrollbarThumbDefault
        color.setFill()
        NSBezierPath(
            roundedRect: rect,
            xRadius: TableScrollbarPrimitiveMetrics.size / 2,
            yRadius: TableScrollbarPrimitiveMetrics.size / 2
        ).fill()
    }
}
