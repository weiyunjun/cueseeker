import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func shioriDescriptionBoxEndsOnTheCoverBottom() {
    let formView = NSHostingView(
        rootView: ShioriFormHeightProbe()
            .frame(width: WorkbenchControlMetrics.redesignShioriListEditorWideFormWidth)
    )
    let coverView = NSHostingView(
        rootView: LibraryCoverFrame {
            Color.clear
        }
        .frame(width: WorkbenchControlMetrics.redesignShioriListEditorCoverWidth)
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
            height: WorkbenchControlMetrics.redesignShioriListEditorDescriptionHeight
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
            height: WorkbenchControlMetrics.redesignShioriListEditorDescriptionHeight
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
            height: WorkbenchControlMetrics.redesignShioriListEditorDescriptionHeight
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

private struct ShioriFormHeightProbe: View {
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
                height: WorkbenchControlMetrics.redesignShioriListEditorDescriptionHeight
            )
        }
    }
}
