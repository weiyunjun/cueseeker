import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func dialogWidthIsItsTierNarrowedToWhatTheWindowLeaves() {
    #expect(dialogWidth(tier: 720, available: 1000) == 720)
    #expect(dialogWidth(tier: 720, available: 432) == 432)
}

@MainActor
@Test
func dialogColumnTakesItsContentsHeightWhenItFits() {
    let header: CGFloat = 40
    let footer: CGFloat = 40
    let gaps: CGFloat = 2 * 20
    #expect(dialogColumnHeight(content: 200, maxHeight: 1000) == header + 200 + footer + gaps)
}

@MainActor
@Test
func dialogColumnKeepsHeaderAndFooterAndScrollsTheRestWhenTooTall() {
    #expect(dialogColumnHeight(content: 600, maxHeight: 500) == 500)
}

@MainActor
private func dialogWidth(tier: CGFloat, available: CGFloat) -> CGFloat {
    let view = NSHostingView(
        rootView: Color.clear
            .frame(height: 10)
            .workbenchDialogWidth(tier)
            .environment(
                \.workbenchDialogAvailableSize,
                CGSize(width: available, height: 800)
            )
    )
    view.layoutSubtreeIfNeeded()
    return view.fittingSize.width
}

@MainActor
private func dialogColumnHeight(content: CGFloat, maxHeight: CGFloat) -> CGFloat {
    let view = NSHostingView(
        rootView: WorkbenchDialogColumn(spacing: 20, maxHeight: maxHeight) {
            Color.clear.frame(height: 40)

            WorkbenchScrollView {
                Color.clear.frame(height: content)
            }

            Color.clear.frame(height: 40)
        }
        .frame(width: 300)
    )
    view.layoutSubtreeIfNeeded()
    return view.fittingSize.height
}
