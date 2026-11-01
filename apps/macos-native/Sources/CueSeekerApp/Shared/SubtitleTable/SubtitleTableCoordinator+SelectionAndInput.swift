import AppKit
import CueSeekerCore
import SwiftUI

extension SubtitleTableView.Coordinator {
    func cancelPendingTextInteraction() {
        stopTextDragAutoScroll()
        pendingTextInteraction = nil
        pendingRowSelectionTarget = nil
        updatePressedRowActionRow(nil)
    }

    var externalTextSelectionWindowRect: CGRect? {
        guard let container, container.window != nil else { return nil }
        return container.convert(container.bounds, to: nil)
    }

    var canBeginExternalTextSelection: Bool {
        isEnabled &&
            !isSelectionMode &&
            pendingTextInteraction == nil &&
            container != nil &&
            container?.window != nil &&
            documentView != nil &&
            headerView != nil &&
            !visibleTextColumnOrder().isEmpty
    }

    func beginExternalTextSelection(
        startWindowPoint: CGPoint,
        currentWindowPoint: CGPoint
    ) -> Bool {
        guard canBeginExternalTextSelection,
              externalTextSelectionWindowRect?.contains(currentWindowPoint) == true,
              let anchor = textPosition(
                  atWindowPoint: startWindowPoint,
                  requiresTextHit: false
              )
        else {
            return false
        }

        clearFocusedCheckbox()
        documentView?.window?.makeFirstResponder(documentView)
        var interaction = PendingTextInteraction(
            startPoint: startWindowPoint,
            anchor: anchor,
            directAction: .none,
            didDrag: true,
            latestWindowPoint: currentWindowPoint
        )
        beginPendingTextSelectionIfPossible(&interaction)
        guard interaction.selectionHasBegun else { return false }
        pendingTextInteraction = interaction
        updateTextSelectionFocus(atWindowPoint: currentWindowPoint)
        updateTextDragAutoScrollState(for: interaction)
        return true
    }

    func updateExternalTextSelection(windowPoint: CGPoint) -> Bool {
        handleMouseDragged(windowPoint: windowPoint)
    }

    func endExternalTextSelection(windowPoint: CGPoint) -> Bool {
        handleMouseUp(windowPoint: windowPoint)
    }

    func cancelExternalTextSelection() {
        cancelPendingTextInteraction()
    }

    func startTextDragAutoScrollIfNeeded() {
        guard textDragAutoScrollTimer == nil else { return }
        let timer = Timer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(textDragAutoScrollTick),
            userInfo: nil,
            repeats: true
        )
        textDragAutoScrollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func updateTextDragAutoScrollState(
        for interaction: PendingTextInteraction
    ) {
        guard let target = textDragAutoScrollTarget(for: interaction),
              target.nextOrigin != target.currentOrigin
        else {
            stopTextDragAutoScroll()
            return
        }
        startTextDragAutoScrollIfNeeded()
    }

    func stopTextDragAutoScroll() {
        textDragAutoScrollTimer?.invalidate()
        textDragAutoScrollTimer = nil
    }

    @objc func textDragAutoScrollTick() {
        guard let interaction = pendingTextInteraction,
              interaction.didDrag,
              interaction.selectionHasBegun,
              interaction.anchor != nil,
              let scrollView
        else {
            stopTextDragAutoScroll()
            return
        }
        if documentView?.window != nil, NSEvent.pressedMouseButtons & 1 == 0 {
            cancelPendingTextInteraction()
            return
        }
        guard let target = textDragAutoScrollTarget(for: interaction),
              target.nextOrigin != target.currentOrigin
        else {
            stopTextDragAutoScroll()
            return
        }
        let clipView = scrollView.contentView
        clipView.scroll(to: target.nextOrigin)
        scrollView.reflectScrolledClipView(clipView)
        refreshHeaderForHorizontalScrollIfNeeded()
        pageScrollbar?.metricsDidChange()
        notifyVisibleRowsChanged()
        updateTextSelectionFocus(atWindowPoint: interaction.latestWindowPoint)
    }

    func textDragAutoScrollTarget(
        for interaction: PendingTextInteraction
    ) -> (currentOrigin: CGPoint, nextOrigin: CGPoint)? {
        guard interaction.didDrag,
              interaction.selectionHasBegun,
              interaction.anchor != nil,
              let scrollView,
              let documentView
        else {
            return nil
        }
        let clipView = scrollView.contentView
        let viewport = clipView.convert(clipView.bounds, to: nil)
        let allowsVerticalScrolling: Bool
        if interaction.anchor?.row == .header,
           let headerView
        {
            let headerRect = headerView.convert(headerView.bounds, to: nil)
            allowsVerticalScrolling = interaction.latestWindowPoint.y < headerRect.minY
        } else {
            allowsVerticalScrolling = true
        }
        let currentOrigin = clipView.bounds.origin
        return (
            currentOrigin,
            SubtitleTableTextDragAutoScrollGeometry.nextOrigin(
                pointer: interaction.latestWindowPoint,
                viewport: viewport,
                currentOrigin: currentOrigin,
                contentSize: documentView.bounds.size,
                viewportSize: clipView.bounds.size,
                allowsVerticalScrolling: allowsVerticalScrolling
            )
        )
    }

    func updateTextSelectionFocus(atWindowPoint windowPoint: CGPoint) {
        guard let focus = textPosition(
            atWindowPoint: windowPoint,
            requiresTextHit: false
        ) else {
            return
        }
        let previousSelection = textSelection
        textSelection.updateFocus(to: focus)
        invalidateTextSelectionChange(from: previousSelection)
    }

    func clearTextSelection() {
        cancelPendingTextInteraction()
        let previousSelection = textSelection
        textSelection.clear()
        invalidateTextSelectionChange(from: previousSelection)
    }

    @objc func appLeftMouseDown(_ notification: Notification) {
        clearTextSelection()
    }

    /// A menu opening anywhere in the App takes every selection with it.
    @objc func appClearTextSelection(_ notification: Notification) {
        clearTextSelection()
    }
    @objc func systemColorsDidChange(_ notification: Notification) {
        guard isSelectionMode else { return }
        #if DEBUG
        didInvalidateForSystemColorsChangeForTesting = true
        #endif
        invalidateVisibleDocument()
    }

    @objc func appDidBecomeActive(_ notification: Notification) {
        reevaluateHoverFromCurrentPointer()
        headerView?.refreshHoverFromWindow()
        headerView?.refreshHeaderHosts()
    }

    @objc func appDidResignActive(_ notification: Notification) {
        clearHover()
        headerView?.clearHoverState()
        headerView?.refreshHeaderHosts()
    }

    @objc func windowDidBecomeKey(_ notification: Notification) {
        guard let window = documentView?.window,
              notification.object as? NSWindow === window
        else {
            return
        }
        reevaluateHoverFromCurrentPointer()
        headerView?.refreshHoverFromWindow()
        headerView?.refreshHeaderHosts()
    }

