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
    static let headerHeight: CGFloat = 34
    static let cornerRadius: CGFloat = 10
}

// MARK: - Typography (aligned with the production search/Shiori cue text)

@MainActor
enum SubtitleTableText {
    static let bodyFont = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
    static let indexFont = NSFont.systemFont(ofSize: 12, weight: .regular)
    static let headerFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
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
}

// MARK: - TextKit layout (one stack per cell; reused for drawing + measurement)

@MainActor
final class SubtitleTextLayout {
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    init() {
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
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

    var length: Int {
        textStorage.length
    }

    /// Nearest insertion-point character index for a point in text-local
    /// coordinates (already offset by the cell's content origin).
    func characterIndex(forPoint point: CGPoint) -> Int {
        guard textStorage.length > 0 else { return 0 }
        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        var characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        if fraction >= 0.5 {
            characterIndex += 1
        }
        return min(max(0, characterIndex), textStorage.length)
    }

    /// Enclosing rects (text-local) for a character range, used to paint the
    /// selection highlight behind the glyphs.
    func selectionRects(forCharacterRange range: NSRange) -> [CGRect] {
        guard range.length > 0 else { return [] }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rects: [CGRect] = []
        layoutManager.enumerateEnclosingRects(
            forGlyphRange: glyphRange,
            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
            in: textContainer
        ) { rect, _ in
            rects.append(rect)
        }
        return rects
    }
}

// MARK: - Self-drawn text cell (foundation for custom selection in B2)

class SubtitleTextCellView: NSView {
    private let layout = SubtitleTextLayout()
    private var attributed = NSAttributedString()
    private var leadingInset = SubtitleTableMetrics.cellLeading
    private var trailingInset = SubtitleTableMetrics.trailingInset
    private var selectedRange: NSRange?

    /// Document coordinates of this cell: row (-1 for the header) and column 0/1/2.
    var rowIndex = 0
    var columnIndex = 0

    /// Header cells center their single line vertically; body cells stay top-aligned.
    var centersVertically = false

    weak var selectionHandler: SubtitleTableView.Coordinator?

    override var isFlipped: Bool { true }

    func configure(attributed: NSAttributedString, leading: CGFloat, trailing: CGFloat) {
        self.attributed = attributed
        self.leadingInset = leading
        self.trailingInset = trailing
        relayout()
        needsDisplay = true
    }

    private var textWidth: CGFloat {
        max(0, bounds.width - leadingInset - trailingInset)
    }

