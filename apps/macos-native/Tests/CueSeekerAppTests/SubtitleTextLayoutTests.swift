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
        attributedString: SubtitleTableText.body("A😀B", isRedesign: true),
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
        role: .primaryContent,
        isRedesign: true
    )
    let secondary = SubtitleTableText.body(
        "title",
        role: .secondaryContext,
        isRedesign: true
    )
    let metadata = SubtitleTableText.body(
        "26-07-01 13:51",
        role: .metadata,
        isRedesign: true
    )
    let metadataMuted = SubtitleTableText.body(
        "26-07-01 13:51",
        role: .metadataMuted,
        isRedesign: true
    )
    let header = SubtitleTableText.header("Cues", isRedesign: true)
    let sequence = SubtitleTableText.index(37, isRedesign: true)

    let primaryFont = try attributedFont(primary)
    let secondaryFont = try attributedFont(secondary)
    let metadataFont = try attributedFont(metadata)
    let metadataMutedFont = try attributedFont(metadataMuted)
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
        weight: .medium
    ).fontDescriptor)
    #expect(secondaryFont.fontDescriptor == NSFont.systemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
        weight: .regular
    ).fontDescriptor)
    #expect(metadataFont.fontDescriptor == NSFont.monospacedDigitSystemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
        weight: .regular
    ).fontDescriptor)
    #expect(metadataMutedFont.fontDescriptor == metadataFont.fontDescriptor)

    #expect(try attributedForeground(primary) === WorkbenchRedesignColors.NS.textPrimary)
    #expect(try attributedForeground(secondary) === WorkbenchRedesignColors.NS.textSecondary)
    #expect(try attributedForeground(metadata) === WorkbenchRedesignColors.NS.textSecondary)
    #expect(try attributedForeground(metadataMuted) === WorkbenchRedesignColors.NS.textMuted)
    #expect(try attributedForeground(header) === WorkbenchRedesignColors.NS.textMuted)
    #expect(sequence.string == "37")
    #expect(try attributedForeground(sequence) === WorkbenchRedesignColors.NS.textMuted)
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
