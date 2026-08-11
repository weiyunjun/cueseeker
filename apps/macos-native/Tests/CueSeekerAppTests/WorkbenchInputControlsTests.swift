import AppKit
import Testing
@testable import CueSeekerApp

@Test
func textAreaScrollbarVisibilityMatchesInputRules() {
    #expect(!WorkbenchTextAreaScrollbarVisibility.isVisible(
        hasOverflow: false,
        isHovered: true,
        isScrolling: true,
        isDragging: true
    ))
    #expect(!WorkbenchTextAreaScrollbarVisibility.isVisible(
        hasOverflow: true,
        isHovered: false,
        isScrolling: false,
        isDragging: false
    ))
    #expect(WorkbenchTextAreaScrollbarVisibility.isVisible(
        hasOverflow: true,
        isHovered: true,
        isScrolling: false,
        isDragging: false
    ))
    #expect(WorkbenchTextAreaScrollbarVisibility.isVisible(
        hasOverflow: true,
        isHovered: false,
        isScrolling: true,
        isDragging: false
    ))
    #expect(WorkbenchTextAreaScrollbarVisibility.isVisible(
        hasOverflow: true,
        isHovered: false,
        isScrolling: false,
        isDragging: true
    ))
}

@MainActor
@Test
func textAreaUsesOneContentInsetWithoutNativeScrollbars() {
    let view = WorkbenchTextAreaContainerView(
        frame: CGRect(x: 0, y: 0, width: 340, height: 96)
    )
    view.layout()

    #expect(view.contentInsetForTesting == NSSize(width: 16, height: 10))
    #expect(view.lineFragmentPaddingForTesting == 0)
    #expect(view.textView.textContainerOrigin == NSPoint(x: 16, y: 10))
    #expect(!view.usesNativeScrollbarsForTesting)
}

@MainActor
@Test
func textAreaReportsFirstResponderChanges() {
    let view = WorkbenchTextAreaContainerView(
        frame: CGRect(x: 0, y: 0, width: 340, height: 96)
    )
    let window = NSWindow(
        contentRect: view.frame,
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = view

    var focusChanges: [Bool] = []
    view.textView.onFirstResponderChange = { focusChanges.append($0) }

    #expect(window.makeFirstResponder(view.textView))
    #expect(window.makeFirstResponder(nil))
    #expect(focusChanges == [true, false])
}

@MainActor
@Test
func textAreaScrollbarAppearsOnlyForOverflowAndHover() {
    let view = WorkbenchTextAreaContainerView(
        frame: CGRect(x: 0, y: 0, width: 340, height: 96)
    )
    view.layout()

    #expect(!view.hasVerticalOverflowForTesting)
    #expect(!view.isScrollbarVisibleForTesting)

    view.setText((1...20).map { "Line \($0)" }.joined(separator: "\n"))
    view.layout()

    #expect(view.hasVerticalOverflowForTesting)
    #expect(!view.isScrollbarVisibleForTesting)

    view.setScrollAreaHoveredForTesting(true)
    #expect(view.isScrollbarVisibleForTesting)

    view.setScrollAreaHoveredForTesting(false)
    #expect(!view.isScrollbarVisibleForTesting)
}
