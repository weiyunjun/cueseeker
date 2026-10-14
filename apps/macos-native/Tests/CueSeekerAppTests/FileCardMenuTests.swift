import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite
@MainActor
struct FileCardMenuTests {
    @Test
    func fileCardMenuItemPropertiesAndActions() {
        var actionExecuted = false
        let renameItem = FileCardMenuItem(
            title: "Rename Folder",
            icon: .pencilSimple,
            isEnabled: true,
            isDestructive: false,
            action: {
                actionExecuted = true
            }
        )

        #expect(renameItem.title == "Rename Folder")
        #expect(renameItem.icon == .pencilSimple)
        #expect(renameItem.isEnabled == true)
        #expect(renameItem.isDestructive == false)
        #expect(renameItem.id == "Rename Folder")

        renameItem.action()
        #expect(actionExecuted == true)

        let removeItem = FileCardMenuItem(
            title: "Remove",
            icon: .minusCircle,
            isEnabled: false,
            isDestructive: true,
            action: {}
        )
        #expect(removeItem.title == "Remove")
        #expect(removeItem.icon == .minusCircle)
        #expect(removeItem.isEnabled == false)
        #expect(removeItem.isDestructive == true)
    }

    @Test
    func fileCardMenuPlacementBelowAndAbove() {
        let container = CGRect(x: 0, y: 0, width: 800, height: 600)
        let menuSize = CGSize(width: 160, height: 76)
        let gap: CGFloat = WorkbenchControlMetrics.redesignSpacing1

        // 1. Anchor button at top of container (plenty of room below)
        let topAnchor = CGRect(x: 700, y: 50, width: 32, height: 32)
        let topAnchorForPlacement = CGRect(
            x: topAnchor.maxX - menuSize.width,
            y: topAnchor.minY,
            width: menuSize.width,
            height: topAnchor.height
        )
        let frameBelow = MenuPlacement.openingFrame(
            anchor: topAnchorForPlacement,
            menuSize: menuSize,
            in: container,
            gap: gap,
            shrinksToFit: false
        )
        #expect(frameBelow.minY == topAnchor.maxY + gap)
        #expect(frameBelow.maxX <= container.maxX)
        #expect(frameBelow.minX >= container.minX)
        #expect(frameBelow.width == menuSize.width)
        #expect(frameBelow.height == menuSize.height)

        // 2. Anchor button near bottom of container (insufficient room below)
        let bottomAnchor = CGRect(x: 700, y: 560, width: 32, height: 32)
        let bottomAnchorForPlacement = CGRect(
            x: bottomAnchor.maxX - menuSize.width,
            y: bottomAnchor.minY,
            width: menuSize.width,
            height: bottomAnchor.height
        )
        let frameAbove = MenuPlacement.openingFrame(
            anchor: bottomAnchorForPlacement,
            menuSize: menuSize,
            in: container,
            gap: gap,
            shrinksToFit: false
        )
        #expect(frameAbove.maxY == bottomAnchor.minY - gap)
        #expect(frameAbove.minY >= container.minY)
        #expect(frameAbove.width == menuSize.width)
        #expect(frameAbove.height == menuSize.height)
    }

    @Test
    func fileCardColorTokensAndDotsThreeIcon() {
        // SettingsGroupBg (Display Title Episode Container)
        #expect(hexString(WorkbenchRedesignColors.NS.settingsGroupBg, appearance: .aqua) == "#F2F4F7")
        #expect(hexString(WorkbenchRedesignColors.NS.settingsGroupBg, appearance: .darkAqua) == "#242429")

        // TableBg (Card Normal)
        #expect(hexString(WorkbenchRedesignColors.NS.tableBg, appearance: .aqua) == "#FFFFFF")
        #expect(hexString(WorkbenchRedesignColors.NS.tableBg, appearance: .darkAqua) == "#2E2E34")

        // RowHover (Card Hover)
        #expect(hexString(WorkbenchRedesignColors.NS.rowHover, appearance: .aqua) == "#F9FAFB")
        #expect(hexString(WorkbenchRedesignColors.NS.rowHover, appearance: .darkAqua) == "#383840")

        // RowSelected (Button Hover / Open)
        #expect(hexString(WorkbenchRedesignColors.NS.rowSelected, appearance: .aqua) == "#ECEEF2")
        #expect(hexString(WorkbenchRedesignColors.NS.rowSelected, appearance: .darkAqua) == "#43434C")

        // Card chevron metric & icon assets resolve
        #expect(WorkbenchControlMetrics.redesignCardChevronSize == 16)
        let iconImage = AppIconStore.image(.dotsThree, size: WorkbenchControlMetrics.redesignControlIconSize)
        #expect(iconImage != nil)
        let chevronImage = AppIconStore.image(.caretRight, size: WorkbenchControlMetrics.redesignCardChevronSize)
        #expect(chevronImage != nil)
    }

    @Test
    func fileCardPopoverMenuRendersFittingSizeWithoutOverflow() {
        let highlight = MenuHighlightModel()
        let items = [
            FileCardMenuItem(
                title: "Rename Folder",
                icon: .pencilSimple,
                isEnabled: true,
                isDestructive: false,
                action: {}
            ),
            FileCardMenuItem(
                title: "Remove",
                icon: .minusCircle,
                isEnabled: true,
                isDestructive: true,
                action: {}
            )
        ]

        let popover = FileCardMenuPopover(
            items: items,
            highlight: highlight,
            onDismiss: {}
        )

        let host = NSHostingView(rootView: popover)
        host.layoutSubtreeIfNeeded()
        let fittingSize = host.fittingSize

        #expect(fittingSize.width >= 160)
        #expect(fittingSize.height > 60)
        #expect(fittingSize.height < 120)
    }

    @Test
    func fileCardTrailingIconButtonCenteringAndTopPinnedMetrics() {
        let baselineCardHeight = WorkbenchControlMetrics.redesignCardBaselineHeight
        let cardPadding = WorkbenchControlMetrics.redesignSpacing4
        let buttonSize = WorkbenchControlMetrics.redesignIconButtonSize
        let buttonTopOffset = WorkbenchControlMetrics.redesignCardTrailingIconButtonTopOffset

        // Top margin in baseline state
        let baselineTopMargin = cardPadding + buttonTopOffset
        // Bottom margin in baseline state
        let baselineBottomMargin = baselineCardHeight - (baselineTopMargin + buttonSize)

        // Baseline card must vertically center the 32px button (18px top, 18px bottom)
        #expect(baselineCardHeight == 68)
        #expect(buttonSize == 32)
        #expect(baselineTopMargin == 18)
        #expect(baselineBottomMargin == 18)
        #expect(baselineTopMargin == baselineBottomMargin)

        // Multi-line expanded card (e.g. text expands card height to 100px)
        let multiLineTopMargin = cardPadding + buttonTopOffset
        #expect(multiLineTopMargin == baselineTopMargin)
        #expect(multiLineTopMargin == 18)
    }
}

private func hexString(_ color: NSColor, appearance: NSAppearance.Name = .aqua) -> String {
    var resolved: NSColor?
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        resolved = color.usingColorSpace(.sRGB)
    }
    guard let srgb = resolved else {
        return ""
    }
    let red = Int((srgb.redComponent * 255).rounded())
    let green = Int((srgb.greenComponent * 255).rounded())
    let blue = Int((srgb.blueComponent * 255).rounded())
    return String(format: "#%02X%02X%02X", red, green, blue)
}
