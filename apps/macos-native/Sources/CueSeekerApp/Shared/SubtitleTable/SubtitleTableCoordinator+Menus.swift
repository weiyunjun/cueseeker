import AppKit
import CueSeekerCore
import SwiftUI

extension SubtitleTableView.Coordinator {
    /// Arrow keys, Enter, Esc, and the submenu's left and right for the
    /// open row menu, offered by the menu gate.
    func handleMenuKey(_ keyCode: UInt16) -> Bool {
        guard isMenuOpen,
              activeRowMenuTarget != nil,
              let rowActionSubmenuState
        else {
            return false
        }
        // While a destination submenu is open it owns the arrow keys;
        // otherwise the parent menu does.
        let isSubmenuOpen = rowActionSubmenuState.openParent != nil
        // Every arrow and Enter belongs to the open menu, whether or not
        // it has anywhere to move: nothing outside the menu may respond.
        switch keyCode {
        case 53:
            dismissMenu()
            return true
        case 126:
            _ = isSubmenuOpen
                ? rowActionDestinationHighlight.moveHighlight(by: -1)
                : rowActionHighlight.moveHighlight(by: -1)
            return true
        case 125:
            _ = isSubmenuOpen
                ? rowActionDestinationHighlight.moveHighlight(by: 1)
                : rowActionHighlight.moveHighlight(by: 1)
            return true
        case 124:
            _ = openHighlightedRowActionSubmenu()
            return true
        case 123:
            _ = rowActionSubmenuState.closeSubmenu()
            return true
        case 36, 76:
            _ = isSubmenuOpen
                ? activateHighlightedRowActionDestination()
                : activateHighlightedRowAction()
            return true
        default:
            return false
        }
    }

    /// The table body in container coordinates. The menus are placed inside
    /// it and cut off at it: the page chrome above the body is frozen, so a
    /// menu that reached it would draw over the header and the toolbar.
    /// This is the table's own boundary, not a rule for menus.
    func menuBodyFrameInContainer() -> CGRect {
        guard let container, let documentView else {
            return container?.bounds ?? .zero
        }
        let body = container.convert(
            currentTableBodyVisibleRect,
            from: documentView
        )
        let clipped = body.intersection(container.bounds)
        return clipped.isNull ? .zero : clipped
    }

    /// The clip view, kept the size of the table body and above the dismiss
    /// overlay so a press on a menu still reaches it.
    @discardableResult
    func ensureMenuClipView(in container: NSView) -> SubtitleTableMenuClipView {
        let clipView = menuClipView ?? {
            let created = SubtitleTableMenuClipView(frame: .zero)
            menuClipView = created
            return created
        }()
        container.addSubview(clipView)
        let body = menuBodyFrameInContainer()
        clipView.frame = body
        // Matching bounds to frame keeps one coordinate space either side
        // of the clip view.
        clipView.bounds = body
        clipView.isHidden = false
        return clipView
    }

    func setMenuHost<Content: View>(_ content: Content, in container: NSView) {
        let wrapped = AnyView(content)
        if let menuHost {
            menuHost.rootView = wrapped
            menuHost.invalidateIntrinsicContentSize()
        } else {
            let host = MenuHostingView(rootView: wrapped)
            host.wantsLayer = true
            host.layer?.masksToBounds = false
            host.onIntrinsicContentSizeInvalidated = { [weak self] in
                self?.requestOpenMenuReposition()
            }
            ensureMenuClipView(in: container).addSubview(host)
            menuHost = host
        }
    }

    func setSubmenuHost<Content: View>(
        _ content: Content,
        in container: NSView
    ) {
        let wrapped = AnyView(content)
        if let submenuHost {
            submenuHost.rootView = wrapped
            submenuHost.invalidateIntrinsicContentSize()
        } else {
            let host = MenuHostingView(rootView: wrapped)
            host.wantsLayer = true
            host.layer?.masksToBounds = false
            ensureMenuClipView(in: container).addSubview(host)
            submenuHost = host
        }
    }