    private func relayout() {
        layout.update(attributedString: attributed, width: textWidth)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        relayout()
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    private func contentOrigin() -> CGPoint {
        let y: CGFloat = centersVertically
            ? max(0, (bounds.height - layout.usedHeight) / 2)
            : SubtitleTableMetrics.rowVerticalInset
        return CGPoint(x: leadingInset, y: y)
    }

    var textLength: Int {
        layout.length
    }

    func characterIndex(at point: CGPoint) -> Int {
        let origin = contentOrigin()
        return layout.characterIndex(forPoint: CGPoint(x: point.x - origin.x, y: point.y - origin.y))
    }

    func setSelectedRange(_ range: NSRange?) {
        selectedRange = range
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let position = TableTextPosition(row: rowIndex, column: columnIndex, char: characterIndex(at: localPoint))
        selectionHandler?.beginSelection(at: position)
    }

    override func mouseDragged(with event: NSEvent) {
        selectionHandler?.updateSelection(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        selectionHandler?.endSelection()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let origin = contentOrigin()
        if let range = selectedRange, range.length > 0 {
            NSColor.selectedTextBackgroundColor.setFill()
            for rect in layout.selectionRects(forCharacterRange: range) {
                rect.offsetBy(dx: origin.x, dy: origin.y).fill()
            }
        }
        layout.draw(at: origin)
    }
}

// MARK: - Hover Play/Copy buttons for the Cues cell

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

/// Cues cell that overlays hover Play/Copy buttons at its left. Text selection
/// and drawing are inherited from SubtitleTextCellView.
final class SubtitleCuesCellView: SubtitleTextCellView {
    private let buttonsHost: NSHostingView<CueHoverButtons>

    override init(frame frameRect: NSRect) {
        buttonsHost = NSHostingView(rootView: CueHoverButtons(onPlay: {}, onCopy: {}))
        super.init(frame: frameRect)
        buttonsHost.translatesAutoresizingMaskIntoConstraints = false
        buttonsHost.isHidden = true
        addSubview(buttonsHost)
        NSLayoutConstraint.activate([
            buttonsHost.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SubtitleTableMetrics.cellLeading),
            buttonsHost.topAnchor.constraint(equalTo: topAnchor, constant: SubtitleTableMetrics.rowVerticalInset - 4),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setActions(onPlay: @escaping () -> Void, onCopy: @escaping () -> Void) {
        buttonsHost.rootView = CueHoverButtons(onPlay: onPlay, onCopy: onCopy)
    }

    /// Visibility is driven centrally by the coordinator's single hovered row.
    func setButtonsVisible(_ visible: Bool) {
        buttonsHost.isHidden = !visible
    }
}

// MARK: - Row view (hover + per-row separator)

final class SubtitleTableRowView: NSTableRowView {
    /// Driven centrally by the coordinator's single hovered row.
    var isHovered = false {
        didSet {
            guard isHovered != oldValue else { return }
            needsDisplay = true
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        if isHovered {
            NSColor.secondaryLabelColor.withAlphaComponent(0.06).setFill()
            bounds.fill()
        }
        // Per-row bottom hairline so separators appear only between real rows.
        NSColor.separatorColor.setStroke()
        let y = bounds.maxY - 0.5
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.minX, y: y))
        path.line(to: NSPoint(x: bounds.maxX, y: y))
        path.lineWidth = 0.5
        path.stroke()
    }
}

// MARK: - Frozen header

final class SubtitleTableHeaderView: NSView {
    let cells: [SubtitleTextCellView]

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        let M = SubtitleTableMetrics.self
        let index = SubtitleTableHeaderView.makeHeaderCell("#", column: 0, trailing: M.indexTrailingInset)
        let name = SubtitleTableHeaderView.makeHeaderCell("Name", column: 1, trailing: M.trailingInset)
        let cues = SubtitleTableHeaderView.makeHeaderCell("Cues", column: 2, trailing: M.trailingInset)
        cells = [index, name, cues]
        super.init(frame: frameRect)

        cells.forEach { addSubview($0) }
        NSLayoutConstraint.activate([
            index.leadingAnchor.constraint(equalTo: leadingAnchor),
            index.topAnchor.constraint(equalTo: topAnchor),
            index.bottomAnchor.constraint(equalTo: bottomAnchor),
            index.widthAnchor.constraint(equalToConstant: M.indexColumnWidth),

            name.leadingAnchor.constraint(equalTo: index.trailingAnchor),
            name.topAnchor.constraint(equalTo: topAnchor),
            name.bottomAnchor.constraint(equalTo: bottomAnchor),
            name.widthAnchor.constraint(equalToConstant: M.nameColumnWidth),

            cues.leadingAnchor.constraint(equalTo: name.trailingAnchor),
            cues.trailingAnchor.constraint(equalTo: trailingAnchor),
            cues.topAnchor.constraint(equalTo: topAnchor),
            cues.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func columnIndex(forX x: CGFloat) -> Int {
        let M = SubtitleTableMetrics.self
        if x < M.indexColumnWidth { return 0 }
        if x < M.indexColumnWidth + M.nameColumnWidth { return 1 }
        return 2
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.separatorColor.setStroke()
        let y = bounds.maxY - 0.5
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.minX, y: y))
        path.line(to: NSPoint(x: bounds.maxX, y: y))
        path.lineWidth = 0.5
        path.stroke()
    }

    private static func makeHeaderCell(_ title: String, column: Int, trailing: CGFloat) -> SubtitleTextCellView {
        let cell = SubtitleTextCellView()
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.centersVertically = true
        cell.rowIndex = -1
        cell.columnIndex = column
        let attributed = NSAttributedString(string: title, attributes: [
            .font: SubtitleTableText.headerFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        cell.configure(attributed: attributed, leading: SubtitleTableMetrics.cellLeading, trailing: trailing)
        return cell
    }
}

// MARK: - Rounded container

final class SubtitleTableContainerView: NSView {
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

// MARK: - Table view (minimal subclass; selection added in B2)

final class SubtitleTableNSTableView: NSTableView {
    weak var tableCoordinator: SubtitleTableView.Coordinator?
    private var hoverTracking: NSTrackingArea?

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
        tableCoordinator?.handleMouseHover(windowPoint: event.locationInWindow)
    }

    override func mouseEntered(with event: NSEvent) {
        tableCoordinator?.handleMouseHover(windowPoint: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        tableCoordinator?.clearHover()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        tableCoordinator?.clearSelection()
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isCommand = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
        guard isCommand, window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "a":
            tableCoordinator?.selectAll()
            return true
        case "c":
            tableCoordinator?.copySelection()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

// MARK: - Document position (reading order across header + rows + columns)

struct TableTextPosition: Comparable {
    var row: Int     // -1 = header, 0..n-1 = data rows
    var column: Int  // 0 = #, 1 = Name, 2 = Cues
    var char: Int

    static func < (lhs: TableTextPosition, rhs: TableTextPosition) -> Bool {
        if lhs.row != rhs.row { return lhs.row < rhs.row }
        if lhs.column != rhs.column { return lhs.column < rhs.column }
        return lhs.char < rhs.char
    }
}

// MARK: - SwiftUI bridge

struct SubtitleTableView: NSViewRepresentable {
    var rows: [SubtitleTableRow]
    var onPlay: (SubtitleTableRow) -> Void

    fileprivate static let indexColumnID = NSUserInterfaceItemIdentifier("SubtitleTable.index")
    fileprivate static let nameColumnID = NSUserInterfaceItemIdentifier("SubtitleTable.name")
    fileprivate static let cuesColumnID = NSUserInterfaceItemIdentifier("SubtitleTable.cues")

    func makeCoordinator() -> Coordinator {
        Coordinator(rows: rows, onPlay: onPlay)
    }

    func makeNSView(context: Context) -> SubtitleTableContainerView {
        let container = SubtitleTableContainerView()

        let header = SubtitleTableHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.headerView = header
        for cell in header.cells {
            cell.selectionHandler = context.coordinator
        }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let table = SubtitleTableNSTableView()
        table.tableCoordinator = context.coordinator
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.style = .plain
        table.headerView = nil
        table.allowsColumnReordering = false
        table.allowsColumnResizing = false
        table.allowsColumnSelection = false
        table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.gridStyleMask = []
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .none
        table.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.tableFrameChanged),
            name: NSView.frameDidChangeNotification,
            object: table
        )

        let indexColumn = NSTableColumn(identifier: Self.indexColumnID)
        indexColumn.width = SubtitleTableMetrics.indexColumnWidth
        indexColumn.minWidth = SubtitleTableMetrics.indexColumnWidth
        indexColumn.maxWidth = SubtitleTableMetrics.indexColumnWidth
        table.addTableColumn(indexColumn)

        let nameColumn = NSTableColumn(identifier: Self.nameColumnID)
        nameColumn.width = SubtitleTableMetrics.nameColumnWidth
        nameColumn.minWidth = SubtitleTableMetrics.nameColumnWidth
        nameColumn.maxWidth = SubtitleTableMetrics.nameColumnWidth
        table.addTableColumn(nameColumn)

        let cuesColumn = NSTableColumn(identifier: Self.cuesColumnID)
        cuesColumn.width = 400
        cuesColumn.minWidth = 200
        table.addTableColumn(cuesColumn)

        scrollView.documentView = table
        context.coordinator.tableView = table

        scrollView.contentView.postsBoundsChangedNotifications = true
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

        table.reloadData()
        return container
    }

    func updateNSView(_ nsView: SubtitleTableContainerView, context: Context) {
        context.coordinator.update(rows: rows, onPlay: onPlay)
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        private var rows: [SubtitleTableRow]
        private var onPlay: (SubtitleTableRow) -> Void
        weak var tableView: NSTableView?
        weak var headerView: SubtitleTableHeaderView?

        private var anchor: TableTextPosition?
        private var focus: TableTextPosition?
        private var autoscrollTask: Task<Void, Never>?
        private var lastDragEvent: NSEvent?

        private var hoveredRow: Int?
        private var lastMouseWindowPoint: CGPoint?

        private let nameMeasurer = SubtitleTextLayout()
        private let cuesMeasurer = SubtitleTextLayout()

        /// Minimum content height = exactly one body line (no inter-line spacing),
        /// so a single-line row is one line tall, not two.
        private lazy var singleLineFloor: CGFloat = {
            let measurer = SubtitleTextLayout()
            measurer.update(
                attributedString: NSAttributedString(string: "Ag", attributes: [.font: SubtitleTableText.bodyFont]),
                width: .greatestFiniteMagnitude
            )
            return measurer.usedHeight
        }()

        private static let indexCellID = NSUserInterfaceItemIdentifier("SubtitleTable.indexCell")
        private static let nameCellID = NSUserInterfaceItemIdentifier("SubtitleTable.nameCell")
        private static let cuesCellID = NSUserInterfaceItemIdentifier("SubtitleTable.cuesCell")
        private static let rowViewID = NSUserInterfaceItemIdentifier("SubtitleTable.rowView")

        init(rows: [SubtitleTableRow], onPlay: @escaping (SubtitleTableRow) -> Void) {
            self.rows = rows
            self.onPlay = onPlay
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func update(rows: [SubtitleTableRow], onPlay: @escaping (SubtitleTableRow) -> Void) {
            self.onPlay = onPlay
            guard rows != self.rows else { return }
            self.rows = rows
            tableView?.reloadData()
        }

        @objc func tableFrameChanged() {
            guard let tableView, tableView.numberOfRows > 0 else { return }
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<tableView.numberOfRows))
        }

        // MARK: Row heights

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            let model = rows[row]
            let M = SubtitleTableMetrics.self

            let nameWidth = M.nameColumnWidth - M.cellLeading - M.trailingInset
            let cuesWidth = cuesColumnWidth(in: tableView) - M.cellLeading - M.trailingInset

            nameMeasurer.update(attributedString: SubtitleTableText.body(model.name), width: nameWidth)
            cuesMeasurer.update(attributedString: SubtitleTableText.body(model.cues), width: cuesWidth)

            let content = max(nameMeasurer.usedHeight, cuesMeasurer.usedHeight, singleLineFloor)
            return content + 2 * M.rowVerticalInset
        }

        private func cuesColumnWidth(in tableView: NSTableView) -> CGFloat {
            if let column = tableView.tableColumns.first(where: { $0.identifier == SubtitleTableView.cuesColumnID }) {
                return column.width
            }
            return max(0, tableView.bounds.width - SubtitleTableMetrics.indexColumnWidth - SubtitleTableMetrics.nameColumnWidth)
        }

        // MARK: Selection

        private func orderedSelection() -> (start: TableTextPosition, end: TableTextPosition)? {
            guard let anchor, let focus else { return nil }
            return anchor <= focus ? (anchor, focus) : (focus, anchor)
        }

        func selectAll() {
            let headerLength = (cellFullText(row: -1, column: 2) as NSString).length
            let start = TableTextPosition(row: -1, column: 0, char: 0)
            let end: TableTextPosition
            if rows.isEmpty {
                end = TableTextPosition(row: -1, column: 2, char: headerLength)
            } else {
                let last = rows.count - 1
                end = TableTextPosition(row: last, column: 2, char: cellTextLength(row: last, column: 2))
            }
            anchor = start
            focus = end
            refreshSelectionHighlights()
        }

        func clearSelection() {
            anchor = nil
            focus = nil
            refreshSelectionHighlights()
        }

        func beginSelection(at position: TableTextPosition) {
            tableView?.window?.makeFirstResponder(tableView)
            anchor = position
            focus = position
            refreshSelectionHighlights()
        }

        func updateSelection(with event: NSEvent) {
            lastDragEvent = event
            applyDragSelection(event)
            if autoscrollTask == nil {
                autoscrollTask = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        guard let self, let event = self.lastDragEvent else { break }
                        self.applyDragSelection(event)
                    }
                }
            }
        }

        private func applyDragSelection(_ event: NSEvent) {
            tableView?.autoscroll(with: event)
            guard let position = position(atWindowPoint: event.locationInWindow) else { return }
            focus = position
            refreshSelectionHighlights()
        }

        func endSelection() {
            autoscrollTask?.cancel()
            autoscrollTask = nil
            lastDragEvent = nil
        }

        func copySelection() {
            guard let selection = orderedSelection(), selection.start < selection.end else { return }
            var lines: [String] = []
            for row in selection.start.row...selection.end.row {
                var columns: [String] = []
                for column in 0..<3 {
                    let full = cellFullText(row: row, column: column) as NSString
                    if let range = cellRange(row: row, column: column, length: full.length, selection: selection) {
                        columns.append(full.substring(with: range).replacingOccurrences(of: "\n", with: " "))
                    } else {
                        columns.append("")
                    }
                }
                lines.append(columns.joined(separator: "\t"))
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
        }

        private func position(atWindowPoint windowPoint: CGPoint) -> TableTextPosition? {
            if let headerView {
                let hp = headerView.convert(windowPoint, from: nil)
                if hp.y >= headerView.bounds.minY, hp.y <= headerView.bounds.maxY {
                    let column = headerView.columnIndex(forX: hp.x)
                    let cell = headerView.cells[column]
                    return TableTextPosition(row: -1, column: column, char: cell.characterIndex(at: cell.convert(windowPoint, from: nil)))
                }
            }
            guard let tableView else { return nil }
            let tp = tableView.convert(windowPoint, from: nil)
            let rowCount = tableView.numberOfRows
            guard rowCount > 0 else { return nil }

            var row = tableView.row(at: tp)
            if row < 0 {
                if tp.y < 0 {
                    row = 0
                } else {
                    let last = rowCount - 1
                    return TableTextPosition(row: last, column: 2, char: cellTextLength(row: last, column: 2))
                }
            }

            var column = tableView.column(at: tp)
            if column < 0 {
                column = tp.x < 0 ? 0 : 2
            }
            column = min(max(0, column), 2)

            let char: Int
            if let cell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? SubtitleTextCellView {
                char = cell.characterIndex(at: cell.convert(windowPoint, from: nil))
            } else {
                char = 0
            }
            return TableTextPosition(row: row, column: column, char: char)
        }

        func refreshSelectionHighlights() {
            let selection = orderedSelection()
            if let headerView {
                for cell in headerView.cells {
                    cell.setSelectedRange(cellRange(row: -1, column: cell.columnIndex, length: cell.textLength, selection: selection))
                }
            }
            guard let tableView else { return }
            let visible = tableView.rows(in: tableView.visibleRect)
            guard visible.length > 0 else { return }
            for row in visible.location..<(visible.location + visible.length) {
                for column in 0..<3 {
                    if let cell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? SubtitleTextCellView {
                        cell.setSelectedRange(cellRange(row: row, column: column, length: cell.textLength, selection: selection))
                    }
                }
            }
        }

        private func cellRange(row: Int, column: Int, length: Int, selection: (start: TableTextPosition, end: TableTextPosition)?) -> NSRange? {
            guard let selection else { return nil }
            let cellStart = TableTextPosition(row: row, column: column, char: 0)
            let cellEnd = TableTextPosition(row: row, column: column, char: length)
            if cellEnd < selection.start || selection.end < cellStart { return nil }
            let lower = (selection.start.row == row && selection.start.column == column) ? selection.start.char : 0
            let upper = (selection.end.row == row && selection.end.column == column) ? selection.end.char : length
            let lo = min(max(0, lower), length)
            let hi = min(max(lo, upper), length)
            return hi > lo ? NSRange(location: lo, length: hi - lo) : nil
        }

        func cellFullText(row: Int, column: Int) -> String {
            if row == -1 {
                return ["#", "Name", "Cues"][column]
            }
            let model = rows[row]
            switch column {
            case 0: return "\(row + 1)"
            case 1: return model.name
            default: return model.cues
            }
        }

        private func cellTextLength(row: Int, column: Int) -> Int {
            (cellFullText(row: row, column: column) as NSString).length
        }

        // MARK: Data source / delegate

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            false
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let rowView = (tableView.makeView(withIdentifier: Self.rowViewID, owner: nil) as? SubtitleTableRowView) ?? {
                let view = SubtitleTableRowView()
                view.identifier = Self.rowViewID
                return view
            }()
            rowView.isHovered = isRowHovered(row)
            return rowView
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let columnID = tableColumn?.identifier else { return nil }
            let model = rows[row]
            let M = SubtitleTableMetrics.self

            switch columnID {
            case SubtitleTableView.indexColumnID:
                let cell = dequeueTextCell(tableView, id: Self.indexCellID)
                cell.configure(attributed: SubtitleTableText.index(row + 1), leading: M.cellLeading, trailing: M.indexTrailingInset)
                prepare(cell, row: row, column: 0)
                return cell

            case SubtitleTableView.nameColumnID:
                let cell = dequeueTextCell(tableView, id: Self.nameCellID)
                cell.configure(attributed: SubtitleTableText.body(model.name), leading: M.cellLeading, trailing: M.trailingInset)
                prepare(cell, row: row, column: 1)
                return cell

            case SubtitleTableView.cuesColumnID:
                let cell = dequeueCuesCell(tableView)
                cell.configure(attributed: SubtitleTableText.body(model.cues), leading: M.cellLeading, trailing: M.trailingInset)
                prepare(cell, row: row, column: 2)
                cell.setActions(
                    onPlay: { [weak self] in self?.playRow(row) },
                    onCopy: { [weak self] in self?.copyRow(row) }
                )
                cell.setButtonsVisible(isRowHovered(row))
                return cell

            default:
                return nil
            }
        }

        private func prepare(_ cell: SubtitleTextCellView, row: Int, column: Int) {
            cell.rowIndex = row
            cell.columnIndex = column
            cell.selectionHandler = self
            cell.setSelectedRange(cellRange(row: row, column: column, length: cell.textLength, selection: orderedSelection()))
        }

        private func dequeueTextCell(_ tableView: NSTableView, id: NSUserInterfaceItemIdentifier) -> SubtitleTextCellView {
            if let reused = tableView.makeView(withIdentifier: id, owner: nil) as? SubtitleTextCellView {
                return reused
            }
            let cell = SubtitleTextCellView()
            cell.identifier = id
            return cell
        }

        private func dequeueCuesCell(_ tableView: NSTableView) -> SubtitleCuesCellView {
            if let reused = tableView.makeView(withIdentifier: Self.cuesCellID, owner: nil) as? SubtitleCuesCellView {
                return reused
            }
            let cell = SubtitleCuesCellView()
            cell.identifier = Self.cuesCellID
            return cell
        }

        func playRow(_ row: Int) {
            guard rows.indices.contains(row) else { return }
            onPlay(rows[row])
        }

        func copyRow(_ row: Int) {
            guard rows.indices.contains(row) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(rows[row].cues, forType: .string)
        }

        // MARK: Hover (single source of truth)

        func handleMouseHover(windowPoint: CGPoint) {
            lastMouseWindowPoint = windowPoint
            updateHoveredRow(rowUnderCursor(windowPoint: windowPoint))
        }

        func clearHover() {
            lastMouseWindowPoint = nil
            updateHoveredRow(nil)
        }

        @objc func scrollContentDidChange() {
            guard let lastMouseWindowPoint else { return }
            updateHoveredRow(rowUnderCursor(windowPoint: lastMouseWindowPoint))
        }

        func isRowHovered(_ row: Int) -> Bool {
            hoveredRow == row
        }

        private func rowUnderCursor(windowPoint: CGPoint) -> Int? {
            guard let tableView else { return nil }
            let point = tableView.convert(windowPoint, from: nil)
            guard tableView.visibleRect.contains(point) else { return nil }
            let row = tableView.row(at: point)
            return row >= 0 ? row : nil
        }

        private func updateHoveredRow(_ newRow: Int?) {
            guard newRow != hoveredRow else { return }
            if let old = hoveredRow {
                applyHover(row: old, hovered: false)
            }
            hoveredRow = newRow
            if let new = hoveredRow {
                applyHover(row: new, hovered: true)
            }
        }

        private func applyHover(row: Int, hovered: Bool) {
            guard let tableView, row >= 0, row < tableView.numberOfRows else { return }
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? SubtitleTableRowView {
                rowView.isHovered = hovered
            }
            if let cues = tableView.view(atColumn: 2, row: row, makeIfNecessary: false) as? SubtitleCuesCellView {
                cues.setButtonsVisible(hovered)
            }
        }
    }
}
