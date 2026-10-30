import AppKit
import SwiftUI

enum SchemaWorkbenchSelectionActionID: String, Hashable {
    case exportToAnki = "anki"
    case copyDeepLinks = "copy-deep-links"
    case copyTable = "copy-table"
    case moveTo = "move-to"
    case delete = "delete"
}

enum WorkbenchAccessibilityTarget: Hashable {
    // Topbar (L-01.2)
    case topbarSidebarToggle
    case topbarBackButton
    case topbarForwardButton
    case topbarRecentSegment(WorkbenchRecentSection)
    case topbarTaskButton
    case topbarSettingsButton

    // Sidebar (L-01.1)
    case sidebarItem(WorkbenchPanelMode)

    // Cover Summary Card (Library Detail & Excerpt Detail)
    case coverSummaryPrimaryButton
    case coverSummaryEditCoverButton
    case coverSummaryMoreButton

    // Toolbar (Library Overview, Excerpt Overview, Search & Excerpt Detail)
    case toolbarSearchField
    case toolbarSearchClearButton
    case toolbarFilterButton
    case toolbarSortButton
    case excerptNewListButton
    case toolbarExitSelectButton
    case toolbarSelectionAction(SchemaWorkbenchSelectionActionID)

    // Subtitle Table (Search & Excerpt Detail)
    case tableHeaderCheckbox
    case tableRowCheckbox(Int)
    case tableRowCueText(Int)
    case tableRowActionButton(Int)

    // Card Grids (Recent, Library Overview & Detail, Excerpt Overview)
    case mediaCard(String)
    case mediaCardActionButton(String)

    // File Page (Level 1 / 2 / 3)
    case fileAddFolderButton
    case fileIndexNowButton
    case fileStatusIndicatorText
    case fileBreadcrumb(String)
    case fileCard(String)
    case fileCardActionButton(String)
    case fileRowActionButton(String)

    var mediaCardID: String? {
        switch self {
        case .mediaCard(let id), .mediaCardActionButton(let id):
            return id
        default:
            return nil
        }
    }

    var isTableTarget: Bool {
        switch self {
        case .tableHeaderCheckbox, .tableRowCheckbox, .tableRowCueText, .tableRowActionButton:
            return true
        default:
            return false
        }
    }

    var tableRowIndex: Int? {
        switch self {
        case .tableRowCheckbox(let row), .tableRowCueText(let row), .tableRowActionButton(let row):
            return row
        default:
            return nil
        }
    }
}

@MainActor
final class WorkbenchAccessibilityCoordinator: ObservableObject {
    @Published private(set) var focusedTarget: WorkbenchAccessibilityTarget?

    /// Current column count of the active Workbench card grid (`Recent`,
    /// `Library` Overview & Detail, `Excerpt` Overview), updated by
    /// `LibraryOverviewGrid` layout.
    var cardGridColumnCount: Int = 1

    /// Current SubtitleTableView coordinator when `Search` or `Excerpt` Detail
    /// is mounted on the Workbench page.
    weak var activeSubtitleTableCoordinator: SubtitleTableView.Coordinator?
    var tableTargetsOverrideForTesting: (() -> [WorkbenchAccessibilityTarget])?

    /// Weak reference to the active Workbench search field's native text field,
    /// so focusing `.toolbarSearchField` places the insertion point inside it
    /// and leaving `.toolbarSearchField` resigns first responder.
    weak var activeSearchTextField: WorkbenchNativeSingleLineTextField?

    /// Closures registered by card grids (`Recent` Excerpt Lists, `Library` Overview,
    /// `Excerpt` Overview) to open the card's `dots-three` menu by card ID.
    private var mediaCardMenuOpeners: [String: () -> Void] = [:]

    /// Closure registered by the active `SchemaWorkbenchSortMenuHost` to toggle
    /// its sort menu when `.toolbarSortButton` is activated.
    var onToggleToolbarSortMenu: (() -> Void)?

    /// Closure registered by `SchemaWorkbenchSearchToolbar` to open the Filter
    /// dialog when `.toolbarFilterButton` is activated.
    var onOpenToolbarFilterDialog: (() -> Void)?

