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
func subtitleTableTextUsesRedesignVisualHierarchy() throws {
    let primary = SubtitleTableText.body(
        "cue",
        role: .primaryContent,
        isRedesign: true
    )
    let hoveredPrimary = SubtitleTableText.body(
        "cue",
        role: .primaryContent,
        isRedesign: true,
        foregroundColor: WorkbenchRedesignColors.NS.textPrimary
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
    let header = SubtitleTableText.header("Cues", isRedesign: true)

    let primaryFont = try attributedFont(primary)
    let secondaryFont = try attributedFont(secondary)
    let metadataFont = try attributedFont(metadata)
    let headerFont = try attributedFont(header)

    #expect(primaryFont.pointSize == WorkbenchControlMetrics.redesignFontSizeTable)
    #expect(secondaryFont.pointSize == WorkbenchControlMetrics.redesignFontSizeTable)
    #expect(metadataFont.pointSize == WorkbenchControlMetrics.redesignFontSizeTable)
    #expect(headerFont.pointSize == WorkbenchControlMetrics.redesignFontSizeTableHeader)
    #expect(fontWeight(primaryFont) == fontWeight(secondaryFont))
    #expect(fontWeight(secondaryFont) == fontWeight(metadataFont))
    #expect(metadataFont.fontDescriptor == NSFont.monospacedDigitSystemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
        weight: .medium
    ).fontDescriptor)

    #expect(try attributedForeground(primary) === WorkbenchRedesignColors.NS.textSecondary)
    #expect(try attributedForeground(hoveredPrimary) === WorkbenchRedesignColors.NS.textPrimary)
    #expect(try attributedForeground(secondary) === WorkbenchRedesignColors.NS.textSecondary)
    #expect(try attributedForeground(metadata) === WorkbenchRedesignColors.NS.textSecondary)
    #expect(try attributedForeground(header) === WorkbenchRedesignColors.NS.textPrimary)
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
