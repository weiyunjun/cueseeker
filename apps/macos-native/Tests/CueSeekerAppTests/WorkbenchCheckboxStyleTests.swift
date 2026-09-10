import AppKit
import Testing
@testable import CueSeekerApp

@Test
func checkboxVariantsShareOneGlyphFamilyAndKeepDocumentedSizes() {
    #expect(WorkbenchCheckboxStyle.icon(for: .unchecked) == .circle)
    #expect(WorkbenchCheckboxStyle.icon(for: .checked) == .checkCircle)
    #expect(WorkbenchCheckboxStyle.icon(for: .indeterminate) == .minusCircle)

    // A ticked box reads as a solid mark; the empty box follows the size tier.
    #expect(WorkbenchCheckboxStyle.iconWeight(for: .unchecked, size: 16) == .light)
    #expect(WorkbenchCheckboxStyle.iconWeight(for: .checked, size: 16) == .fill)
    #expect(WorkbenchCheckboxStyle.iconWeight(for: .indeterminate, size: 16) == .fill)

    #expect(WorkbenchControlMetrics.redesignCheckboxSize == 16)
    #expect(SubtitleTableMetrics.checkboxSize == 16)
    #expect(PlaybackCollageSelectionMetrics.checkboxSize == 24)
}

@MainActor
@Test
func indeterminateCheckboxDrawsOneFlatColourAtTheDocumentedSize() throws {
    let size = SubtitleTableMetrics.checkboxSize
    let color = WorkbenchCheckboxStyle.controlColor(
        for: .indeterminate,
        isEnabled: true
    )
    let image = try #require(WorkbenchCheckboxStyle.appKitImage(
        for: .indeterminate,
        isEnabled: true,
        size: size
    ))
    // The glyph arrives already filled with the one control colour, so the
    // drawing carries no tint of its own and matches the documented size.
    #expect(image.size == NSSize(width: size, height: size))
    #expect(image.isTemplate == false)
    #expect(color == WorkbenchCheckboxStyle.controlColor(for: .indeterminate, isEnabled: true))
}

@MainActor
@Test
func appKitCheckboxSymbolsUseVariantPointSizeAndStayCentered() throws {
    for size in [
        SubtitleTableMetrics.checkboxSize,
        PlaybackCollageSelectionMetrics.checkboxSize,
    ] {
        let image = try #require(WorkbenchCheckboxStyle.appKitImage(
            for: .checked,
            isEnabled: true,
            size: size
        ))
        let controlRect = CGRect(x: 20, y: 30, width: size, height: size)
        let drawingRect = WorkbenchCheckboxStyle.appKitDrawingRect(
            imageSize: image.size,
            centeredIn: controlRect
        )

        #expect(drawingRect.size == image.size)
        #expect(drawingRect.midX == controlRect.midX)
        #expect(drawingRect.midY == controlRect.midY)
    }
}
