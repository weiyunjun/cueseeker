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
    static let bodyFontSize: CGFloat = 13
    static let headerFontSize: CGFloat = 11
}

// MARK: - Label factory

@MainActor
private func makeWrappingLabel(secondary: Bool) -> NSTextField {
    let field = NSTextField(labelWithString: "")
    field.translatesAutoresizingMaskIntoConstraints = false
    field.isEditable = false
    field.isBordered = false
    field.drawsBackground = false
    field.isSelectable = true
    field.allowsEditingTextAttributes = false
    field.lineBreakMode = .byWordWrapping
    field.maximumNumberOfLines = 0
    field.cell?.wraps = true
    field.cell?.isScrollable = false
    field.font = .systemFont(ofSize: SubtitleTableMetrics.bodyFontSize)
    field.textColor = secondary ? .secondaryLabelColor : .labelColor
    field.setContentHuggingPriority(.required, for: .vertical)
    field.setContentCompressionResistancePriority(.required, for: .vertical)
    return field
}

/// Pins a wrapping label to the top of `host` so every cell stays top-aligned
/// while the row grows to fit its tallest cell. The bottom inset is high (not
/// required) so it yields when the cell is stretched to the shared row height.
@MainActor
private func pinTopAligned(_ label: NSTextField, in host: NSView, leading: CGFloat, trailing: CGFloat) {
    // Bottom is required-minus-one so the natural fitting height includes the
    // bottom inset, but yields (keeping the label top-aligned) when the row is
    // stretched to the height of a taller sibling cell.
    let bottom = label.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -SubtitleTableMetrics.rowVerticalInset)
    bottom.priority = NSLayoutConstraint.Priority(999)
    NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: leading),
        label.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -trailing),
        label.topAnchor.constraint(equalTo: host.topAnchor, constant: SubtitleTableMetrics.rowVerticalInset),
        bottom,
    ])
}

// MARK: - Cell views

final class IndexCellView: NSView {
    private let label = makeWrappingLabel(secondary: true)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.maximumNumberOfLines = 1
        addSubview(label)
        pinTopAligned(label, in: self, leading: SubtitleTableMetrics.cellLeading, trailing: 4)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(number: Int) {
        label.stringValue = "\(number)"
    }
}

final class NameCellView: NSView {
    private let label = makeWrappingLabel(secondary: false)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(label)
        pinTopAligned(label, in: self, leading: SubtitleTableMetrics.cellLeading, trailing: SubtitleTableMetrics.trailingInset)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String) {
        label.stringValue = text
    }

    override func layout() {
        super.layout()
        label.preferredMaxLayoutWidth = label.bounds.width
    }
}

final class CuesCellView: NSView {
    private let label = makeWrappingLabel(secondary: false)
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

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String, onPlay: @escaping () -> Void) {
        label.stringValue = text
        self.onPlay = onPlay
    }

    override func layout() {
        super.layout()
        label.preferredMaxLayoutWidth = label.bounds.width
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

// MARK: - Row view (hover + subtle select-all highlight)

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
        if isHovered && !isSelected {
            NSColor.secondaryLabelColor.withAlphaComponent(0.06).setFill()
            bounds.fill()
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.16).setFill()
        bounds.fill()
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
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let M = SubtitleTableMetrics.self
        let idx = Self.makeHeaderLabel("#")
        let name = Self.makeHeaderLabel("Name")
        let cues = Self.makeHeaderLabel("Cues")
        [idx, name, cues].forEach { addSubview($0) }
        NSLayoutConstraint.activate([
            idx.leadingAnchor.constraint(equalTo: leadingAnchor, constant: M.cellLeading),
            idx.centerYAnchor.constraint(equalTo: centerYAnchor),
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: M.indexColumnWidth + M.cellLeading),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            cues.leadingAnchor.constraint(equalTo: leadingAnchor, constant: M.indexColumnWidth + M.nameColumnWidth + M.cellLeading),
            cues.centerYAnchor.constraint(equalTo: centerYAnchor),
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
        field.font = .systemFont(ofSize: SubtitleTableMetrics.headerFontSize, weight: .semibold)
        field.textColor = .secondaryLabelColor
        field.isSelectable = true
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

// MARK: - Table view (cmd+A / cmd+C scoped to the table)

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
            selectAll(nil)
            return true
        case "c":
            if !selectedRowIndexes.isEmpty {
                tableCoordinator?.copySelectedRowsText()
                return true
            }
            return super.performKeyEquivalent(with: event)
        default:
            return super.performKeyEquivalent(with: event)
        }
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

    private static let indexColumnID = NSUserInterfaceItemIdentifier("SubtitleTable.index")
    private static let nameColumnID = NSUserInterfaceItemIdentifier("SubtitleTable.name")
    private static let cuesColumnID = NSUserInterfaceItemIdentifier("SubtitleTable.cues")

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
        table.usesAutomaticRowHeights = true
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.allowsColumnReordering = false
        table.allowsColumnResizing = false
        table.allowsColumnSelection = false
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.gridStyleMask = [.solidHorizontalGridLineMask]
        table.gridColor = .separatorColor
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular

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

        private static let indexCellID = NSUserInterfaceItemIdentifier("SubtitleTable.indexCell")
        private static let nameCellID = NSUserInterfaceItemIdentifier("SubtitleTable.nameCell")
        private static let cuesCellID = NSUserInterfaceItemIdentifier("SubtitleTable.cuesCell")
        private static let rowViewID = NSUserInterfaceItemIdentifier("SubtitleTable.rowView")

        init(rows: [SubtitleTableRow], onPlay: @escaping (SubtitleTableRow) -> Void) {
            self.rows = rows
            self.onPlay = onPlay
        }

        func update(rows: [SubtitleTableRow], onPlay: @escaping (SubtitleTableRow) -> Void) {
            self.onPlay = onPlay
            guard rows != self.rows else { return }
            self.rows = rows
            tableView?.reloadData()
        }

        func copySelectedRowsText() {
            guard let tableView else { return }
            let indexes = tableView.selectedRowIndexes
            guard !indexes.isEmpty else { return }
            let text = indexes.map { index -> String in
                let row = rows[index]
                let cuesOneLine = row.cues.replacingOccurrences(of: "\n", with: " ")
                return "\(row.name)\t\(cuesOneLine)"
            }.joined(separator: "\n")

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
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
                return cell

            case SubtitleTableView.nameColumnID:
                let cell = (tableView.makeView(withIdentifier: Self.nameCellID, owner: nil) as? NameCellView) ?? {
                    let view = NameCellView()
                    view.identifier = Self.nameCellID
                    return view
                }()
                cell.configure(text: model.name)
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
                return cell

            default:
                return nil
            }
        }
    }
}
