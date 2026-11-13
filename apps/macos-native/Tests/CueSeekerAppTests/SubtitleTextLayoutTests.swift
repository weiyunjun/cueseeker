import AppKit
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleTextLayoutRendersAllBodyLinesByDefault() {
    let text = (0..<20)
        .map { "line \($0)" }
        .joined(separator: "\n")
    let attributed = SubtitleTableText.body(text)

    let uncapped = SubtitleTextLayout(maximumNumberOfLines: 0)
    uncapped.update(attributedString: attributed, width: 400)

    let defaultLayout = SubtitleTextLayout()
    defaultLayout.update(attributedString: attributed, width: 400)

    let explicitlyCapped = SubtitleTextLayout(maximumNumberOfLines: 6)
    explicitlyCapped.update(attributedString: attributed, width: 400)

    #expect(defaultLayout.usedHeight == uncapped.usedHeight)
    #expect(defaultLayout.usedHeight > explicitlyCapped.usedHeight)
}

@MainActor
@Test
func subtitleTextLayoutLeavesShortBodyTextUncapped() {
    let text = "line one\nline two"
    let attributed = SubtitleTableText.body(text)

    let uncapped = SubtitleTextLayout(maximumNumberOfLines: 0)
    uncapped.update(attributedString: attributed, width: 400)

    let defaultLayout = SubtitleTextLayout()
    defaultLayout.update(attributedString: attributed, width: 400)

    #expect(defaultLayout.usedHeight == uncapped.usedHeight)
}

@MainActor
@Test
func subtitleTextLayoutUsesWholeUTF16GlyphBoundariesAndOffsetsSelectionRects() throws {
    let layout = SubtitleTextLayout()
    layout.update(
        attributedString: SubtitleTableText.body("A😀B"),
        width: 300
    )
    let origin = CGPoint(x: 17, y: 29)
    let emojiRect = try #require(
        layout.selectionRects(forUTF16Range: NSRange(location: 1, length: 2), at: origin).first
    )
    let leftPoint = CGPoint(x: emojiRect.minX + emojiRect.width * 0.25, y: emojiRect.midY)
    let rightPoint = CGPoint(x: emojiRect.minX + emojiRect.width * 0.75, y: emojiRect.midY)

    #expect(layout.utf16Length == 4)
    #expect(layout.utf16Offset(at: leftPoint, origin: origin) == 1)
    #expect(layout.utf16Offset(at: rightPoint, origin: origin) == 3)
    #expect(layout.utf16Offset(at: leftPoint, origin: origin) != 2)
    #expect(layout.utf16Offset(at: rightPoint, origin: origin) != 2)
    #expect(emojiRect.minX >= origin.x)
    #expect(emojiRect.minY >= origin.y)
}

@MainActor
@Test
func subtitleTableTextUsesRedesignVisualHierarchy() throws {
    let primary = SubtitleTableText.body(
        "cue",
        role: .primaryContent
    )
    let secondary = SubtitleTableText.body(
        "title",
        role: .secondaryContext
    )
    let metadata = SubtitleTableText.body(
        "26-07-01 13:51",
        role: .metadata
    )
    let header = SubtitleTableText.header("Cues")
    let sequence = SubtitleTableText.index(37)

    let primaryFont = try attributedFont(primary)
    let secondaryFont = try attributedFont(secondary)
    let metadataFont = try attributedFont(metadata)
    let headerFont = try attributedFont(header)

    #expect(primaryFont.pointSize == WorkbenchControlMetrics.redesignFontSizeTable)
    #expect(secondaryFont.pointSize == WorkbenchControlMetrics.redesignFontSizeTable)
    #expect(metadataFont.pointSize == WorkbenchControlMetrics.redesignFontSizeTable)
    #expect(headerFont.pointSize == WorkbenchControlMetrics.redesignFontSizeTableHeader)
    #expect(headerFont.fontDescriptor == NSFont.systemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeTableHeader,
        weight: .medium
    ).fontDescriptor)
    #expect(fontWeight(secondaryFont) == fontWeight(metadataFont))
    #expect(primaryFont.fontDescriptor == NSFont.systemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
        weight: .regular
    ).fontDescriptor)
    #expect(secondaryFont.fontDescriptor == NSFont.systemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
        weight: .regular
    ).fontDescriptor)
    #expect(metadataFont.fontDescriptor == NSFont.monospacedDigitSystemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
        weight: .regular
    ).fontDescriptor)

    #expect(try attributedForeground(primary) === WorkbenchRedesignColors.NS.textPrimary)
    #expect(try attributedForeground(secondary) === WorkbenchRedesignColors.NS.textSecondary)
    #expect(try attributedForeground(metadata) === WorkbenchRedesignColors.NS.textSecondary)
    #expect(try attributedForeground(header) === WorkbenchRedesignColors.NS.textSecondary)
    #expect(sequence.string == "37")
    #expect(try attributedForeground(sequence) === WorkbenchRedesignColors.NS.textMuted)
}

