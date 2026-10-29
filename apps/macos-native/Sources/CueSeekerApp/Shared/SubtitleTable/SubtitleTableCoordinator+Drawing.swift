import AppKit
import CueSeekerCore
import SwiftUI

extension SubtitleTableView.Coordinator {
    func dateAddedHeaderForRendering() -> String {
        dateAddedHeader
    }

    func displayTitleHeaderForRendering() -> String {
        displayTitleHeader
    }

    func timeHeaderForRendering() -> String {
        timeHeader
    }

    func cuesHeaderForRendering() -> String {
        cuesHeader
    }

    func languageHeaderForRendering() -> String {
        languageHeader
    }

    func showsDateAddedColumnForRendering() -> Bool {
        showsDateAddedColumn
    }

    func showsDisplayTitleColumnForRendering() -> Bool {
        showsDisplayTitleColumn
    }

    func showsTimeColumnForRendering() -> Bool {
        showsTimeColumn
    }

    func showsLanguageColumnForRendering() -> Bool {
        showsLanguageColumn
    }

    func headerColumnLayoutForRendering(viewportWidth: CGFloat, height: CGFloat) -> SubtitleTableColumnLayout {
        let offsetX = scrollView?.contentView.bounds.origin.x ?? 0
        return tableColumnLayout(
            contentWidth: tableContentWidth(
                viewportWidth: scrollView?.contentView.bounds.width
                    ?? viewportWidth
            ),
            height: height
        ).offsetBy(dx: -offsetX)
    }

    func textForLanguageColumn(row: Int) -> String {
        if let model = rowProvider(row) {
            return model.tags.map(\.label).joined(separator: ", ")
        }
        return ""
    }

