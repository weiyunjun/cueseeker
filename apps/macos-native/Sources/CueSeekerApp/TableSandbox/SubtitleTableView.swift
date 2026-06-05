import AppKit
import SwiftUI

// MARK: - Metrics

enum SubtitleTableMetrics {
    static let indexColumnWidth: CGFloat = 50
    static let nameColumnWidth: CGFloat = 240
    static let cellLeading: CGFloat = 12
    static let trailingInset: CGFloat = 14
    static let rowVerticalInset: CGFloat = 9
    static let headerHeight: CGFloat = 34
    static let playButtonSize: CGFloat = 16
    static let playToTextSpacing: CGFloat = 8
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

    static func bodyAttributedString(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: bodyFont,
            .paragraphStyle: bodyParagraphStyle(),
            .foregroundColor: NSColor.labelColor,
        ])
    }
}

// MARK: - Selectable label (drag-select clears any active select-all)

final class SelectableLabel: NSTextField {
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }
}

@MainActor
private func makeCellLabel() -> SelectableLabel {
    let field = SelectableLabel(labelWithString: "")
    field.translatesAutoresizingMaskIntoConstraints = false
    field.isEditable = false
    field.isBordered = false
    field.drawsBackground = false
    field.backgroundColor = .clear
    field.isSelectable = true
    field.allowsEditingTextAttributes = false
    field.lineBreakMode = .byWordWrapping
    field.maximumNumberOfLines = 0
    field.cell?.wraps = true
    field.cell?.isScrollable = false
    field.setContentHuggingPriority(.required, for: .vertical)
    field.setContentCompressionResistancePriority(.required, for: .vertical)
    return field
}

/// Pins a wrapping label to the top of `host`. The bottom is required-minus-one
/// so natural sizing keeps the bottom inset, but yields to keep the label
/// top-aligned when the row is taller than this cell's content.
@MainActor
private func pinTopAligned(_ label: NSView, in host: NSView, leading: CGFloat, trailing: CGFloat) {
    let bottom = label.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -SubtitleTableMetrics.rowVerticalInset)
    bottom.priority = NSLayoutConstraint.Priority(999)
    NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: leading),
        label.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -trailing),
        label.topAnchor.constraint(equalTo: host.topAnchor, constant: SubtitleTableMetrics.rowVerticalInset),
        bottom,
    ])
}

// MARK: - Highlighting cell base (text-only select-all highlight)

class HighlightingCellView: NSView {
    let label = makeCellLabel()
    var onTextInteraction: (() -> Void)?

    private var textSelected = false
    private var highlightRect: CGRect = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.onMouseDown = { [weak self] in
            self?.onTextInteraction?()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    func setTextSelected(_ selected: Bool) {
        guard selected != textSelected else { return }
        textSelected = selected
        needsDisplay = true
    }

    private func recomputeHighlightRect() {
        let width = label.bounds.width
        guard width > 0, label.attributedStringValue.length > 0 else {
            highlightRect = .zero
            return
        }
        let size = label.attributedStringValue.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        highlightRect = CGRect(
            x: label.frame.minX,
            y: label.frame.minY,
            width: ceil(size.width),
            height: ceil(size.height)
        )
    }

    override func layout() {
        super.layout()
        label.preferredMaxLayoutWidth = label.bounds.width
        recomputeHighlightRect()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard textSelected, highlightRect.width > 0 else { return }
        NSColor.selectedTextBackgroundColor.setFill()
        highlightRect.fill()
    }
}

final class IndexCellView: HighlightingCellView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.maximumNumberOfLines = 1
        label.font = SubtitleTableText.indexFont
        label.textColor = .secondaryLabelColor
        addSubview(label)
        pinTopAligned(label, in: self, leading: SubtitleTableMetrics.cellLeading, trailing: 4)
    }

    func configure(number: Int) {
        label.stringValue = "\(number)"
        needsLayout = true
    }
}

final class NameCellView: HighlightingCellView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(label)
        pinTopAligned(label, in: self, leading: SubtitleTableMetrics.cellLeading, trailing: SubtitleTableMetrics.trailingInset)
    }

    func configure(text: String) {
        label.attributedStringValue = SubtitleTableText.bodyAttributedString(text)
        needsLayout = true
    }
}

final class CuesCellView: HighlightingCellView {
    private let playButton = HoverImageButton()
    private var onPlay: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        playButton.configureAsPlay()
        playButton.target = self
        playButton.action = #selector(playTapped)
        addSubview(playButton)
        addSubview(label)

        let M = SubtitleTableMetrics.self
        let labelBottom = label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -M.rowVerticalInset)
        labelBottom.priority = NSLayoutConstraint.Priority(999)
        NSLayoutConstraint.activate([
            playButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: M.cellLeading),
            playButton.topAnchor.constraint(equalTo: topAnchor, constant: M.rowVerticalInset),
            playButton.widthAnchor.constraint(equalToConstant: M.playButtonSize),
            playButton.heightAnchor.constraint(equalToConstant: M.playButtonSize),

            label.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: M.playToTextSpacing),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -M.trailingInset),
            label.topAnchor.constraint(equalTo: topAnchor, constant: M.rowVerticalInset),
            labelBottom,
        ])
    }

    func configure(text: String, onPlay: @escaping () -> Void) {
        label.attributedStringValue = SubtitleTableText.bodyAttributedString(text)
        self.onPlay = onPlay
        needsLayout = true
    }

    @objc private func playTapped() {
        onPlay?()
    }
}

// MARK: - Play button (low-key, hover darkens)

