import AppKit
import CueSeekerCore
import SwiftUI

extension SubtitleTableView.Coordinator {
    func numberOfRowsForTesting() -> Int {
        rowCount
    }

    func rowsVersionForTesting() -> Int {
        rowsVersion
    }

    func probeSurfaceForTesting() -> SubtitleTableProbeSurface {
        probeSurface
    }

    func showsCueGroupForTesting() -> Bool {
        showsCueGroup
    }

    func quiesceForTesting() {
        cancelPendingTextInteraction()
        unbindExternalTextSelectionSession()
        NotificationCenter.default.removeObserver(self)
        closeMenuGateSession()
        if let monitor = keyboardFocusEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardFocusEventMonitor = nil
        }
        container?.onLayout = nil
    }

    func primaryCueIdentityForTesting(row: Int) -> SubtitleTablePrimaryCueIdentity? {
        rowProvider(row)?.primaryCueIdentity
    }

    func primaryCueTextForTesting(row: Int) -> String? {
        rowProvider(row)?.primaryCueText
    }

    func rowSelectionStateForTesting(row: Int) -> Bool {
        isRowSelected(row)
    }

    func focusedCheckboxRowForTesting() -> Int? {
        focusedCheckboxRow
    }

    func isMenuOpenForTesting() -> Bool {
        isMenuOpen && menuHost?.isHidden == false
    }

    func menuFrameForTesting() -> CGRect? {
        menuHost?.frame
    }

    func menuBodyFrameForTesting() -> CGRect {
        menuBodyFrameInContainer()
    }

    /// True while the open menu sits in the view that cuts it off at the
    /// table body.
    func menuIsClippedToTableBodyForTesting() -> Bool {
        guard let menuHost, !menuHost.isHidden, let menuClipView else {
            return false
        }
        return menuHost.superview === menuClipView
            && menuClipView.layer?.masksToBounds == true
            && menuClipView.frame == menuBodyFrameInContainer()
    }

    func submenuFrameForTesting() -> CGRect? {
        guard submenuHost?.isHidden == false else {
            return nil
        }
        return submenuHost?.frame
    }

    func submenuReceivesHitForTesting(
        containerPoint: CGPoint
    ) -> Bool {
        guard let container,
              let submenuHost,
              !submenuHost.isHidden,
              // `hitTest` reads its point in the space outside the
              // container, which measures the other way up.
              let hitView = container.hitTest(
                  container.convert(containerPoint, to: container.superview)
              )
        else {
            return false
        }
        return hitView === submenuHost
            || hitView.isDescendant(of: submenuHost)
    }

    func rowActionParentItemFrameForTesting(
        _ action: SubtitleTableRowAction
    ) -> CGRect? {
        rowActionSubmenuState?.parentItemFrame(for: action)
    }

    func openRowActionSubmenuForTesting(
        _ action: SubtitleTableRowAction
    ) {
        rowActionSubmenuState?.open(action)
    }

    /// The menu gate owns these keys at runtime, so tests reach the same
    /// handler directly.
    func handleMenuKeyForTesting(_ keyCode: UInt16) -> Bool {
        handleMenuKey(keyCode)
    }

    func menuContainsWindowPointForTesting(_ windowPoint: CGPoint) -> Bool {
        isWindowPointInsideOpenMenu(windowPoint)
    }

    func menuOutsideClickDismissesForTesting(windowPoint: CGPoint) -> Bool {
        guard isMenuOpen else { return false }
        return !isWindowPointInsideOpenMenu(windowPoint)
    }

    func dataCellRectForTesting(row: Int, columnID: String) -> CGRect? {
        guard let documentView else { return nil }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        return dataCellRect(columnID: columnID, rowRect: rowRect)
    }

    func cellContentHoverFrameForTesting(row: Int, columnID: String) -> CGRect? {
        cellContentHoverFrameInContainer(for: row, columnID: columnID)
    }

    func cellContentHoverDocumentRectForTesting(row: Int, columnID: String) -> CGRect? {
        cellContentHoverRectInDocument(row: row, columnID: columnID)
    }

    func isCellHoveredForTesting(row: Int, columnID: String) -> Bool {
        isCellHovered(row: row, columnID: columnID)
    }

    func rowBackgroundColorForTesting(row: Int) -> NSColor? {
        rowBackgroundColor(row: row)
    }

    func setFocusedCheckboxRowForTesting(_ row: Int?) {
        updateFocusedCheckbox(row)
    }

    func setSelectionModeForTesting(_ isSelectionMode: Bool) {
        self.isSelectionMode = isSelectionMode
    }

    func cueTextHitTestForTesting(row: Int, point: CGPoint) -> Bool {
        isPointInCueText(row: row, point: point)
    }

    @discardableResult
    func toggleRowCheckboxFromMouseForTesting(row: Int) -> Bool {
        toggleRowCheckboxFromMouse(row: row)
    }

    func tableContentWidthForTesting(viewportWidth: CGFloat) -> CGFloat {
        tableContentWidth(viewportWidth: viewportWidth)
    }

    func selectableTextForTesting(row: Int, columnID: String) -> String? {
        rowProvider(row).map { selectableText(for: columnID, model: $0) }
    }

    func textPositionForTesting(
        row: Int,
        columnID: String,
        point: CGPoint,
        requiresTextHit: Bool = true
    ) -> SubtitleTableTextPosition? {
        textPosition(
            row: row,
            columnID: columnID,
            point: point,
            requiresTextHit: requiresTextHit
        )
    }

    func textFragmentInfoForTesting(
        row: Int,
        columnID: String
    ) -> [(logicalRange: NSRange, textBounds: CGRect, clipRect: CGRect)] {
        guard let documentView else { return [] }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        return textFragments(row: row, columnID: columnID, rowRect: rowRect).map {
            (
                logicalRange: $0.logicalUTF16Range,
                textBounds: textBounds(for: $0),
                clipRect: $0.clipRect
            )
        }
    }

    func cueTextFragmentInfoForTesting(
        row: Int,
        measurement: SubtitleTableRowMeasurement
    ) -> [(logicalRange: NSRange, textBounds: CGRect, clipRect: CGRect)] {
        guard let documentView,
              let model = rowProvider(row)
        else {
            return []
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        guard let cellRect = dataCellRect(columnID: "cues", rowRect: rowRect) else {
            return []
        }
        return cueTextFragments(
            model: model,
            in: cellRect,
            measurement: measurement
        ).map {
            (
                logicalRange: $0.logicalUTF16Range,
                textBounds: textBounds(for: $0),
                clipRect: $0.clipRect
            )
        }
    }

    func headerTextFragmentInfoForTesting() -> [(
        columnID: String,
        columnIndex: Int,
        textBounds: CGRect,
        clipRect: CGRect
    )] {
        headerTextFragments().map {
            (
                columnID: $0.columnID,
                columnIndex: $0.columnIndex,
                textBounds: textBounds(for: $0.fragment),
                clipRect: $0.fragment.clipRect
            )
        }
    }

    func headerTextPositionForTesting(
        point: CGPoint,
        requiresTextHit: Bool = true
    ) -> SubtitleTableTextPosition? {
        headerTextPosition(at: point, requiresTextHit: requiresTextHit)
    }

    func headerTextSelectionRectsForTesting(columnID: String) -> [CGRect] {
        guard let item = headerTextFragments().first(where: { $0.columnID == columnID }),
              let selectedRange = textSelection.selectedUTF16Range(
                  row: .header,
                  columnIndex: item.columnIndex,
                  utf16Length: item.fragment.logicalUTF16Range.length
              )
        else {
            return []
        }
        textLayout.update(
            attributedString: item.fragment.attributed,
            width: item.fragment.width
        )
        return textLayout.selectionRects(
            forUTF16Range: selectedRange,
            at: item.fragment.origin
        ).compactMap {
            let clipped = $0.intersection(item.fragment.clipRect)
            return clipped.isNull || clipped.width <= 0 || clipped.height <= 0
                ? nil
                : clipped
        }
    }

    func textSelectionRangeForTesting(row: Int, columnID: String) -> NSRange? {
        guard let model = rowProvider(row) else { return nil }
        return selectedUTF16Range(
            row: row,
            columnID: columnID,
            text: selectableText(for: columnID, model: model)
        )
    }

    func textSelectionRectsForTesting(row: Int, columnID: String) -> [CGRect] {
        guard let documentView,
              let selectedRange = textSelectionRangeForTesting(row: row, columnID: columnID)
        else {
            return []
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        return textFragments(row: row, columnID: columnID, rowRect: rowRect).flatMap { fragment -> [CGRect] in
            textLayout.update(attributedString: fragment.attributed, width: fragment.width)
            guard let localRange = localSelectionRange(
                selectedRange,
                in: fragment.logicalUTF16Range
            ) else {
                return []
            }
            return textLayout.selectionRects(forUTF16Range: localRange, at: fragment.origin).compactMap {
                let clipped = $0.intersection(fragment.clipRect)
                return clipped.isNull || clipped.width <= 0 || clipped.height <= 0
                    ? nil
                    : clipped
            }
        }
    }

    func clearTextSelectionForTesting() {
        clearTextSelection()
    }

    func textSelectionInvalidationCountForTesting() -> Int {
        textSelectionInvalidationCount
    }

    func resetTextSelectionInvalidationCountForTesting() {
        textSelectionInvalidationCount = 0
    }

    func textSelectionSelectsAllForTesting() -> Bool {
        textSelection.selectsAllResults
    }

    func pendingTextSelectionHasBegunForTesting() -> Bool {
        pendingTextInteraction?.selectionHasBegun == true
    }

    func documentTextPositionForTesting(
        point: CGPoint,
        requiresTextHit: Bool = true
    ) -> SubtitleTableTextPosition? {
        textPosition(atDocumentPoint: point, requiresTextHit: requiresTextHit)
    }

    func waitForTextCopyForTesting() async {
        await textCopyTask?.value
    }

    func textDragAutoScrollTickForTesting() {
        textDragAutoScrollTick()
    }

    func copyCellTextForTesting(row: Int, columnID: String) {
        copyCellText(row: row, columnID: columnID)
    }

    func copyCueTextForTesting(row: Int) {
        copyRow(row)
    }

    func copyDeepLinkForTesting(row: Int) {
        guard let model = rowProvider(row) else { return }
        copyDeepLink(target: model)
    }

    func copyCueGroupTextForTesting(row: Int) {
        copyCueGroup(row)
    }

    func rowMenuElementsForTesting() -> [SubtitleTableRowActionMenuElement] {
        SubtitleTableRowActionMenuModel(
            style: rowActionMenuStyle,
            showsCueGroup: showsCueGroup
        ).elements
    }

    func rowMenuItemsForTesting() -> [(title: String, icon: AppIcon)] {
        SubtitleTableRowActionMenuModel(
            style: rowActionMenuStyle,
            showsCueGroup: showsCueGroup
        ).actions.map { ($0.title, $0.icon) }
    }

    func performRowActionForTesting(_ action: SubtitleTableRowAction, row: Int) {
        performRowAction(action, row: row)
    }

    func performActiveRowMenuActionForTesting(_ action: SubtitleTableRowAction) {
        performActiveRowMenuAction(action)
    }

    func performActiveRowMenuDestinationActionForTesting(
        _ action: SubtitleTableRowAction,
        destinationID: Int64
    ) {
        performActiveRowMenuDestinationAction(
            action,
            destinationID: destinationID
        )
    }

    func activeRowMenuTargetForTesting() -> SubtitleTableRow? {
        activeRowMenuTarget
    }

    func setActiveRowMenuTargetForTesting(_ target: SubtitleTableRow?) {
        activeRowMenuTarget = target
    }

    func rowHeightForTesting(_ row: Int) -> CGFloat {
        rowHeightCache.height(for: row)
    }

    func checkboxRectForTesting(row: Int) -> CGRect? {
        guard let documentView,
              row >= 0,
              row < rowCount
        else {
            return nil
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        return checkboxRect(forRowRect: rowRect)
    }

    func rowYOffsetForTesting(_ row: Int) -> CGFloat {
        rowDocumentY(for: row)
    }

    func totalRowsHeightForTesting() -> CGFloat {
        rowHeightCache.totalHeight
    }

    func primaryFirstLineScreenYForTesting(row: Int) -> CGFloat? {
        guard let scrollView,
              let documentView,
              let measurement = cachedMeasurement(for: row, documentWidth: documentView.bounds.width)
        else {
            return nil
        }
        return rowHeightCache.yOffset(for: row)
            + rowsOriginY
            + measurement.primaryFirstLineOffset
            - scrollView.contentView.bounds.minY
    }

    func measurementComputeCountForTesting() -> Int {
        measurementComputeCount
    }

    func retainedRowMeasurementCountForTesting() -> Int {
        rowMeasurementCache.count
    }

    func resetMeasurementComputeCountForTesting() {
        measurementComputeCount = 0
    }

    func drawnRowCountForTesting() -> Int {
        drawnRowCount
    }

    func resetDrawnRowCountForTesting() {
        drawnRowCount = 0
    }

    func drawingRowRangeForTesting(dirtyRect: CGRect) -> Range<Int>? {
        let viewportDirtyRect = dirtyRect.intersection(currentTableBodyVisibleRect)
        guard !viewportDirtyRect.isNull else { return nil }
        return visibleRowRange(in: viewportDirtyRect)
    }

    func measurementRowRangeForTesting() -> Range<Int>? {
        guard let scrollView else { return nil }
        return measurementRowRange(in: tableBodyVisibleRect(for: scrollView))
    }

    func openSubtitleFileForTesting(row: Int) {
        openSubtitleFile(row: row)
    }

    func tableOutlineFrameForTesting() -> CGRect? {
        tableOutlineFrameInContainer()
    }

    func usesOverlayScrollbarsForTesting() -> Bool {
        pageScrollbar?.drawsOverlayScrollbars == true &&
            scrollView?.hasVerticalScroller == false &&
            scrollView?.hasHorizontalScroller == false
    }

    func pageChromeFramesForTesting() -> (
        scrollable: CGRect,
        pinned: CGRect,
        tableHeader: CGRect
    )? {
        guard let scrollablePageChromeHost,
              let pinnedPageChromeHost,
              let headerView
        else {
            return nil
        }
        return (
            scrollablePageChromeHost.frame,
            pinnedPageChromeHost.frame,
            headerView.frame
        )
    }

    func rowActionButtonFrameForTesting(row: Int) -> CGRect? {
        rowActionButtonFrameInContainer(for: row)
    }

    func rowActionButtonDocumentFrameForTesting(row: Int) -> CGRect? {
        rowActionButtonFrameInDocument(for: row)
    }

    func rowActionButtonHitTestForTesting(row: Int, point: CGPoint) -> Bool {
        isPointInRowActionButton(row: row, point: point)
    }

    func shouldShowRowActionButtonForTesting(row: Int) -> Bool {
        shouldShowRowActionButton(row: row)
    }

    func rowActionButtonBackgroundColorForTesting(row: Int) -> NSColor? {
        rowActionButtonBackgroundColor(row: row)
    }

    func verticalScrollOffsetForTesting() -> CGFloat {
        scrollView?.contentView.bounds.origin.y ?? 0
    }

    func shouldDrawRowBottomDividerForTesting(row: Int) -> Bool {
        shouldDrawRowBottomDivider(row: row)
    }

    func displayIndexForTesting(row: Int) -> Int? {
        displayIndex(forRow: row, model: rowProvider(row))
    }

    func cueStateIndicatorRectForTesting(row: Int) -> CGRect? {
        cueStateIndicatorRectInDocument(row: row)
    }

    func firstFocusableCheckboxRowForTesting(visibleRows: Range<Int>?) -> Int? {
        firstFocusableCheckboxRow(visibleRows: visibleRows)
    }
}