    func requestOpenMenuReposition() {
        guard isMenuOpen, !pendingMenuReposition else { return }
        pendingMenuReposition = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingMenuReposition = false
            self.repositionOpenMenu()
        }
    }

    /// The rectangle the open menu hangs off, in container coordinates.
    /// A right-click anchor is stored in document coordinates so it follows
    /// the row the pointer landed on while the table scrolls.
    func menuAnchorFrameInContainer(
        _ anchor: ActiveMenuAnchor
    ) -> CGRect {
        switch anchor {
        case .row(let row, let columnID, let anchorFrame, let clickPointInDocument):
            if let clickPointInDocument, let container, let documentView {
                let point = container.convert(
                    clickPointInDocument,
                    from: documentView
                )
                return CGRect(origin: point, size: .zero)
            }
            return rowMenuTriggerFrameInContainer(
                row: row,
                columnID: columnID,
                fallback: anchorFrame
            )
        }
    }

    func integralMenuFrame(_ frame: CGRect) -> CGRect {
        CGRect(
            x: frame.origin.x.rounded(),
            y: frame.origin.y.rounded(),
            width: ceil(frame.size.width),
            height: max(0, floor(frame.size.height))
        )
    }

    func openingMenuFrame(
        anchorFrameInContainer: CGRect,
        menuSize: CGSize
    ) -> CGRect {
        integralMenuFrame(
            MenuPlacement.openingFrame(
                anchor: anchorFrameInContainer,
                menuSize: menuSize,
                in: menuBodyFrameInContainer(),
                gap: WorkbenchControlMetrics.redesignSpacing1,
                edgeInset: SubtitleTableMetrics.trailingInset,
                shrinksToFit: true
            )
        )
    }

    func showMenu(
        for row: Int,
        columnID: String = "cues",
        buttonFrame: CGRect,
        clickPointInDocument: CGPoint? = nil
    ) {
        guard !isSelectionMode,
              row >= 0,
              row < rowCount,
              let target = rowProvider(row)
        else {
            return
        }
        cancelPendingTextInteraction()
        updateHoveredCueStateRow(nil)
        // The row the menu hangs off stays lit until the menu closes, so
        // it is said here rather than left to whatever the pointer happened
        // to hover on the way in. Hover is frozen from now on.
        updateHoveredRow(row)
        if let clickPointInDocument {
            let hoveredColumn = hoveredDataColumnID(row: row, point: clickPointInDocument)
            updateHoveredColumnID(hoveredColumn)
            let cueTextRow = hoveredColumn == "cues"
                && rowProvider(row)?.cueState.isUnavailable != true
                && isPointInCueText(row: row, point: clickPointInDocument)
                ? row
                : nil
            updateHoveredCueTextRow(cueTextRow)
        } else {
            updateHoveredColumnID(columnID)
        }
        isMenuOpen = true
        activeRowMenuRow = row
        activeRowMenuColumnID = columnID
        activeRowMenuTarget = target
        activeMenuAnchor = .row(
            row: row,
            columnID: columnID,
            anchorFrame: buttonFrame,
            clickPointInDocument: clickPointInDocument
        )
        menuPlacementOffset = nil
        invalidateRows([row])

        guard let container = self.container else {
            isMenuOpen = false
            activeRowMenuRow = nil
            activeRowMenuColumnID = nil
            activeRowMenuTarget = nil
            activeMenuAnchor = nil
        menuPlacementOffset = nil
            return
        }

        rowActionSubmenuState?.reset()
        hideRowActionDestinationSubmenu()
        let submenuState = MenuSubmenuState<SubtitleTableRowAction>()
        submenuState.parentHighlight = rowActionHighlight
        rowActionSubmenuState = submenuState
        submenuState.onOpenParentChange = { [weak self] action in
            guard let self else {
                return
            }
            if let action {
                self.showRowActionDestinationSubmenu(for: action)
            } else {
                self.hideRowActionDestinationSubmenu()
            }
        }
        let canOpenFolder = canOpenSubtitleFile(target: target)
        let disabledActions = disabledRowActions(for: target)
        rowActionHighlight.open(
            selectablePositions: activeRowActionMenuModel.selectablePositions(
                disabledActions: disabledActions,
                canOpenFolder: canOpenFolder
            )
        )
        let menuView = { [rowActionHighlight, rowActionMenuStyle, showsCueGroup] (maximumHeight: CGFloat) in
            RowActionMenu(
                style: rowActionMenuStyle,
                showsCueGroup: showsCueGroup,
                canOpenFolder: canOpenFolder,
                disabledActions: disabledActions,
                maximumHeight: maximumHeight,
                submenuState: submenuState,
                highlight: rowActionHighlight,
                onAction: { [weak self] action in
                    self?.performActiveRowMenuAction(action)
                }
            )
        }

        setMenuHost(menuView(MenuMetrics.maximumHeight), in: container)

        let clipView = ensureMenuClipView(in: container)
        if let menuHost {
            clipView.addSubview(menuHost)
        }

        menuHost?.layout()
        let menuSize = menuHost?.fittingSize ?? CGSize(width: 172, height: 128)

        let anchorFrame = activeMenuAnchor.map(menuAnchorFrameInContainer) ?? .zero
        var finalMenuFrame = openingMenuFrame(
            anchorFrameInContainer: anchorFrame,
            menuSize: menuSize
        )
        if finalMenuFrame.height < menuSize.height {
            // The side it opened on has less room than the menu wanted, so
            // it is rebuilt against that room. Its scrollbar comes up, which
            // widens it, which moves its trailing edge — hence the second
            // placement rather than only a shorter frame.
            setMenuHost(menuView(finalMenuFrame.height), in: container)
            menuHost?.layout()
            finalMenuFrame = openingMenuFrame(
                anchorFrameInContainer: anchorFrame,
                menuSize: menuHost?.fittingSize ?? finalMenuFrame.size
            )
        }
        menuPlacementOffset = MenuPlacement.offset(
            from: anchorFrame,
            to: finalMenuFrame
        )

        pendingMenuReposition = false
        menuHost?.frame = finalMenuFrame
        menuHost?.layoutSubtreeIfNeeded()
        menuHost?.isHidden = false

        openMenuGateSession()
    }

    var activeRowActionMenuModel: SubtitleTableRowActionMenuModel {
        SubtitleTableRowActionMenuModel(
            style: rowActionMenuStyle,
            showsCueGroup: showsCueGroup
        )
    }

    /// Runs whatever the parent highlight sits on. A submenu parent opens
    /// its submenu instead of acting, matching a click on the same row.
    func activateHighlightedRowAction() -> Bool {
        guard let position = rowActionHighlight.highlightedPosition,
              let action = activeRowActionMenuModel.action(at: position)
        else {
            return false
        }
        if action.opensDestinationSubmenu {
            rowActionSubmenuState?.open(action)
            return true
        }
        rowActionSubmenuState?.reset()
        performActiveRowMenuAction(action)
        return true
    }

    func openHighlightedRowActionSubmenu() -> Bool {
        guard rowActionSubmenuState?.openParent == nil,
              let position = rowActionHighlight.highlightedPosition,
              let action = activeRowActionMenuModel.action(at: position),
              action.opensDestinationSubmenu
        else {
            return false
        }
        rowActionSubmenuState?.open(action)
        return true
    }

    func activateHighlightedRowActionDestination() -> Bool {
        guard let openParent = rowActionSubmenuState?.openParent,
              let position = rowActionDestinationHighlight
                  .highlightedPosition
        else {
            return false
        }
        if position == rowActionDestinations.count {
            performActiveRowMenuCreateListAction(openParent)
            return true
        }
        guard rowActionDestinations.indices.contains(position) else {
            return false
        }
        performActiveRowMenuDestinationAction(
            openParent,
            destinationID: rowActionDestinations[position].id
        )
        return true
    }

    func showRowActionDestinationSubmenu(
        for action: SubtitleTableRowAction
    ) {
        guard isMenuOpen,
              let container,
              let submenuState = rowActionSubmenuState,
              let parentItemFrame = submenuState.parentItemFrame(
                for: action
              )
        else {
            return
        }
        if !rowActionDestinationHighlight.isOpen {
            rowActionDestinationHighlight.open(
                selectablePositions: ExcerptDestinationMenu
                    .selectablePositions(
                        destinationCount: rowActionDestinations.count
                    ),
                // Only saving remembers a destination; moving and
                // duplicating open on their first list as before.
                defaultPosition: action == .saveToExcerpt
                    ? ExcerptDestinationMenu.defaultPosition(
                        destinations: rowActionDestinations
                    )
                    : nil
            )
        }
        let submenuView = { [rowActionDestinationHighlight, rowActionDestinations] (maximumHeight: CGFloat) in
            RowActionDestinationSubmenu(
                destinations: rowActionDestinations,
                submenuState: submenuState,
                highlight: rowActionDestinationHighlight,
                maximumHeight: maximumHeight,
                onDestinationAction: { [weak self] destination in
                    self?.performActiveRowMenuDestinationAction(
                        action,
                        destinationID: destination.id
                    )
                },
                onCreateList: { [weak self] in
                    self?.performActiveRowMenuCreateListAction(action)
                }
            )
        }
        setSubmenuHost(submenuView(MenuMetrics.maximumHeight), in: container)
        guard let menuHost,
              let submenuHost
        else {
            return
        }
        ensureMenuClipView(in: container).addSubview(submenuHost)
        submenuHost.layoutSubtreeIfNeeded()
        let visibleRect = menuBodyFrameInContainer()
        var submenuSize = submenuHost.fittingSize
        var submenuFrame = integralMenuFrame(
            MenuSubmenuGeometry.frame(
                parentMenuFrame: menuHost.frame,
                parentItemFrame: parentItemFrame,
                submenuSize: submenuSize,
                visibleRect: visibleRect
            )
        )
        if submenuFrame.height < submenuSize.height {
            // Same second pass the parent menu makes: held to the room the
            // boundary leaves, the submenu gains its scrollbar and widens,
            // and the wider surface has to be placed again.
            setSubmenuHost(submenuView(submenuFrame.height), in: container)
            submenuHost.layoutSubtreeIfNeeded()
            submenuSize = submenuHost.fittingSize
            submenuFrame = integralMenuFrame(
                MenuSubmenuGeometry.frame(
                    parentMenuFrame: menuHost.frame,
                    parentItemFrame: parentItemFrame,
                    submenuSize: submenuSize,
                    visibleRect: visibleRect
                )
            )
        }
        submenuHost.frame = submenuFrame
        submenuHost.layoutSubtreeIfNeeded()
        submenuHost.isHidden = false
    }

    func hideRowActionDestinationSubmenu() {
        rowActionDestinationHighlight.close()
        submenuHost?.rootView = AnyView(EmptyView())
        submenuHost?.invalidateIntrinsicContentSize()
        submenuHost?.isHidden = true
    }

    func dismissMenu() {
        let previousRowMenuRow = activeRowMenuRow
        let previousHoveredRow = hoveredRow
        isMenuOpen = false
        activeRowMenuRow = nil
        activeRowMenuColumnID = nil
        activeRowMenuTarget = nil
        rowActionSubmenuState?.reset()
        rowActionSubmenuState = nil
        rowActionHighlight.close()
        activeMenuAnchor = nil
        menuPlacementOffset = nil
        updateHoveredColumnID(nil)
        updateHoveredCueTextRow(nil)
        updateHoveredRowActionRow(nil)
        menuHost?.rootView = AnyView(EmptyView())
        menuHost?.invalidateIntrinsicContentSize()
        menuHost?.isHidden = true
        hideRowActionDestinationSubmenu()
        menuClipView?.isHidden = true
        closeMenuGateSession()
        reevaluateHoverFromCurrentPointer()
        headerView?.refreshHeaderHosts()
        invalidateRows([previousRowMenuRow, previousHoveredRow])
    }

    /// Hands the open row menu to the menu gate, which owns the outside
    /// press, the whole-window scroll ban, and the menu's keys.
    func openMenuGateSession() {
        guard menuGateSession == nil else {
            return
        }
        menuGateSession = interfaceLayers?.menuGate.open(
            MenuGate.Client(
                owner: .workbenchPage,
                kind: .tableRowMenu,
                window: { [weak self] in self?.container?.window },
                isPointerOnMenu: { [weak self] event in
                    self?.isWindowPointInsideOpenMenu(
                        event.locationInWindow
                    ) ?? false
                },
                notePointer: { [weak self] event in
                    self?.noteMenuPointer(
                        windowPoint: event.locationInWindow
                    )
                },
                handleKey: { [weak self] keyCode, _ in
                    self?.handleMenuKey(keyCode) ?? false
                },
                dismiss: { [weak self] forwarding in
                    guard let self else { return }
                    if forwarding {
                        // Closed before the press reaches the row under
                        // it, so the row's own right-click opens its menu
                        // on this same press.
                        self.dismissMenu()
                    } else {
                        DispatchQueue.main.async {
                            self.dismissMenu()
                        }
                    }
                }
            )
        )
    }

    /// The open submenu's whole account of where the pointer is. Every
    /// frame is in the container's space, which the menu clip view shares.
    func noteMenuPointer(windowPoint: CGPoint) {
        guard let container,
              let submenuState = rowActionSubmenuState,
              let openParent = submenuState.openParent,
              let menuHost,
              !menuHost.isHidden,
              let submenuHost,
              !submenuHost.isHidden,
              let parentItemFrame = submenuState.parentItemFrame(
                for: openParent
              )
        else {
            return
        }
        submenuState.notePointer(
            container.convert(windowPoint, from: nil),
            parentMenuFrame: menuHost.frame,
            triggerFrame: parentItemFrame.offsetBy(
                dx: menuHost.frame.minX,
                dy: menuHost.frame.minY
            ),
            submenuFrame: submenuHost.frame
        )
    }

    func isWindowPointInsideOpenMenu(_ windowPoint: CGPoint) -> Bool {
        if let menuHost, !menuHost.isHidden {
            let point = menuHost.convert(windowPoint, from: nil)
            if menuHost.bounds.contains(point) {
                return true
            }
        }
        if let submenuHost, !submenuHost.isHidden {
            let point = submenuHost.convert(windowPoint, from: nil)
            if submenuHost.bounds.contains(point) {
                return true
            }
        }
        return false
    }

    func repositionOpenMenu() {
        guard isMenuOpen,
              let container,
              let menuHost,
              !menuHost.isHidden,
              let activeMenuAnchor
        else {
            return
        }

        ensureMenuClipView(in: container)

        menuHost.layoutSubtreeIfNeeded()
        let menuSize = menuHost.fittingSize
        let resolvedMenuSize = CGSize(
            width: menuSize.width > 0 ? menuSize.width : menuHost.frame.width,
            height: menuSize.height > 0 ? menuSize.height : menuHost.frame.height
        )

        let anchorFrame = menuAnchorFrameInContainer(activeMenuAnchor)
        // The side was chosen when the menu opened. Moving the anchor only
        // moves the menu; it never sends it to the other side mid-scroll.
        let offset = menuPlacementOffset ?? MenuPlacement.offset(
            from: anchorFrame,
            to: menuHost.frame
        )
        menuPlacementOffset = offset
        let finalMenuFrame = integralMenuFrame(
            MenuPlacement.followingFrame(
                anchor: anchorFrame,
                offset: offset,
                menuSize: resolvedMenuSize
            )
        )

        menuHost.frame = finalMenuFrame
        if let openParent = rowActionSubmenuState?.openParent {
            showRowActionDestinationSubmenu(for: openParent)
        }
    }

    func closeMenuGateSession() {
        menuGateSession?.close()
        menuGateSession = nil
        // The rects come back with the menu gone, and AppKit re-decides
        // from them.
    }

    func playRow(_ row: Int) {
        guard !isSelectionMode,
              let model = rowProvider(row),
              !model.cueState.isUnavailable
        else {
            return
        }
        onPlay(model)
    }

    func performActiveRowMenuAction(
        _ action: SubtitleTableRowAction
    ) {
        guard let target = activeRowMenuTarget else { return }
        dismissMenu()
        performRowAction(action, target: target)
    }

    func performActiveRowMenuDestinationAction(
        _ action: SubtitleTableRowAction,
        destinationID: Int64
    ) {
        guard let target = activeRowMenuTarget else {
            return
        }
        guard !disabledRowActions(for: target).contains(action) else {
            return
        }
        dismissMenu()
        switch action {
        case .saveToExcerpt:
            onSaveExcerpt(target, destinationID)
        case .moveToList:
            if let cueID = target.primaryCueID, let isCueInLibrary, !isCueInLibrary(cueID) {
                onToast?(TableToastRequest.cueNotInLibrary)
                return
            }
            onMoveExcerpt(target, destinationID)
        case .duplicateToList:
            if let cueID = target.primaryCueID, let isCueInLibrary, !isCueInLibrary(cueID) {
                onToast?(TableToastRequest.cueNotInLibrary)
                return
            }
            onDuplicateExcerpt(target, destinationID)
        default:
            break
        }
    }

    func performActiveRowMenuCreateListAction(
        _ action: SubtitleTableRowAction
    ) {
        guard let target = activeRowMenuTarget,
              action.opensDestinationSubmenu,
              !disabledRowActions(for: target).contains(action)
        else {
            return
        }
        dismissMenu()
        if action == .moveToList || action == .duplicateToList {
            if let cueID = target.primaryCueID, let isCueInLibrary, !isCueInLibrary(cueID) {
                onToast?(TableToastRequest.cueNotInLibrary)
                return
            }
        }
        onCreateExcerptList(target, action)
    }

    func performRowAction(_ action: SubtitleTableRowAction, row: Int) {
        guard let target = rowProvider(row) else { return }
        performRowAction(action, target: target)
    }

    func performRowAction(
        _ action: SubtitleTableRowAction,
        target: SubtitleTableRow
    ) {
        guard !disabledRowActions(for: target).contains(action) else {
            return
        }
        switch action {
        case .play:
            onPlay(target)
        case .openSubtitleFolder:
            openSubtitleFile(target: target)
        case .copyCueText:
            copyRow(target: target)
        case .copyDeepLink:
            copyDeepLink(target: target)
        case .copyCueGroupText:
            copyCueGroup(target: target)
        case .copyTimeRange:
            copyCellText(target: target, columnID: "time")
        case .saveToExcerpt, .moveToList, .duplicateToList:
            break
        case .removeExcerpt:
            onRemoveExcerpt(target)
        }
    }

    func disabledRowActions(
        for target: SubtitleTableRow
    ) -> Set<SubtitleTableRowAction> {
        var actions = target.cueState.disabledRowActions
        if target.primaryCueID.map({ $0 <= 0 }) ?? true {
            actions.insert(.copyDeepLink)
            actions.insert(.saveToExcerpt)
        }
        return actions
    }

    func copyRow(_ row: Int) {
        guard let model = rowProvider(row) else { return }
        copyRow(target: model)
    }

    func copyRow(target: SubtitleTableRow) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(target.primaryCueText, forType: .string)
        onToast?(TableToastRequest.copyCueText)
    }

    func copyDeepLink(target: SubtitleTableRow) {
        guard let cueID = target.primaryCueID else { return }
        if let isCueInLibrary, !isCueInLibrary(cueID) {
            onToast?(TableToastRequest.cueNotInLibrary)
            return
        }
        _ = CueClipboard.copyDeepLink(
            cueText: target.primaryCueText,
            cueID: cueID,
            to: .general
        )
        onToast?(TableToastRequest.copyDeepLink)
    }

    func copyCueGroup(_ row: Int) {
        guard let model = rowProvider(row) else { return }
        copyCueGroup(target: model)
    }

    func copyCueGroup(target: SubtitleTableRow) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(target.cueGroupCopyText, forType: .string)
        onToast?(TableToastRequest.copyCueGroupText)
    }

    func copyCellText(row: Int, columnID: String) {
        guard let model = rowProvider(row) else { return }
        copyCellText(target: model, columnID: columnID)
    }

    func copyCellText(target: SubtitleTableRow, columnID: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text(for: columnID, model: target), forType: .string)
        if columnID == "time" {
            onToast?(TableToastRequest.copyTimeRange)
        }
    }

    func canOpenSubtitleFile(target: SubtitleTableRow) -> Bool {
        !target.subtitlePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func openSubtitleFile(row: Int) {
        guard let model = rowProvider(row) else { return }
        openSubtitleFile(target: model)
    }

    func openSubtitleFile(target: SubtitleTableRow) {
        let path = target.subtitlePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        onOpenSubtitleFile(path)
    }
}
