import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerCore
@testable import CueSeekerPlayback
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
                onEditingEnded: onCommit,
                onSubmit: onCommit
            )
            .frame(width: 114)
        }
    }

    private final class SubtitleValueBox: ObservableObject {
        @Published var size: Double = 28
        @Published var letterSpacing: Double = 0
        @Published var textColor: SRTSubtitleStyle.Color = SRTSubtitleStyle.Color(red: 1, green: 1, blue: 1, alpha: 1)
        @Published var isColorPopoverOpen: Bool = false
    }

    private struct SubtitleNumberFieldsHarness: View {
        @ObservedObject var box: SubtitleValueBox

        var body: some View {
            VStack(spacing: 12) {
                SettingsSubtitleNumberField(
                    value: $box.size,
                    minimum: SRTSubtitleStyle.minimumSize,
                    maximum: SettingsSubtitleBounds.sizeMaximum
                )
                SettingsSubtitleNumberField(
                    value: $box.letterSpacing,
                    minimum: SettingsSubtitleBounds.spacingMinimum,
                    maximum: SettingsSubtitleBounds.spacingMaximum
                )
                SettingsSubtitleColorField(
                    color: $box.textColor,
                    accessibilityLabel: "Color",
                    isPopoverOpen: $box.isColorPopoverOpen
                )
            }
            .padding(16)
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
        editor.insertText("12ab34ms", replacementRange: editor.selectedRange())
        #expect(editor.string == "1234")
        #expect(box.text == "1234")
        #expect(editor.selectedRange() == NSRange(location: 4, length: 0))

        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        editor.insertText("12ab\n34ms", replacementRange: editor.selectedRange())
        #expect(editor.string == "12")
        #expect(box.text == "12")
        #expect(editor.selectedRange() == NSRange(location: 2, length: 0))

        // Out-of-range immediate clamp (> 10000 -> 10000), including ultra-long strings with dots
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        editor.insertText("", replacementRange: editor.selectedRange())
        #expect(editor.string.isEmpty)

        editor.insertText("2026101420.21.042", replacementRange: editor.selectedRange())
        #expect(editor.string == "10000")
        #expect(box.text == "10000")
        let editorFontAfterNormalize = editor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(editorFontAfterNormalize?.pointSize == WorkbenchControlMetrics.redesignFontSizeControl)

        // Overflowing >19-digit string also clamps to 10000
        editor.insertText("2026101420.21.042", replacementRange: NSRange(location: editor.string.utf16.count, length: 0))
        #expect(editor.string == "10000")
        #expect(box.text == "10000")

        // Pressing Return keeps caret at position without selecting all
        editor.setSelectedRange(NSRange(location: 2, length: 0))
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(editor.selectedRange() == NSRange(location: 2, length: 0))
    }

    @Test
    func emptyTextFieldPreservesFontSizeWhenNormalizingMultilineInputAndSubtitleFieldsRestoreOnInvalidInput() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // 1. Empty form text field receiving "1\n2" preserves 14pt font in active field editor
        let textBox = StringBox("")
        let textHosting = NSHostingView(
            rootView: FormFieldHarness(box: textBox)
                .frame(width: 400, height: 120)
        )
        textHosting.frame = NSRect(x: 0, y: 0, width: 400, height: 120)
        window.contentView = textHosting
        textHosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        let textField = try #require(collectEditableTextFields(in: textHosting).first)
        #expect(window.makeFirstResponder(textField))
        let textEditor = try #require(textField.currentEditor() as? NSTextView)
        textEditor.insertText("1\n2", replacementRange: textEditor.selectedRange())
        #expect(textEditor.string == "1 2")
        let activeFont = textEditor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(activeFont?.pointSize == WorkbenchControlMetrics.redesignFontSizeControl)

        // 2. Subtitle number fields truncate at '.' and newline, clamp immediately at maximum, do nothing on Return, and restore/clamp on blur
        let subtitleBox = SubtitleValueBox()
        let subtitleHosting = NSHostingView(
            rootView: SubtitleNumberFieldsHarness(box: subtitleBox)
                .frame(width: 400, height: 260)
        )
        subtitleHosting.frame = NSRect(x: 0, y: 0, width: 400, height: 260)
        window.contentView = subtitleHosting
        subtitleHosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        let subtitleFields = collectEditableTextFields(in: subtitleHosting)
        #expect(subtitleFields.count == 3)
        let sizeField = subtitleFields[0]
        let letterSpacingField = subtitleFields[1]
        let colorField = subtitleFields[2]

        #expect(window.makeFirstResponder(sizeField))
        let sizeEditor = try #require(sizeField.currentEditor() as? NSTextView)
        #expect(sizeEditor.string == "28")

        // Selecting all and typing purely invalid characters (".", "-", "abc") does not wipe "28"
        sizeEditor.setSelectedRange(NSRange(location: 0, length: sizeEditor.string.utf16.count))
        sizeEditor.insertText(".-abc", replacementRange: sizeEditor.selectedRange())
        #expect(sizeEditor.string == "28")
        #expect(subtitleBox.size == 28)

        // Clearing to empty and losing focus to another field restores "28"
        sizeEditor.setSelectedRange(NSRange(location: 0, length: sizeEditor.string.utf16.count))
        sizeEditor.insertText("", replacementRange: sizeEditor.selectedRange())
        #expect(sizeEditor.string.isEmpty)
        #expect(window.makeFirstResponder(letterSpacingField))
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        #expect(sizeField.stringValue == "28")
        #expect(subtitleBox.size == 28)

        // Letter spacing truncates at '.' and newline, and strips '-'
        let spacingEditor = try #require(letterSpacingField.currentEditor() as? NSTextView)
        spacingEditor.setSelectedRange(NSRange(location: 0, length: spacingEditor.string.utf16.count))
        spacingEditor.insertText("-12.5", replacementRange: spacingEditor.selectedRange())
        #expect(spacingEditor.string == "12")
        #expect(subtitleBox.letterSpacing == 12)

        spacingEditor.setSelectedRange(NSRange(location: 0, length: spacingEditor.string.utf16.count))
        spacingEditor.insertText("34\n56", replacementRange: spacingEditor.selectedRange())
        #expect(spacingEditor.string == "34")
        #expect(subtitleBox.letterSpacing == 34)

        // Exceeding maximum (Size max = 200) clamps immediately to "200"
        #expect(window.makeFirstResponder(sizeField))
        let sizeEditorAgain = try #require(sizeField.currentEditor() as? NSTextView)
        sizeEditorAgain.setSelectedRange(NSRange(location: 0, length: sizeEditorAgain.string.utf16.count))
        sizeEditorAgain.insertText("250", replacementRange: sizeEditorAgain.selectedRange())
        #expect(sizeEditorAgain.string == "200")
        #expect(subtitleBox.size == 200)

        // Typing "0" in Size (minimum: 1): pressing Return performs no action; blurring clamps to "1"
        sizeEditorAgain.setSelectedRange(NSRange(location: 0, length: sizeEditorAgain.string.utf16.count))
        sizeEditorAgain.insertText("0", replacementRange: sizeEditorAgain.selectedRange())
        #expect(sizeEditorAgain.string == "0")
        sizeEditorAgain.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(sizeEditorAgain.string == "0")
        #expect(window.makeFirstResponder(letterSpacingField))
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        #expect(sizeField.stringValue == "1")
        #expect(subtitleBox.size == 1)

        // 3. Color hex field supports 6-digit live apply, 3-digit commit without expanding to 6 digits, 4-digit truncation to 3 digits on blur, 0-2 digit restore on blur, and '#' stripping / newline & dot truncation on paste
        let subtitleOverlays = collectContainerOverlays(in: subtitleHosting)
        let colorOverlay = try #require(subtitleOverlays.last { $0.onPressRelease != nil })
        let swatchPointInWindow = colorOverlay.convert(NSPoint(x: 10, y: colorOverlay.bounds.midY), to: nil)
        let outsidePointInWindow = colorOverlay.convert(NSPoint(x: -10, y: -10), to: nil)
        let downEvent = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: swatchPointInWindow,
            modifierFlags: [],
            timestamp: 1,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        let outsideUpEvent = try #require(NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: outsidePointInWindow,
            modifierFlags: [],
            timestamp: 2,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 0
        ))
        let insideUpEvent = try #require(NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: swatchPointInWindow,
            modifierFlags: [],
            timestamp: 3,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 0
        ))
        colorOverlay.mouseDown(with: downEvent)
        #expect(!subtitleBox.isColorPopoverOpen)
        colorOverlay.mouseUp(with: outsideUpEvent)
        #expect(!subtitleBox.isColorPopoverOpen)

        colorOverlay.mouseDown(with: downEvent)
        #expect(!subtitleBox.isColorPopoverOpen)
        colorOverlay.mouseUp(with: insideUpEvent)
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        #expect(subtitleBox.isColorPopoverOpen)
        let colorEditor = try #require(colorField.currentEditor() as? NSTextView)
        #expect(colorEditor.string == "FFFFFF")

        // Paste "#f0a" (3-digit hex with '#'): strips '#' and uppercases to "F0A"; on blur stays "F0A" (not expanded to "FF00AA")
        colorEditor.setSelectedRange(NSRange(location: 0, length: colorEditor.string.utf16.count))
        colorEditor.insertText("#f0a", replacementRange: colorEditor.selectedRange())
        #expect(colorEditor.string == "F0A")
        #expect(window.makeFirstResponder(sizeField))
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        #expect(colorField.stringValue == "F0A")
        #expect(abs(subtitleBox.textColor.red - 1.0) < 0.001)
        #expect(abs(subtitleBox.textColor.green - 0.0) < 0.001)
        #expect(abs(subtitleBox.textColor.blue - (10.0 * 17.0 / 255.0)) < 0.001)

        // Type 4-digit hex "1234" and blur -> truncates to first 3 digits "123"
        #expect(window.makeFirstResponder(colorField))
        let colorEditor4 = try #require(colorField.currentEditor() as? NSTextView)
        colorEditor4.setSelectedRange(NSRange(location: 0, length: colorEditor4.string.utf16.count))
        colorEditor4.insertText("1234", replacementRange: colorEditor4.selectedRange())
        #expect(colorEditor4.string == "1234")
        #expect(window.makeFirstResponder(sizeField))
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        #expect(colorField.stringValue == "123")

        // Type 2-digit hex "AB" and blur -> restores previous valid hex "123"
        #expect(window.makeFirstResponder(colorField))
        let colorEditor2 = try #require(colorField.currentEditor() as? NSTextView)
        colorEditor2.setSelectedRange(NSRange(location: 0, length: colorEditor2.string.utf16.count))
        colorEditor2.insertText("AB", replacementRange: colorEditor2.selectedRange())
        #expect(colorEditor2.string == "AB")
        #expect(window.makeFirstResponder(sizeField))
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        #expect(colorField.stringValue == "123")

        // Paste "#00ff00.extra\nline" -> strips '#', truncates at '.', applies 6-digit "00FF00" immediately
        #expect(window.makeFirstResponder(colorField))
        let colorEditor6 = try #require(colorField.currentEditor() as? NSTextView)
        colorEditor6.setSelectedRange(NSRange(location: 0, length: colorEditor6.string.utf16.count))
        colorEditor6.insertText("#00ff00.extra\nline", replacementRange: colorEditor6.selectedRange())
        #expect(colorEditor6.string == "00FF00")
        #expect(abs(subtitleBox.textColor.red - 0.0) < 0.001)
        #expect(abs(subtitleBox.textColor.green - 1.0) < 0.001)
        #expect(abs(subtitleBox.textColor.blue - 0.0) < 0.001)

        // 4. Font menu options place System Font first followed by sorted system font families
        let sampleFonts: [SettingsSubtitleFontOption] = [
            SettingsSubtitleFontOption(id: "Helvetica Neue", title: "Helvetica Neue", fontName: "Helvetica Neue"),
            SettingsSubtitleFontOption(id: "PingFang SC", title: "PingFang SC", fontName: "PingFang SC"),
            SettingsSubtitleFontOption(id: "SF Mono", title: "SF Mono", fontName: "SF Mono"),
        ]
        let menuOptions = SettingsSubtitleCategory.menuOptions(
            availableFonts: sampleFonts,
            systemFontTitle: "System Font"
        )
        #expect(menuOptions.count == 4)
        #expect(menuOptions.first?.fontName == nil)
        #expect(menuOptions.first?.title == "System Font")
        #expect(menuOptions.dropFirst().map(\.title) == ["Helvetica Neue", "PingFang SC", "SF Mono"])
        #expect(SettingsSubtitleCategory.option(at: 0, availableFonts: sampleFonts, systemFontTitle: "System Font")?.fontName == nil)
        #expect(SettingsSubtitleCategory.option(at: 2, availableFonts: sampleFonts, systemFontTitle: "System Font")?.title == "PingFang SC")
        #expect(SettingsSubtitleCategory.option(at: 99, availableFonts: sampleFonts, systemFontTitle: "System Font") == nil)
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

        // Clicking on the top edge padding above the middle of "query" places caret at horizontal position, not index 0
        let editor = try #require(nativeField.currentEditor() as? NSTextView)
        let midTextPointInField = NSPoint(x: 24, y: nativeField.bounds.midY)
        let midTextWindowX = nativeField.convert(midTextPointInField, to: nil).x
        let topPaddingWindowPoint = NSPoint(
            x: midTextWindowX,
            y: overlay.convert(NSPoint(x: 0, y: 2), to: nil).y
        )
        if let topClickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: topPaddingWindowPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1
        ) {
            overlay.mouseDown(with: topClickEvent)
        }
        let expectedIndex = editor.characterIndexForInsertion(
            at: NSPoint(x: midTextPointInField.x, y: editor.bounds.midY)
        )
        #expect(expectedIndex > 0 && expectedIndex < box.text.count)
        #expect(editor.selectedRange() == NSRange(location: expectedIndex, length: 0))
    }

    @Test
    func singleLineInputKeepsIdenticalClipBoundsAndGlyphPositionAcrossFocusAndOverflowStates() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 220))
        window.contentView = container

        let wideField = WorkbenchNativeSingleLineTextField(frame: NSRect(x: 20, y: 140, width: 240, height: 17))
        wideField.font = .monospacedDigitSystemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
        wideField.textColor = .white
        wideField.alignment = .left
        wideField.stringValue = "1234567890"
        container.addSubview(wideField)

        let narrowLeftField = WorkbenchNativeSingleLineTextField(frame: NSRect(x: 20, y: 90, width: 62, height: 17))
        narrowLeftField.font = .monospacedDigitSystemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
        narrowLeftField.textColor = .white
        narrowLeftField.alignment = .left
        narrowLeftField.stringValue = "20261014202"
        container.addSubview(narrowLeftField)

        let narrowRightField = WorkbenchNativeSingleLineTextField(frame: NSRect(x: 20, y: 40, width: 62, height: 17))
        narrowRightField.font = .monospacedDigitSystemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
        narrowRightField.textColor = .white
        narrowRightField.alignment = .right
        narrowRightField.stringValue = "36"
        container.addSubview(narrowRightField)

        container.layoutSubtreeIfNeeded()

        func glyphSpanX(in field: NSView) throws -> ClosedRange<Int> {
            let rep = try #require(field.bitmapImageRepForCachingDisplay(in: field.bounds))
            field.cacheDisplay(in: field.bounds, to: rep)
            var minX = Int.max
            var maxX = Int.min
            for y in 0..<rep.pixelsHigh {
                for x in 0..<rep.pixelsWide {
                    if let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.1 {
                        minX = min(minX, x)
                        maxX = max(maxX, x)
                    }
                }
            }
            #expect(minX <= maxX)
            return minX...maxX
        }

        // Capture unfocused glyph spans
        let unfocusedLeftOverflowSpan = try glyphSpanX(in: narrowLeftField)
        let unfocusedRightShortSpan = try glyphSpanX(in: narrowRightField)

        // Focus wide field first, then switch focus to narrow right-aligned field ("36")
        #expect(window.makeFirstResponder(wideField))
        #expect(window.makeFirstResponder(narrowRightField))
        let rightEditor = try #require(narrowRightField.currentEditor() as? NSTextView)
        let rightClipView = try #require(rightEditor.superview as? NSClipView)
        #expect(rightClipView.frame == narrowRightField.bounds)
        #expect(rightClipView.bounds.origin == .zero)
        #expect(rightEditor.frame.width == narrowRightField.bounds.width)
        rightEditor.setSelectedRange(NSRange(location: 0, length: 0))
        rightEditor.insertionPointColor = .clear
        let focusedRightShortSpan = try glyphSpanX(in: narrowRightField)
        #expect(focusedRightShortSpan == unfocusedRightShortSpan)

        // Switch focus to narrow left-aligned overflowing field ("20261014202")
        #expect(window.makeFirstResponder(narrowLeftField))
        let leftEditor = try #require(narrowLeftField.currentEditor() as? NSTextView)
        let leftClipView = try #require(leftEditor.superview as? NSClipView)
        #expect(leftClipView.frame == narrowLeftField.bounds)
        leftEditor.setSelectedRange(NSRange(location: 0, length: 0))
        leftEditor.scrollRangeToVisible(NSRange(location: 0, length: 0))
        leftEditor.insertionPointColor = .clear
        #expect(leftClipView.bounds.origin == .zero)
        let focusedLeftOverflowSpan = try glyphSpanX(in: narrowLeftField)
        #expect(focusedLeftOverflowSpan == unfocusedLeftOverflowSpan)

        // Switch focus to narrow right-aligned field across all lengths 1...20 and verify 0 pixel diff between unfocused and focused
        let baseDigits = "20261014202104289123"
        for len in 1...20 {
            _ = window.makeFirstResponder(nil)
            let sample = String(baseDigits.prefix(len))
            narrowRightField.stringValue = sample

            let unfocusedRep = try #require(narrowRightField.bitmapImageRepForCachingDisplay(in: narrowRightField.bounds))
            narrowRightField.cacheDisplay(in: narrowRightField.bounds, to: unfocusedRep)

            #expect(window.makeFirstResponder(narrowRightField))
            let roEditor = try #require(narrowRightField.currentEditor() as? NSTextView)
            let roClipView = try #require(roEditor.superview as? NSClipView)
            #expect(roClipView.frame == narrowRightField.bounds)
            #expect(roClipView.bounds.origin == .zero)
            roEditor.setSelectedRange(NSRange(location: 0, length: 0))
            roEditor.insertionPointColor = .clear

            let focusedRep = try #require(narrowRightField.bitmapImageRepForCachingDisplay(in: narrowRightField.bounds))
            narrowRightField.cacheDisplay(in: narrowRightField.bounds, to: focusedRep)

            var diffPixels = 0
            for y in 0..<unfocusedRep.pixelsHigh {
                for x in 0..<unfocusedRep.pixelsWide {
                    let a0 = unfocusedRep.colorAt(x: x, y: y)?.alphaComponent ?? 0
                    let a1 = focusedRep.colorAt(x: x, y: y)?.alphaComponent ?? 0
                    if abs(a0 - a1) > 0.05 {
                        diffPixels += 1
                    }
                }
            }
            #expect(diffPixels == 0)
        }
    }

    @Test
    func ankiExportDialogNeverLeavesTwoInputsFocusedAfterMenuOpenAndDismiss() throws {
        _ = NSApplication.shared
        let layers = InterfaceLayerRegistry()
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isFocusLocked = { layers.hasUncoveredOpenMenu }

        let session = AnkiExportSession(
            items: [],
            options: AnkiExportOptions(),
            folderURL: URL(fileURLWithPath: "/tmp"),
            onOptionsChange: { _ in }
        )
        let hostingView = NSHostingView(
            rootView: AnkiExportDialog(
                session: session,
                menuGate: layers.menuGate,
                onChooseFolder: {},
                onExport: {},
                onClose: {}
            )
            .frame(width: 800, height: 700)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 800, height: 700)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let fields = collectEditableTextFields(in: hostingView)
            .compactMap { $0 as? WorkbenchNativeSingleLineTextField }
        #expect(fields.count == 2)
        let fileNameField = fields[0]
        let locationField = fields[1]

        var fileNameFocusedStates: [Bool] = []
        var locationFocusedStates: [Bool] = []
        let origFileNameOnFocus = fileNameField.onFocusChange
        fileNameField.onFocusChange = { focused in
            fileNameFocusedStates.append(focused)
            origFileNameOnFocus?(focused)
        }
        let origLocationOnFocus = locationField.onFocusChange
        locationField.onFocusChange = { focused in
            locationFocusedStates.append(focused)
            origLocationOnFocus?(focused)
        }

        let overlays = collectContainerOverlays(in: hostingView)
        #expect(overlays.count == 2)
        let fileNameOverlay = overlays[0]
        let locationOverlay = overlays[1]

        // 1. Click first input (File Name) via container overlay mouseDown without typing
        if let clickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: fileNameOverlay.convert(NSPoint(x: 4, y: fileNameOverlay.bounds.midY), to: nil),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 10,
            clickCount: 1,
            pressure: 1
        ) {
            fileNameOverlay.mouseDown(with: clickEvent)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(fileNameField.isCurrentlyFocused)
        #expect(!locationField.isCurrentlyFocused)
        #expect(fileNameFocusedStates.last == true)

        // 2. Simulate opening menu via MenuGate (which calls window.makeFirstResponder(nil))
        let menuSession = layers.menuGate.open(MenuGate.Client(
            owner: .dialog,
            kind: .cardMenu,
            window: { window },
            isPointerOnMenu: { _ in false },
            handleKey: { _, _ in false },
            dismiss: { _ in }
        ))
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(!fileNameField.isCurrentlyFocused)
        #expect(!locationField.isCurrentlyFocused)
        #expect(fileNameFocusedStates.last == false)

        // 3. Close menu
        menuSession.close()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        // 4. Click second input (Location) via container overlay mouseDown
        if let clickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: locationOverlay.convert(NSPoint(x: 4, y: locationOverlay.bounds.midY), to: nil),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 12,
            clickCount: 1,
            pressure: 1
        ) {
            locationOverlay.mouseDown(with: clickEvent)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(!fileNameField.isCurrentlyFocused)
        #expect(locationField.isCurrentlyFocused)
        #expect(fileNameFocusedStates.last == false)
        #expect(locationFocusedStates.last == true)
    }

    @Test
    func subtitleFontMenuFollowsStandardDropdownStructureVirtualizesHundredsOfFontsAndRevealsKeyboardHighlight() throws {
        _ = NSApplication.shared
        let manyFonts = (0..<500).map { index in
            let name = String(format: "Font Family %03d", index)
            return SettingsSubtitleFontOption(id: name, title: name, fontName: name)
        }
        let metrics = SettingsSubtitleFontMenu.measureMetrics(
            systemFontTitle: "System Font",
            availableFonts: manyFonts
        )
        #expect(metrics.itemStackWidth > 100)
        #expect(metrics.dividerHeight >= 9)

        let panelSize = SettingsSubtitleFontMenu.panelSize(
            availableFontCount: manyFonts.count,
            itemStackWidth: metrics.itemStackWidth,
            dividerHeight: metrics.dividerHeight,
            maximumHeight: MenuMetrics.maximumHeight
        )
        #expect(panelSize.height == MenuMetrics.maximumHeight)
        #expect(panelSize.width == ceil(metrics.itemStackWidth) + MenuMetrics.padding * 2 + MenuMetrics.scrollbarStrip)

        // Position hit-testing: System Font is at 0, Divider returns nil, font rows start at 1
        let midX = MenuMetrics.padding + metrics.itemStackWidth / 2
        #expect(
            SettingsSubtitleFontMenu.positionInDocument(
                at: CGPoint(x: midX, y: MenuMetrics.padding + 10),
                availableFontCount: manyFonts.count,
                itemStackWidth: metrics.itemStackWidth,
                dividerHeight: metrics.dividerHeight
            ) == 0
        )
        let dividerMidY = MenuMetrics.padding + WorkbenchControlMetrics.redesignMenuItemHeight + metrics.dividerHeight / 2
        #expect(
            SettingsSubtitleFontMenu.positionInDocument(
                at: CGPoint(x: midX, y: dividerMidY),
                availableFontCount: manyFonts.count,
                itemStackWidth: metrics.itemStackWidth,
                dividerHeight: metrics.dividerHeight
            ) == nil
        )
        let firstFontMidY = MenuMetrics.padding
            + WorkbenchControlMetrics.redesignMenuItemHeight
            + metrics.dividerHeight
            + 10
        #expect(
            SettingsSubtitleFontMenu.positionInDocument(
                at: CGPoint(x: midX, y: firstFontMidY),
                availableFontCount: manyFonts.count,
                itemStackWidth: metrics.itemStackWidth,
                dividerHeight: metrics.dividerHeight
            ) == 1
        )

        let highlight = MenuHighlightModel()
        highlight.open(selectablePositions: Array(0...manyFonts.count))
        #expect(highlight.highlightedPosition == nil)

        let scrollController = WorkbenchScrollViewController()
        let menu = SettingsSubtitleFontMenu(
            systemFontTitle: "System Font",
            availableFonts: manyFonts,
            selectedFontName: nil,
            maximumHeight: MenuMetrics.maximumHeight,
            itemStackWidth: metrics.itemStackWidth,
            dividerHeight: metrics.dividerHeight,
            highlight: highlight,
            scrollController: scrollController,
            onSelect: { _ in }
        )

        // Virtualized window mounts only a small slice rather than all 500 fonts
        #expect(menu.mountedFontRangeForTesting.count < 45)

        let window = CueSeekerWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let hostingView = NSHostingView(
            rootView: ZStack(alignment: .topLeading) {
                Color.clear
                menu
            }
            .frame(width: 400, height: 600)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        // No embedded search field inside the redesigned font menu
        #expect(collectEditableTextFields(in: hostingView).isEmpty)
        #expect(scrollController.currentOffsetY == 0)

        // Pressing Up when nothing is highlighted jumps to the last font (position 500)
        // and scrolls the virtualized list to the bottom without animation.
        #expect(highlight.moveHighlight(by: -1))
        #expect(highlight.highlightedPosition == 500)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(scrollController.currentOffsetY > 10_000)
    }

    @Test
    func clickingOverflowingInputDoesNotSelectAllOrJumpScrollAndSupportsMultiClickDragAndRightClick() throws {
        _ = NSApplication.shared
        let window = CueSeekerWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let longText = "alpha bravo charlie delta echo foxtrot golf hotel india juliet"
        let box = StringBox(longText)
        let hostingView = NSHostingView(
            rootView: FormFieldHarness(box: box)
                .frame(width: 180)
                .frame(width: 420, height: 220)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 420, height: 220)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        let field = try #require(collectEditableTextFields(in: hostingView).first as? WorkbenchNativeSingleLineTextField)
        let overlay = try #require(collectContainerOverlays(in: hostingView).first)
        #expect(!field.isCurrentlyFocused)

        // 1. Clicking near the left padding on an overflowing input focuses without Select-All or horizontal scroll jump
        let clickNearLeft = overlay.convert(NSPoint(x: 6, y: overlay.bounds.midY), to: nil)
        let down1 = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: clickNearLeft,
            modifierFlags: [],
            timestamp: 1,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        window.sendEvent(down1)
        overlay.mouseDown(with: down1)
        #expect(field.isCurrentlyFocused)
        let editor = try #require(field.currentEditor() as? NSTextView)
        let clipView = try #require(editor.superview as? NSClipView)
        #expect(clipView.bounds.origin == .zero)
        #expect(editor.selectedRange() == NSRange(location: 0, length: 0))

        // 2. Dragging from left padding to the right and releasing outside the container retains focus and selection
        let dragMidPoint = field.convert(NSPoint(x: 45, y: field.bounds.midY), to: nil)
        let dragEvent = try #require(NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: dragMidPoint,
            modifierFlags: [],
            timestamp: 2,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        overlay.mouseDragged(with: dragEvent)
        let draggedSelection = editor.selectedRange()
        #expect(draggedSelection.location == 0 && draggedSelection.length > 2)

        let releaseOutsideEvent = try #require(NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: 5, y: 5),
            modifierFlags: [],
            timestamp: 3,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 0
        ))
        window.sendEvent(releaseOutsideEvent)
        #expect(field.isCurrentlyFocused)
        #expect(editor.selectedRange() == draggedSelection)

        // 3. Double-clicking selects word; triple-clicking selects entire line
        let doubleClickEvent = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: clickNearLeft,
            modifierFlags: [],
            timestamp: 4,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 2,
            pressure: 1
        ))
        overlay.mouseDown(with: doubleClickEvent)
        #expect(editor.selectedRange().length > 0 && editor.selectedRange().length < longText.utf16.count)

        let tripleClickEvent = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: clickNearLeft,
            modifierFlags: [],
            timestamp: 5,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 3,
            clickCount: 3,
            pressure: 1
        ))
        overlay.mouseDown(with: tripleClickEvent)
        #expect(editor.selectedRange() == NSRange(location: 0, length: longText.utf16.count))

        // 4. Right-clicking inside an already-focused input keeps focus and preserves selection
        let rightClickInsideField = field.convert(NSPoint(x: 20, y: field.bounds.midY), to: nil)
        let rightDownInside = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: rightClickInsideField,
            modifierFlags: [],
            timestamp: 6,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 4,
            clickCount: 1,
            pressure: 1
        ))
        window.sendEvent(rightDownInside)
        #expect(field.isCurrentlyFocused)
        #expect(editor.selectedRange() == NSRange(location: 0, length: longText.utf16.count))
    }

    @Test
    func clickingOutsideCancelsFocusWhileClearButtonScrollbarAndColorPopoverRetainFocus() throws {
        _ = NSApplication.shared
        let window = CueSeekerWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // 1. Search Field: clear button keeps focus and clears text; outside left/right click cancels focus
        let searchBox = StringBox("search query")
        let searchHosting = NSHostingView(
            rootView: SearchFieldHarness(box: searchBox)
                .frame(width: 500, height: 200)
        )
        searchHosting.frame = NSRect(x: 0, y: 0, width: 500, height: 200)
        window.contentView = searchHosting
        searchHosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        let searchField = try #require(collectEditableTextFields(in: searchHosting).first as? WorkbenchNativeSingleLineTextField)
        let searchOverlay = try #require(collectContainerOverlays(in: searchHosting).first)
        #expect(window.makeFirstResponder(searchField))
        searchField.selectAllInCurrentEditor()
        let searchEditor = try #require(searchField.currentEditor() as? NSTextView)
        #expect(searchEditor.selectedRange() == NSRange(location: 0, length: 12))

        // Click outside (leftMouseDown at (10, 10)) cancels focus and collapses selection
        let outsideLeftDown = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 10, y: 10),
            modifierFlags: [],
            timestamp: 1,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        window.sendEvent(outsideLeftDown)
        #expect(!searchField.isCurrentlyFocused)

        // Right-click inside unfocused search container focuses it; right-click outside cancels focus
        let insideRightDown = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: searchOverlay.convert(NSPoint(x: 16, y: searchOverlay.bounds.midY), to: nil),
            modifierFlags: [],
            timestamp: 2,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1
        ))
        window.sendEvent(insideRightDown)
        #expect(searchField.isCurrentlyFocused)

        let outsideRightDown = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: NSPoint(x: 10, y: 10),
            modifierFlags: [],
            timestamp: 3,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 3,
            clickCount: 1,
            pressure: 1
        ))
        window.sendEvent(outsideRightDown)
        #expect(!searchField.isCurrentlyFocused)

        // clearTextAndFocus() clears text and keeps/gains focus on the search field
        searchField.clearTextAndFocus()
        searchBox.text = ""
        #expect(searchField.isCurrentlyFocused)
        #expect(searchField.stringValue.isEmpty)

        // 2. Color Well + Preset Popover companion surface retains focus when clicked inside, and blurs when clicked outside
        let subtitleBox = SubtitleValueBox()
        subtitleBox.isColorPopoverOpen = true
        let colorHosting = NSHostingView(
            rootView: VStack(spacing: 8) {
                SettingsSubtitleColorField(
                    color: Binding(get: { subtitleBox.textColor }, set: { subtitleBox.textColor = $0 }),
                    accessibilityLabel: "Color",
                    isPopoverOpen: Binding(get: { subtitleBox.isColorPopoverOpen }, set: { subtitleBox.isColorPopoverOpen = $0 })
                )
                if subtitleBox.isColorPopoverOpen {
                    SettingsSubtitleColorPresetsPopover(
                        selectedColor: subtitleBox.textColor,
                        onSelectPreset: { _ in }
                    )
                }
            }
            .frame(width: 500, height: 320)
        )
        colorHosting.frame = NSRect(x: 0, y: 0, width: 500, height: 320)
        window.contentView = colorHosting
        colorHosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        let colorField = try #require(collectEditableTextFields(in: colorHosting).first as? WorkbenchNativeSingleLineTextField)
        #expect(window.makeFirstResponder(colorField))
        #expect(colorField.isCurrentlyFocused)

        func findCompanionView(in view: NSView) -> FocusedTextInputCompanionView? {
            if let companion = view as? FocusedTextInputCompanionView {
                return companion
            }
            for sub in view.subviews {
                if let found = findCompanionView(in: sub) {
                    return found
                }
            }
            return nil
        }

        let companion = try #require(findCompanionView(in: colorHosting))
        let pointInPopover = companion.convert(
            NSPoint(x: companion.bounds.midX, y: companion.bounds.midY),
            to: nil as NSView?
        )
        let clickInPopover = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: pointInPopover,
            modifierFlags: [],
            timestamp: 4,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 4,
            clickCount: 1,
            pressure: 1
        ))
        window.sendEvent(clickInPopover)
        #expect(colorField.isCurrentlyFocused)

        window.sendEvent(outsideLeftDown)
        #expect(!colorField.isCurrentlyFocused)
    }

    @Test
    func autofocusSelectsAllOnSearchRenameAndCommandPanelWithoutRefocusingOnModalOrSelectionDismiss() throws {
        _ = NSApplication.shared
        let layers = InterfaceLayerRegistry()
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isFocusLocked = { layers.hasUncoveredOpenMenu }
        window.dialogSize = { layers.topDialogSize }
        window.isWorkbenchCovered = { layers.isCovered(.workbenchPage) }

        // 1. Rename Dialog (opened right as a card menu token is released & dialog layer opens) autofocuses and selects all prefilled name
        var openMenuToken: InterfaceLayerRegistry.OpenMenuToken? = layers.registerOpenMenu(ownedBy: .workbenchPage)
        let folder = IndexedContentFolder(
            id: 1,
            relativePath: "Season 01",
            folderPath: "/Media/Season 01"
        )
        let renameSession = LibraryRenameSession(folder: folder)
        layers.topDialogSize = NSSize(width: WorkbenchControlMetrics.redesignDialogWidthMedium, height: 220)
        layers.setOpen(.dialog, true)

        let renameHosting = NSHostingView(
            rootView: ZStack {
                Color.clear
                LibraryRenameDialog(
                    session: renameSession,
                    onConfirm: {},
                    onClose: {}
                )
            }
            .frame(width: 900, height: 700)
        )
        renameHosting.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        window.contentView = renameHosting
        renameHosting.layoutSubtreeIfNeeded()
        // Release menu token on the next turn (simulating MenuGateClientView dismantle)
        openMenuToken = nil
        _ = openMenuToken
        RunLoop.main.run(until: Date().addingTimeInterval(0.06))

        let renameField = try #require(collectEditableTextFields(in: renameHosting).first as? WorkbenchNativeSingleLineTextField)
        #expect(renameField.isCurrentlyFocused)
        let renameEditor = try #require(renameField.currentEditor() as? NSTextView)
        #expect(renameEditor.string == "Season 01")
        #expect(renameEditor.selectedRange() == NSRange(location: 0, length: "Season 01".utf16.count))

        layers.setOpen(.dialog, false)

        // 2. Workbench Search Toolbar with autofocusSearchOnAppear = true autofocuses & selects all on initial entry,
        //    and does NOT re-autofocus after exiting selection mode; autofocusSearchOnAppear = false (Excerpt detail) does not autofocus.
        final class ToolbarStateBox: ObservableObject {
            @Published var query = "existing query"
            @Published var isSelectionMode = false
        }
        struct ToolbarHarness: View {
            @ObservedObject var state: ToolbarStateBox
            let autofocusOnAppear: Bool
            var body: some View {
                SchemaWorkbenchSearchToolbar(
                    placeholder: "Search",
                    searchDraft: $state.query,
                    searchResultCountText: "3 results",
                    autofocusSearchOnAppear: autofocusOnAppear,
                    selectedCountText: "1 / 3",
                    selectionActions: [],
                    isSelectionMode: state.isSelectionMode,
                    onFilter: {},
                    onToggleSelectionMode: { state.isSelectionMode.toggle() }
                )
                .frame(width: 600, height: 100)
            }
        }

        let searchState = ToolbarStateBox()
        let searchToolbarHosting = NSHostingView(
            rootView: ToolbarHarness(state: searchState, autofocusOnAppear: true)
                .frame(width: 900, height: 700)
        )
        searchToolbarHosting.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        window.contentView = searchToolbarHosting
        searchToolbarHosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let toolbarSearchField = try #require(collectEditableTextFields(in: searchToolbarHosting).first as? WorkbenchNativeSingleLineTextField)
        #expect(toolbarSearchField.isCurrentlyFocused)
        let toolbarSearchEditor = try #require(toolbarSearchField.currentEditor() as? NSTextView)
        #expect(toolbarSearchEditor.selectedRange() == NSRange(location: 0, length: "existing query".utf16.count))

        // Blur search field, enter selection mode, then exit selection mode -> must remain unfocused
        _ = window.makeFirstResponder(nil)
        #expect(!toolbarSearchField.isCurrentlyFocused)
        searchState.isSelectionMode = true
        searchToolbarHosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        searchState.isSelectionMode = false
        searchToolbarHosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let remountedSearchField = try #require(collectEditableTextFields(in: searchToolbarHosting).first as? WorkbenchNativeSingleLineTextField)
        #expect(!remountedSearchField.isCurrentlyFocused)

        // Excerpt detail toolbar (autofocusSearchOnAppear: false) does not autofocus on appear
        _ = window.makeFirstResponder(nil)
        let excerptState = ToolbarStateBox()
        let excerptToolbarHosting = NSHostingView(
            rootView: ToolbarHarness(state: excerptState, autofocusOnAppear: false)
                .frame(width: 900, height: 700)
        )
        excerptToolbarHosting.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        window.contentView = excerptToolbarHosting
        excerptToolbarHosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let excerptSearchField = try #require(collectEditableTextFields(in: excerptToolbarHosting).first as? WorkbenchNativeSingleLineTextField)
        #expect(!excerptSearchField.isCurrentlyFocused)

        // 3. Command Panel search field (autofocus: true, including prefilled cue text) autofocuses and selects all text
        let commandQueryBox = StringBox("prefilled subtitle cue")
        let commandHosting = NSHostingView(
            rootView: WorkbenchSearchField(
                placeholder: "Search",
                text: Binding(get: { commandQueryBox.text }, set: { commandQueryBox.text = $0 }),
                autofocus: true
            )
            .frame(width: 500)
            .frame(width: 900, height: 700)
        )
        commandHosting.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        window.contentView = commandHosting
        commandHosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let commandField = try #require(collectEditableTextFields(in: commandHosting).first as? WorkbenchNativeSingleLineTextField)
        #expect(commandField.isCurrentlyFocused)
        let commandEditor = try #require(commandField.currentEditor() as? NSTextView)
        #expect(commandEditor.selectedRange() == NSRange(location: 0, length: "prefilled subtitle cue".utf16.count))
    }
}

