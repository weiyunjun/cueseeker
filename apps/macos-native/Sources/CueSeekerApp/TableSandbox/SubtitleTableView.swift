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

final class SubtitleTextCellView: NSView {
    private let layout = SubtitleTextLayout()
    private var attributed = NSAttributedString()
    private var leadingInset = SubtitleTableMetrics.cellLeading
    private var trailingInset = SubtitleTableMetrics.trailingInset
    private var selectedRange: NSRange?

    /// Header cells center their single line vertically; body cells stay top-aligned.
    var centersVertically = false

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

// MARK: - Row view (hover + per-row separator)

final class SubtitleTableRowView: NSTableRowView {
    private var hoverTracking: NSTrackingArea?
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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking {
            removeTrackingArea(hoverTracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
}

// MARK: - Frozen header

final class SubtitleTableHeaderView: NSView {
    private let indexLabel = SubtitleTableHeaderView.makeHeaderLabel("#")
    private let nameLabel = SubtitleTableHeaderView.makeHeaderLabel("Name")
    private let cuesLabel = SubtitleTableHeaderView.makeHeaderLabel("Cues")

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let M = SubtitleTableMetrics.self
        [indexLabel, nameLabel, cuesLabel].forEach { addSubview($0) }
        NSLayoutConstraint.activate([
            indexLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: M.cellLeading),
            indexLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: M.indexColumnWidth + M.cellLeading),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            cuesLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: M.indexColumnWidth + M.nameColumnWidth + M.cellLeading),
            cuesLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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

    private static func makeHeaderLabel(_ title: String) -> NSTextField {
        let field = NSTextField(labelWithString: title)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = SubtitleTableText.headerFont
        field.textColor = .secondaryLabelColor
        field.drawsBackground = false
    return field
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

        // MARK: Data source / delegate

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            false
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            if let reused = tableView.makeView(withIdentifier: Self.rowViewID, owner: nil) as? SubtitleTableRowView {
                return reused
            }
            let view = SubtitleTableRowView()
            view.identifier = Self.rowViewID
            return view
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let columnID = tableColumn?.identifier else { return nil }
            let model = rows[row]
            let M = SubtitleTableMetrics.self

            switch columnID {
            case SubtitleTableView.indexColumnID:
                let cell = dequeueTextCell(tableView, id: Self.indexCellID)
                cell.configure(attributed: SubtitleTableText.index(row + 1), leading: M.cellLeading, trailing: M.indexTrailingInset)
                return cell

            case SubtitleTableView.nameColumnID:
                let cell = dequeueTextCell(tableView, id: Self.nameCellID)
                cell.configure(attributed: SubtitleTableText.body(model.name), leading: M.cellLeading, trailing: M.trailingInset)
                return cell

            case SubtitleTableView.cuesColumnID:
                let cell = dequeueTextCell(tableView, id: Self.cuesCellID)
                cell.configure(attributed: SubtitleTableText.body(model.cues), leading: M.cellLeading, trailing: M.trailingInset)
                return cell

            default:
                return nil
            }
        }

        private func dequeueTextCell(_ tableView: NSTableView, id: NSUserInterfaceItemIdentifier) -> SubtitleTextCellView {
            if let reused = tableView.makeView(withIdentifier: id, owner: nil) as? SubtitleTextCellView {
                return reused
            }
            let cell = SubtitleTextCellView()
            cell.identifier = id
            return cell
        }
    }
}