final class HoverImageButton: NSButton {
    private var hoverTracking: NSTrackingArea?

    func configureAsPlay() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        focusRingType = .none
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")?
            .withSymbolConfiguration(config)
        contentTintColor = .secondaryLabelColor
        toolTip = "Play"
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
        contentTintColor = .labelColor
    }

    override func mouseExited(with event: NSEvent) {
        contentTintColor = .secondaryLabelColor
    }
}

// MARK: - Row view (hover + per-row separator, no row selection)

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

// MARK: - Sticky header

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

    func setTextSelected(_ selected: Bool) {
        for label in [indexLabel, nameLabel, cuesLabel] {
            label.drawsBackground = selected
            label.backgroundColor = selected ? .selectedTextBackgroundColor : .clear
        }
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

    private static func makeHeaderLabel(_ title: String) -> NSTextField {
        let field = NSTextField(labelWithString: title)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = SubtitleTableText.headerFont
        field.textColor = .secondaryLabelColor
        field.isSelectable = true
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

// MARK: - Table view (cmd+A / cmd+C scoped to the table, no row selection)

final class SubtitleTableNSTableView: NSTableView {
    weak var tableCoordinator: SubtitleTableView.Coordinator?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isCommand = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
        guard isCommand, let chars = event.charactersIgnoringModifiers, isFocusWithinTable else {
            return super.performKeyEquivalent(with: event)
        }

        switch chars {
        case "a":
            window?.makeFirstResponder(self)
            tableCoordinator?.setAllTextSelected(true)
            return true
        case "c":
            if tableCoordinator?.isAllTextSelected == true {
                tableCoordinator?.copyAllText()
                return true
            }
            return super.performKeyEquivalent(with: event)
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        tableCoordinator?.setAllTextSelected(false)
        super.mouseDown(with: event)
    }

    private var isFocusWithinTable: Bool {
        guard let responder = window?.firstResponder else { return false }
        if responder === self { return true }
        var view = responder as? NSView
        while let current = view {
            if current === self { return true }
            view = current.superview
        }
        return false
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
        weak var headerView: SubtitleTableHeaderView?
        private(set) var isAllTextSelected = false

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

        // MARK: Select-all text + copy

        func setAllTextSelected(_ selected: Bool) {
            isAllTextSelected = selected
            tableView?.enumerateAvailableRowViews { rowView, _ in
                for subview in rowView.subviews {
                    (subview as? HighlightingCellView)?.setTextSelected(selected)
                }
            }
            headerView?.setTextSelected(selected)
        }

        func copyAllText() {
            var lines = ["#\tName\tCues"]
            for (index, row) in rows.enumerated() {
                let cues = row.cues.replacingOccurrences(of: "\n", with: " ")
                lines.append("\(index + 1)\t\(row.name)\t\(cues)")
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
        }

        // MARK: Row heights

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            let model = rows[row]
            let M = SubtitleTableMetrics.self

            let nameWidth = M.nameColumnWidth - M.cellLeading - M.trailingInset
            let cuesWidth = cuesColumnWidth(in: tableView)
                - M.cellLeading - M.playButtonSize - M.playToTextSpacing - M.trailingInset

            let nameHeight = Self.measuredHeight(model.name, width: nameWidth)
            let cuesHeight = Self.measuredHeight(model.cues, width: cuesWidth)
            let oneLine = ceil(SubtitleTableText.bodyFont.boundingRectForFont.height)
            let content = max(nameHeight, cuesHeight, oneLine)
            return content + 2 * M.rowVerticalInset
        }

        private func cuesColumnWidth(in tableView: NSTableView) -> CGFloat {
            if let column = tableView.tableColumns.first(where: { $0.identifier == SubtitleTableView.cuesColumnID }) {
                return column.width
            }
            return max(0, tableView.bounds.width - SubtitleTableMetrics.indexColumnWidth - SubtitleTableMetrics.nameColumnWidth)
        }

        private static func measuredHeight(_ text: String, width: CGFloat) -> CGFloat {
            guard width > 0, !text.isEmpty else {
                return ceil(SubtitleTableText.bodyFont.boundingRectForFont.height)
            }
            let rect = SubtitleTableText.bodyAttributedString(text).boundingRect(
                with: NSSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            return ceil(rect.height)
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

            switch columnID {
            case SubtitleTableView.indexColumnID:
                let cell = (tableView.makeView(withIdentifier: Self.indexCellID, owner: nil) as? IndexCellView) ?? {
                    let view = IndexCellView()
                    view.identifier = Self.indexCellID
                    return view
                }()
                cell.configure(number: row + 1)
                bind(cell)
                return cell

            case SubtitleTableView.nameColumnID:
                let cell = (tableView.makeView(withIdentifier: Self.nameCellID, owner: nil) as? NameCellView) ?? {
                    let view = NameCellView()
                    view.identifier = Self.nameCellID
                    return view
                }()
                cell.configure(text: model.name)
                bind(cell)
                return cell

            case SubtitleTableView.cuesColumnID:
                let cell = (tableView.makeView(withIdentifier: Self.cuesCellID, owner: nil) as? CuesCellView) ?? {
                    let view = CuesCellView()
                    view.identifier = Self.cuesCellID
                    return view
                }()
                cell.configure(text: model.cues) { [weak self] in
                    self?.onPlay(model)
                }
                bind(cell)
                return cell

            default:
                return nil
            }
        }

        private func bind(_ cell: HighlightingCellView) {
            cell.onTextInteraction = { [weak self] in
                self?.setAllTextSelected(false)
            }
            cell.setTextSelected(isAllTextSelected)
        }
    }
}