    /// Closure registered by `SchemaWorkbenchSearchToolbar` to exit batch
    /// selection mode when `.toolbarExitSelectButton` is activated.
    var onExitTableSelectionMode: (() -> Void)?

    /// Closure registered by `SchemaWorkbenchSearchToolbar` to perform a batch
    /// selection action when `.toolbarSelectionAction(id)` is activated.
    var onPerformSelectionAction: ((SchemaWorkbenchSelectionActionID) -> Void)?

    /// Whether the active Workbench table (`Search` or `Excerpt` Detail) is
    /// currently in batch selection mode (`Select Mode`).
    var isTableInSelectionMode: Bool = false

    /// Closure registered by `WorkbenchLibraryView` or `WorkbenchExcerptTableView`
    /// to toggle the Cover Summary `More` menu when `.coverSummaryMoreButton` is activated.
    var onToggleCoverSummaryMoreMenu: (() -> Void)?

    /// Closure registered by `WorkbenchExcerptTableView` to toggle the `Move to`
    /// menu in batch selection mode when `.toolbarSelectionAction(.moveTo)` is activated.
    var onToggleSelectionMoveToMenu: (() -> Void)?

    /// Closure registered by `WorkbenchFileView` to toggle the `Add Folder`
    /// menu when `.fileAddFolderButton` is activated.
    var onToggleFileAddFolderMenu: (() -> Void)?

    /// Closures registered by `WorkbenchFileView` cards and file rows for
    /// opening their `dots-three` menu by ID.
    private var fileCardMenuOpeners: [String: () -> Void] = [:]

    var isActive: Bool {
        focusedTarget != nil
    }

    var focusedCardID: String? {
        focusedTarget?.mediaCardID
    }

    func isFocused(_ target: WorkbenchAccessibilityTarget) -> Bool {
        focusedTarget == target
    }

    func setFocus(_ target: WorkbenchAccessibilityTarget?) {
        let previous = focusedTarget
        if focusedTarget != target {
            focusedTarget = target
        }
        syncNativeSearchFieldFocus(from: previous, to: target)
        activeSubtitleTableCoordinator?.syncWorkbenchAccessibilityFocus(target)
    }

    @discardableResult
    func clear() -> Bool {
        guard focusedTarget != nil else {
            return false
        }
        focusedTarget = nil
        activeSubtitleTableCoordinator?.syncWorkbenchAccessibilityFocus(nil)
        return true
    }

    @discardableResult
    func resignActiveSearchTextFieldIfFocused() -> Bool {
        guard let field = activeSearchTextField, field.isCurrentlyFocused else {
            return false
        }
        _ = field.window?.makeFirstResponder(nil)
        return true
    }

    func registerMediaCardAction(id: String, openMenu: @escaping () -> Void) {
        mediaCardMenuOpeners[id] = openMenu
    }

    func unregisterMediaCardAction(id: String) {
        mediaCardMenuOpeners.removeValue(forKey: id)
    }

    func activateMediaCardAction(id: String) -> Bool {
        guard let openMenu = mediaCardMenuOpeners[id] else {
            return false
        }
        openMenu()
        return true
    }

    func registerFileCardAction(id: String, openMenu: @escaping () -> Void) {
        fileCardMenuOpeners[id] = openMenu
    }

    func unregisterFileCardAction(id: String) {
        fileCardMenuOpeners.removeValue(forKey: id)
    }

    @discardableResult
    func activateFileCardAction(id: String) -> Bool {
        guard let openMenu = fileCardMenuOpeners[id] else {
            return false
        }
        openMenu()
        return true
    }

    private func syncNativeSearchFieldFocus(
        from previous: WorkbenchAccessibilityTarget?,
        to next: WorkbenchAccessibilityTarget?
    ) {
        if next == .toolbarSearchField {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.focusedTarget == .toolbarSearchField else { return }
                self.activeSearchTextField?.focusFromAccessibility()
            }
        } else if next != nil {
            if let field = activeSearchTextField, field.isCurrentlyFocused {
                _ = field.window?.makeFirstResponder(nil)
            }
        }
    }
}

private struct WorkbenchAccessibilityCoordinatorKey: EnvironmentKey {
    static let defaultValue: WorkbenchAccessibilityCoordinator? = nil
}

