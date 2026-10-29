import AppKit
import CueSeekerCore
import SwiftUI

struct SubtitleTableView: NSViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isWorkbenchPageCovered) var isWorkbenchPageCovered
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var interfaceLayerContext
    @Environment(\.subtitleTableExternalTextSelectionSession) private var externalTextSelectionSession
    var tableName: String
    var probeSurface: SubtitleTableProbeSurface = .search
    var probeScope: String?
    var rowCount: Int
    var rowProvider: (Int) -> SubtitleTableRow?
    var rowsVersion: Int
    var rowsUpdate: TableSandboxRowsUpdate
    var dateAddedHeader = L("table.column.date_added")
    var displayTitleHeader = L("table.column.name")
    var timeHeader = L("table.column.time_range")
    var cuesHeader = L("table.column.cues")
    var languageHeader = L("table.column.language")
    var columnOrder: [String] = []
    var showsDateAddedColumn = false
    var showsDisplayTitleColumn = true
    var showsTimeColumn = false
    var showsLanguageColumn = false
    var showsCueGroup = false
    var scrollResetToken = 0
    var scrollTargetRow: Int?
    var onVisibleRowsChange: (Range<Int>) -> Void = { _ in }
    var isSelectionMode = false
    var isRowSelected: (Int) -> Bool = { _ in false }
    var selectionHeaderState: WorkbenchCheckboxState = .unchecked
    var onToggleRowSelection: (Int) -> Void = { _ in }
    var onShiftRowSelection: (Int) -> Void = { _ in }
    var onToggleAllSelection: () -> Void = {}
    /// The Selection Action Overlay's probe, so the pointer stops changing the
    /// table's Hover once it moves onto the Overlay.
    var selectionOverlayAnchor: MenuAnchorHandle?
    var allResultsTextCopyRowCount: Int?
    var loadRowsForTextCopy: SubtitleTableTextCopyRowLoader?
    var onPlay: (SubtitleTableRow) -> Void
    var onOpenSubtitleFile: (String) -> Void = { path in
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
    var rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search
    var rowActionDestinations: [SubtitleTableRowActionDestination] = []
    var onSaveExcerpt: (SubtitleTableRow, Int64) -> Void = { _, _ in }
    var onMoveExcerpt: (SubtitleTableRow, Int64) -> Void = { _, _ in }
    var onDuplicateExcerpt: (SubtitleTableRow, Int64) -> Void = { _, _ in }
    var onCreateExcerptList: (SubtitleTableRow, SubtitleTableRowAction) -> Void
        = { _, _ in }
    var onRemoveExcerpt: (SubtitleTableRow) -> Void = { _ in }
    var isCueInLibrary: ((Int64) -> Bool)? = nil
    var onToast: ((ToastRequest) -> Void)? = nil
    var showsHeader: Bool = true
    var pageChrome: SubtitleTablePageChrome?
    @Environment(\.workbenchPageScrollbar) private var pageScrollbar

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            tableName: tableName,
            probeSurface: probeSurface,
            probeScope: probeScope,
            rowCount: rowCount,
            rowProvider: rowProvider,
            rowsVersion: rowsVersion,
            dateAddedHeader: dateAddedHeader,
            displayTitleHeader: displayTitleHeader,
            timeHeader: timeHeader,
            cuesHeader: cuesHeader,
            languageHeader: languageHeader,
            columnOrder: columnOrder,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn,
            showsCueGroup: showsCueGroup,
            scrollResetToken: scrollResetToken,
            scrollTargetRow: scrollTargetRow,
            onVisibleRowsChange: onVisibleRowsChange,
            isSelectionMode: isSelectionMode,
            isRowSelected: isRowSelected,
            selectionHeaderState: selectionHeaderState,
            onToggleRowSelection: onToggleRowSelection,
            onShiftRowSelection: onShiftRowSelection,
            onToggleAllSelection: onToggleAllSelection,
            selectionOverlayAnchor: selectionOverlayAnchor,
            allResultsTextCopyRowCount: allResultsTextCopyRowCount,
            loadRowsForTextCopy: loadRowsForTextCopy,
            onPlay: onPlay,
            onOpenSubtitleFile: onOpenSubtitleFile,
            rowActionMenuStyle: rowActionMenuStyle,
            rowActionDestinations: rowActionDestinations,
            onSaveExcerpt: onSaveExcerpt,
            onMoveExcerpt: onMoveExcerpt,
            onDuplicateExcerpt: onDuplicateExcerpt,
            onCreateExcerptList: onCreateExcerptList,
            onRemoveExcerpt: onRemoveExcerpt,
            isCueInLibrary: isCueInLibrary,
            onToast: onToast
        )
        coordinator.showsHeader = showsHeader
        return coordinator
    }

    func makeNSView(context: Context) -> SubtitleTableContainerView {
        UIInvalidationProbe.count(
            probeSurface.counterName("native_make"),
            scope: probeScope,
            details: "table=\(tableName)"
        )
        context.coordinator.isEnabled = isEnabled
        context.coordinator.isCoveredByHigherLayer = isWorkbenchPageCovered
        context.coordinator.interfaceLayers = interfaceLayers
        context.coordinator.interfaceLayerContext = interfaceLayerContext
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

        let pageChromeViewport: SubtitleTablePageChromeViewportView?
        if pageChrome != nil {
            let viewport = SubtitleTablePageChromeViewportView()
            viewport.translatesAutoresizingMaskIntoConstraints = false
            viewport.scrollView = scrollView
            pageChromeViewport = viewport
        } else {
            pageChromeViewport = nil
        }

        let outlineOverlay = SubtitleTableOutlineOverlayView()
        outlineOverlay.translatesAutoresizingMaskIntoConstraints = false
        outlineOverlay.coordinator = context.coordinator

        context.coordinator.attach(
            container: container,
            headerView: header,
            scrollView: scrollView,
            pageScrollbar: pageScrollbar,
            documentView: documentView,
            pageChromeViewport: pageChromeViewport,
            outlineOverlay: outlineOverlay
        )
        context.coordinator.bindExternalTextSelectionSession(externalTextSelectionSession)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollContentDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        container.addSubview(scrollView)
        if let pageChromeViewport {
            container.addSubview(pageChromeViewport)
            pageChromeViewport.addSubview(header)
        } else {
            container.addSubview(header)
        }
        container.addSubview(outlineOverlay)

        let headerHeightConstraint = header.heightAnchor.constraint(equalToConstant: context.coordinator.currentHeaderHeight)
        context.coordinator.headerHeightConstraint = headerHeightConstraint

        header.isHidden = !context.coordinator.showsHeader

        NSLayoutConstraint.activate([
            outlineOverlay.topAnchor.constraint(equalTo: container.topAnchor),
            outlineOverlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            outlineOverlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            outlineOverlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        if let pageChrome, let pageChromeViewport {
            header.translatesAutoresizingMaskIntoConstraints = true
            NSLayoutConstraint.activate([
                pageChromeViewport.topAnchor.constraint(equalTo: container.topAnchor),
                pageChromeViewport.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                pageChromeViewport.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                pageChromeViewport.bottomAnchor.constraint(equalTo: container.bottomAnchor),

                scrollView.topAnchor.constraint(equalTo: container.topAnchor),
                scrollView.leadingAnchor.constraint(
                    equalTo: container.leadingAnchor,
                    constant: pageChrome.leadingInset
                ),
                scrollView.trailingAnchor.constraint(
                    equalTo: container.trailingAnchor,
                    constant: -pageChrome.trailingInset
                ),
                scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: container.topAnchor),
                header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                headerHeightConstraint,

                scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
                scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        context.coordinator.resizeDocument()
        if pageChrome != nil {
            context.coordinator.scrollToTop()
        }
        context.coordinator.refreshPageScrollPresentation()
        context.coordinator.notifyVisibleRowsChanged()
        return container
    }

    func updateNSView(_ nsView: SubtitleTableContainerView, context: Context) {
        UIInvalidationProbe.count(
            probeSurface.counterName("native_update"),
            scope: probeScope,
            details: "table=\(tableName)"
        )
        context.coordinator.bindPageScrollbar(pageScrollbar)
        context.coordinator.showsHeader = showsHeader
        context.coordinator.isEnabled = isEnabled
        context.coordinator.isCoveredByHigherLayer = isWorkbenchPageCovered
        context.coordinator.interfaceLayers = interfaceLayers
        context.coordinator.interfaceLayerContext = interfaceLayerContext
        context.coordinator.updatePageChrome(pageChrome)
        context.coordinator.bindExternalTextSelectionSession(externalTextSelectionSession)
        context.coordinator.update(
            tableName: tableName,
            probeSurface: probeSurface,
            probeScope: probeScope,
            rowCount: rowCount,
            rowProvider: rowProvider,
            rowsVersion: rowsVersion,
            rowsUpdate: rowsUpdate,
            dateAddedHeader: dateAddedHeader,
            displayTitleHeader: displayTitleHeader,
            timeHeader: timeHeader,
            cuesHeader: cuesHeader,
            languageHeader: languageHeader,
            columnOrder: columnOrder,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn,
            showsCueGroup: showsCueGroup,
            scrollResetToken: scrollResetToken,
            scrollTargetRow: scrollTargetRow,
            onVisibleRowsChange: onVisibleRowsChange,
            isSelectionMode: isSelectionMode,
            isRowSelected: isRowSelected,
            selectionHeaderState: selectionHeaderState,
            onToggleRowSelection: onToggleRowSelection,
            onShiftRowSelection: onShiftRowSelection,
            onToggleAllSelection: onToggleAllSelection,
            selectionOverlayAnchor: selectionOverlayAnchor,
            allResultsTextCopyRowCount: allResultsTextCopyRowCount,
            loadRowsForTextCopy: loadRowsForTextCopy,
            onPlay: onPlay,
            onOpenSubtitleFile: onOpenSubtitleFile,
            rowActionMenuStyle: rowActionMenuStyle,
            rowActionDestinations: rowActionDestinations,
            onSaveExcerpt: onSaveExcerpt,
            onMoveExcerpt: onMoveExcerpt,
            onDuplicateExcerpt: onDuplicateExcerpt,
            onCreateExcerptList: onCreateExcerptList,
            onRemoveExcerpt: onRemoveExcerpt,
            isCueInLibrary: isCueInLibrary,
            onToast: onToast
        )
    }

    static func dismantleNSView(
        _ nsView: SubtitleTableContainerView,
        coordinator: Coordinator
    ) {
        coordinator.unbindExternalTextSelectionSession()
        coordinator.bindPageScrollbar(nil)
        coordinator.cancelPendingTextInteraction()
        coordinator.hideCueStateTip()
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, SubtitleTableExternalTextSelectionTarget {
        var tableName: String
        var probeSurface: SubtitleTableProbeSurface
        var probeScope: String?
        var rowCount: Int
        var rowProvider: (Int) -> SubtitleTableRow?
        var rowsVersion: Int
        var dateAddedHeader: String
        var displayTitleHeader: String
        var timeHeader: String
        var cuesHeader: String
        var languageHeader: String
        var columnOrder: [String]
        var showsDateAddedColumn: Bool
        var showsDisplayTitleColumn: Bool
        var showsTimeColumn: Bool
        var showsLanguageColumn: Bool
        var showsCueGroup: Bool
        var scrollResetToken: Int
        var scrollTargetRow: Int?
        var onVisibleRowsChange: (Range<Int>) -> Void
        var isSelectionMode: Bool
        var isRowSelected: (Int) -> Bool
        var selectionHeaderState: WorkbenchCheckboxState
        var onToggleRowSelection: (Int) -> Void
        var onShiftRowSelection: (Int) -> Void
        var onToggleAllSelection: () -> Void
        var selectionOverlayAnchor: MenuAnchorHandle?
        var allResultsTextCopyRowCount: Int
        var loadRowsForTextCopy: SubtitleTableTextCopyRowLoader?
        var onPlay: (SubtitleTableRow) -> Void
        var onOpenSubtitleFile: (String) -> Void
        var rowActionMenuStyle: SubtitleTableRowActionMenuStyle
        var rowActionDestinations: [SubtitleTableRowActionDestination]
        var onSaveExcerpt: (SubtitleTableRow, Int64) -> Void
        var onMoveExcerpt: (SubtitleTableRow, Int64) -> Void
        var onDuplicateExcerpt: (SubtitleTableRow, Int64) -> Void
        var onCreateExcerptList:
            (SubtitleTableRow, SubtitleTableRowAction) -> Void
        var onRemoveExcerpt: (SubtitleTableRow) -> Void
        var isCueInLibrary: ((Int64) -> Bool)?
        var onToast: ((ToastRequest) -> Void)?

        var isEnabled: Bool = true {
            didSet {
                guard oldValue != isEnabled else { return }
                if !isEnabled {
                    clearFocusedCheckbox()
                    cancelPendingTextInteraction()
                    updateHoveredColumnID(nil)
                    updateHoveredCueTextRow(nil)
                    updateHoveredCueStateRow(nil)
                }
                headerView?.refreshHeaderHosts()
            }
        }

        var showsHeader: Bool = true {
            didSet {
                guard oldValue != showsHeader else { return }
                headerView?.isHidden = !showsHeader
                headerHeightConstraint?.constant = currentHeaderHeight
                container?.layoutSubtreeIfNeeded()
                outlineOverlayView?.needsDisplay = true
                if pageChrome != nil {
                    refreshPageScrollPresentation()
                }
            }
        }

        var headerHeightConstraint: NSLayoutConstraint?

        var currentHeaderHeight: CGFloat {
            guard showsHeader else { return 0 }
            return WorkbenchControlMetrics.redesignTableHeaderHeight
        }

        var currentRowHeight: CGFloat {
            SubtitleTableCueGeometry.minimumRowHeight
        }

        weak var container: SubtitleTableContainerView?
        weak var headerView: SubtitleVirtualTableHeaderView?
        weak var scrollView: NSScrollView?
        var pageScrollbar: WorkbenchPageScrollbar?
        weak var documentView: SubtitleVirtualTableDocumentView?
        weak var pageChromeViewport: SubtitleTablePageChromeViewportView?
        weak var outlineOverlayView: SubtitleTableOutlineOverlayView?
        var pageChrome: SubtitleTablePageChrome?
        var scrollablePageChromeHost: SubtitleTablePageChromeHostingView?
        var pinnedPageChromeHost: SubtitleTablePageChromeHostingView?
        var isMenuOpen = false
        var menuHost: MenuHostingView?
        var submenuHost: MenuHostingView?
        var menuClipView: SubtitleTableMenuClipView?
        var activeMenuAnchor: ActiveMenuAnchor?
        /// Where the menu sits relative to its anchor, fixed when it opened.
        var menuPlacementOffset: CGSize?
        var activeRowMenuRow: Int?
        var activeRowMenuColumnID: String?
        var activeRowMenuTarget: SubtitleTableRow?
        var rowActionSubmenuState: MenuSubmenuState<SubtitleTableRowAction>?
        let rowActionHighlight = MenuHighlightModel()
        let rowActionDestinationHighlight = MenuHighlightModel()
        var pendingMenuReposition = false
        nonisolated(unsafe) var keyboardFocusEventMonitor: Any?
        nonisolated(unsafe) var textCopyTask: Task<Void, Never>?
        nonisolated(unsafe) var textDragAutoScrollTimer: Timer?
        weak var externalTextSelectionSession: SubtitleTableExternalTextSelectionSession?

        enum ActiveMenuAnchor {
            /// A right-click anchor is kept in document coordinates, so the
            /// menu travels with the content the pointer landed on.
            case row(row: Int, columnID: String, anchorFrame: CGRect, clickPointInDocument: CGPoint?)
            case rowActionButton(row: Int, fallbackFrame: CGRect)
        }

        struct DynamicScrollAnchor {
            let primaryCueIdentity: SubtitleTablePrimaryCueIdentity
            let row: Int
            let primaryFirstLineScreenY: CGFloat
        }

        /// The registry the open row menu is reported to. nil in hierarchies
        /// outside the main window.
        var interfaceLayers: InterfaceLayerRegistry?
        var menuGateSession: MenuGate.Session?
        var isCoveredByHigherLayer = false {
            didSet {
                guard isCoveredByHigherLayer != oldValue else { return }
                if isCoveredByHigherLayer {
                    // A surface above the table takes its input and leaves its
                    // picture alone: the highlight stays where it was and an
                    // open menu stays open. Only work already in flight stops.
                    cancelPendingTextInteraction()
                    hideCueStateTip()
                } else {
                    reevaluateHoverFromCurrentPointer()
                }
                headerView?.refreshHeaderHosts()
            }
        }

        /// The layer context read where the table sits. It carries the
        /// registry's freeze answer into this AppKit surface — a menu open on
        /// the table's layer, wherever it hangs, freezes the table exactly
        /// like the table's own row menu does — and it is re-injected into
        /// every view the table hosts, whose own hover gates would otherwise
        /// read a default context that is never frozen.
        var interfaceLayerContext = InterfaceLayerContext() {
            didSet {
                guard interfaceLayerContext.layer != oldValue.layer
                    || interfaceLayerContext.isCovered != oldValue.isCovered
                    || interfaceLayerContext.isFrozen != oldValue.isFrozen
                else {
                    return
                }
                updatePageChromeHosts()
                guard interfaceLayerContext.isFrozen != oldValue.isFrozen
                else {
                    return
                }
                if interfaceLayerContext.isFrozen {
                    cancelPendingTextInteraction()
                    hideCueStateTip()
                } else {
                    reevaluateHoverFromCurrentPointer()
                }
                headerView?.refreshHeaderHosts()
            }
        }

        let textLayout = SubtitleTextLayout()
        let cueTextMeasurer = SubtitleTableCueTextMeasurer()
        var textSelection = SubtitleTableTextSelectionState()
        var rowMeasurementCache = SubtitleTableRowHeightCache()
        var rowHeightCache = SubtitleVirtualRowHeightCache()
        var lastRowMeasurementLayoutKey: SubtitleTableRowMeasurementLayoutKey?
        var isApplyingDynamicReflow = false
        var isResizingDocument = false
        var measurementComputeCount = 0
        var drawnRowCount = 0
        var textSelectionInvalidationCount = 0
        var hoveredRow: Int?
        var hoveredColumnID: String?
        var hoveredCueTextRow: Int?
        var hoveredCueStateRow: Int?
        var hoveredRowActionRow: Int?
        var pressedRowActionRow: Int?
        var focusedCheckboxRow: Int?
        var cueStateTooltipTargetID = UUID()
        var lastNotifiedVisibleRows: Range<Int>?
        var lastHeaderHorizontalOffset: CGFloat?
        var isScrollbarDragging = false

        #if DEBUG
        var didInvalidateForSystemColorsChangeForTesting = false
        #endif

        enum PendingDirectTextAction {
            case none
            case play(row: Int)
        }

        enum PendingRowSelectionTarget {
            case rowCheckbox(row: Int)
            case rowActionButton(row: Int)
            case selectionModeRow(row: Int, isShiftPressed: Bool)
        }

        struct PendingTextInteraction {
            let startPoint: CGPoint
            let anchor: SubtitleTableTextPosition?
            let directAction: PendingDirectTextAction
            var didDrag = false
            var selectionHasBegun = false
            var latestWindowPoint: CGPoint
        }

        var pendingTextInteraction: PendingTextInteraction?
        var pendingRowSelectionTarget: PendingRowSelectionTarget?
        static let textDragThreshold: CGFloat = 3

        enum TextSelectionRowProjection: Equatable {
            case none
            case full
            case bounded(SubtitleTableTextPosition, SubtitleTableTextPosition)
            case from(SubtitleTableTextPosition)
            case through(SubtitleTableTextPosition)
        }

        struct HeaderTextFragmentLayout {
            let columnID: String
            let columnIndex: Int
            let cellRect: CGRect
            let fragment: SubtitleTableTextFragmentLayout
        }

        init(
            tableName: String,
            probeSurface: SubtitleTableProbeSurface = .search,
            probeScope: String? = nil,
            rowCount: Int,
            rowProvider: @escaping (Int) -> SubtitleTableRow?,
            rowsVersion: Int,
            dateAddedHeader: String = L("table.column.date_added"),
            displayTitleHeader: String = L("table.column.name"),
            timeHeader: String = L("table.column.time_range"),
            cuesHeader: String = L("table.column.cues"),
            languageHeader: String = L("table.column.language"),
            columnOrder: [String] = [],
            showsDateAddedColumn: Bool = false,
            showsDisplayTitleColumn: Bool = true,
            showsTimeColumn: Bool = false,
            showsLanguageColumn: Bool = false,
            showsCueGroup: Bool = false,
            scrollResetToken: Int = 0,
            scrollTargetRow: Int? = nil,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            isSelectionMode: Bool = false,
            isRowSelected: @escaping (Int) -> Bool = { _ in false },
            selectionHeaderState: WorkbenchCheckboxState = .unchecked,
            onToggleRowSelection: @escaping (Int) -> Void = { _ in },
            onShiftRowSelection: @escaping (Int) -> Void = { _ in },
            onToggleAllSelection: @escaping () -> Void = {},
            selectionOverlayAnchor: MenuAnchorHandle? = nil,
            allResultsTextCopyRowCount: Int? = nil,
            loadRowsForTextCopy: SubtitleTableTextCopyRowLoader? = nil,
            onPlay: @escaping (SubtitleTableRow) -> Void,
            onOpenSubtitleFile: @escaping (String) -> Void = { path in
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            },
            rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search,
            rowActionDestinations: [SubtitleTableRowActionDestination] = [],
            onSaveExcerpt: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onMoveExcerpt: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onDuplicateExcerpt: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onCreateExcerptList: @escaping (
                SubtitleTableRow, SubtitleTableRowAction
            ) -> Void = { _, _ in },
            onRemoveExcerpt: @escaping (SubtitleTableRow) -> Void = { _ in },
            isCueInLibrary: ((Int64) -> Bool)? = nil,
            onToast: ((ToastRequest) -> Void)? = nil
        ) {
            self.tableName = tableName
            self.probeSurface = probeSurface
            self.probeScope = probeScope
            self.rowCount = max(0, rowCount)
            self.rowProvider = rowProvider
            self.rowsVersion = rowsVersion
            self.dateAddedHeader = dateAddedHeader
            self.displayTitleHeader = displayTitleHeader
            self.timeHeader = timeHeader
            self.cuesHeader = cuesHeader
            self.languageHeader = languageHeader
            self.columnOrder = columnOrder
            self.showsDateAddedColumn = showsDateAddedColumn
            self.showsDisplayTitleColumn = showsDisplayTitleColumn
            self.showsTimeColumn = showsTimeColumn
            self.showsLanguageColumn = showsLanguageColumn
            self.showsCueGroup = showsCueGroup
            self.scrollResetToken = scrollResetToken
            self.scrollTargetRow = scrollTargetRow
            self.onVisibleRowsChange = onVisibleRowsChange
            self.isSelectionMode = isSelectionMode
            self.isRowSelected = isRowSelected
            self.selectionHeaderState = selectionHeaderState
            self.onToggleRowSelection = onToggleRowSelection
            self.onShiftRowSelection = onShiftRowSelection
            self.onToggleAllSelection = onToggleAllSelection
            self.selectionOverlayAnchor = selectionOverlayAnchor
            self.allResultsTextCopyRowCount = max(0, allResultsTextCopyRowCount ?? rowCount)
            self.loadRowsForTextCopy = loadRowsForTextCopy
            self.onPlay = onPlay
            self.onOpenSubtitleFile = onOpenSubtitleFile
            self.rowActionMenuStyle = rowActionMenuStyle
            self.rowActionDestinations = rowActionDestinations
            self.onSaveExcerpt = onSaveExcerpt
            self.onMoveExcerpt = onMoveExcerpt
            self.onDuplicateExcerpt = onDuplicateExcerpt
            self.onCreateExcerptList = onCreateExcerptList
            self.onRemoveExcerpt = onRemoveExcerpt
            self.isCueInLibrary = isCueInLibrary
            self.onToast = onToast
        }

        deinit {
            textCopyTask?.cancel()
            textDragAutoScrollTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
            if let monitor = keyboardFocusEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func attach(
            container: SubtitleTableContainerView,
            headerView: SubtitleVirtualTableHeaderView,
            scrollView: NSScrollView,
            pageScrollbar: WorkbenchPageScrollbar?,
            documentView: SubtitleVirtualTableDocumentView,
            pageChromeViewport: SubtitleTablePageChromeViewportView? = nil,
            outlineOverlay: SubtitleTableOutlineOverlayView? = nil
        ) {
            self.container = container
            self.headerView = headerView
            self.scrollView = scrollView
            self.documentView = documentView
            self.pageChromeViewport = pageChromeViewport
            self.outlineOverlayView = outlineOverlay
            outlineOverlay?.coordinator = self
            headerView.coordinator = self
            headerView.isHidden = !showsHeader
            headerView.refreshHeaderHosts()
            headerView.needsDisplay = true
            documentView.coordinator = self
            documentView.needsDisplay = true
            bindPageScrollbar(pageScrollbar)
            configureScrollbars()
            updatePageChromeHosts()

            container.onLayout = { [weak self] in
                self?.resizeDocument()
                self?.layoutPageChrome()
                self?.outlineOverlayView?.needsDisplay = true
                self?.repositionOpenMenu()
            }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appLeftMouseDown),
                name: .cueSeekerLeftMouseDown,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appClearTextSelection),
                name: .cueSeekerClearTextSelection,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(systemColorsDidChange),
                name: NSColor.systemColorsDidChangeNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: NSApplication.didBecomeActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidResignActive),
                name: NSApplication.didResignActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey),
                name: NSWindow.didBecomeKeyNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey),
                name: NSWindow.didResignKeyNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollDebounceDidSettle),
                name: .cueSeekerScrollDebounceSettled,
                object: nil
            )
            installKeyboardFocusEventMonitor()
        }

        func bindExternalTextSelectionSession(
            _ session: SubtitleTableExternalTextSelectionSession?
        ) {
            guard externalTextSelectionSession !== session else { return }
            externalTextSelectionSession?.unbind(self)
            externalTextSelectionSession = session
            session?.bind(self)
        }

        func unbindExternalTextSelectionSession() {
            externalTextSelectionSession?.unbind(self)
            externalTextSelectionSession = nil
        }

        func updatePageChrome(_ pageChrome: SubtitleTablePageChrome?) {
            let geometryChanged = scrollableHeaderHeight(for: self.pageChrome)
                != scrollableHeaderHeight(for: pageChrome)
                || self.pageChrome?.pinnedHeaderHeight
                    != pageChrome?.pinnedHeaderHeight
                || self.pageChrome?.bottomInset != pageChrome?.bottomInset
            let previousPinnedHeaderHeight = self.pageChrome?.pinnedHeaderHeight
            self.pageChrome = pageChrome
            updatePageChromeHosts()
            if geometryChanged {
                resizeDocument()
                if let previousPinnedHeaderHeight,
                   let nextPinnedHeaderHeight = pageChrome?.pinnedHeaderHeight,
                   let scrollView {
                    let offset = scrollView.contentView.bounds.minY
                    let pinThreshold = scrollableHeaderHeight(for: pageChrome) ?? 0
                    if offset >= pinThreshold {
                        let delta = nextPinnedHeaderHeight - previousPinnedHeaderHeight
                        let maximumY = max(
                            0,
                            (documentView?.bounds.height ?? 0)
                                - scrollView.contentView.bounds.height
                        )
                        var origin = scrollView.contentView.bounds.origin
                        origin.y = min(max(0, origin.y + delta), maximumY)
                        scrollView.contentView.scroll(to: origin)
                        scrollView.reflectScrolledClipView(scrollView.contentView)
                    }
                }
            }
            layoutPageChrome()
        }

        /// Content width the page chrome is laid out in, after its own insets.
        func pageChromeContentWidth(
            for pageChrome: SubtitleTablePageChrome
        ) -> CGFloat {
            max(
                0,
                (container?.bounds.width ?? 0)
                    - max(0, pageChrome.leadingInset)
                    - max(0, pageChrome.trailingInset)
            )
        }

        func scrollableHeaderHeight(
            for pageChrome: SubtitleTablePageChrome?
        ) -> CGFloat? {
            guard let pageChrome else { return nil }
            return pageChrome.scrollableHeaderHeight(
                pageChromeContentWidth(for: pageChrome)
            )
        }

        var pageScrollGeometry: SubtitleTablePageScrollGeometry? {
            guard let pageChrome else { return nil }
            return SubtitleTablePageScrollGeometry(
                scrollableHeaderHeight: pageChrome.scrollableHeaderHeight(
                    pageChromeContentWidth(for: pageChrome)
                ),
                pinnedHeaderHeight: pageChrome.pinnedHeaderHeight,
                tableHeaderHeight: currentHeaderHeight,
                bottomInset: pageChrome.bottomInset
            )
        }

        var rowsOriginY: CGFloat {
            pageScrollGeometry?.rowsOriginY ?? 0
        }

        func updatePageChromeHosts() {
            guard let pageChrome,
                  let pageChromeViewport,
                  let scrollView
            else {
                scrollablePageChromeHost?.removeFromSuperview()
                pinnedPageChromeHost?.removeFromSuperview()
                scrollablePageChromeHost = nil
                pinnedPageChromeHost = nil
                return
            }

            let scrollableRootView = InterfaceLayerHosting.bridgedRootView(
                pageChrome.scrollableHeader,
                layers: interfaceLayers,
                context: interfaceLayerContext
            )
            if let scrollablePageChromeHost {
                scrollablePageChromeHost.coordinator = self
                scrollablePageChromeHost.rootView = scrollableRootView
            } else {
                let host = SubtitleTablePageChromeHostingView(
                    rootView: scrollableRootView
                )
                host.coordinator = self
                host.scrollView = scrollView
                pageChromeViewport.addSubview(host)
                scrollablePageChromeHost = host
            }

            let pinnedRootView = InterfaceLayerHosting.bridgedRootView(
                pageChrome.pinnedHeader,
                layers: interfaceLayers,
                context: interfaceLayerContext
            )
            if let pinnedPageChromeHost {
                pinnedPageChromeHost.coordinator = self
                pinnedPageChromeHost.rootView = pinnedRootView
            } else {
                let host = SubtitleTablePageChromeHostingView(
                    rootView: pinnedRootView
                )
                host.coordinator = self
                host.scrollView = scrollView
                pageChromeViewport.addSubview(host)
                pinnedPageChromeHost = host
            }

            if let headerView {
                pageChromeViewport.addSubview(headerView)
            }
            if let pinnedPageChromeHost, let scrollablePageChromeHost {
                pageChromeViewport.addSubview(
                    pinnedPageChromeHost,
                    positioned: .above,
                    relativeTo: nil
                )
                pageChromeViewport.addSubview(
                    scrollablePageChromeHost,
                    positioned: .below,
                    relativeTo: pinnedPageChromeHost
                )
            }
        }

        func layoutPageChrome() {
            guard let pageChrome,
                  let geometry = pageScrollGeometry,
                  let container,
                  let scrollView,
                  let headerView,
                  let scrollablePageChromeHost,
                  let pinnedPageChromeHost
            else {
                return
            }

            let scrollOffset = scrollView.contentView.bounds.minY
            let inset = max(0, pageChrome.leadingInset)
            let contentWidth = max(
                0,
                container.bounds.width - inset - max(0, pageChrome.trailingInset)
            )
            scrollablePageChromeHost.frame = CGRect(
                x: inset,
                y: geometry.scrollableHeaderOriginY(scrollOffset: scrollOffset),
                width: contentWidth,
                height: geometry.scrollableHeaderHeight
            )
            let pinnedOriginY = geometry.pinnedHeaderOriginY(
                scrollOffset: scrollOffset
            )
            pinnedPageChromeHost.frame = CGRect(
                x: inset,
                y: pinnedOriginY,
                width: contentWidth,
                height: pageChrome.pinnedHeaderHeight
            )
            headerView.isHidden = !showsHeader
            headerView.frame = CGRect(
                x: inset,
                y: pinnedOriginY + pageChrome.pinnedHeaderHeight,
                width: contentWidth,
                height: currentHeaderHeight
            )
            outlineOverlayView?.needsDisplay = true
        }

        func refreshPageScrollPresentation() {
            layoutPageChrome()
            pageScrollbar?.metricsDidChange()
            invalidateVisibleDocument()
        }

        func update(
            tableName: String,
            probeSurface: SubtitleTableProbeSurface = .search,
            probeScope: String? = nil,
            rowCount: Int,
            rowProvider: @escaping (Int) -> SubtitleTableRow?,
            rowsVersion: Int,
            rowsUpdate: TableSandboxRowsUpdate,
            dateAddedHeader: String = L("table.column.date_added"),
            displayTitleHeader: String,
            timeHeader: String = L("table.column.time_range"),
            cuesHeader: String = L("table.column.cues"),
            languageHeader: String = L("table.column.language"),
            columnOrder: [String] = [],
            showsDateAddedColumn: Bool = false,
            showsDisplayTitleColumn: Bool = true,
            showsTimeColumn: Bool = false,
            showsLanguageColumn: Bool,
            showsCueGroup: Bool = false,
            scrollResetToken: Int,
            scrollTargetRow: Int? = nil,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            isSelectionMode: Bool = false,
            isRowSelected: @escaping (Int) -> Bool,
            selectionHeaderState: WorkbenchCheckboxState,
            onToggleRowSelection: @escaping (Int) -> Void,
            onShiftRowSelection: @escaping (Int) -> Void = { _ in },
            onToggleAllSelection: @escaping () -> Void,
            selectionOverlayAnchor: MenuAnchorHandle? = nil,
            allResultsTextCopyRowCount: Int? = nil,
            loadRowsForTextCopy: SubtitleTableTextCopyRowLoader? = nil,
            onPlay: @escaping (SubtitleTableRow) -> Void,
            onOpenSubtitleFile: @escaping (String) -> Void = { path in
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            },
            rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search,
            rowActionDestinations: [SubtitleTableRowActionDestination] = [],
            onSaveExcerpt: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onMoveExcerpt: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onDuplicateExcerpt: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onCreateExcerptList: @escaping (
                SubtitleTableRow, SubtitleTableRowAction
            ) -> Void = { _, _ in },
            onRemoveExcerpt: @escaping (SubtitleTableRow) -> Void = { _ in },
            isCueInLibrary: ((Int64) -> Bool)? = nil,
            onToast: ((ToastRequest) -> Void)? = nil
        ) {
            let tableChanged = tableName != self.tableName
            self.probeSurface = probeSurface
            self.probeScope = probeScope
            let nextRowCount = max(0, rowCount)
            let rowCountChanged = nextRowCount != self.rowCount
            let rowsVersionChanged = rowsVersion != self.rowsVersion
            let rowsChanged = rowCountChanged || rowsVersionChanged
            let effectiveRowsUpdate = rowsChanged ? rowsUpdate : .none
            let cuePresentationInputChanged = showsCueGroup != self.showsCueGroup ||
                columnOrder != self.columnOrder ||
                showsDateAddedColumn != self.showsDateAddedColumn ||
                showsDisplayTitleColumn != self.showsDisplayTitleColumn ||
                showsTimeColumn != self.showsTimeColumn ||
                showsLanguageColumn != self.showsLanguageColumn
            let heightAffectingCellsWillChange: Bool
            if case .cells(let cells) = effectiveRowsUpdate {
                let heightAffectingColumnIDs: Set<String> = [
                    "dateAdded", "display", "time", "cues", "language",
                ]
                heightAffectingCellsWillChange = cells.contains {
                    heightAffectingColumnIDs.contains($0.columnID)
                }
            } else {
                heightAffectingCellsWillChange = false
            }
            let preservesReloadAnchor = !tableChanged && effectiveRowsUpdate == .reload
            let presentationAnchor = (
                cuePresentationInputChanged || preservesReloadAnchor || heightAffectingCellsWillChange
            )
                ? captureDynamicScrollAnchor()
                : nil
            self.tableName = tableName
            self.rowProvider = rowProvider
            let dateAddedChanged = dateAddedHeader != self.dateAddedHeader
            self.dateAddedHeader = dateAddedHeader
            let displayTitleChanged = displayTitleHeader != self.displayTitleHeader
            self.displayTitleHeader = displayTitleHeader
            let timeChanged = timeHeader != self.timeHeader
            self.timeHeader = timeHeader
            let cuesHeaderChanged = cuesHeader != self.cuesHeader
            self.cuesHeader = cuesHeader
            let languageHeaderChanged = languageHeader != self.languageHeader
            self.languageHeader = languageHeader
            let columnOrderChanged = columnOrder != self.columnOrder
            self.columnOrder = columnOrder
            let dateAddedColumnChanged = showsDateAddedColumn != self.showsDateAddedColumn
            self.showsDateAddedColumn = showsDateAddedColumn
            let displayTitleColumnChanged = showsDisplayTitleColumn != self.showsDisplayTitleColumn
            self.showsDisplayTitleColumn = showsDisplayTitleColumn
            let timeColumnChanged = showsTimeColumn != self.showsTimeColumn
            self.showsTimeColumn = showsTimeColumn
            let languageColumnChanged = showsLanguageColumn != self.showsLanguageColumn
            self.showsLanguageColumn = showsLanguageColumn
            let showCueGroupChanged = showsCueGroup != self.showsCueGroup
            self.showsCueGroup = showsCueGroup
            let shouldResetScroll = scrollResetToken != self.scrollResetToken
            self.scrollResetToken = scrollResetToken
            self.scrollTargetRow = scrollTargetRow
            self.onVisibleRowsChange = onVisibleRowsChange
            let selectionModeChanged = isSelectionMode != self.isSelectionMode
            self.isSelectionMode = isSelectionMode
            self.isRowSelected = isRowSelected
            let selectionHeaderChanged = selectionHeaderState != self.selectionHeaderState
            self.selectionHeaderState = selectionHeaderState
            self.onToggleRowSelection = onToggleRowSelection
            self.onShiftRowSelection = onShiftRowSelection
            self.onToggleAllSelection = onToggleAllSelection
            self.selectionOverlayAnchor = selectionOverlayAnchor
            self.allResultsTextCopyRowCount = max(0, allResultsTextCopyRowCount ?? rowCount)
            self.loadRowsForTextCopy = loadRowsForTextCopy
            self.onPlay = onPlay
            self.onOpenSubtitleFile = onOpenSubtitleFile
            self.rowActionMenuStyle = rowActionMenuStyle
            self.rowActionDestinations = rowActionDestinations
            self.onSaveExcerpt = onSaveExcerpt
            self.onMoveExcerpt = onMoveExcerpt
            self.onDuplicateExcerpt = onDuplicateExcerpt
            self.onCreateExcerptList = onCreateExcerptList
            self.onRemoveExcerpt = onRemoveExcerpt
            self.isCueInLibrary = isCueInLibrary
            self.onToast = onToast

            self.rowCount = nextRowCount
            self.rowsVersion = rowsVersion
            if rowsChanged || shouldResetScroll {
                lastNotifiedVisibleRows = nil
            }
            if let focusedCheckboxRow, focusedCheckboxRow >= nextRowCount {
                updateFocusedCheckbox(nil)
            }

            let isAppendUpdate: Bool
            if case .append = effectiveRowsUpdate {
                isAppendUpdate = true
            } else {
                isAppendUpdate = false
            }
            let columnVisibilityChanged = dateAddedColumnChanged || displayTitleColumnChanged || timeColumnChanged || languageColumnChanged || columnOrderChanged
            let headerTitleChanged = dateAddedChanged || displayTitleChanged || timeChanged || cuesHeaderChanged || languageHeaderChanged
            let resetsMeasuredGeometry = tableChanged ||
                effectiveRowsUpdate == .reload ||
                (rowCountChanged && !isAppendUpdate) ||
                headerTitleChanged
            if resetsMeasuredGeometry || cuePresentationInputChanged {
                rowMeasurementCache.removeAll()
                rowHeightCache.removeAll()
            } else if case .cells(let cells) = effectiveRowsUpdate {
                let heightAffectingColumnIDs: Set<String> = [
                    "dateAdded", "display", "time", "cues", "language",
                ]
                for cell in cells where heightAffectingColumnIDs.contains(cell.columnID) {
                    rowMeasurementCache.remove(rowIndex: cell.row)
                    rowHeightCache.removeHeight(for: cell.row)
                }
            }
            rowHeightCache.configure(rowCount: nextRowCount, defaultHeight: currentRowHeight)

            let needsDocumentResize = tableChanged || rowsChanged || columnVisibilityChanged || headerTitleChanged
            let rowsUpdateInvalidatesTextSelection: Bool
            switch effectiveRowsUpdate {
            case .reload, .cells:
                rowsUpdateInvalidatesTextSelection = true
            case .none, .append:
                rowsUpdateInvalidatesTextSelection = false
            }
            if tableChanged || shouldResetScroll || rowsUpdateInvalidatesTextSelection || columnVisibilityChanged || headerTitleChanged || showCueGroupChanged || selectionModeChanged {
                clearTextSelection()
            }
            if selectionModeChanged {
                clearFocusedCheckbox()
                updateHoveredColumnID(nil)
                updateHoveredCueTextRow(nil)
                updateHoveredCueStateRow(nil)
                updateHoveredRowActionRow(nil)
                updatePressedRowActionRow(nil)
                if isMenuOpen {
                    dismissMenu()
                }
            }

            if needsDocumentResize {
                resizeDocument(preserving: presentationAnchor)
            }
            if showCueGroupChanged {
                UIInvalidationProbe.count(
                    probeSurface.counterName("show_cue_group_owner_update"),
                    scope: probeScope,
                    details: "table=\(tableName) enabled=\(showsCueGroup)"
                )
                reflowVisibleRows(anchor: presentationAnchor)
            }
            if rowsChanged || columnVisibilityChanged {
                if isMenuOpen {
                    repositionOpenMenu()
                }
            }
            if shouldResetScroll {
                if let scrollTargetRow {
                    scrollToRow(scrollTargetRow)
                } else {
                    scrollToTop()
                }
            } else if rowsChanged || columnVisibilityChanged {
                notifyVisibleRowsChanged(force: rowsChanged)
            }
            if showCueGroupChanged {
                invalidateVisibleDocument()
                if isMenuOpen {
                    dismissMenu()
                }
            }
            if tableChanged || rowsChanged || columnVisibilityChanged || headerTitleChanged || selectionHeaderChanged || selectionModeChanged {
                headerView?.refreshHeaderHosts()
            }
            if columnVisibilityChanged || headerTitleChanged || selectionHeaderChanged || selectionModeChanged {
                headerView?.needsDisplay = true
            }
            if columnVisibilityChanged || selectionModeChanged {
                invalidateVisibleDocument()
            }
            invalidateRows(for: effectiveRowsUpdate, rowsChanged: rowsChanged)
            if needsDocumentResize || columnVisibilityChanged || headerTitleChanged || shouldResetScroll || selectionModeChanged {
            }
        }

        func selectionHeaderStateForRendering() -> WorkbenchCheckboxState {
            selectionHeaderState
        }

        func isSelectionModeForRendering() -> Bool {
            isSelectionMode
        }

        func canToggleSelectionForRendering() -> Bool {
            guard isEnabled, rowCount > 0 else { return false }
            return (0..<rowCount).contains { rowProvider($0)?.cueState.isUnavailable != true }
        }

        func tableOutlineFrameInContainer() -> CGRect? {
            guard showsHeader,
                  rowCount > 0,
                  let container,
                  let headerView,
                  !headerView.isHidden,
                  let scrollView,
                  let documentView
            else {
                return nil
            }
            let headerFrame = container.convert(headerView.bounds, from: headerView)
            let scrollFrame = container.convert(scrollView.bounds, from: scrollView)
            let rowsBottomInDocument = rowsOriginY + rowHeightCache.totalHeight
            let rowsBottomInContainer = container.convert(
                CGPoint(x: 0, y: rowsBottomInDocument),
                from: documentView
            ).y
            let minY = headerFrame.minY
            let maxY = min(
                scrollFrame.maxY,
                max(headerFrame.maxY, rowsBottomInContainer)
            )
            guard maxY > minY, headerFrame.width > 0 else {
                return nil
            }
            let rawRect = CGRect(
                x: headerFrame.minX,
                y: minY,
                width: headerFrame.width,
                height: maxY - minY
            )
            let clipped = rawRect.intersection(container.bounds)
            return clipped.isNull || clipped.width <= 0 || clipped.height <= 0 ? nil : clipped
        }

        /// Whether a click anywhere on the header should select or clear every
        /// row. Same guards the row Checkboxes use.
        var acceptsSelectModeHeaderClick: Bool {
            isSelectionMode
                && canToggleSelectionForRendering()
                && !isMenuOpen
                && !isCoveredByHigherLayer
        }

        func bindPageScrollbar(_ pageScrollbar: WorkbenchPageScrollbar?) {
            guard self.pageScrollbar !== pageScrollbar else { return }
            if let scrollView {
                self.pageScrollbar?.detach(scrollView: scrollView)
            }
            self.pageScrollbar?.onDragStateChanged = nil
            self.pageScrollbar = pageScrollbar
            pageScrollbar?.onDragStateChanged = { [weak self] isDragging in
                self?.setScrollbarDragging(isDragging)
            }
            configureScrollbars()
        }

        func documentViewForKeyboardFocusBridge() -> NSView? {
            documentView
        }

        func configureScrollbars() {
            guard let scrollView else { return }
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            pageScrollbar?.attach(scrollView: scrollView)
        }

        func toggleAllRowSelection() {
            guard canToggleSelectionForRendering() else { return }
            onToggleAllSelection()
            headerView?.refreshHeaderHosts()
            invalidateVisibleDocument()
        }

        func cellFullText(row: Int, column: Int) -> String {
            if row == -1 {
                var headers = ["#"]
                for columnID in visibleTextColumnOrder() {
                    headers.append(headerTitle(for: columnID))
                }
                return headers.indices.contains(column) ? headers[column] : ""
            }
            guard row >= 0, row < rowCount else { return "" }
            guard column != 0 else { return "\(row + 1)" }
            guard let model = rowProvider(row) else { return "" }
            let textColumns = visibleTextColumnOrder()
            let textColumnIndex = column - 1
            guard textColumns.indices.contains(textColumnIndex) else { return "" }
            return text(for: textColumns[textColumnIndex], model: model)
        }

        func resizeDocument(preserving preservedAnchor: DynamicScrollAnchor? = nil) {
            guard !isResizingDocument, let scrollView, let documentView else { return }
            isResizingDocument = true
            defer { isResizingDocument = false }

            rowHeightCache.configure(rowCount: rowCount, defaultHeight: currentRowHeight)
            let viewportWidth = max(scrollView.contentSize.width, scrollView.bounds.width)
            let width = tableContentWidth(viewportWidth: viewportWidth)
            let oldSize = documentView.frame.size
            let oldLayout = tableColumnLayout(contentWidth: max(1, oldSize.width), height: currentRowHeight)
            let newLayout = tableColumnLayout(contentWidth: width, height: currentRowHeight)
            let nextRowMeasurementLayoutKey = newLayout.rowMeasurementLayoutKey
            let rowMeasurementLayoutChanged = lastRowMeasurementLayoutKey != nil &&
                lastRowMeasurementLayoutKey != nextRowMeasurementLayoutKey
            let anchor = preservedAnchor ?? (rowMeasurementLayoutChanged ? captureDynamicScrollAnchor() : nil)
            if rowMeasurementLayoutChanged {
                UIInvalidationProbe.mark(
                    "ACTION UI.SubtitleTable.\(probeSurface.rawValue).width_reflow",
                    scope: probeScope,
                    details: "table=\(tableName)"
                )
                UIInvalidationProbe.count(
                    probeSurface.counterName("width_reflow_owner_update"),
                    scope: probeScope,
                    details: "table=\(tableName)"
                )
                rowMeasurementCache.removeAll()
                rowHeightCache.removeAll()
            }
            lastRowMeasurementLayoutKey = nextRowMeasurementLayoutKey

            let nextSize = CGSize(
                width: width,
                height: pageScrollGeometry?.documentHeight(
                    rowsHeight: rowHeightCache.totalHeight,
                    viewportHeight: scrollView.contentSize.height
                ) ?? max(1, scrollView.contentSize.height, rowHeightCache.totalHeight)
            )
            pageScrollbar?.setNeedsDisplay()
            let sizeChanged = documentView.frame.size != nextSize
            if sizeChanged {
                documentView.setFrameSize(nextSize)
            }
            clampHorizontalScrollOffset(contentWidth: width)
            reflowVisibleRows(anchor: anchor)
            pageScrollbar?.metricsDidChange()
            if rowMeasurementLayoutChanged {
                invalidateColumnLayoutChange(
                    oldLayout: oldLayout,
                    newLayout: newLayout
                )
                headerView?.refreshHeaderHosts()
                refreshHeaderForHorizontalScrollIfNeeded()
            } else if oldSize.width != nextSize.width {
                refreshHeaderForHorizontalScrollIfNeeded(force: true)
            } else {
                refreshHeaderForHorizontalScrollIfNeeded()
            }
            outlineOverlayView?.needsDisplay = true
        }

        func notifyVisibleRowsChanged(force: Bool = false) {
            guard !isCoveredByHigherLayer else { return }
            reflowVisibleRows()
            guard let scrollView,
                  let range = measurementRowRange(
                    in: tableBodyVisibleRect(for: scrollView)
                  )
            else { return }
            // Reflow can temporarily move the clip view while preserving a
            // primary-Cue anchor. Prune only after the visible range settles,
            // otherwise a second layout pass can lose that anchor measurement.
            rowMeasurementCache.retain(rowIndices: range)
            guard force || range != lastNotifiedVisibleRows else { return }
            lastNotifiedVisibleRows = range
            onVisibleRowsChange(range)
        }

        func scrollToTop() {
            guard let scrollView else {
                return
            }

            scrollView.contentView.scroll(to: CGPoint(
                x: 0,
                y: 0
            ))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            layoutPageChrome()
            invalidateVisibleDocument()
            pageScrollbar?.setNeedsDisplay()
            notifyVisibleRowsChanged(force: true)
        }

        func scrollToRow(_ row: Int) {
            guard let scrollView, let documentView else {
                return
            }

            let clampedRow = min(max(0, row), max(0, rowCount - 1))
            reflowVisibleRows(explicitTargetRow: clampedRow)
            let maxY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
            let localRowY = rowHeightCache.yOffset(for: clampedRow)
            let y = pageScrollGeometry?.scrollOffsetForRow(
                localRowY: localRowY,
                maximumOffset: maxY
            ) ?? min(localRowY, maxY)
            var origin = scrollView.contentView.bounds.origin
            origin.y = y
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            layoutPageChrome()
            documentView.setNeedsDisplay(documentView.visibleRect)
            pageScrollbar?.setNeedsDisplay()
            notifyVisibleRowsChanged(force: true)
        }

        func clampHorizontalScrollOffset(contentWidth: CGFloat) {
            guard let scrollView else { return }
            let maxX = max(0, contentWidth - scrollView.contentView.bounds.width)
            var origin = scrollView.contentView.bounds.origin
            let clampedX = min(max(0, origin.x), maxX)
            guard abs(clampedX - origin.x) > 0.5 else { return }
            origin.x = clampedX
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        @objc func scrollContentDidChange() {
            updateHoveredCueStateRow(nil)
            layoutPageChrome()
            outlineOverlayView?.needsDisplay = true
            notifyVisibleRowsChanged()
            pageScrollbar?.metricsDidChange()
            refreshHeaderForHorizontalScrollIfNeeded()
            if isMenuOpen {
                repositionOpenMenu()
            }
        }

        func tableContentWidth(viewportWidth: CGFloat) -> CGFloat {
            let cuesMinimumWidth = SubtitleTableMetrics.cuesColumnMinimumWidth
            let minimumWidth = SubtitleTableColumnLayout.minimumContentWidth(
                showsDateAddedColumn: showsDateAddedColumn,
                showsDisplayTitleColumn: showsDisplayTitleColumn,
                showsTimeColumn: showsTimeColumn,
                showsLanguageColumn: showsLanguageColumn,
                cuesMinimumWidth: cuesMinimumWidth
            )
            return max(viewportWidth, minimumWidth)
        }

        func tableColumnLayout(contentWidth: CGFloat, height: CGFloat) -> SubtitleTableColumnLayout {
            SubtitleTableColumnLayout.resolve(
                contentWidth: contentWidth,
                height: height,
                showsDateAddedColumn: showsDateAddedColumn,
                showsDisplayTitleColumn: showsDisplayTitleColumn,
                showsTimeColumn: showsTimeColumn,
                showsLanguageColumn: showsLanguageColumn,
                cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
                columnOrder: columnOrder
            )
        }

        func visibleTextColumnOrder() -> [String] {
            SubtitleTableColumnLayout.resolvedTextColumnOrder(
                columnOrder,
                showsDateAddedColumn: showsDateAddedColumn,
                showsDisplayTitleColumn: showsDisplayTitleColumn,
                showsTimeColumn: showsTimeColumn,
                showsLanguageColumn: showsLanguageColumn
            )
        }

        func refreshHeaderForHorizontalScrollIfNeeded(force: Bool = false) {
            let offset = scrollView?.contentView.bounds.origin.x ?? 0
            guard force || lastHeaderHorizontalOffset != offset else { return }
            lastHeaderHorizontalOffset = offset
            headerView?.refreshHeaderFramesForHorizontalScroll()
            headerView?.needsDisplay = true
        }

        func captureDynamicScrollAnchor() -> DynamicScrollAnchor? {
            guard let scrollView,
                  let documentView,
                  let visibleRows = visibleRowRange()
            else {
                return nil
            }

            for row in visibleRows {
                guard let model = rowProvider(row) else {
                    continue
                }
                guard let measurement = cachedMeasurement(
                    for: row,
                    documentWidth: documentView.bounds.width
                ) ?? rowMeasurementCache.cachedMeasurement(
                    rowIndex: row,
                    primaryCueIdentity: model.primaryCueIdentity
                )
                else {
                    continue
                }
                let firstLineDocumentY = rowDocumentY(for: row)
                    + measurement.primaryFirstLineOffset
                return DynamicScrollAnchor(
                    primaryCueIdentity: model.primaryCueIdentity,
                    row: row,
                    primaryFirstLineScreenY: firstLineDocumentY - scrollView.contentView.bounds.minY
                )
            }
            return nil
        }

        func restoreDynamicScrollAnchor(_ anchor: DynamicScrollAnchor?) {
            guard let anchor,
                  let scrollView,
                  let documentView,
                  let model = rowProvider(anchor.row),
                  model.primaryCueIdentity == anchor.primaryCueIdentity,
                  let measurement = cachedMeasurement(for: anchor.row, documentWidth: documentView.bounds.width)
            else {
                return
            }

            let firstLineDocumentY = rowDocumentY(for: anchor.row)
                + measurement.primaryFirstLineOffset
            let maximumY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
            let nextY = min(
                max(0, firstLineDocumentY - anchor.primaryFirstLineScreenY),
                maximumY
            )
            var origin = scrollView.contentView.bounds.origin
            guard abs(origin.y - nextY) > 0.01 else { return }
            origin.y = nextY
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            UIInvalidationProbe.count(
                probeSurface.counterName("dynamic_scroll_anchor_correction"),
                scope: probeScope,
                details: "table=\(tableName) row=\(anchor.row)"
            )
        }

        func reflowVisibleRows(
            anchor: DynamicScrollAnchor? = nil,
            explicitTargetRow: Int? = nil
        ) {
            guard !isApplyingDynamicReflow,
                  let scrollView,
                  let documentView
            else {
                return
            }
            isApplyingDynamicReflow = true
            defer { isApplyingDynamicReflow = false }

            let resolvedAnchor = anchor ?? captureDynamicScrollAnchor()
            rowHeightCache.configure(rowCount: rowCount, defaultHeight: currentRowHeight)
            if anchor == nil,
               let measurementRange = measurementRowRange(
                    in: tableBodyVisibleRect(for: scrollView)
               )
            {
                for row in measurementRange {
                    _ = measureRow(row, documentWidth: documentView.bounds.width)
                }
            }
            let requiredTargetRow = explicitTargetRow ?? resolvedAnchor?.row
            if let requiredTargetRow,
               requiredTargetRow >= 0,
               requiredTargetRow < rowCount,
               measurementRowRange(
                    in: tableBodyVisibleRect(for: scrollView)
               )?.contains(requiredTargetRow) != true
            {
                _ = measureRow(requiredTargetRow, documentWidth: documentView.bounds.width)
            }

            let nextHeight = pageScrollGeometry?.documentHeight(
                rowsHeight: rowHeightCache.totalHeight,
                viewportHeight: scrollView.contentSize.height
            ) ?? max(1, scrollView.contentSize.height, rowHeightCache.totalHeight)
            if abs(documentView.frame.height - nextHeight) > 0.01 {
                documentView.setFrameSize(CGSize(width: documentView.frame.width, height: nextHeight))
            }
            restoreDynamicScrollAnchor(resolvedAnchor)
            var postRestoreHeightChanged = false
            if let postRestoreRange = measurementRowRange(
                in: tableBodyVisibleRect(for: scrollView)
            ) {
                for row in postRestoreRange {
                    postRestoreHeightChanged = measureRow(
                        row,
                        documentWidth: documentView.bounds.width
                    ) || postRestoreHeightChanged
                }
            }
            if postRestoreHeightChanged {
                let resolvedHeight = pageScrollGeometry?.documentHeight(
                    rowsHeight: rowHeightCache.totalHeight,
                    viewportHeight: scrollView.contentSize.height
                ) ?? max(1, scrollView.contentSize.height, rowHeightCache.totalHeight)
                if abs(documentView.frame.height - resolvedHeight) > 0.01 {
                    documentView.setFrameSize(CGSize(
                        width: documentView.frame.width,
                        height: resolvedHeight
                    ))
                }
                restoreDynamicScrollAnchor(resolvedAnchor)
            }
            pageScrollbar?.metricsDidChange()
            pageScrollbar?.setNeedsDisplay()
            outlineOverlayView?.needsDisplay = true
            documentView.setNeedsDisplay(documentView.visibleRect)
            if isMenuOpen {
                repositionOpenMenu()
            }
        }

        func scheduleResizeAfterDrawing() {
            resizeDocument()
        }
    }
}
