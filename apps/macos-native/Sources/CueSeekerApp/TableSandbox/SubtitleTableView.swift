import AppKit
import SwiftUI

// MARK: - Metrics

enum SubtitleTableMetrics {
    static let indexColumnWidth: CGFloat = 50
    static let nameColumnWidth: CGFloat = 240
    static let cellLeading: CGFloat = 12
    static let trailingInset: CGFloat = 14
    static let indexTrailingInset: CGFloat = 6
    static let rowVerticalInset: CGFloat = 9
    static let headerHeight: CGFloat = 44
    static let headerHorizontalInset: CGFloat = 12
    static let indexHeaderHorizontalInset: CGFloat = 16
    static let cornerRadius: CGFloat = 10
    static let estimatedRowHeight: CGFloat = 56
    static let maximumBodyLineCount = 6
}

// MARK: - Typography

@MainActor
enum SubtitleTableText {
    static let bodyFont = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
    static let indexFont = NSFont.systemFont(ofSize: 12, weight: .regular)
    static let headerFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let lineSpacing: CGFloat = 4

    static func bodyParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        return style
    }

    static func body(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: bodyFont,
            .paragraphStyle: bodyParagraphStyle(),
            .foregroundColor: NSColor.labelColor,
        ])
    }

    static func index(_ number: Int) -> NSAttributedString {
        NSAttributedString(string: "\(number)", attributes: [
            .font: indexFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }

    static func header(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: headerFont,
            .foregroundColor: NSColor.labelColor,
        ])
    }
}

// MARK: - TextKit layout

@MainActor
final class SubtitleTextLayout {
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    init(maximumNumberOfLines: Int = SubtitleTableMetrics.maximumBodyLineCount) {
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = maximumNumberOfLines
        layoutManager.usesFontLeading = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func update(attributedString: NSAttributedString, width: CGFloat) {
        textStorage.setAttributedString(attributedString)
        textContainer.size = CGSize(width: max(0, width), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
    }

    var usedHeight: CGFloat {
        ceil(layoutManager.usedRect(for: textContainer).height)
    }

    func draw(at origin: CGPoint) {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }
}

// MARK: - Hover Play/Copy buttons

private struct CueHoverButtons: View {
    var onPlay: () -> Void
    var onCopy: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            button(title: "Play", systemImage: "play.fill", action: onPlay)
            button(title: "Copy", systemImage: "doc.on.doc", action: onCopy)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private func button(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarButtonStyle())
    }
}

// MARK: - Container and header

final class SubtitleTableContainerView: NSView {
    var onLayout: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = SubtitleTableMetrics.cornerRadius
        layer?.borderWidth = 1
        layer?.masksToBounds = true
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
            layer.backgroundColor = NSColor.textBackgroundColor.cgColor
            layer.borderColor = NSColor.separatorColor.cgColor
        }
    }
}

final class SubtitleVirtualTableHeaderView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let M = SubtitleTableMetrics.self
        drawHeader(
            "#",
            rect: CGRect(x: 0, y: 0, width: M.indexColumnWidth, height: bounds.height),
            leading: M.indexHeaderHorizontalInset,
            trailing: M.indexTrailingInset
        )
        drawHeader(
            "Name",
            rect: CGRect(x: M.indexColumnWidth, y: 0, width: M.nameColumnWidth, height: bounds.height),
            leading: M.headerHorizontalInset,
            trailing: M.trailingInset
        )
        drawHeader(
            "Cues",
            rect: CGRect(
                x: M.indexColumnWidth + M.nameColumnWidth,
                y: 0,
                width: max(0, bounds.width - M.indexColumnWidth - M.nameColumnWidth),
                height: bounds.height
            ),
            leading: M.headerHorizontalInset,
            trailing: M.trailingInset
        )

        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.minX, y: bounds.maxY - 0.5))
        path.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY - 0.5))
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawHeader(_ text: String, rect: CGRect, leading: CGFloat, trailing: CGFloat) {
        let attributed = SubtitleTableText.header(text)
        let size = attributed.size()
        let origin = CGPoint(
            x: rect.minX + leading,
            y: rect.minY + max(0, (rect.height - size.height) / 2)
        )
        let clipped = CGRect(
            x: origin.x,
            y: origin.y,
            width: max(0, rect.width - leading - trailing),
            height: size.height
        )
        attributed.draw(in: clipped)
    }
}

// MARK: - Virtual document view