extension EnvironmentValues {
    var workbenchAccessibility: WorkbenchAccessibilityCoordinator? {
        get { self[WorkbenchAccessibilityCoordinatorKey.self] }
        set { self[WorkbenchAccessibilityCoordinatorKey.self] = newValue }
    }
}

struct WorkbenchAccessibilityReader<Content: View>: View {
    @Environment(\.workbenchAccessibility) private var coordinator
    @ViewBuilder let content: (WorkbenchAccessibilityCoordinator?) -> Content

    var body: some View {
        if let coordinator {
            ObservedCoordinatorView(coordinator: coordinator, content: content)
        } else {
            content(nil)
        }
    }

    private struct ObservedCoordinatorView: View {
        @ObservedObject var coordinator: WorkbenchAccessibilityCoordinator
        @ViewBuilder let content: (WorkbenchAccessibilityCoordinator?) -> Content

        var body: some View {
            content(coordinator)
        }
    }
}

struct WorkbenchAccessibilityScrollRevealProbe: NSViewRepresentable {
    let isFocused: Bool

    init(isFocused: Bool) {
        self.isFocused = isFocused
    }

    init(isActive: Bool) {
        self.isFocused = isActive
    }

    func makeNSView(context _: Context) -> ProbeView {
        ProbeView()
    }

    func updateNSView(_ nsView: ProbeView, context _: Context) {
        nsView.update(isFocused: isFocused)
    }

    final class ProbeView: NSView {
        private var wasFocused = false

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        func update(isFocused: Bool) {
            let becameFocused = isFocused && !wasFocused
            wasFocused = isFocused
            guard becameFocused else { return }
            DispatchQueue.main.async { [weak self] in
                self?.revealInEnclosingScrollView()
            }
        }

        private func revealInEnclosingScrollView() {
            guard wasFocused,
                  bounds.width > 0,
                  bounds.height > 0,
                  let scrollView = enclosingScrollView,
                  let documentView = scrollView.documentView
            else {
                return
            }
            let clipView = scrollView.contentView
            let rectInDocument = documentView.convert(bounds, from: self).insetBy(dx: -6, dy: -6)
            let visible = clipView.documentVisibleRect
            guard visible.height > 0 else { return }
            var targetOriginY = visible.origin.y
            if rectInDocument.minY < visible.minY {
                targetOriginY = max(0, rectInDocument.minY)
            } else if rectInDocument.maxY > visible.maxY {
                targetOriginY = max(0, rectInDocument.maxY - visible.height)
            }
            if abs(targetOriginY - visible.origin.y) > 0.5 {
                clipView.scroll(to: CGPoint(x: visible.origin.x, y: targetOriginY))
                scrollView.reflectScrolledClipView(clipView)
            }
        }
    }
}

extension View {
    func workbenchAccessibilityFocusRing(
        isFocused: Bool,
        cornerRadius: CGFloat = WorkbenchControlMetrics.redesignCornerRadius,
        isCircular: Bool = false,
        isCapsule: Bool = false,
        isPlayerChrome: Bool = false
    ) -> some View {
        let expansion = WorkbenchControlMetrics.redesignFocusRingPathExpansion
        let lineWidth = WorkbenchControlMetrics.redesignFocusRingWidth
        let color = isPlayerChrome ? PlaybackTheme.focusRing : WorkbenchRedesignColors.focusRing
        return self
            .background(WorkbenchAccessibilityScrollRevealProbe(isFocused: isFocused))
            .overlay {
                if isFocused {
                    if isCircular {
                        Circle()
                            .stroke(color, lineWidth: lineWidth)
                            .padding(-expansion)
                            .allowsHitTesting(false)
                    } else if isCapsule {
                        Capsule(style: .continuous)
                            .stroke(color, lineWidth: lineWidth)
                            .padding(-expansion)
                            .allowsHitTesting(false)
                    } else {
                        RoundedRectangle(
                            cornerRadius: cornerRadius + expansion,
                            style: .continuous
                        )
                        .stroke(color, lineWidth: lineWidth)
                        .padding(-expansion)
                        .allowsHitTesting(false)
                    }
                }
            }
    }
}