    @objc func windowDidResignKey(_ notification: Notification) {
        guard let window = documentView?.window,
              notification.object as? NSWindow === window
        else {
            return
        }
        clearHover()
        headerView?.clearHoverState()
        headerView?.refreshHeaderHosts()
    }

    @objc func windowFocusDidChange(_ notification: Notification) {
        guard let window = documentView?.window,
              notification.object as? NSWindow === window
        else {
            return
        }
        let isWindowFocused = (window as? CueSeekerWindow)?.isFocusedForHover
            ?? (NSApp.isActive && window.isKeyWindow)
        if isWindowFocused {
            reevaluateHoverFromCurrentPointer()
            headerView?.refreshHoverFromWindow()
        } else {
            clearHover()
            headerView?.clearHoverState()
        }
        headerView?.refreshHeaderHosts()
    }

    @objc func scrollDebounceDidSettle(_ notification: Notification) {
        guard !isCoveredByHigherLayer else {
            return
        }
        reevaluateHoverFromCurrentPointer()
        headerView?.refreshHoverFromWindow()
        headerView?.refreshHeaderHosts()
    }

    func reevaluateHoverFromCurrentPointer() {
        guard !isPointerFrozen,
              !AppCursorVisibility.isCursorHidden,
              !PointerHoverScrollState.shared.isScrolling,
              let window = documentView?.window
        else {
            return
        }
        let isWindowFocused = (window as? CueSeekerWindow)?.isFocusedForHover
            ?? (NSApp.isActive && window.isKeyWindow)
        if !isWindowFocused {
            clearHover()
            headerView?.clearHoverState()
            return
        }
        let screenPoint = NSEvent.mouseLocation
        let isPointerOverWindow = (window as? CueSeekerWindow)?.isWindowFocusedOverrideForTesting != nil
            || NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: 0) == window.windowNumber
        if isPointerOverWindow {
            handleMouseHover(windowPoint: window.mouseLocationOutsideOfEventStream)
        } else {
            clearHover()
            headerView?.clearHoverState()
        }
    }

    func selectAllTableText() {
        guard isEnabled, !isSelectionMode else { return }
        let previousSelection = textSelection
        textSelection.selectAll()
        invalidateTextSelectionChange(from: previousSelection)
    }

    func copyTableTextSelection(to pasteboard: NSPasteboard = .general) {
        guard isEnabled,
              !isSelectionMode,
              textSelection.hasSelection
        else {
            return
        }
        let request = SubtitleTableTextCopyRequest(
            selection: textSelection,
            columns: visibleTextColumnOrder().map {
                SubtitleTableTextCopyColumn(id: $0, title: headerTitle(for: $0))
            },
            rowCount: textSelection.selectsAllResults
                ? allResultsTextCopyRowCount
                : rowCount,
            showsCueGroup: showsCueGroup
        )
        guard !request.columns.isEmpty else { return }

        textCopyTask?.cancel()
        textCopyTask = nil
        let initialPasteboardChangeCount = pasteboard.changeCount
        if request.bodyRowRange.isEmpty {
            let builder = SubtitleTableTextCopyBuilder(request: request)
            guard pasteboard.changeCount == initialPasteboardChangeCount else { return }
            _ = SubtitleTableClipboard.copy(
                representations: builder.representations,
                to: pasteboard
            )
            return
        }

        let loader = request.selection.selectsAllResults
            ? loadRowsForTextCopy
            : nil
        let capturedRowProvider = rowProvider
        textCopyTask = Task { @MainActor in
            var builder = SubtitleTableTextCopyBuilder(request: request)
            let batchSize = 512
            var batchStart = request.bodyRowRange.lowerBound
            while batchStart < request.bodyRowRange.upperBound {
                guard !Task.isCancelled else { return }
                let batchEnd = min(batchStart + batchSize, request.bodyRowRange.upperBound)
                let batchRange = batchStart..<batchEnd
                let rows: [SubtitleTableRow]?
                if let loader {
                    rows = await loader(batchRange)
                } else {
                    let loadedRows = batchRange.compactMap(capturedRowProvider)
                    rows = loadedRows.count == batchRange.count ? loadedRows : nil
                }
                guard let rows,
                      rows.count == batchRange.count,
                      !Task.isCancelled
                else {
                    return
                }
                builder.append(rows: rows, startingAt: batchStart)
                batchStart = batchEnd
            }
            guard !Task.isCancelled,
                  pasteboard.changeCount == initialPasteboardChangeCount
            else {
                return
            }
            _ = SubtitleTableClipboard.copy(
                representations: builder.representations,
                to: pasteboard
            )
        }
    }

    func textSelectionProjection(
        _ selection: SubtitleTableTextSelectionState,
        for row: SubtitleTableTextRow
    ) -> TextSelectionRowProjection {
        guard selection.hasSelection else { return .none }
        if selection.selectsAllResults {
            return .full
        }
        guard let range = selection.orderedRange,
              range.start.row <= row,
              row <= range.end.row
        else {
            return .none
        }
        if range.start.row == row, range.end.row == row {
            return .bounded(range.start, range.end)
        }
        if range.start.row == row {
            return .from(range.start)
        }
        if range.end.row == row {
            return .through(range.end)
        }
        return .full
    }

    func invalidateTextSelectionChange(
        from previousSelection: SubtitleTableTextSelectionState
    ) {
        guard previousSelection != textSelection else { return }

        if textSelectionProjection(previousSelection, for: .header) !=
            textSelectionProjection(textSelection, for: .header)
        {
            textSelectionInvalidationCount += 1
            headerView?.invalidateHeaderTextSelection()
        }

        guard let documentView,
              let visibleRows = visibleRowRange()
        else {
            return
        }
        for row in visibleRows where
            textSelectionProjection(previousSelection, for: .body(row)) !=
            textSelectionProjection(textSelection, for: .body(row))
        {
            textSelectionInvalidationCount += 1
            documentView.setNeedsDisplay(
                rectForRow(row, width: documentView.bounds.width)
            )
        }
    }

    func headerTitle(for columnID: String) -> String {
        switch columnID {
        case "dateAdded":
            return dateAddedHeader
        case "display":
            return displayTitleHeader
        case "time":
            return timeHeader
        case "cues":
            return cuesHeader
        case "language":
            return languageHeader
        default:
            return ""
        }
    }

    func headerTextFragments() -> [HeaderTextFragmentLayout] {
        guard let headerView else { return [] }
        let columnIDs = visibleTextColumnOrder()
        let layout = headerColumnLayoutForRendering(
            viewportWidth: headerView.bounds.width,
            height: headerView.bounds.height
        )
        return columnIDs.enumerated().compactMap { columnIndex, columnID in
            guard let cellRect = layout.rect(for: columnID) else { return nil }
            let title = headerTitle(for: columnID)
            let attributed = SubtitleTableText.header(title)
            let size = attributed.size()
            let leading = WorkbenchControlMetrics.redesignPaddingHeaderTriggerX
            let width = max(1, cellRect.width - 2 * leading)
            textLayout.update(attributedString: attributed, width: width)
            let lineHeight = textLayout.usedHeight
            let origin = CGPoint(
                x: cellRect.minX + leading,
                y: cellRect.minY + max(0, (cellRect.height - lineHeight) / 2)
            )
            return HeaderTextFragmentLayout(
                columnID: columnID,
                columnIndex: columnIndex,
                cellRect: cellRect,
                fragment: SubtitleTableTextFragmentLayout(
                    attributed: attributed,
                    origin: origin,
                    width: width,
                    clipRect: CGRect(
                        x: origin.x,
                        y: origin.y,
                        width: max(0, min(size.width, cellRect.maxX - leading - origin.x)),
                        height: min(lineHeight, cellRect.height)
                    ),
                    logicalUTF16Range: NSRange(
                        location: 0,
                        length: (title as NSString).length
                    )
                )
            )
        }
    }

    func headerTextPosition(
        at point: CGPoint,
        requiresTextHit: Bool
    ) -> SubtitleTableTextPosition? {
        let fragments = headerTextFragments()
        let candidate: HeaderTextFragmentLayout?
        if requiresTextHit {
            candidate = fragments.first { item in
                guard item.fragment.clipRect.contains(point) else { return false }
                textLayout.update(
                    attributedString: item.fragment.attributed,
                    width: item.fragment.width
                )
                return textLayout.containsText(at: point, origin: item.fragment.origin)
            }
        } else {
            candidate = fragments.min { lhs, rhs in
                squaredDistance(from: point, to: textBounds(for: lhs.fragment)) <
                    squaredDistance(from: point, to: textBounds(for: rhs.fragment))
            }
        }
        guard let candidate else { return nil }
        textLayout.update(
            attributedString: candidate.fragment.attributed,
            width: candidate.fragment.width
        )
        return SubtitleTableTextPosition(
            row: .header,
            columnIndex: candidate.columnIndex,
            utf16Offset: textLayout.utf16Offset(
                at: point,
                origin: candidate.fragment.origin
            )
        )
    }

    func isHeaderTextHitForInteraction(at point: CGPoint) -> Bool {
        headerTextPosition(at: point, requiresTextHit: true) != nil
    }

    func drawHeaderTextSelectionBackground(in dirtyRect: CGRect) {
        guard textSelection.hasSelection else { return }
        for item in headerTextFragments() where item.fragment.clipRect.intersects(dirtyRect) {
            let title = item.fragment.attributed.string
            guard let selectedRange = textSelection.selectedUTF16Range(
                row: .header,
                columnIndex: item.columnIndex,
                utf16Length: (title as NSString).length
            ) else {
                continue
            }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(item.fragment.clipRect)
            textLayout.update(
                attributedString: item.fragment.attributed,
                width: item.fragment.width
            )
            drawSelectionBackground(
                selectedRange,
                with: textLayout,
                at: item.fragment.origin
            )
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    func text(for columnID: String, model: SubtitleTableRow) -> String {
        switch columnID {
        case "dateAdded":
            return model.dateAdded
        case "display":
            return model.displayTitle
        case "time":
            return model.timeRange
        case "cues":
            return model.cues
        case "language":
            return model.tags.map(\.label).joined(separator: ", ")
        default:
            return ""
        }
    }

    func displayedCueTexts(for model: SubtitleTableRow) -> [String] {
        [model.primaryCueText] + (showsCueGroup ? model.additionalCueTexts : [])
    }

    func selectableText(for columnID: String, model: SubtitleTableRow) -> String {
        if columnID == "cues" {
            return displayedCueTexts(for: model).joined(separator: "\n")
        }
        return text(for: columnID, model: model)
    }

    func selectedUTF16Range(
        row: Int,
        columnID: String,
        text: String
    ) -> NSRange? {
        guard textSelection.hasSelection else { return nil }
        guard let columnIndex = visibleTextColumnOrder().firstIndex(of: columnID) else {
            return nil
        }
        return textSelection.selectedUTF16Range(
            row: .body(row),
            columnIndex: columnIndex,
            utf16Length: (text as NSString).length
        )
    }

    /// The one answer to "may the table follow the pointer". A table that
    /// a higher layer covers, that has its own menu open, or whose layer
    /// the registry reports frozen — any menu open on it, wherever it
    /// hangs — keeps its picture: hover, cursor shapes, everything.
    /// Every pointer-following path asks this and nothing else.
    var isPointerFrozen: Bool {
        isCoveredByHigherLayer || isMenuOpen
            || interfaceLayerContext.isFrozen
    }

    /// The table's answer to the pointer, asked by `AppPointerShape` when
    /// the pointer really moved. Playable cue text takes the hand and
    /// selectable text the I-beam; a frozen table, Select Mode and
    /// everything else answer the arrow. Only the row under the pointer
    /// is laid out for the answer.
    func pointerShape(atWindowPoint windowPoint: CGPoint) -> PointerShape {
        guard !isPointerFrozen, let documentView else {
            return .arrow
        }
        let point = documentView.convert(windowPoint, from: nil)
        let visibleRect = currentTableBodyVisibleRect
        guard visibleRect.contains(point),
              let row = rowAtDocumentPoint(point)
        else {
            return .arrow
        }
        let rows = row..<(row + 1)
        if isPointInRowActionButton(row: row, point: point) {
            return .arrow
        }
        if interactiveCellRects(in: visibleRect, rows: rows)
            .contains(where: { $0.contains(point) }) {
            return .grab
        }
        if selectableTextRects(
            in: visibleRect,
            documentWidth: documentView.bounds.width,
            rows: rows
        ).contains(where: { $0.contains(point) }) {
            return .iBeam
        }
        return .arrow
    }

    /// Select Mode has no hand anywhere: a press on the row ticks its
    /// checkbox instead of playing, so no part of it is playable cue text.
    func interactiveCellRects(
        in visibleRect: CGRect,
        rows: Range<Int>? = nil
    ) -> [CGRect] {
        guard isEnabled,
              !isSelectionMode,
              !isMenuOpen,
              !isCoveredByHigherLayer,
              let range = rows ?? visibleRowRange(in: visibleRect)
        else {
            return []
        }

        return range.flatMap { row -> [CGRect] in
            guard let model = rowProvider(row),
                  !model.cueState.isUnavailable
            else {
                return []
            }
            let candidateRects = [
                cellContentHoverRectInDocument(row: row, columnID: "cues"),
            ].compactMap { $0 }
            return candidateRects.compactMap { candidateRect in
                let cursorRect = candidateRect.intersection(visibleRect)
                guard !cursorRect.isNull, cursorRect.width > 0, cursorRect.height > 0 else {
                    return nil
                }
                return cursorRect
            }
        }
    }

    func selectableTextRects(
        in visibleRect: CGRect,
        documentWidth: CGFloat,
        rows: Range<Int>? = nil
    ) -> [CGRect] {
        guard isEnabled,
              !isSelectionMode,
              !isMenuOpen,
              !isCoveredByHigherLayer,
              let range = rows ?? visibleRowRange(in: visibleRect)
        else {
            return []
        }

        let selectableColumnIDs = visibleTextColumnOrder().filter {
            $0 != "cues"
        }
        return range.flatMap { row -> [CGRect] in
            guard rowProvider(row) != nil else { return [] }
            let rowRect = rectForRow(row, width: documentWidth)
            return selectableColumnIDs.flatMap { columnID in
                textFragments(row: row, columnID: columnID, rowRect: rowRect).flatMap { fragment in
                    textLayout.update(attributedString: fragment.attributed, width: fragment.width)
                    return textLayout.usedRects(at: fragment.origin).compactMap { rect in
                        let clipped = rect.intersection(fragment.clipRect).intersection(visibleRect)
                        return clipped.isNull || clipped.width <= 0 || clipped.height <= 0
                            ? nil
                            : clipped
                    }
                }
            }
        }
    }

    func rowAtDocumentPoint(_ point: CGPoint) -> Int? {
        guard rowCount > 0 else { return nil }
        guard point.y >= rowsOriginY else { return nil }
        let row = rowHeightCache.rowIndex(atY: point.y - rowsOriginY)
        let rect = rectForRow(row, width: documentView?.bounds.width ?? 0)
        return rect.contains(point) ? row : nil
    }

    func rowActionButtonFrameInDocument(for row: Int) -> CGRect? {
        guard !isSelectionMode,
              row >= 0,
              row < rowCount,
              rowProvider(row) != nil,
              let documentView
        else {
            return nil
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        return rowActionButtonFrameInDocument(forRowRect: rowRect)
    }

    func rowActionButtonFrameInDocument(forRowRect rowRect: CGRect) -> CGRect? {
        guard !isSelectionMode else {
            return nil
        }
        let layout = tableColumnLayout(contentWidth: rowRect.width, height: rowRect.height)
        let cuesRect = rowColumnRect(layout.cuesRect, rowRect: rowRect)
        let size = SubtitleTableMetrics.rowActionButtonSize
        return CGRect(
            x: cuesRect.maxX - SubtitleTableMetrics.trailingInset - size,
            y: rowRect.minY + (rowRect.height - size) / 2,
            width: size,
            height: size
        )
    }

    func rowActionButtonFrameInContainer(for row: Int) -> CGRect? {
        guard let container,
              let scrollView,
              let documentView,
              let documentFrame = rowActionButtonFrameInDocument(for: row)
        else {
            return nil
        }
        let frame = container.convert(documentFrame, from: documentView)
        guard frame.intersects(scrollView.frame) else {
            return nil
        }
        return frame
    }

    func bodyTextOrigin(in rect: CGRect) -> CGPoint {
        let M = SubtitleTableMetrics.self
        let yOffset = rect.minY + max(0, (rect.height - textLayout.usedHeight) / 2)
        return CGPoint(x: rect.minX + M.cellLeading, y: yOffset)
    }

    func isPointInRowActionButton(row: Int, point: CGPoint) -> Bool {
        guard isEnabled,
              !isSelectionMode,
              !isCoveredByHigherLayer,
              let buttonRect = rowActionButtonFrameInDocument(for: row)
        else {
            return false
        }
        return buttonRect.contains(point)
    }

    func cellContentHoverRectInDocument(row: Int, columnID: String) -> CGRect? {
        guard let documentView,
              let model = rowProvider(row),
              row >= 0,
              row < rowCount
        else {
            return nil
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        guard let cellRect = dataCellRect(columnID: columnID, rowRect: rowRect) else {
            return nil
        }
        let measurement = cachedMeasurement(for: row, documentWidth: documentView.bounds.width)
            ?? SubtitleTableRowMeasurement(
                height: rowRect.height,
                primaryLineCount: 1,
                extraCueLineCounts: []
            )
        if columnID == "cues" {
            return cuesContentHoverRect(
                model: model,
                in: cellRect,
                measurement: measurement
            )
        }
        if columnID == "language" {
            return tagContentHoverRect(
                tags: model.tags,
                in: cellRect,
                trailing: SubtitleTableMetrics.trailingInset
            )
        }
        return bodyContentHoverRect(
            text: text(for: columnID, model: model),
            in: cellRect,
            trailing: bodyTextTrailingInset(for: columnID, rowRect: rowRect),
            role: bodyTextRole(for: columnID)
        )
    }

    func cellContentHoverFrameInContainer(for row: Int, columnID: String) -> CGRect? {
        guard let container,
              let scrollView,
              let documentView,
              let documentFrame = cellContentHoverRectInDocument(row: row, columnID: columnID)
        else {
            return nil
        }
        let frame = container.convert(documentFrame, from: documentView)
        guard frame.intersects(scrollView.frame) else {
            return nil
        }
        return frame
    }

    func rowMenuTriggerFrameInContainer(row: Int, columnID: String, fallback: CGRect) -> CGRect {
        cellContentHoverFrameInContainer(for: row, columnID: columnID) ??
            fallback
    }

    func dataCellRect(columnID: String, rowRect: CGRect) -> CGRect? {
        let layout = tableColumnLayout(contentWidth: rowRect.width, height: rowRect.height)
        switch columnID {
        case "dateAdded":
            return layout.dateAddedRect.map { rowColumnRect($0, rowRect: rowRect) }
        case "display":
            guard showsDisplayTitleColumn else { return nil }
            return rowColumnRect(layout.nameRect, rowRect: rowRect)
        case "time":
            return layout.timeRect.map { rowColumnRect($0, rowRect: rowRect) }
        case "cues":
            return rowColumnRect(layout.cuesRect, rowRect: rowRect)
        case "language":
            return layout.languageRect.map { rowColumnRect($0, rowRect: rowRect) }
        default:
            return nil
        }
    }

    func textFragments(
        row: Int,
        columnID: String,
        rowRect: CGRect
    ) -> [SubtitleTableTextFragmentLayout] {
        guard let model = rowProvider(row),
              let cellRect = dataCellRect(columnID: columnID, rowRect: rowRect)
        else {
            return []
        }

        if columnID == "cues" {
            let measurement = cachedMeasurement(for: row, documentWidth: rowRect.width)
                ?? SubtitleTableRowMeasurement(
                    height: rowRect.height,
                    primaryLineCount: 1,
                    extraCueLineCounts: []
                )
            return cueTextFragments(model: model, in: cellRect, measurement: measurement)
        }

        if columnID == "language" {
            let tagStyle = SubtitleTableTagStyle.resolve()
            let laidOutTags = layoutTags(
                model.tags,
                in: cellRect,
                trailing: SubtitleTableMetrics.trailingInset,
                tagStyle: tagStyle
            )
            return tagTextFragments(laidOutTags, tagStyle: tagStyle)
        }

        let cellText = selectableText(for: columnID, model: model)
        guard !cellText.isEmpty else { return [] }
        let attributed = SubtitleTableText.body(
            cellText,
            role: bodyTextRole(for: columnID)
        )
        let width = max(
            0,
            cellRect.width
                - SubtitleTableMetrics.cellLeading
                - bodyTextTrailingInset(for: columnID, rowRect: rowRect)
        )
        textLayout.update(attributedString: attributed, width: width)
        return [SubtitleTableTextFragmentLayout(
            attributed: attributed,
            origin: bodyTextOrigin(in: cellRect),
            width: width,
            clipRect: cellRect,
            logicalUTF16Range: NSRange(
                location: 0,
                length: (cellText as NSString).length
            )
        )]
    }

    func textPosition(
        row: Int,
        columnID: String,
        point: CGPoint,
        requiresTextHit: Bool
    ) -> SubtitleTableTextPosition? {
        guard let documentView,
              let columnIndex = visibleTextColumnOrder().firstIndex(of: columnID),
              let model = rowProvider(row)
        else {
            return nil
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        let fragments = textFragments(row: row, columnID: columnID, rowRect: rowRect)
        if fragments.isEmpty {
            guard !requiresTextHit,
                  selectableText(for: columnID, model: model).isEmpty
            else {
                return nil
            }
            return SubtitleTableTextPosition(
                row: .body(row),
                columnIndex: columnIndex,
                utf16Offset: 0
            )
        }

        let candidate: SubtitleTableTextFragmentLayout?
        if requiresTextHit {
            candidate = fragments.first { fragment in
                guard fragment.clipRect.contains(point) else { return false }
                textLayout.update(attributedString: fragment.attributed, width: fragment.width)
                return textLayout.containsText(at: point, origin: fragment.origin)
            }
        } else {
            candidate = fragments.min { lhs, rhs in
                squaredDistance(from: point, to: textBounds(for: lhs))
                    < squaredDistance(from: point, to: textBounds(for: rhs))
            }
        }
        guard let candidate else { return nil }
        textLayout.update(attributedString: candidate.attributed, width: candidate.width)
        let localOffset = textLayout.utf16Offset(at: point, origin: candidate.origin)
        return SubtitleTableTextPosition(
            row: .body(row),
            columnIndex: columnIndex,
            utf16Offset: candidate.logicalUTF16Range.location + localOffset
        )
    }

    func textPosition(
        atDocumentPoint point: CGPoint,
        requiresTextHit: Bool
    ) -> SubtitleTableTextPosition? {
        guard let documentView else {
            return nil
        }
        let row: Int
        if requiresTextHit {
            guard let exactRow = rowAtDocumentPoint(point) else { return nil }
            row = exactRow
        } else {
            guard rowCount > 0 else {
                return projectedHeaderTextPosition(forDocumentPoint: point)
            }
            row = rowHeightCache.rowIndex(
                atY: max(0, point.y - rowsOriginY)
            )
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        let columnIDs = visibleTextColumnOrder()
        let columnID: String?
        if requiresTextHit {
            columnID = columnIDs.first(where: {
                dataCellRect(columnID: $0, rowRect: rowRect)?.contains(point) == true
            })
        } else {
            columnID = columnIDs.min { lhs, rhs in
                let lhsRect = dataCellRect(columnID: lhs, rowRect: rowRect) ?? .zero
                let rhsRect = dataCellRect(columnID: rhs, rowRect: rowRect) ?? .zero
                return squaredDistance(from: point, to: lhsRect) <
                    squaredDistance(from: point, to: rhsRect)
            }
        }
        guard let columnID else {
            return nil
        }
        return textPosition(
            row: row,
            columnID: columnID,
            point: point,
            requiresTextHit: requiresTextHit
        )
    }

    func projectedHeaderTextPosition(
        forDocumentPoint point: CGPoint
    ) -> SubtitleTableTextPosition? {
        guard let documentView, let headerView else { return nil }
        let windowPoint = documentView.convert(point, to: nil)
        var headerPoint = headerView.convert(windowPoint, from: nil)
        headerPoint.x = min(
            max(headerView.bounds.minX, headerPoint.x),
            headerView.bounds.maxX.nextDown
        )
        headerPoint.y = headerView.bounds.midY
        return headerTextPosition(at: headerPoint, requiresTextHit: false)
    }

    func textPosition(
        atWindowPoint windowPoint: CGPoint,
        requiresTextHit: Bool
    ) -> SubtitleTableTextPosition? {
        if let headerView {
            let headerWindowRect = headerView.convert(headerView.bounds, to: nil)
            let projectsToHeader = headerWindowRect.contains(windowPoint) ||
                (!requiresTextHit && windowPointProjectsToHeader(
                    windowPoint,
                    headerWindowRect: headerWindowRect
                ))
            if projectsToHeader {
                var point = headerView.convert(windowPoint, from: nil)
                if !requiresTextHit {
                    point.x = min(max(headerView.bounds.minX, point.x), headerView.bounds.maxX)
                    point.y = min(max(headerView.bounds.minY, point.y), headerView.bounds.maxY)
                }
                return headerTextPosition(at: point, requiresTextHit: requiresTextHit)
            }
        }

        guard let documentView else { return nil }
        var point = documentView.convert(windowPoint, from: nil)
        if !requiresTextHit {
            let visibleRect = currentTableBodyVisibleRect
            guard !visibleRect.isEmpty else { return nil }
            point.x = min(max(visibleRect.minX, point.x), visibleRect.maxX.nextDown)
            point.y = min(max(visibleRect.minY, point.y), visibleRect.maxY.nextDown)
        }
        return textPosition(
            atDocumentPoint: point,
            requiresTextHit: requiresTextHit
        )
    }

    func windowPointProjectsToHeader(
        _ windowPoint: CGPoint,
        headerWindowRect: CGRect
    ) -> Bool {
        if windowPoint.y >= headerWindowRect.minY,
           windowPoint.y <= headerWindowRect.maxY {
            return true
        }

        guard let scrollView else { return false }
        let bodyWindowRect = scrollView.convert(scrollView.bounds, to: nil)
        if bodyWindowRect.midY < headerWindowRect.midY {
            return windowPoint.y > headerWindowRect.maxY
        }
        if bodyWindowRect.midY > headerWindowRect.midY {
            return windowPoint.y < headerWindowRect.minY
        }
        return false
    }

    func textBounds(for fragment: SubtitleTableTextFragmentLayout) -> CGRect {
        textLayout.update(attributedString: fragment.attributed, width: fragment.width)
        return (textLayout.unionUsedRect(at: fragment.origin) ?? CGRect(origin: fragment.origin, size: .zero))
            .intersection(fragment.clipRect)
    }

    func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    func actionMenuColumnID(row: Int, point: CGPoint) -> String? {
        guard row >= 0,
              row < rowCount,
              rowProvider(row) != nil,
              let documentView
        else {
            return nil
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        return visibleTextColumnOrder().first { columnID in
            dataCellRect(columnID: columnID, rowRect: rowRect)?.contains(point) == true
        }
    }

    func hoveredDataColumnID(row: Int, point: CGPoint) -> String? {
        guard !isSelectionMode,
              row >= 0,
              row < rowCount,
              rowProvider(row) != nil
        else {
            return nil
        }
        if rowProvider(row)?.cueState.isUnavailable != true,
           let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "cues"),
           hoverRect.contains(point) {
            return "cues"
        }
        return nil
    }

    func isPointInCheckbox(row: Int, point: CGPoint) -> Bool {
        guard isEnabled,
              !isCoveredByHigherLayer,
              row >= 0,
              row < rowCount,
              let model = rowProvider(row),
              !model.cueState.isUnavailable,
              let documentView
        else {
            return false
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        return checkboxRect(forRowRect: rowRect).contains(point)
    }

    func isPointInCueText(row: Int, point: CGPoint) -> Bool {
        guard !isSelectionMode,
              row >= 0,
              row < rowCount,
              let model = rowProvider(row),
              !model.primaryCueText.isEmpty,
              let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "cues")
        else {
            return false
        }
        return hoverRect.contains(point)
    }

    func isPointInCueStateIndicator(
        row: Int,
        point: CGPoint
    ) -> Bool {
        guard let rect = cueStateIndicatorRectInDocument(row: row) else {
            return false
        }
        return rect.insetBy(dx: -3, dy: -3).contains(point)
    }

    func handleMouseHover(windowPoint: CGPoint) {
        // A frozen table keeps its picture: the row a menu hangs off, or
        // the one lit when the freeze began, keeps its highlight, and no
        // other row takes one, wherever the pointer goes.
        if isPointerFrozen {
            return
        }
        // The Selection Action Overlay floats over the table. Inside it the
        // table keeps the row it had when the pointer moved in, and takes a
        // new one only after the pointer moves back onto the table.
        if isSelectionMode,
           let overlayFrame = selectionOverlayAnchor?.windowFrame,
           overlayFrame.contains(windowPoint) {
            return
        }
        guard let documentView else { return }
        let point = documentView.convert(windowPoint, from: nil)
        guard currentTableBodyVisibleRect.contains(point) else {
            clearHover()
            return
        }
        let row = rowAtDocumentPoint(point)
        updateHoveredRow(row)
        if isSelectionMode {
            updateHoveredCueStateRow(nil)
            updateHoveredColumnID(nil)
            updateHoveredRowActionRow(nil)
            updateHoveredCueTextRow(nil)
            return
        }
        let rowActionRow = row.flatMap {
            isPointInRowActionButton(row: $0, point: point) ? $0 : nil
        }
        let cueStateRow = rowActionRow == nil
            ? row.flatMap { isPointInCueStateIndicator(row: $0, point: point) ? $0 : nil }
            : nil
        updateHoveredCueStateRow(cueStateRow)
        let hoveredColumn = rowActionRow == nil
            ? row.flatMap { hoveredDataColumnID(row: $0, point: point) }
            : nil
        updateHoveredColumnID(hoveredColumn)
        let cueTextRow = rowActionRow == nil
            ? row.flatMap {
                hoveredColumn == "cues"
                    && rowProvider($0)?.cueState.isUnavailable != true
                    && isPointInCueText(row: $0, point: point)
                    ? $0
                    : nil
            }
            : nil
        updateHoveredRowActionRow(rowActionRow)
        updateHoveredCueTextRow(cueTextRow)
    }

    func handleMouseDown(windowPoint: CGPoint, isShiftPressed: Bool = false) -> Bool {
        guard isEnabled,
              !isMenuOpen,
              !isCoveredByHigherLayer,
              let documentView
        else {
            return false
        }
        let point = documentView.convert(windowPoint, from: nil)
        guard currentTableBodyVisibleRect.contains(point) else {
            return false
        }
        let row = rowAtDocumentPoint(point)
        if isSelectionMode {
            guard let row else { return false }
            clearFocusedCheckbox()
            cancelPendingTextInteraction()
            if rowProvider(row)?.cueState.isUnavailable == true {
                return true
            }
            pendingRowSelectionTarget = .selectionModeRow(
                row: row,
                isShiftPressed: isShiftPressed
            )
            return true
        }
        if let row, isPointInRowActionButton(row: row, point: point) {
            clearFocusedCheckbox()
            cancelPendingTextInteraction()
            pendingRowSelectionTarget = .rowActionButton(row: row)
            updatePressedRowActionRow(row)
            return true
        }
        if let row, isPointInCheckbox(row: row, point: point) {
            clearFocusedCheckbox()
            cancelPendingTextInteraction()
            guard row >= 0,
                  row < rowCount,
                  rowProvider(row)?.cueState.isUnavailable != true
            else {
                return false
            }
            pendingRowSelectionTarget = .rowCheckbox(row: row)
            return true
        }
        if let row, isPointInCueStateIndicator(row: row, point: point) {
            clearFocusedCheckbox()
            cancelPendingTextInteraction()
            return true
        }

        let directAction: PendingDirectTextAction
        if let row,
           rowProvider(row)?.cueState.isUnavailable != true,
           isPointInCueText(row: row, point: point)
        {
            directAction = .play(row: row)
        } else {
            directAction = .none
        }
        let exactAnchor = textPosition(atDocumentPoint: point, requiresTextHit: true)
        let anchor = exactAnchor ?? (
            isNoDirectTextAction(directAction)
                ? textPosition(atDocumentPoint: point, requiresTextHit: false)
                : nil
        )
        guard anchor != nil || !isNoDirectTextAction(directAction) else {
            return false
        }

        clearFocusedCheckbox()
        pendingRowSelectionTarget = nil
        pendingTextInteraction = PendingTextInteraction(
            startPoint: windowPoint,
            anchor: anchor,
            directAction: directAction,
            latestWindowPoint: windowPoint
        )
        return true
    }

    func handleHeaderMouseDown(windowPoint: CGPoint) -> Bool {
        guard isEnabled,
              !isSelectionMode,
              !isMenuOpen,
              !isCoveredByHigherLayer,
              let headerView
        else {
            return false
        }
        let point = headerView.convert(windowPoint, from: nil)
        guard headerView.bounds.contains(point),
              let anchor = headerTextPosition(at: point, requiresTextHit: false)
        else {
            return false
        }

        clearFocusedCheckbox()
        pendingRowSelectionTarget = nil
        pendingTextInteraction = PendingTextInteraction(
            startPoint: windowPoint,
            anchor: anchor,
            directAction: .none,
            latestWindowPoint: windowPoint
        )
        return true
    }

    func handleMouseDragged(windowPoint: CGPoint) -> Bool {
        if case .rowActionButton(let row) = pendingRowSelectionTarget {
            guard let documentView else { return false }
            let point = documentView.convert(windowPoint, from: nil)
            let isInside = currentTableBodyVisibleRect.contains(point)
                && isPointInRowActionButton(row: row, point: point)
            updatePressedRowActionRow(isInside ? row : nil)
            updateHoveredRowActionRow(isInside ? row : nil)
            return true
        }
        guard var interaction = pendingTextInteraction else {
            return false
        }
        interaction.latestWindowPoint = windowPoint
        let distance = hypot(
            windowPoint.x - interaction.startPoint.x,
            windowPoint.y - interaction.startPoint.y
        )
        if distance >= Self.textDragThreshold {
            interaction.didDrag = true
        }
        if interaction.didDrag {
            beginPendingTextSelectionIfPossible(&interaction)
        }
        pendingTextInteraction = interaction
        if interaction.selectionHasBegun {
            updateTextSelectionFocus(atWindowPoint: windowPoint)
            updateTextDragAutoScrollState(for: interaction)
        }
        return true
    }

    func handleMouseUp(windowPoint: CGPoint) -> Bool {
        if let selectionTarget = pendingRowSelectionTarget {
            pendingRowSelectionTarget = nil
            updatePressedRowActionRow(nil)
            guard isEnabled,
                  !isMenuOpen,
                  !isCoveredByHigherLayer,
                  let documentView
            else {
                return false
            }
            let point = documentView.convert(windowPoint, from: nil)
            guard currentTableBodyVisibleRect.contains(point) else {
                return true
            }
            switch selectionTarget {
            case .rowCheckbox(let row):
                if !isSelectionMode, isPointInCheckbox(row: row, point: point) {
                    _ = toggleRowCheckboxFromMouse(row: row)
                }
            case .rowActionButton(let row):
                if !isSelectionMode,
                   isPointInRowActionButton(row: row, point: point),
                   let buttonFrame = rowActionButtonFrameInContainer(for: row)
                {
                    showMenu(
                        for: row,
                        columnID: "cues",
                        buttonFrame: buttonFrame,
                        clickPointInDocument: nil,
                        usesActionButtonAnchor: true
                    )
                }
            case .selectionModeRow(let row, let isShiftPressed):
                if isSelectionMode, rowAtDocumentPoint(point) == row {
                    if isShiftPressed {
                        _ = shiftSelectRowFromMouse(row: row)
                    } else {
                        _ = toggleRowCheckboxFromMouse(row: row)
                    }
                }
            }
            return true
        }

        guard var interaction = pendingTextInteraction else {
            return false
        }
        stopTextDragAutoScroll()
        pendingTextInteraction = nil
        if hypot(
            windowPoint.x - interaction.startPoint.x,
            windowPoint.y - interaction.startPoint.y
        ) >= Self.textDragThreshold {
            interaction.didDrag = true
        }
        if interaction.didDrag {
            beginPendingTextSelectionIfPossible(&interaction)
        }
        if interaction.selectionHasBegun {
            updateTextSelectionFocus(atWindowPoint: windowPoint)
        }
        guard !interaction.didDrag else { return true }

        switch interaction.directAction {
        case .none:
            break
        case .play(let row):
            playRow(row)
        }
        return true
    }

    func beginPendingTextSelectionIfPossible(
        _ interaction: inout PendingTextInteraction
    ) {
        guard !interaction.selectionHasBegun,
              let anchor = interaction.anchor
        else {
            return
        }
        let previousSelection = textSelection
        textSelection.begin(at: anchor)
        interaction.selectionHasBegun = true
        invalidateTextSelectionChange(from: previousSelection)
    }

    func isNoDirectTextAction(_ action: PendingDirectTextAction) -> Bool {
        if case .none = action {
            return true
        }
        return false
    }

    func handleRightMouseDown(windowPoint: CGPoint) -> Bool {
        // An open menu is not a reason to refuse: the press that closed it
        // is the same press that opens this row's menu.
        guard isEnabled,
              !isCoveredByHigherLayer,
              let documentView,
              let container
        else {
            return false
        }
        if isMenuOpen, isWindowPointInsideOpenMenu(windowPoint) {
            return true
        }
        let point = documentView.convert(windowPoint, from: nil)
        if isSelectionMode {
            cancelPendingTextInteraction()
            return currentTableBodyVisibleRect.contains(point)
                && rowAtDocumentPoint(point) != nil
        }
        guard currentTableBodyVisibleRect.contains(point),
              let row = rowAtDocumentPoint(point),
              let columnID = actionMenuColumnID(row: row, point: point)
        else {
            return false
        }
        let fallbackFrame = CGRect(
            origin: container.convert(point, from: documentView),
            size: .zero
        )
        showMenu(
            for: row,
            columnID: columnID,
            buttonFrame: fallbackFrame,
            clickPointInDocument: point
        )
        return true
    }

    func toggleRowCheckboxFromMouse(row: Int) -> Bool {
        guard isEnabled,
              !isMenuOpen,
              !isCoveredByHigherLayer,
              row >= 0,
              row < rowCount,
              rowProvider(row)?.cueState.isUnavailable != true
        else {
            return false
        }
        clearFocusedCheckbox()
        onToggleRowSelection(row)
        invalidateRows([row])
        headerView?.refreshHeaderHosts()
        return true
    }

    /// A Shift range covers rows the click never touched, so the whole
    /// visible document is redrawn instead of the clicked row.
    func shiftSelectRowFromMouse(row: Int) -> Bool {
        guard isEnabled,
              isSelectionMode,
              !isMenuOpen,
              !isCoveredByHigherLayer,
              row >= 0,
              row < rowCount,
              rowProvider(row)?.cueState.isUnavailable != true
        else {
            return false
        }
        clearFocusedCheckbox()
        onShiftRowSelection(row)
        headerView?.refreshHeaderHosts()
        invalidateVisibleDocument()
        return true
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isEnabled,
              isSelectionMode,
              !isMenuOpen,
              !isCoveredByHigherLayer
        else {
            return false
        }

        switch event.keyCode {
        case 48:
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
                return false
            }
            if moveFocusedCheckboxByTab(isShiftPressed: event.modifierFlags.contains(.shift)) {
                return true
            }
            exitFocusedCheckboxByTab(isShiftPressed: event.modifierFlags.contains(.shift))
            return true
        case 49:
            guard let focusedCheckboxRow,
                  focusedCheckboxRow >= 0,
                  focusedCheckboxRow < rowCount
            else {
                return false
            }
            onToggleRowSelection(focusedCheckboxRow)
            invalidateRows([focusedCheckboxRow])
            headerView?.refreshHeaderHosts()
            return true
        case 125:
            guard focusedCheckboxRow != nil else { return false }
            moveFocusedCheckbox(by: 1)
            return true
        case 126:
            guard focusedCheckboxRow != nil else { return false }
            moveFocusedCheckbox(by: -1)
            return true
        default:
            return false
        }
    }

    func clearFocusedCheckbox() {
        updateFocusedCheckbox(nil)
    }

    func moveFocusedCheckbox(by delta: Int) {
        guard rowCount > 0 else {
            updateFocusedCheckbox(nil)
            return
        }
        let current = focusedCheckboxRow ?? hoveredRow ?? visibleRowRange()?.lowerBound ?? 0
        let next = min(max(0, current + delta), rowCount - 1)
        updateFocusedCheckbox(next)
        scrollFocusedCheckboxIntoVisible()
    }

    func moveFocusedCheckboxByTab(isShiftPressed: Bool) -> Bool {
        guard let focusedCheckboxRow, rowCount > 0 else {
            return false
        }
        let next = focusedCheckboxRow + (isShiftPressed ? -1 : 1)
        guard next >= 0, next < rowCount else {
            return false
        }
        updateFocusedCheckbox(next)
        scrollFocusedCheckboxIntoVisible()
        return true
    }

    func exitFocusedCheckboxByTab(isShiftPressed: Bool) {
        clearFocusedCheckbox()
        if isShiftPressed {
            documentView?.window?.selectPreviousKeyView(documentView)
        } else {
            documentView?.window?.selectNextKeyView(documentView)
        }
    }

    func updateFocusedCheckbox(_ row: Int?) {
        let nextRow = row.flatMap { $0 >= 0 && $0 < rowCount ? $0 : nil }
        guard nextRow != focusedCheckboxRow else { return }
        let oldRow = focusedCheckboxRow
        focusedCheckboxRow = nextRow
        invalidateRows([oldRow, nextRow])
    }

    func scrollFocusedCheckboxIntoVisible() {
        guard let focusedCheckboxRow, let documentView else { return }
        documentView.scrollToVisible(rectForRow(focusedCheckboxRow, width: documentView.bounds.width))
        notifyVisibleRowsChanged()
    }

    @discardableResult
    func focusFirstVisibleCheckboxFromKeyboard() -> Bool {
        guard isEnabled,
              rowCount > 0,
              !isMenuOpen,
              !isCoveredByHigherLayer,
              let documentView
        else {
            return false
        }
        guard let row = firstFocusableCheckboxRow(visibleRows: visibleRowRange()) else {
            return false
        }
        documentView.window?.makeFirstResponder(documentView)
        updateFocusedCheckbox(row)
        scrollFocusedCheckboxIntoVisible()
        return true
    }

    func firstFocusableCheckboxRow(visibleRows: Range<Int>?) -> Int? {
        guard rowCount > 0 else { return nil }
        guard let visibleRows, visibleRows.lowerBound < visibleRows.upperBound else {
            return 0
        }
        return min(max(0, visibleRows.lowerBound), rowCount - 1)
    }

    func installKeyboardFocusEventMonitor() {
        guard keyboardFocusEventMonitor == nil else { return }
        keyboardFocusEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyboardFocusEvent(event)
        }
    }

    func handleKeyboardFocusEvent(_ event: NSEvent) -> NSEvent? {
        guard workbenchAccessibility == nil,
              event.keyCode == 48,
              let container,
              event.window === container.window,
              isEnabled,
              !isMenuOpen,
              !isCoveredByHigherLayer,
              event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
              let firstResponder = event.window?.firstResponder,
              headerView?.isLastInteractiveHeaderResponder(firstResponder) == true
        else {
            return event
        }
        return focusFirstVisibleCheckboxFromKeyboard() ? nil : event
    }

    /// An exit AppKit reported. Only a pointer that really left the
    /// table body drops the hover; one that is still over it was not
    /// moved, the table was, and the hover stays on its row.
    func clearHoverUnlessPointerInside(windowPoint: CGPoint) {
        if let documentView,
           currentTableBodyVisibleRect.contains(
               documentView.convert(windowPoint, from: nil)
           ) {
            return
        }
        clearHover()
    }

    func clearHover() {
        // The pointer leaving the table for a surface above it is not a
        // reason to drop the highlight underneath: a frozen table keeps
        // its picture until it owns input again.
        if isPointerFrozen {
            return
        }
        updateHoveredColumnID(nil)
        updateHoveredRow(nil)
        updateHoveredCueTextRow(nil)
        updateHoveredCueStateRow(nil)
        updateHoveredRowActionRow(nil)
    }

    func updateHoveredRow(_ newRow: Int?) {
        if isCoveredByHigherLayer {
            return
        }
        guard newRow != hoveredRow else { return }
        let oldRow = hoveredRow
        hoveredRow = newRow
        invalidateRows([oldRow, newRow])
    }

    func updateHoveredColumnID(_ newColumnID: String?) {
        guard newColumnID != hoveredColumnID else { return }
        let row = hoveredRow
        hoveredColumnID = newColumnID
        invalidateRows([row])
    }

    func updateHoveredCueTextRow(_ newRow: Int?) {
        guard newRow != hoveredCueTextRow else { return }
        let oldRow = hoveredCueTextRow
        hoveredCueTextRow = newRow
        invalidateRows([oldRow, newRow])
    }

    func updateHoveredCueStateRow(_ newRow: Int?) {
        guard newRow != hoveredCueStateRow else {
            if let newRow {
                showCueStateTip(for: newRow, isSameRow: true)
            }
            return
        }
        let oldRow = hoveredCueStateRow
        hoveredCueStateRow = newRow
        invalidateRows([oldRow, newRow])
        if let newRow {
            cueStateTooltipTargetID = UUID()
            showCueStateTip(for: newRow, isSameRow: false)
        } else {
            hideCueStateTip()
        }
    }

    func showCueStateTip(for row: Int, isSameRow: Bool) {
        guard let documentView,
              let window = documentView.window,
              let contentView = window.contentView,
              let model = rowProvider(row),
              model.cueState != .normal,
              let documentRect = cueStateIndicatorRectInDocument(row: row)
        else {
            hideCueStateTip()
            return
        }
        let scenarioID: String
        switch model.cueState {
        case .contentChanged:
            scenarioID = "table.cue_state.content_changed"
        case .unavailable:
            scenarioID = "table.cue_state.unavailable"
        case .normal:
            hideCueStateTip()
            return
        }

        let windowRect = documentView.convert(documentRect, to: nil)
        let windowHeight = contentView.bounds.height
        let anchor = CGRect(
            x: windowRect.minX,
            y: windowHeight - windowRect.maxY,
            width: windowRect.width,
            height: windowRect.height
        )
        let content = TooltipContent.cueState(model.cueState)
        if isSameRow {
            TooltipCenter.shared.updateAnchor(
                targetID: cueStateTooltipTargetID,
                anchorRect: anchor,
                content: content
            )
        } else {
            TooltipCenter.shared.hoverBegan(
                targetID: cueStateTooltipTargetID,
                surface: .main,
                scenarioID: scenarioID,
                anchorRect: anchor,
                content: content
            )
        }
    }

    func hideCueStateTip() {
        TooltipCenter.shared.hoverEnded(targetID: cueStateTooltipTargetID)
    }

    func updateHoveredRowActionRow(_ newRow: Int?) {
        guard newRow != hoveredRowActionRow else { return }
        let oldRow = hoveredRowActionRow
        hoveredRowActionRow = newRow
        invalidateRows([oldRow, newRow])
    }

    func updatePressedRowActionRow(_ newRow: Int?) {
        guard newRow != pressedRowActionRow else { return }
        let oldRow = pressedRowActionRow
        pressedRowActionRow = newRow
        invalidateRows([oldRow, newRow])
    }
}
