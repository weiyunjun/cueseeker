import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct WorkbenchInputControlsTests {
    private final class StringBox: ObservableObject {
        @Published var text: String
        var submitCount = 0

        init(_ text: String = "") {
            self.text = text
        }
    }

    private struct SearchFieldHarness: View {
        @ObservedObject var box: StringBox

        var body: some View {
            WorkbenchSearchField(
                placeholder: "Search",
                text: $box.text,
                isRedesign: true,
                autofocus: false,
                trailingStatusText: "1/3",
                onSubmit: { box.submitCount += 1 }
            )
            .frame(width: 360)
        }
    }

    private struct FormFieldHarness: View {
        @ObservedObject var box: StringBox
        @FocusState private var isFocused: Bool

        var body: some View {
            WorkbenchFormTextField(
                label: "Name",
                placeholder: "Placeholder",
                text: $box.text,
                validationMessage: nil,
                focus: $isFocused
            )
            .frame(width: 320)
        }
    }

    private struct NumberFieldHarness: View {
        @ObservedObject var box: StringBox
        let normalizeDraft: (String) -> String
        let onCommit: () -> Void
        @FocusState private var isFocused: Bool

        var body: some View {
            WorkbenchNumberField(
                placeholder: "500",
                text: $box.text,
                unit: "ms",
                focus: $isFocused,
                normalizeDraft: normalizeDraft,
                onSubmit: onCommit
            )
            .frame(width: 114)
        }
    }

    private func collectEditableTextFields(in view: NSView) -> [NSTextField] {
        var result: [NSTextField] = []
        if let field = view as? NSTextField, field.isEditable {
            result.append(field)
        }
        for subview in view.subviews {
            result.append(contentsOf: collectEditableTextFields(in: subview))
        }
        return result
    }

    private func collectContainerOverlays(in view: NSView) -> [WorkbenchSingleLineContainerOverlayView] {
        var result: [WorkbenchSingleLineContainerOverlayView] = []
        if let overlay = view as? WorkbenchSingleLineContainerOverlayView {
            result.append(overlay)
        }
        for subview in view.subviews {
            result.append(contentsOf: collectContainerOverlays(in: subview))
        }
        return result
    }

    @Test
    func searchFieldKeepsHStackGeometryWhileNormalizingMultilineInputAndPreservingCursorOnReturn() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let box = StringBox("")
        let hostingView = NSHostingView(
            rootView: SearchFieldHarness(box: box)
                .frame(width: 500, height: 200)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 200)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        let field = try #require(collectEditableTextFields(in: hostingView).first)
        let overlay = try #require(collectContainerOverlays(in: hostingView).first)
        let pillRect = overlay.convert(overlay.bounds, to: nil)
        let initialFieldRect = field.convert(field.bounds, to: nil)

        // Verify text field starts after the leading magnifying glass icon and is vertically centered
        #expect(initialFieldRect.minX >= pillRect.minX + 40)
        #expect(abs(initialFieldRect.midY - pillRect.midY) <= 1.5)

        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)

        // Type/paste multiline text ( causing the clear button to appear in the HStack )
        editor.insertText("d'z'f大丈夫\r\n第二行\n第三行", replacementRange: editor.selectedRange())
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        #expect(editor.string == "d'z'f大丈夫 第二行 第三行")
        #expect(box.text == "d'z'f大丈夫 第二行 第三行")
        #expect(editor.selectedRange() == NSRange(location: editor.string.utf16.count, length: 0))

        // Verify geometry after clear button appears: field and active editor never jump to (0, 0) or overlap the icon
        let activeFieldRect = field.convert(field.bounds, to: nil)
        let activeEditorRect = editor.convert(editor.bounds, to: nil)
        #expect(activeFieldRect.minX >= pillRect.minX + 40)
        #expect(activeEditorRect.minX >= pillRect.minX + 40)
        #expect(abs(activeFieldRect.midY - pillRect.midY) <= 1.5)

        // Move caret to middle and press Return / Option+Return / Ctrl+Return
        editor.setSelectedRange(NSRange(location: 4, length: 0))
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(box.submitCount == 1)
        #expect(editor.selectedRange() == NSRange(location: 4, length: 0))

        editor.doCommand(by: #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)))
        editor.doCommand(by: #selector(NSResponder.insertLineBreak(_:)))
        editor.doCommand(by: #selector(NSResponder.insertParagraphSeparator(_:)))
        #expect(!editor.string.contains("\n"))
        #expect(editor.selectedRange() == NSRange(location: 4, length: 0))
    }

    @Test
    func numberFieldFiltersDisallowedCharactersAndNewlinesBeforeDisplayWithoutSelectingAllOnReturn() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let box = StringBox("500")
        let hostingView = NSHostingView(
            rootView: NumberFieldHarness(
                box: box,
                normalizeDraft: SettingsPlayCategory.normalizeGapDraft,
                onCommit: {
                    if let v = Int(box.text) {
                        box.text = String(SettingsStore.clampedAutoSwitchCueSequenceGapMilliseconds(v))
                    }
                }
            )
            .frame(width: 400, height: 200)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 200)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        let field = try #require(collectEditableTextFields(in: hostingView).first)
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)

        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        editor.insertText("12ab\n34ms", replacementRange: editor.selectedRange())
        #expect(editor.string == "1234")
        #expect(box.text == "1234")
        #expect(editor.selectedRange() == NSRange(location: 4, length: 0))

        // Out-of-range immediate clamp (> 10000 -> 10000)
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        editor.insertText("99999", replacementRange: editor.selectedRange())
        #expect(editor.string == "10000")
        #expect(box.text == "10000")

        // Pressing Return keeps caret at position without selecting all
        editor.setSelectedRange(NSRange(location: 2, length: 0))
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(editor.selectedRange() == NSRange(location: 2, length: 0))
    }

    @Test
    func containerOverlayProvidesIBeamAndClickToFocusAcrossPaddingWhileExcludingClearButton() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let box = StringBox("query")
        let hostingView = NSHostingView(
            rootView: SearchFieldHarness(box: box)
                .frame(width: 500, height: 200)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 200)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        let field = try #require(collectEditableTextFields(in: hostingView).first)
        let overlay = try #require(collectContainerOverlays(in: hostingView).first)

        // Leading icon area hits the overlay (which reports .iBeam and focuses field on mouseDown)
        let leadingPointInOverlay = NSPoint(x: 20, y: overlay.bounds.midY)
        let leadingHit = overlay.hitTest(overlay.superview!.convert(leadingPointInOverlay, from: overlay))
        #expect(leadingHit === overlay)
        #expect(overlay.pointerShape(atWindowPoint: overlay.convert(leadingPointInOverlay, to: nil)) == .iBeam)

        // Top edge padding hits the overlay
        let topEdgePointInOverlay = NSPoint(x: overlay.bounds.midX, y: 3)
        let topEdgeHit = overlay.hitTest(overlay.superview!.convert(topEdgePointInOverlay, from: overlay))
        #expect(topEdgeHit === overlay)

        // Trailing clear button area (24x24 inset by 14px from right) is excluded from the overlay
        let clearButtonPointInOverlay = NSPoint(
            x: overlay.bounds.width - 14 - 12,
            y: overlay.bounds.midY
        )
        let clearHit = overlay.hitTest(overlay.superview!.convert(clearButtonPointInOverlay, from: overlay))
        #expect(clearHit == nil)

        // Clicking on the leading icon area focuses the search field
        let nativeField = try #require(field as? WorkbenchNativeSingleLineTextField)
        #expect(!nativeField.isCurrentlyFocused)
        if let clickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: overlay.convert(leadingPointInOverlay, to: nil),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ) {
            overlay.mouseDown(with: clickEvent)
        }
        #expect(nativeField.isCurrentlyFocused)
    }
}
