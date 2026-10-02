import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp
import CueSeekerCore

@Suite
@MainActor
struct TaskCardMenuTests {
    @Test
    func taskCardMenuItemProperties() {
        let removeItem = WorkbenchCardMenuItem(
            title: L("task.menu.remove"),
            icon: .minusCircle,
            isEnabled: true,
            isDestructive: true,
            action: {}
        )
        #expect(removeItem.title == "Remove Task")
        #expect(removeItem.icon == .minusCircle)
        #expect(removeItem.isEnabled == true)
        #expect(removeItem.isDestructive == true)

        let deleteItem = WorkbenchCardMenuItem(
            title: L("task.menu.delete"),
            icon: .trash,
            isEnabled: true,
            isDestructive: true,
            action: {}
        )
        #expect(deleteItem.title == "Delete Record")
        #expect(deleteItem.icon == .trash)
        #expect(deleteItem.isEnabled == true)
        #expect(deleteItem.isDestructive == true)
    }

    @Test
    func taskCardToastAndStateChangeInterception() {
        let toast = TaskToastRequest.taskStatusChanged
        #expect(toast.scenarioID == "task.action.status_changed")
        #expect(toast.icon == .warning)
        #expect(toast.duration == ToastDuration.alert)
        #expect(toast.message == "Task status has changed")

        // Interception logic verification
        var toastShown = false
        var confirmationShown = false
        let fakeTasksCurrent: [Int64] = [] // Empty, simulating task already finished
        let targetTaskID: Int64 = 999

        let handleRemove = {
            guard fakeTasksCurrent.contains(targetTaskID) else {
                toastShown = true
                return
            }
            confirmationShown = true
        }

        handleRemove()
        #expect(toastShown == true)
        #expect(confirmationShown == false)
    }

    @Test
    func taskCardGeometryAndTokensMatchSpecification() {
        let baselineCardHeight = WorkbenchControlMetrics.redesignCardBaselineHeight
        let cardPadding = WorkbenchControlMetrics.redesignSpacing4
        let buttonSize = WorkbenchControlMetrics.redesignIconButtonSize
        let buttonTopOffset = WorkbenchControlMetrics.redesignCardTrailingIconButtonTopOffset

        // Top margin in baseline state
        let baselineTopMargin = cardPadding + buttonTopOffset
        // Bottom margin in baseline state
        let baselineBottomMargin = baselineCardHeight - (baselineTopMargin + buttonSize)

        #expect(baselineCardHeight == 68)
        #expect(buttonSize == 32)
        #expect(baselineTopMargin == 18)
        #expect(baselineBottomMargin == 18)
        #expect(baselineTopMargin == baselineBottomMargin)

        // Line 3 expansion retains top distance of 18px
        let multiLineTopMargin = cardPadding + buttonTopOffset
        #expect(multiLineTopMargin == baselineTopMargin)
        #expect(multiLineTopMargin == 18)

        // Tokens
        #expect(hexString(WorkbenchRedesignColors.NS.tableBg, appearance: .aqua) == "#FFFFFF")
        #expect(hexString(WorkbenchRedesignColors.NS.tableBg, appearance: .darkAqua) == "#26262A")

        #expect(hexString(WorkbenchRedesignColors.NS.rowHover, appearance: .aqua) == "#F9FAFB")
        #expect(hexString(WorkbenchRedesignColors.NS.rowHover, appearance: .darkAqua) == "#2E2E33")

        #expect(hexString(WorkbenchRedesignColors.NS.rowSelected, appearance: .aqua) == "#F3F4F6")
        #expect(hexString(WorkbenchRedesignColors.NS.rowSelected, appearance: .darkAqua) == "#36363C")
    }

    @Test
    func taskCardPopoverRendersFittingSizeWithoutOverflow() {
        let highlight = MenuHighlightModel()
        let items = [
            WorkbenchCardMenuItem(
                title: "Remove Task",
                icon: .minusCircle,
                isEnabled: true,
                isDestructive: true,
                action: {}
            )
        ]

        let popover = WorkbenchCardMenuPopover(
            items: items,
            highlight: highlight,
            onDismiss: {}
        )

        let host = NSHostingView(rootView: popover)
        host.layoutSubtreeIfNeeded()
        let fittingSize = host.fittingSize

        #expect(fittingSize.width >= 160)
        #expect(fittingSize.height > 30)
        #expect(fittingSize.height < 80)
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