final class SubtitleVirtualTableDocumentView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?
    private var hoverTracking: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking {
            removeTrackingArea(hoverTracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        coordinator?.handleMouseHover(windowPoint: event.locationInWindow)
    }

    override func mouseEntered(with event: NSEvent) {
        coordinator?.handleMouseHover(windowPoint: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        coordinator?.clearHover()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        coordinator?.drawRows(in: dirtyRect)
    }
}

// MARK: - Height cache

struct SubtitleVirtualRowHeightCache {
    private var heights: [Int: CGFloat] = [:]

    var count: Int {
        heights.count
    }

    mutating func removeAll() {
        heights.removeAll()
    }

    mutating func prune(rowCount: Int, isLoaded: (Int) -> Bool) {
        heights = heights.filter { row, _ in
            row >= 0 && row < rowCount && isLoaded(row)
        }
    }

    func height(for row: Int, defaultHeight: CGFloat) -> CGFloat {
        defaultHeight
    }

    mutating func setHeight(_ height: CGFloat, for row: Int, defaultHeight: CGFloat) -> Bool {
        _ = height
        _ = row
        _ = defaultHeight
        return false
    }

    func yOffset(for row: Int, defaultHeight: CGFloat) -> CGFloat {
        CGFloat(max(0, row)) * defaultHeight
    }

    func totalHeight(rowCount: Int, defaultHeight: CGFloat) -> CGFloat {
        CGFloat(max(0, rowCount)) * defaultHeight
    }

    func rowIndex(atY y: CGFloat, rowCount: Int, defaultHeight: CGFloat) -> Int {
        guard rowCount > 0 else { return 0 }
        let row = Int((max(0, y) / max(1, defaultHeight)).rounded(.down))
        return min(max(0, row), rowCount - 1)
    }
}

// MARK: - SwiftUI bridge

struct SubtitleTableView: NSViewRepresentable {
    var tableName: String
    var rowCount: Int
    var rowProvider: (Int) -> SubtitleTableRow?
    var rowsVersion: Int
    var rowsUpdate: TableSandboxRowsUpdate
    var onVisibleRowsChange: (Range<Int>) -> Void = { _ in }
    var onPlay: (SubtitleTableRow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            tableName: tableName,
            rowCount: rowCount,
            rowProvider: rowProvider,
            rowsVersion: rowsVersion,
            onVisibleRowsChange: onVisibleRowsChange,
            onPlay: onPlay
        )
    }

    func makeNSView(context: Context) -> SubtitleTableContainerView {
        let container = SubtitleTableContainerView()

        let header = SubtitleVirtualTableHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.coordinator = context.coordinator

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let documentView = SubtitleVirtualTableDocumentView()
        documentView.coordinator = context.coordinator
        documentView.frame = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
        scrollView.documentView = documentView
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.attach(
            container: container,
            headerView: header,
            scrollView: scrollView,
            documentView: documentView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollContentDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        container.addSubview(header)
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: SubtitleTableMetrics.headerHeight),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.resizeDocument()
        context.coordinator.notifyVisibleRowsChanged()
        return container
    }

    func updateNSView(_ nsView: SubtitleTableContainerView, context: Context) {
        context.coordinator.update(
            tableName: tableName,
            rowCount: rowCount,
            rowProvider: rowProvider,
            rowsVersion: rowsVersion,
            rowsUpdate: rowsUpdate,
            onVisibleRowsChange: onVisibleRowsChange,
            onPlay: onPlay
        )
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject {
        private var tableName: String
        private var rowCount: Int
        private var rowProvider: (Int) -> SubtitleTableRow?
        private var rowsVersion: Int
        private var onVisibleRowsChange: (Range<Int>) -> Void
        private var onPlay: (SubtitleTableRow) -> Void

        private weak var container: SubtitleTableContainerView?
        private weak var headerView: SubtitleVirtualTableHeaderView?
        private weak var scrollView: NSScrollView?
        private weak var documentView: SubtitleVirtualTableDocumentView?
        private var buttonsHost: NSHostingView<CueHoverButtons>?

        private let textLayout = SubtitleTextLayout()
        private var rowHeightCache = SubtitleVirtualRowHeightCache()
        private var hoveredRow: Int?

        init(
            tableName: String,
            rowCount: Int,
            rowProvider: @escaping (Int) -> SubtitleTableRow?,
            rowsVersion: Int,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            onPlay: @escaping (SubtitleTableRow) -> Void
        ) {
            self.tableName = tableName
            self.rowCount = max(0, rowCount)
            self.rowProvider = rowProvider
            self.rowsVersion = rowsVersion
            self.onVisibleRowsChange = onVisibleRowsChange
            self.onPlay = onPlay
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(
            container: SubtitleTableContainerView,
            headerView: SubtitleVirtualTableHeaderView,
            scrollView: NSScrollView,
            documentView: SubtitleVirtualTableDocumentView
        ) {
            self.container = container
            self.headerView = headerView
            self.scrollView = scrollView
            self.documentView = documentView

            let buttonsHost = NSHostingView(rootView: CueHoverButtons(onPlay: {}, onCopy: {}))
            buttonsHost.isHidden = true
            buttonsHost.translatesAutoresizingMaskIntoConstraints = true
            documentView.addSubview(buttonsHost)
            self.buttonsHost = buttonsHost

            container.onLayout = { [weak self] in
                self?.resizeDocument()
            }
        }

        func update(
            tableName: String,
            rowCount: Int,
            rowProvider: @escaping (Int) -> SubtitleTableRow?,
            rowsVersion: Int,
            rowsUpdate: TableSandboxRowsUpdate,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            onPlay: @escaping (SubtitleTableRow) -> Void
        ) {
            self.tableName = tableName
            self.rowProvider = rowProvider
            self.onVisibleRowsChange = onVisibleRowsChange
            self.onPlay = onPlay

            let nextRowCount = max(0, rowCount)
            let changed = nextRowCount != self.rowCount || rowsVersion != self.rowsVersion
            self.rowCount = nextRowCount
            self.rowsVersion = rowsVersion

            rowHeightCache.prune(rowCount: nextRowCount) { [rowProvider] row in
                rowProvider(row) != nil
            }
            resizeDocument()
            headerView?.needsDisplay = true
            documentView?.needsDisplay = true
            layoutHoverButtons()
            if changed {
                notifyVisibleRowsChanged()
            }
        }

        func numberOfRowsForTesting() -> Int {
            rowCount
        }

        func cellFullText(row: Int, column: Int) -> String {
            if row == -1 {
                return ["#", "Name", "Cues"][column]
            }
            guard row >= 0, row < rowCount else { return "" }
            guard column != 0 else { return "\(row + 1)" }
            guard let model = rowProvider(row) else { return "" }
            switch column {
            case 1: return model.name
            default: return model.cues
            }
        }

        func resizeDocument() {
            guard let scrollView, let documentView else { return }
            let width = max(scrollView.contentSize.width, scrollView.bounds.width)
            let height = max(
                scrollView.contentSize.height,
                CGFloat(rowCount) * SubtitleTableMetrics.estimatedRowHeight
            )
            let nextSize = CGSize(width: width, height: max(1, height))
            guard documentView.frame.size != nextSize else { return }
            documentView.setFrameSize(nextSize)
        }

        func notifyVisibleRowsChanged() {
            guard let range = visibleRowRange() else { return }
            onVisibleRowsChange(range)
        }

        @objc func scrollContentDidChange() {
            notifyVisibleRowsChanged()
            layoutHoverButtons()
        }

        func drawRows(in dirtyRect: CGRect) {
            guard let documentView else { return }
            documentView.effectiveAppearance.performAsCurrentDrawingAppearance {
                drawRowsNow(in: dirtyRect)
            }
        }

        private func drawRowsNow(in dirtyRect: CGRect) {
            guard rowCount > 0,
                  let documentView,
                  let range = visibleRowRange(in: dirtyRect)
            else {
                return
            }

            for row in range {
                let rowRect = rectForRow(row, width: documentView.bounds.width)
                drawRowBackground(row: row, rect: rowRect)
                drawCellTexts(row: row, rowRect: rowRect)
            }
        }

        private func drawRowBackground(row: Int, rect: CGRect) {
            if hoveredRow == row {
                NSColor.secondaryLabelColor.withAlphaComponent(0.06).setFill()
                rect.fill()
            }

            NSColor.separatorColor.setStroke()
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY - 0.5))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 0.5))
            path.lineWidth = 0.5
            path.stroke()
        }

        private func drawCellTexts(row: Int, rowRect: CGRect) {
            let M = SubtitleTableMetrics.self
            let model = rowProvider(row)

            drawIndex(row + 1, in: CGRect(x: 0, y: rowRect.minY, width: M.indexColumnWidth, height: rowRect.height))
            drawBody(
                model?.name ?? "",
                in: CGRect(x: M.indexColumnWidth, y: rowRect.minY, width: M.nameColumnWidth, height: rowRect.height),
                trailing: M.trailingInset
            )
            drawBody(
                model?.cues ?? "",
                in: CGRect(
                    x: M.indexColumnWidth + M.nameColumnWidth,
                    y: rowRect.minY,
                    width: max(0, rowRect.width - M.indexColumnWidth - M.nameColumnWidth),
                    height: rowRect.height
                ),
                trailing: M.trailingInset
            )
        }

        private func drawIndex(_ number: Int, in rect: CGRect) {
            let M = SubtitleTableMetrics.self
            textLayout.update(
                attributedString: SubtitleTableText.index(number),
                width: max(0, rect.width - M.cellLeading - M.indexTrailingInset)
            )
            textLayout.draw(at: CGPoint(x: rect.minX + M.cellLeading, y: rect.minY + M.rowVerticalInset))
        }

        private func drawBody(_ text: String, in rect: CGRect, trailing: CGFloat) {
            let M = SubtitleTableMetrics.self
            guard !text.isEmpty else { return }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(rect)
            textLayout.update(
                attributedString: SubtitleTableText.body(text),
                width: max(0, rect.width - M.cellLeading - trailing)
            )
            textLayout.draw(at: CGPoint(x: rect.minX + M.cellLeading, y: rect.minY + M.rowVerticalInset))
            NSGraphicsContext.restoreGraphicsState()
        }

        private func heightForRow(_ row: Int, width: CGFloat) -> CGFloat {
            _ = row
            _ = width
            return SubtitleTableMetrics.estimatedRowHeight
        }

        private func rectForRow(_ row: Int, width: CGFloat) -> CGRect {
            let y = rowHeightCache.yOffset(for: row, defaultHeight: SubtitleTableMetrics.estimatedRowHeight)
            let height = heightForRow(row, width: width)
            return CGRect(x: 0, y: y, width: width, height: height)
        }

        private func visibleRowRange() -> Range<Int>? {
            guard let scrollView else { return nil }
            return visibleRowRange(in: scrollView.contentView.bounds)
        }

        private func visibleRowRange(in rect: CGRect) -> Range<Int>? {
            guard rowCount > 0 else { return nil }
            let lower = rowHeightCache.rowIndex(
                atY: rect.minY,
                rowCount: rowCount,
                defaultHeight: SubtitleTableMetrics.estimatedRowHeight
            )
            let upper = rowHeightCache.rowIndex(
                atY: max(rect.minY, rect.maxY),
                rowCount: rowCount,
                defaultHeight: SubtitleTableMetrics.estimatedRowHeight
            )
            let overscan = 4
            let lowerBound = max(0, lower - overscan)
            let upperBound = min(rowCount, upper + overscan + 1)
            return lowerBound < upperBound ? lowerBound..<upperBound : nil
        }

        private func rowAtDocumentPoint(_ point: CGPoint) -> Int? {
            guard rowCount > 0 else { return nil }
            let row = rowHeightCache.rowIndex(
                atY: point.y,
                rowCount: rowCount,
                defaultHeight: SubtitleTableMetrics.estimatedRowHeight
            )
            let rect = rectForRow(row, width: documentView?.bounds.width ?? 0)
            return rect.contains(point) ? row : nil
        }

        func handleMouseHover(windowPoint: CGPoint) {
            guard let documentView else { return }
            let point = documentView.convert(windowPoint, from: nil)
            guard documentView.visibleRect.contains(point) else {
                clearHover()
                return
            }
            updateHoveredRow(rowAtDocumentPoint(point))
        }

        func clearHover() {
            updateHoveredRow(nil)
        }

        private func updateHoveredRow(_ newRow: Int?) {
            guard newRow != hoveredRow else { return }
            let oldRow = hoveredRow
            hoveredRow = newRow
            invalidateRows([oldRow, newRow])
            layoutHoverButtons()
        }

        private func invalidateRows(_ rows: [Int?]) {
            guard let documentView else { return }
            for row in rows.compactMap({ $0 }) where row >= 0 && row < rowCount {
                documentView.setNeedsDisplay(rectForRow(row, width: documentView.bounds.width))
            }
        }

        private func layoutHoverButtons() {
            guard let buttonsHost, let documentView, let hoveredRow,
                  hoveredRow >= 0,
                  hoveredRow < rowCount,
                  let model = rowProvider(hoveredRow)
            else {
                buttonsHost?.isHidden = true
                return
            }

            buttonsHost.rootView = CueHoverButtons(
                onPlay: { [weak self] in self?.playRow(hoveredRow) },
                onCopy: { [weak self] in self?.copyRow(hoveredRow) }
            )
            let rowRect = rectForRow(hoveredRow, width: documentView.bounds.width)
            let x = SubtitleTableMetrics.indexColumnWidth + SubtitleTableMetrics.nameColumnWidth + SubtitleTableMetrics.cellLeading
            let y = rowRect.minY + SubtitleTableMetrics.rowVerticalInset - 4
            buttonsHost.frame = CGRect(x: x, y: y, width: 120, height: 28)
            buttonsHost.isHidden = model.cues.isEmpty
        }

        private func playRow(_ row: Int) {
            guard let model = rowProvider(row) else { return }
            onPlay(model)
        }

        private func copyRow(_ row: Int) {
            guard let model = rowProvider(row) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(model.cues, forType: .string)
        }

        private func scheduleResizeAfterDrawing() {
            resizeDocument()
        }
    }
}