@MainActor
@Test
func subtitleTableBodyUsesFixedCenteredTwentyPointLineBoxesAndAlignsHitSelection() throws {
    let layout = SubtitleTextLayout()
    let expectedLineHeight = WorkbenchControlMetrics.redesignLineHeightTableCell
    #expect(expectedLineHeight == 20)

    for (role, sample) in [
        (SubtitleTableTextRole.secondaryContext, "Episode Title 日本語"),
        (.metadata, "00:01:02 - 00:01:05"),
    ] {
        let single = SubtitleTableText.body(sample, role: role)
        layout.update(attributedString: single, width: 400)
        #expect(layout.usedHeight == expectedLineHeight)
        let singleRects = layout.usedRects(at: .zero)
        #expect(singleRects.count == 1)
        #expect(singleRects.first?.height == expectedLineHeight)

        let paragraph = try #require(
            single.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )
        #expect(paragraph.minimumLineHeight == expectedLineHeight)
        #expect(paragraph.maximumLineHeight == expectedLineHeight)
        #expect(paragraph.lineSpacing == 0)
        #expect(paragraph.paragraphSpacing == 0)

        let font = try attributedFont(single)
        let baselineOffset = try #require(
            single.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat
        )
        let expectedOffset = max(0, (expectedLineHeight - ceil(font.ascender - font.descender + font.leading)) / 2)
        #expect(abs(baselineOffset - expectedOffset) < 0.001)
    }

    // Two explicit lines stack at 2 * 20 = 40 without trailing or extra lineSpacing.
    let twoLines = SubtitleTableText.body("First Line\nSecond Line", role: .secondaryContext)
    layout.update(attributedString: twoLines, width: 400)
    #expect(layout.usedHeight == 40)
    let lineRects = layout.usedRects(at: .zero)
    #expect(lineRects.count == 2)
    #expect(lineRects[0].minY == 0)
    #expect(lineRects[0].height == 20)
    #expect(lineRects[1].minY == 20)
    #expect(lineRects[1].height == 20)

    // Hit testing and selection rects map accurately onto both 20pt visual line boxes.
    let firstLineHit = CGPoint(x: lineRects[0].minX + 4, y: lineRects[0].midY)
    let secondLineHit = CGPoint(x: lineRects[1].minX + 4, y: lineRects[1].midY)
    #expect(layout.containsText(at: firstLineHit, origin: .zero))
    #expect(layout.containsText(at: secondLineHit, origin: .zero))
    let secondOffset = layout.utf16Offset(at: secondLineHit, origin: .zero)
    #expect(secondOffset >= ("First Line\n" as NSString).length)
    let selectionRects = layout.selectionRects(
        forUTF16Range: NSRange(location: 0, length: twoLines.length),
        at: .zero
    )
    #expect(selectionRects.count == 2)
    #expect(selectionRects.allSatisfy { $0.height == 20 })
}

private func attributedFont(_ attributed: NSAttributedString) throws -> NSFont {
    try #require(attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
}

private func attributedForeground(_ attributed: NSAttributedString) throws -> NSColor {
    try #require(attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
}

private func fontWeight(_ font: NSFont) -> Int {
    NSFontManager.shared.weight(of: font)
}

@MainActor
@Test
func subtitleTableIndexTextCentersAndAccommodatesFiveDigitsInRedesign() throws {
    let index5 = SubtitleTableText.index(76817)
    let font = try attributedFont(index5)
    #expect(font.pointSize == 12)
    #expect(font.fontDescriptor == NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular).fontDescriptor)

    let paragraphStyle = try #require(index5.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
    #expect(paragraphStyle.alignment == .center)
    #expect(paragraphStyle.lineBreakMode == .byClipping)

    let layout = SubtitleTextLayout()
    let columnWidth: CGFloat = SubtitleTableMetrics.indexColumnWidth
    #expect(columnWidth == 50)

    // Test single digit (1) and 5 digits (76817, 99999)
    for number in [1, 76817, 99999] {
        let attr = SubtitleTableText.index(number)
        layout.update(attributedString: attr, width: columnWidth)
        let rects = layout.usedRects(at: .zero)
        #expect(rects.count == 1) // strictly single line
        let used = try #require(rects.first)
        let center = used.minX + used.width / 2
        #expect(abs(center - columnWidth / 2) < 0.5) // centered at 25.0
        #expect(used.minX > 5) // at least 5px margin on left
        #expect(columnWidth - used.maxX > 5) // at least 5px margin on right
    }
}