    func drawRows(in dirtyRect: CGRect) {
        guard let documentView else { return }
        documentView.effectiveAppearance.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            drawRowsNow(in: dirtyRect)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    func drawRowsNow(in dirtyRect: CGRect) {
        let viewportDirtyRect = dirtyRect.intersection(currentTableBodyVisibleRect)
        // The table is a surface of its own, one step above the page. The
        // container stays the page: on a detail page it also holds the
        // page chrome, so the body paints its own background.
        if !viewportDirtyRect.isNull {
            WorkbenchRedesignColors.NS.bgSurface.setFill()
            viewportDirtyRect.fill()
        }
        guard rowCount > 0,
              let documentView,
              !viewportDirtyRect.isNull,
              let range = visibleRowRange(in: viewportDirtyRect)
        else {
            return
        }

        NSBezierPath(rect: viewportDirtyRect).addClip()
        let radius = WorkbenchControlMetrics.redesignCornerRadius
        let occupiedBodyMaxY = min(
            currentTableBodyVisibleRect.maxY,
            rowsOriginY + rowHeightCache.totalHeight
        )
        let occupiedBodyHeight = max(
            0,
            occupiedBodyMaxY - currentTableBodyVisibleRect.minY
        )
        if occupiedBodyHeight > 0 {
            NSBezierPath(
                roundedRect: CGRect(
                    x: currentTableBodyVisibleRect.minX,
                    y: currentTableBodyVisibleRect.minY - radius,
                    width: currentTableBodyVisibleRect.width,
                    height: occupiedBodyHeight + radius
                ),
                xRadius: radius,
                yRadius: radius
            ).addClip()
        }
        for row in range {
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            guard rowRect.intersects(viewportDirtyRect) else { continue }
            drawnRowCount += 1
            UIInvalidationProbe.count(
                probeSurface.counterName("dynamic_row_draw"),
                scope: probeScope,
                details: "table=\(tableName) row=\(row)"
            )
            drawRowBackground(row: row, rect: rowRect)
            drawCellTexts(row: row, rowRect: rowRect)
        }
    }

    func drawRowBackground(row: Int, rect: CGRect) {
        if let backgroundColor = rowBackgroundColor(row: row) {
            backgroundColor.setFill()
            rect.fill()
        }

        guard shouldDrawRowBottomDivider(row: row) else { return }

        WorkbenchRedesignColors.NS.borderDivider.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.maxY - 0.5))
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 0.5))
        path.lineWidth = 1
        path.stroke()
    }

    func shouldDrawRowBottomDivider(row: Int) -> Bool {
        guard row >= 0, row < rowCount else { return false }
        return row < rowCount - 1
    }

    func rowBackgroundColor(row: Int) -> NSColor? {
        if isSelectionMode, isRowSelected(row) {
            return WorkbenchRedesignColors.NS.tableRowSelected
        }
        guard hoveredRow == row else { return nil }
        return WorkbenchRedesignColors.NS.tableRowHover
    }

    func drawCellTexts(row: Int, rowRect: CGRect) {
        let model = rowProvider(row)
        let isUnavailable = model?.cueState.isUnavailable == true
        let M = SubtitleTableMetrics.self
        let hasTextSelection = textSelection.hasSelection
        let layout = tableColumnLayout(contentWidth: rowRect.width, height: rowRect.height)
        let measurement = cachedMeasurement(for: row, documentWidth: rowRect.width)
            ?? SubtitleTableRowMeasurement(
                height: rowRect.height,
                primaryLineCount: 1,
                extraCueLineCounts: []
            )

        if !isUnavailable && (isSelectionMode || hoveredRow == row) {
            let checkboxState: WorkbenchCheckboxState = isRowSelected(row) ? .checked : .unchecked
            let isCheckboxEnabled = isEnabled
            WorkbenchCheckboxDrawing.draw(
                state: checkboxState,
                isEnabled: isCheckboxEnabled,
                in: checkboxRect(forRowRect: rowRect),
                isFocused: isCheckboxEnabled && focusedCheckboxRow == row && documentView?.window?.firstResponder === documentView
            )
        } else if !isUnavailable, let indexNumber = displayIndex(forRow: row, model: model) {
            drawIndex(indexNumber, in: rowColumnRect(layout.indexRect, rowRect: rowRect))
        }
        if let dateAddedRect = layout.dateAddedRect {
            let cellRect = rowColumnRect(dateAddedRect, rowRect: rowRect)
            let text = model?.dateAdded ?? ""
            drawBody(
                text,
                in: cellRect,
                trailing: M.trailingInset,
                role: .metadata,
                foregroundColor: isUnavailable ? WorkbenchRedesignColors.NS.textMuted : nil,
                selectedRange: hasTextSelection
                    ? selectedUTF16Range(row: row, columnID: "dateAdded", text: text)
                    : nil
            )
        }
        if showsDisplayTitleColumn {
            let cellRect = rowColumnRect(layout.nameRect, rowRect: rowRect)
            let text = model?.displayTitle ?? ""
            drawBody(
                text,
                in: cellRect,
                trailing: M.trailingInset,
                role: .secondaryContext,
                foregroundColor: isUnavailable ? WorkbenchRedesignColors.NS.textMuted : nil,
                selectedRange: hasTextSelection
                    ? selectedUTF16Range(row: row, columnID: "display", text: text)
                    : nil
            )
        }
        if let timeRect = layout.timeRect {
            let cellRect = rowColumnRect(timeRect, rowRect: rowRect)
            let text = model?.timeRange ?? ""
            drawBody(
                text,
                in: cellRect,
                trailing: M.trailingInset,
                role: .metadata,
                foregroundColor: isUnavailable ? WorkbenchRedesignColors.NS.textMuted : nil,
                selectedRange: hasTextSelection
                    ? selectedUTF16Range(row: row, columnID: "time", text: text)
                    : nil
            )
        }
        let cuesRect = rowColumnRect(layout.cuesRect, rowRect: rowRect)
        let isCuesHovered = !isSelectionMode
            && !isUnavailable
            && isCellHovered(row: row, columnID: "cues")
        drawCues(
            model: model,
            in: cuesRect,
            measurement: measurement,
            isHovered: isCuesHovered,
            selectedRange: hasTextSelection ? model.flatMap {
                let text = selectableText(for: "cues", model: $0)
                return selectedUTF16Range(row: row, columnID: "cues", text: text)
            } : nil
        )
        if let model {
            drawCueStateIndicator(
                row: row,
                model: model,
                cuesRect: cuesRect,
                measurement: measurement
            )
        }
        drawRowActionButton(row: row, rowRect: rowRect)
        if let languageRect = layout.languageRect {
            let cellRect = rowColumnRect(languageRect, rowRect: rowRect)
            let tags = model?.tags ?? []
            drawTags(
                tags,
                in: cellRect,
                trailing: M.trailingInset,
                isMuted: isUnavailable,
                selectedRange: hasTextSelection ? selectedUTF16Range(
                    row: row,
                    columnID: "language",
                    text: tags.map(\.label).joined(separator: ", ")
                ) : nil
            )
        }
    }

    func isCellHovered(row: Int, columnID: String) -> Bool {
        hoveredRow == row && hoveredColumnID == columnID
    }

    func contentHoverRect(rects: [CGRect], clippedTo clipRect: CGRect) -> CGRect? {
        let M = SubtitleTableMetrics.self
        guard var contentBounds = rects.first else { return nil }
        for rect in rects.dropFirst() {
            contentBounds = contentBounds.union(rect)
        }
        let hoverRect = contentBounds
            .insetBy(dx: -M.tableCellHoverPaddingX, dy: -M.tableCellHoverPaddingY)
            .intersection(clipRect)
        guard !hoverRect.isNull, hoverRect.width > 0, hoverRect.height > 0 else { return nil }
        return hoverRect
    }

    func drawContentHoverBackground(rects: [CGRect], clippedTo clipRect: CGRect) {
        let M = SubtitleTableMetrics.self
        guard let hoverRect = contentHoverRect(rects: rects, clippedTo: clipRect) else { return }
        WorkbenchRedesignColors.NS.bgHover.setFill()
        NSBezierPath(
            roundedRect: hoverRect,
            xRadius: M.tableCellHoverRadius,
            yRadius: M.tableCellHoverRadius
        ).fill()
    }

    func rowColumnRect(_ columnRect: CGRect, rowRect: CGRect) -> CGRect {
        CGRect(
            x: columnRect.minX,
            y: rowRect.minY,
            width: columnRect.width,
            height: rowRect.height
        )
    }

    func displayIndex(forRow row: Int, model: SubtitleTableRow?) -> Int? {
        guard row >= 0, row < rowCount else { return nil }
        if model?.cueState.isUnavailable == true {
            return nil
        }
        if let displayIndex = model?.displayIndex {
            return displayIndex
        }
        var count = 0
        for index in 0...row where rowProvider(index)?.cueState.isUnavailable != true {
            count += 1
        }
        return count > 0 ? count : nil
    }

    func drawIndex(_ number: Int, in rect: CGRect) {
        textLayout.update(
            attributedString: SubtitleTableText.index(number),
            width: rect.width
        )
        let yOffset = rect.minY + (rect.height - textLayout.usedHeight) / 2
        textLayout.draw(at: CGPoint(x: rect.minX, y: yOffset))
    }

    func localSelectionRange(
        _ selectedRange: NSRange?,
        in logicalRange: NSRange
    ) -> NSRange? {
        guard let selectedRange else { return nil }
        let intersection = NSIntersectionRange(selectedRange, logicalRange)
        guard intersection.length > 0 else { return nil }
        return NSRange(
            location: intersection.location - logicalRange.location,
            length: intersection.length
        )
    }

    func drawSelectionBackground(
        _ range: NSRange?,
        with layout: SubtitleTextLayout,
        at origin: CGPoint
    ) {
        guard let range, range.length > 0 else { return }
        NSColor.selectedTextBackgroundColor.setFill()
        for rect in layout.selectionRects(forUTF16Range: range, at: origin) {
            rect.fill()
        }
    }

    func drawBody(
        _ text: String,
        in rect: CGRect,
        trailing: CGFloat,
        role: SubtitleTableTextRole = .primaryContent,
        foregroundColor: NSColor? = nil,
        selectedRange: NSRange? = nil
    ) {
        let M = SubtitleTableMetrics.self
        guard !text.isEmpty else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath.clip(rect)
        textLayout.update(
            attributedString: SubtitleTableText.body(
                text,
                role: role,
                foregroundColor: foregroundColor
            ),
            width: max(0, rect.width - M.cellLeading - trailing)
        )
        let origin = bodyTextOrigin(in: rect)
        drawSelectionBackground(selectedRange, with: textLayout, at: origin)
        textLayout.draw(at: origin)
        NSGraphicsContext.restoreGraphicsState()
    }

    func drawCues(
        model: SubtitleTableRow?,
        in rect: CGRect,
        measurement: SubtitleTableRowMeasurement,
        isHovered: Bool,
        selectedRange: NSRange?
    ) {
        guard let model else { return }
        let primaryColor = model.cueState.isUnavailable
            ? WorkbenchRedesignColors.NS.textMuted
            : WorkbenchRedesignColors.NS.textPrimary
        let extraColor = WorkbenchRedesignColors.NS.textSecondary
        let fragments = cueTextFragments(
            model: model,
            in: rect,
            measurement: measurement,
            primaryColor: primaryColor,
            extraColor: extraColor
        )

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath.clip(rect)

        for fragment in fragments {
            textLayout.update(
                attributedString: fragment.attributed,
                width: fragment.width
            )
            drawSelectionBackground(
                localSelectionRange(selectedRange, in: fragment.logicalUTF16Range),
                with: textLayout,
                at: fragment.origin
            )
            if isHovered {
                textLayout.drawUnderline(
                    at: fragment.origin,
                    color: fragment.foregroundColor ?? primaryColor,
                    thickness: SubtitleTableMetrics.interactiveTextUnderlineThickness,
                    offset: SubtitleTableMetrics.interactiveTextUnderlineOffset,
                    backingScaleFactor: backingScaleFactor()
                )
            }
            textLayout.draw(at: fragment.origin)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    func drawCueStateIndicator(
        row: Int,
        model: SubtitleTableRow,
        cuesRect: CGRect,
        measurement: SubtitleTableRowMeasurement
    ) {
        guard let icon = model.cueState.icon,
              let rect = cueStateIndicatorRect(
                model: model,
                cuesRect: cuesRect,
                measurement: measurement
              ),
              let image = AppIconStore.tintedImage(
                icon,
                size: rect.height,
                color: WorkbenchRedesignColors.NS.textMuted
              )
        else {
            return
        }
        if hoveredCueStateRow == row {
            WorkbenchRedesignColors.NS.tableRowSelected.setFill()
            if model.cueState.isUnavailable {
                let circleInset = rect.width * 32 / 256
                NSBezierPath(
                    ovalIn: rect.insetBy(dx: circleInset, dy: circleInset)
                ).fill()
            } else {
                NSBezierPath(
                    roundedRect: rect.insetBy(dx: -3, dy: -3),
                    xRadius: 5,
                    yRadius: 5
                ).fill()
            }
        }
        image.draw(in: rect)
    }

    func isRowActionMenuOpen(row: Int) -> Bool {
        if case .rowActionButton(let menuRow, _) = activeMenuAnchor {
            return menuRow == row
        }
        return false
    }

    func shouldShowRowActionButton(row: Int) -> Bool {
        guard !isSelectionMode,
              row >= 0,
              row < rowCount,
              rowProvider(row) != nil
        else {
            return false
        }
        return hoveredRow == row || isRowActionMenuOpen(row: row)
    }

    func rowActionButtonBackgroundColor(row: Int) -> NSColor? {
        guard shouldShowRowActionButton(row: row), isEnabled else {
            return nil
        }
        if pressedRowActionRow == row {
            return WorkbenchRedesignColors.NS.rowActionBgPressed
        }
        if isRowActionMenuOpen(row: row) || hoveredRowActionRow == row {
            return WorkbenchRedesignColors.NS.rowSelected
        }
        return nil
    }

    func drawRowActionButton(row: Int, rowRect: CGRect) {
        guard shouldShowRowActionButton(row: row),
              let buttonRect = rowActionButtonFrameInDocument(forRowRect: rowRect)
        else {
            return
        }
        if let backgroundColor = rowActionButtonBackgroundColor(row: row) {
            backgroundColor.setFill()
            NSBezierPath(
                roundedRect: buttonRect,
                xRadius: SubtitleTableMetrics.rowActionButtonCornerRadius,
                yRadius: SubtitleTableMetrics.rowActionButtonCornerRadius
            ).fill()
        }
        let iconSize = SubtitleTableMetrics.rowActionButtonIconSize
        let iconColor = isEnabled
            ? WorkbenchRedesignColors.NS.textSecondary
            : WorkbenchRedesignColors.NS.textDisabled
        guard let image = AppIconStore.tintedImage(
            .dotsThree,
            size: iconSize,
            color: iconColor
        ) else {
            return
        }
        let iconRect = CGRect(
            x: buttonRect.midX - iconSize / 2,
            y: buttonRect.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        image.draw(in: iconRect)
    }

    func cueStateIndicatorRect(
        model: SubtitleTableRow,
        cuesRect: CGRect,
        measurement: SubtitleTableRowMeasurement
    ) -> CGRect? {
        guard model.cueState.icon != nil else {
            return nil
        }
        let size = SubtitleTableMetrics.cueStateIndicatorSize
        if model.cueState.isUnavailable {
            let firstLineMinY = cuesRect.minY + measurement.primaryFirstLineOffset
            let iconY = firstLineMinY + (SubtitleTableCueGeometry.primaryLineHeight - size) / 2
            return CGRect(
                x: cuesRect.minX + SubtitleTableCueGeometry.cellLeadingPadding,
                y: iconY,
                width: size,
                height: size
            )
        }
        guard let primary = cueTextFragments(
            model: model,
            in: cuesRect,
            measurement: measurement
        ).last else {
            return nil
        }
        textLayout.update(
            attributedString: primary.attributed,
            width: primary.width
        )
        guard let lastLine = textLayout.usedRects(at: primary.origin).last else {
            return nil
        }
        let proposedX = lastLine.maxX + 8
        let maxIndicatorX = cuesRect.maxX
            - SubtitleTableCueGeometry.cellTrailingPadding
            - SubtitleTableMetrics.rowActionButtonReservation
            - size
        let x = min(proposedX, maxIndicatorX)
        return CGRect(
            x: max(cuesRect.minX, x),
            y: lastLine.midY - size / 2,
            width: size,
            height: size
        )
    }

    func cueStateIndicatorRectInDocument(row: Int) -> CGRect? {
        guard let documentView,
              let model = rowProvider(row)
        else {
            return nil
        }
        let rowRect = rectForRow(row, width: documentView.bounds.width)
        let layout = tableColumnLayout(
            contentWidth: rowRect.width,
            height: rowRect.height
        )
        let cuesRect = rowColumnRect(layout.cuesRect, rowRect: rowRect)
        let measurement = cachedMeasurement(
            for: row,
            documentWidth: documentView.bounds.width
        ) ?? SubtitleTableRowMeasurement(
            height: rowRect.height,
            primaryLineCount: 1,
            extraCueLineCounts: []
        )
        return cueStateIndicatorRect(
            model: model,
            cuesRect: cuesRect,
            measurement: measurement
        )
    }

    func cuesTextWidth(
        in rect: CGRect,
        model: SubtitleTableRow
    ) -> CGFloat {
        let indicatorReservation: CGFloat
        if model.cueState.isUnavailable {
            indicatorReservation = SubtitleTableCueGeometry.unavailableLeadingIndent
        } else if model.cueState.icon != nil {
            indicatorReservation = 22
        } else {
            indicatorReservation = 0
        }
        return max(
            1,
            rect.width
                - SubtitleTableCueGeometry.cellLeadingPadding
                - SubtitleTableCueGeometry.cellTrailingPadding
                - SubtitleTableMetrics.rowActionButtonReservation
                - indicatorReservation
        )
    }

    func cueTextFragments(
        model: SubtitleTableRow,
        in rect: CGRect,
        measurement: SubtitleTableRowMeasurement,
        primaryColor: NSColor = WorkbenchRedesignColors.NS.textPrimary,
        extraColor: NSColor = WorkbenchRedesignColors.NS.textSecondary
    ) -> [SubtitleTableTextFragmentLayout] {
        let extraTexts = showsCueGroup ? model.additionalCueTexts : []
        let leadingIndent = model.cueState.isUnavailable
            ? SubtitleTableCueGeometry.unavailableLeadingIndent
            : 0
        let textX = rect.minX + SubtitleTableCueGeometry.cellLeadingPadding + leadingIndent
        let textWidth = cuesTextWidth(in: rect, model: model)
        var fragments = [SubtitleTableTextFragmentLayout]()
        fragments.reserveCapacity(extraTexts.count + 1)

        let primaryText = model.primaryCueText
        let primaryLength = (primaryText as NSString).length
        fragments.append(SubtitleTableTextFragmentLayout(
            attributed: SubtitleTableCueTextMeasurer.attributedString(
                primaryText,
                style: .primary,
                foregroundColor: primaryColor
            ),
            origin: CGPoint(
                x: textX,
                y: rect.minY + measurement.primaryFirstLineOffset
            ),
            width: textWidth,
            clipRect: rect,
            logicalUTF16Range: NSRange(location: 0, length: primaryLength)
        ))
        var logicalOffset = primaryLength + 1

        for (index, text) in extraTexts.enumerated() {
            let length = (text as NSString).length
            if measurement.extraCueOffsets.indices.contains(index) {
                fragments.append(SubtitleTableTextFragmentLayout(
                    attributed: SubtitleTableCueTextMeasurer.attributedString(
                        text,
                        style: .extra,
                        foregroundColor: extraColor
                    ),
                    origin: CGPoint(
                        x: textX,
                        y: rect.minY + measurement.extraCueOffsets[index]
                    ),
                    width: textWidth,
                    clipRect: rect,
                    logicalUTF16Range: NSRange(location: logicalOffset, length: length)
                ))
            }
            logicalOffset += length + 1
        }
        return fragments
    }

    func cuesTextTrailingInset(forRowRect _: CGRect) -> CGFloat {
        let M = SubtitleTableMetrics.self
        return M.trailingInset + M.rowActionButtonReservation
    }

    func bodyTextRole(for columnID: String) -> SubtitleTableTextRole {
        switch columnID {
        case "dateAdded":
            return .metadata
        case "time":
            return .metadata
        case "display":
            return .secondaryContext
        default:
            return .primaryContent
        }
    }

    func bodyTextTrailingInset(for columnID: String, rowRect: CGRect) -> CGFloat {
        let M = SubtitleTableMetrics.self
        return columnID == "cues" ? cuesTextTrailingInset(forRowRect: rowRect) : M.trailingInset
    }

    func bodyContentHoverRect(
        text: String,
        in rect: CGRect,
        trailing: CGFloat,
        role: SubtitleTableTextRole
    ) -> CGRect? {
        let M = SubtitleTableMetrics.self
        guard !text.isEmpty else { return nil }
        textLayout.update(
            attributedString: SubtitleTableText.body(
                text,
                role: role
            ),
            width: max(0, rect.width - M.cellLeading - trailing)
        )
        let origin = bodyTextOrigin(in: rect)
        guard let textBounds = textLayout.unionUsedRect(at: origin) else { return nil }
        return contentHoverRect(rects: [textBounds], clippedTo: rect)
    }

    func cuesContentHoverRect(
        model: SubtitleTableRow,
        in rect: CGRect,
        measurement: SubtitleTableRowMeasurement
    ) -> CGRect? {
        let textWidth = cuesTextWidth(in: rect, model: model)
        let leadingIndent = model.cueState.isUnavailable
            ? SubtitleTableCueGeometry.unavailableLeadingIndent
            : 0
        let textX = rect.minX + SubtitleTableCueGeometry.cellLeadingPadding + leadingIndent
        var usedRects = [CGRect]()
        for (extraText, offset) in zip(
            showsCueGroup ? model.additionalCueTexts : [],
            measurement.extraCueOffsets
        ) {
            textLayout.update(
                attributedString: SubtitleTableCueTextMeasurer.attributedString(
                    extraText,
                    style: .extra,
                    foregroundColor: WorkbenchRedesignColors.NS.textMuted
                ),
                width: textWidth
            )
            usedRects.append(contentsOf: textLayout.usedRects(at: CGPoint(
                x: textX,
                y: rect.minY + offset
            )))
        }
        textLayout.update(
            attributedString: SubtitleTableCueTextMeasurer.attributedString(
                model.primaryCueText,
                style: .primary,
                foregroundColor: WorkbenchRedesignColors.NS.textPrimary
            ),
            width: textWidth
        )
        usedRects.append(contentsOf: textLayout.usedRects(at: CGPoint(
            x: textX,
            y: rect.minY + measurement.primaryFirstLineOffset
        )))
        return contentHoverRect(rects: usedRects, clippedTo: rect)
    }

    func drawTags(
        _ tags: [WorkbenchTag],
        in rect: CGRect,
        trailing: CGFloat,
        isHovered: Bool = false,
        isMuted: Bool = false,
        selectedRange: NSRange? = nil
    ) {
        guard !tags.isEmpty else { return }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath.clip(rect)

        let tagStyle = SubtitleTableTagStyle.resolve()
        let laidOutTags = layoutTags(
            tags,
            in: rect,
            trailing: trailing,
            tagStyle: tagStyle
        )

        if isHovered {
            drawContentHoverBackground(rects: laidOutTags.map { $0.tagRect }, clippedTo: rect)
        }

        for item in laidOutTags {
            let path = NSBezierPath(
                roundedRect: item.tagRect,
                xRadius: tagStyle.cornerRadius,
                yRadius: tagStyle.cornerRadius
            )
            tagStyle.fillColor(for: item.tag, isEnabled: isEnabled).setFill()
            path.fill()
        }

        if selectedRange == nil {
            for item in laidOutTags {
                attributedTagText(item.attributed, isMuted: isMuted)
                    .draw(in: tagTextRect(for: item, tagStyle: tagStyle))
            }
            NSGraphicsContext.restoreGraphicsState()
            return
        }

        for fragment in tagTextFragments(
            laidOutTags,
            tagStyle: tagStyle,
            isMuted: isMuted
        ) {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(fragment.clipRect)
            textLayout.update(attributedString: fragment.attributed, width: fragment.width)
            drawSelectionBackground(
                localSelectionRange(selectedRange, in: fragment.logicalUTF16Range),
                with: textLayout,
                at: fragment.origin
            )
            textLayout.draw(at: fragment.origin)
            NSGraphicsContext.restoreGraphicsState()
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    func tagTextRect(
        for item: SubtitleTableLaidOutTag,
        tagStyle: SubtitleTableTagStyle
    ) -> CGRect {
        CGRect(
            x: item.tagRect.minX + tagStyle.horizontalInset,
            y: item.tagRect.minY + max(0, (item.tagRect.height - item.textSize.height) / 2),
            width: max(0, item.tagRect.width - 2 * tagStyle.horizontalInset),
            height: item.textSize.height
        )
    }

    func tagTextFragments(
        _ laidOutTags: [SubtitleTableLaidOutTag],
        tagStyle: SubtitleTableTagStyle,
        isMuted: Bool = false
    ) -> [SubtitleTableTextFragmentLayout] {
        var logicalOffset = 0
        return laidOutTags.enumerated().map { index, item in
            let length = (item.attributed.string as NSString).length
            let textRect = tagTextRect(for: item, tagStyle: tagStyle)
            defer { logicalOffset += length + (index == laidOutTags.indices.last ? 0 : 2) }
            return SubtitleTableTextFragmentLayout(
                attributed: attributedTagText(item.attributed, isMuted: isMuted),
                origin: textRect.origin,
                width: textRect.width,
                clipRect: textRect,
                logicalUTF16Range: NSRange(location: logicalOffset, length: length)
            )
        }
    }

    func attributedTagText(
        _ attributed: NSAttributedString,
        isMuted: Bool
    ) -> NSAttributedString {
        guard isMuted else {
            return attributed
        }
        let result = NSMutableAttributedString(attributedString: attributed)
        result.addAttribute(
            .foregroundColor,
            value: WorkbenchRedesignColors.NS.textMuted,
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }

    func tagContentHoverRect(
        tags: [WorkbenchTag],
        in rect: CGRect,
        trailing: CGFloat
    ) -> CGRect? {
        guard !tags.isEmpty else { return nil }
        let tagStyle = SubtitleTableTagStyle.resolve()
        let laidOutTags = layoutTags(
            tags,
            in: rect,
            trailing: trailing,
            tagStyle: tagStyle
        )
        return contentHoverRect(rects: laidOutTags.map { $0.tagRect }, clippedTo: rect)
    }

    func layoutTags(
        _ tags: [WorkbenchTag],
        in rect: CGRect,
        trailing: CGFloat,
        tagStyle: SubtitleTableTagStyle
    ) -> [SubtitleTableLaidOutTag] {
        let M = SubtitleTableMetrics.self
        let naturalLayout = naturalTagLayout(
            tags,
            availableWidth: max(0, rect.width - M.cellLeading - trailing),
            tagStyle: tagStyle
        )
        let top = rect.minY + max(0, (rect.height - naturalLayout.blockHeight) / 2)
        return naturalLayout.items.map { item in
            let tagRect = item.tagRect.offsetBy(dx: rect.minX + M.cellLeading, dy: top)
            return SubtitleTableLaidOutTag(
                tag: item.tag,
                attributed: item.attributed,
                textSize: item.textSize,
                tagRect: tagRect
            )
        }
    }

    func naturalTagLayout(
        _ tags: [WorkbenchTag],
        availableWidth: CGFloat,
        tagStyle: SubtitleTableTagStyle
    ) -> SubtitleTableTagLayoutResult {
        guard !tags.isEmpty, availableWidth > 0 else {
            return SubtitleTableTagLayoutResult(items: [], blockHeight: 0)
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var laidOutTags = [SubtitleTableLaidOutTag]()

        for tag in tags {
            let attributed = SubtitleTableText.tag(tag, isEnabled: isEnabled)
            let textSize = attributed.size()
            let tagHeight = tagStyle.height(for: textSize)
            let tagWidth = min(tagStyle.width(for: textSize), availableWidth)
            if x > 0, x + tagWidth > availableWidth {
                x = 0
                y += currentRowHeight + tagStyle.verticalSpacing
                currentRowHeight = 0
            }

            let tagRect = CGRect(x: x, y: y, width: tagWidth, height: tagHeight)
            laidOutTags.append(SubtitleTableLaidOutTag(
                tag: tag,
                attributed: attributed,
                textSize: textSize,
                tagRect: tagRect
            ))
            currentRowHeight = max(currentRowHeight, tagHeight)
            x += tagWidth + tagStyle.horizontalSpacing
        }

        return SubtitleTableTagLayoutResult(
            items: laidOutTags,
            blockHeight: laidOutTags.isEmpty ? 0 : y + currentRowHeight
        )
    }

    func effectiveCuesTextWidth(documentWidth: CGFloat) -> CGFloat {
        let layout = tableColumnLayout(contentWidth: documentWidth, height: currentRowHeight)
        return max(
            1,
            layout.cuesRect.width
                - SubtitleTableCueGeometry.cellLeadingPadding
                - SubtitleTableCueGeometry.cellTrailingPadding
                - SubtitleTableMetrics.rowActionButtonReservation
        )
    }

    func rowMeasurement(
        for model: SubtitleTableRow,
        documentWidth: CGFloat,
        effectiveCuesWidth: CGFloat
    ) -> SubtitleTableRowMeasurement {
        let layout = tableColumnLayout(contentWidth: documentWidth, height: currentRowHeight)
        var otherContentHeights = [SubtitleTableMetrics.checkboxSize]

        if let dateAddedRect = layout.dateAddedRect {
            otherContentHeights.append(bodyContentHeight(
                model.dateAdded,
                cellWidth: dateAddedRect.width,
                trailing: SubtitleTableMetrics.trailingInset,
                role: .metadata
            ))
        }
        if showsDisplayTitleColumn {
            otherContentHeights.append(bodyContentHeight(
                model.displayTitle,
                cellWidth: layout.nameRect.width,
                trailing: SubtitleTableMetrics.trailingInset,
                role: .secondaryContext
            ))
        }
        if let timeRect = layout.timeRect {
            otherContentHeights.append(bodyContentHeight(
                model.timeRange,
                cellWidth: timeRect.width,
                trailing: SubtitleTableMetrics.trailingInset,
                role: .metadata
            ))
        }

        let tagStyle = SubtitleTableTagStyle.resolve()
        if let languageRect = layout.languageRect {
            otherContentHeights.append(tagContentHeight(
                model.tags,
                cellWidth: languageRect.width,
                trailing: SubtitleTableMetrics.trailingInset,
                tagStyle: tagStyle
            ))
        }
        let trailingIndicatorReservation: CGFloat =
            (!model.cueState.isUnavailable && model.cueState.icon != nil) ? 22 : 0
        let measuredCuesWidth = max(
            1,
            effectiveCuesWidth - trailingIndicatorReservation
        )
        return cueTextMeasurer.rowMeasurement(
            row: model,
            effectiveCuesWidth: measuredCuesWidth,
            showsCueGroup: showsCueGroup,
            otherContentHeights: otherContentHeights
        )
    }

    func bodyContentHeight(
        _ text: String,
        cellWidth: CGFloat,
        trailing: CGFloat,
        role: SubtitleTableTextRole
    ) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        textLayout.update(
            attributedString: SubtitleTableText.body(
                text,
                role: role
            ),
            width: max(0, cellWidth - SubtitleTableMetrics.cellLeading - trailing)
        )
        return textLayout.usedHeight
    }

    func tagContentHeight(
        _ tags: [WorkbenchTag],
        cellWidth: CGFloat,
        trailing: CGFloat,
        tagStyle: SubtitleTableTagStyle
    ) -> CGFloat {
        naturalTagLayout(
            tags,
            availableWidth: max(0, cellWidth - SubtitleTableMetrics.cellLeading - trailing),
            tagStyle: tagStyle
        ).blockHeight
    }

    func cachedMeasurement(for row: Int, documentWidth: CGFloat) -> SubtitleTableRowMeasurement? {
        guard let model = rowProvider(row) else { return nil }
        let layout = tableColumnLayout(contentWidth: documentWidth, height: currentRowHeight)
        return rowMeasurementCache.cachedMeasurement(
            rowIndex: row,
            row: model,
            layoutKey: layout.rowMeasurementLayoutKey,
            showsCueGroup: showsCueGroup,
            styleRevision: SubtitleTableCueGeometry.styleRevision
        )
    }

    @discardableResult
    func measureRow(_ row: Int, documentWidth: CGFloat) -> Bool {
        guard row >= 0,
              row < rowCount,
              let model = rowProvider(row)
        else {
            return false
        }

        let effectiveWidth = effectiveCuesTextWidth(documentWidth: documentWidth)
        let layout = tableColumnLayout(contentWidth: documentWidth, height: currentRowHeight)
        let lookup = rowMeasurementCache.lookup(
            rowIndex: row,
            row: model,
            layoutKey: layout.rowMeasurementLayoutKey,
            showsCueGroup: showsCueGroup,
            styleRevision: SubtitleTableCueGeometry.styleRevision
        ) {
            measurementComputeCount += 1
            UIInvalidationProbe.count(
                probeSurface.counterName("dynamic_row_measurement"),
                scope: probeScope,
                details: "table=\(tableName) row=\(row)"
            )
            return rowMeasurement(
                for: model,
                documentWidth: documentWidth,
                effectiveCuesWidth: effectiveWidth
            )
        }
        return rowHeightCache.setHeight(lookup.height, for: row)
    }

    func heightForRow(_ row: Int, width: CGFloat) -> CGFloat {
        _ = width
        return rowHeightCache.height(for: row)
    }

    func rectForRow(_ row: Int, width: CGFloat) -> CGRect {
        let y = rowDocumentY(for: row)
        let height = heightForRow(row, width: width)
        return CGRect(x: 0, y: y, width: width, height: height)
    }

    func rowDocumentY(for row: Int) -> CGFloat {
        rowsOriginY + rowHeightCache.yOffset(for: row)
    }

    func checkboxRect(forRowRect rowRect: CGRect) -> CGRect {
        let size = SubtitleTableMetrics.checkboxSize
        return CGRect(
            x: (SubtitleTableMetrics.indexColumnWidth - size) / 2,
            y: rowRect.midY - size / 2,
            width: size,
            height: size
        )
    }

    func checkboxHitRect(forRowRect rowRect: CGRect) -> CGRect {
        checkboxRect(forRowRect: rowRect).insetBy(
            dx: -SubtitleTableMetrics.checkboxHitSlop,
            dy: -SubtitleTableMetrics.checkboxHitSlop
        )
    }

    func visibleRowRange() -> Range<Int>? {
        guard let scrollView else { return nil }
        return visibleRowRange(in: tableBodyVisibleRect(for: scrollView))
    }

    func visibleRowRange(in rect: CGRect) -> Range<Int>? {
        rowRange(in: rect, overscan: 0)
    }

    func measurementRowRange(in rect: CGRect) -> Range<Int>? {
        rowRange(in: rect, overscan: SubtitleTableCueGeometry.measurementOverscan)
    }

    var currentTableBodyVisibleRect: CGRect {
        guard let scrollView else {
            return documentView?.visibleRect ?? .zero
        }
        return tableBodyVisibleRect(for: scrollView)
    }

    func tableBodyVisibleRect(for scrollView: NSScrollView) -> CGRect {
        guard var visibleRect = pageScrollGeometry?.tableBodyVisibleRect(
            scrollOffset: scrollView.contentView.bounds.minY,
            viewportSize: scrollView.contentView.bounds.size
        ) else {
            return scrollView.contentView.bounds
        }
        visibleRect.origin.x = scrollView.contentView.bounds.minX
        return visibleRect
    }

    func rowRange(in rect: CGRect, overscan: Int) -> Range<Int>? {
        guard rowCount > 0 else { return nil }
        let localMinY = rect.minY - rowsOriginY
        let localMaxY = rect.maxY - rowsOriginY
        guard localMaxY >= 0 else { return nil }
        let lower = rowHeightCache.rowIndex(atY: max(0, localMinY))
        let upperY = rect.maxY > rect.minY
            ? max(0, localMaxY).nextDown
            : max(0, localMinY)
        let upper = rowHeightCache.rowIndex(atY: upperY)
        let lowerBound = max(0, lower - overscan)
        let upperBound = min(rowCount, upper + overscan + 1)
        return lowerBound < upperBound ? lowerBound..<upperBound : nil
    }

    func invalidateRows(_ rows: [Int?]) {
        guard let documentView else { return }
        for row in rows.compactMap({ $0 }) where row >= 0 && row < rowCount {
            documentView.setNeedsDisplay(rectForRow(row, width: documentView.bounds.width))
        }
    }

    func invalidateVisibleDocument() {
        guard let documentView else { return }
        let visibleRect = documentView.visibleRect
        if visibleRect.isEmpty {
            documentView.needsDisplay = true
        } else {
            documentView.setNeedsDisplay(visibleRect)
        }
    }

    func invalidateColumnLayoutChange(
        oldLayout: SubtitleTableColumnLayout,
        newLayout: SubtitleTableColumnLayout
    ) {
        guard let documentView,
              let visibleRows = visibleRowRange()
        else {
            return
        }

        for row in visibleRows {
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            for columnID in visibleTextColumnOrder() {
                var dirtyRect = CGRect.null
                if let oldColumnRect = oldLayout.rect(for: columnID) {
                    dirtyRect = dirtyRect.union(rowColumnRect(oldColumnRect, rowRect: rowRect))
                }
                if let newColumnRect = newLayout.rect(for: columnID) {
                    dirtyRect = dirtyRect.union(rowColumnRect(newColumnRect, rowRect: rowRect))
                }
                if !dirtyRect.isNull {
                    documentView.setNeedsDisplay(dirtyRect)
                }
            }
        }
    }

    func invalidateRows(for rowsUpdate: TableSandboxRowsUpdate, rowsChanged: Bool) {
        guard rowsChanged else { return }
        switch rowsUpdate {
        case .none:
            break
        case .append(let range):
            guard let visibleRows = visibleRowRange() else { return }
            let lowerBound = max(range.lowerBound, visibleRows.lowerBound)
            let upperBound = min(range.upperBound, visibleRows.upperBound)
            guard lowerBound < upperBound else { return }
            invalidateRows((lowerBound..<upperBound).map { Optional($0) })
        case .cells(let cells):
            invalidateCells(cells)
        case .reload:
            invalidateVisibleDocument()
        }
    }

    func invalidateCells(_ cells: [TableSandboxCellInvalidation]) {
        guard let documentView else { return }
        for cell in cells where cell.row >= 0 && cell.row < rowCount {
            let rowRect = rectForRow(cell.row, width: documentView.bounds.width)
            if let cellRect = dataCellRect(columnID: cell.columnID, rowRect: rowRect) {
                documentView.setNeedsDisplay(cellRect)
            }
        }
    }

    func setScrollbarDragging(_ isDragging: Bool) {
        guard isScrollbarDragging != isDragging else { return }
        isScrollbarDragging = isDragging
    }

    func backingScaleFactor() -> CGFloat {
        documentView?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
    }
}
