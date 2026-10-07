import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func excerptDescriptionBoxEndsOnTheCoverBottom() {
    let formView = NSHostingView(
        rootView: ExcerptFormHeightProbe()
            .frame(width: WorkbenchControlMetrics.redesignExcerptListEditorWideFormWidth)
    )
    let coverView = NSHostingView(
        rootView: LibraryCoverFrame {
            Color.clear
        }
        .frame(width: WorkbenchControlMetrics.redesignExcerptListEditorCoverWidth)
    )
    // The Description's reserved message line hangs below the box.
    let messageLineView = NSHostingView(
        rootView: Text("\u{00A0}")
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeCaption,
                weight: .regular
            ))
    )
    formView.layoutSubtreeIfNeeded()
    coverView.layoutSubtreeIfNeeded()
    messageLineView.layoutSubtreeIfNeeded()

    #expect(
        formView.fittingSize.height
            == coverView.fittingSize.height
            + WorkbenchControlMetrics.redesignSpacing1
            + messageLineView.fittingSize.height
    )
}

@MainActor
@Test
func textAreaUsesOneContentInsetWithoutNativeScrollbars() {
    let view = WorkbenchTextAreaContainerView(
        frame: CGRect(
            x: 0,
            y: 0,
            width: 340,
            height: WorkbenchControlMetrics.redesignExcerptListEditorDescriptionHeight
        )
    )
    view.configure(placeholder: "Description", isEnabled: true)
    view.layout()

    #expect(view.contentInsetForTesting == NSSize(width: 16, height: 10))
    #expect(view.lineFragmentPaddingForTesting == 0)
    #expect(view.textView.textContainerOrigin == NSPoint(x: 16, y: 10))
    #expect(
        view.textView.insertionPointColor.isEqual(
            WorkbenchRedesignColors.NS.borderFocus
        )
    )
    #expect(!view.usesNativeScrollbarsForTesting)
}

@MainActor
@Test
func textAreaReportsFirstResponderChanges() {
    let view = WorkbenchTextAreaContainerView(
        frame: CGRect(
            x: 0,
            y: 0,
            width: 340,
            height: WorkbenchControlMetrics.redesignExcerptListEditorDescriptionHeight
        )
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
func textAreaScrollbarPersistsOnlyWhileContentOverflows() {
    let view = WorkbenchTextAreaContainerView(
        frame: CGRect(
            x: 0,
            y: 0,
            width: 340,
            height: WorkbenchControlMetrics.redesignExcerptListEditorDescriptionHeight
        )
    )
    view.layout()

    #expect(!view.hasVerticalOverflowForTesting)
    #expect(!view.isScrollbarVisibleForTesting)

    view.setText((1...20).map { "Line \($0)" }.joined(separator: "\n"))
    view.layout()

    #expect(view.hasVerticalOverflowForTesting)
    #expect(view.isScrollbarVisibleForTesting)

    view.setText("")
    view.layout()

    #expect(!view.hasVerticalOverflowForTesting)
    #expect(!view.isScrollbarVisibleForTesting)
}

private struct ExcerptFormHeightProbe: View {
    @State private var name = ""
    @State private var description = ""
    @FocusState private var isNameFocused: Bool
    @FocusState private var isDescriptionFocused: Bool

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing2
        ) {
            WorkbenchFormTextField(
                label: "List Name",
                placeholder: "Enter a list name",
                text: $name,
                validationMessage: nil,
                focus: $isNameFocused
            )

            WorkbenchFormTextArea(
                label: "Description",
                placeholder: "Add a description (optional)",
                text: $description,
                validationMessage: nil,
                focus: $isDescriptionFocused,
                height: WorkbenchControlMetrics.redesignExcerptListEditorDescriptionHeight
            )
        }
    }
}

@MainActor
@Test
func singleLineTextInputUsesNativePrompt() {
    let hostingView = NSHostingView(rootView: SingleLineInputProbe())
    hostingView.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
    hostingView.layoutSubtreeIfNeeded()

    func findTextField(in view: NSView) -> NSTextField? {
        if let tf = view as? NSTextField { return tf }
        for subview in view.subviews {
            if let found = findTextField(in: subview) { return found }
        }
        return nil
    }

    let textField = findTextField(in: hostingView)
    #expect(textField != nil)
    #expect(textField?.placeholderString == "Search keywords...")
}

private struct SingleLineInputProbe: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        WorkbenchSingleLineTextInput(
            placeholder: "Search keywords...",
            text: $text,
            placeholderColor: .gray,
            textColor: .black,
            fontSize: 14,
            focus: $isFocused,
            accessibilityLabel: "Search"
        )
    }
}
