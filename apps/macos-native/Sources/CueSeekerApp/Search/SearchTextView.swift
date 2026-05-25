import SwiftUI
import AppKit

struct SearchTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @Binding var isFocused: Bool
    var forcedTextUpdateID: Int = 0
    var focusRequestID: Int = 0
    var font: NSFont = .systemFont(ofSize: 17, weight: .semibold)
    var textColor: NSColor = .labelColor
    var placeholderColor: NSColor = .placeholderTextColor
    var onSubmit: () -> Void = {}
    var onMoveUp: () -> Bool = { false }
    var onMoveDown: () -> Bool = { false }

    func makeNSView(context: Context) -> CustomTextView {
        let textView = CustomTextView()
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.delegate = context.coordinator
        
        // Configure for single line behavior
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.maximumNumberOfLines = 1
        textView.textContainerInset = NSSize(width: 0, height: 2) // Visual vertical center
        
        textView.placeholder = placeholder
        textView.placeholderColor = placeholderColor
        textView.onFocusChange = { focused in
            DispatchQueue.main.async {
                self.isFocused = focused
            }
        }
        
        return textView
    }

    func updateNSView(_ textView: CustomTextView, context: Context) {
        context.coordinator.parent = self
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.placeholder = placeholder
        textView.placeholderColor = placeholderColor
        let shouldForceFocus = context.coordinator.appliedFocusRequestID != focusRequestID
        if shouldForceFocus {
            context.coordinator.appliedFocusRequestID = focusRequestID
        }

        let shouldForceTextUpdate = context.coordinator.appliedForcedTextUpdateID != forcedTextUpdateID
        if shouldForceTextUpdate {
            context.coordinator.appliedForcedTextUpdateID = forcedTextUpdateID
        }
        let shouldApplyTextUpdate = SearchTextViewTextUpdatePolicy.shouldApplyProgrammaticTextUpdate(
            currentText: textView.string,
            targetText: text,
            isFocused: textView.window?.firstResponder == textView,
            hasMarkedText: textView.hasMarkedText(),
            isForced: shouldForceTextUpdate
        )
        if shouldApplyTextUpdate {
            textView.string = text
        }
        
        if isFocused && textView.window?.firstResponder != textView {
            context.coordinator.requestFocus(for: textView)
        } else if isFocused && shouldForceFocus {
            context.coordinator.requestFocus(for: textView)
        } else if !isFocused && textView.window?.firstResponder == textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SearchTextView
        var appliedForcedTextUpdateID: Int
        var appliedFocusRequestID: Int

        init(_ parent: SearchTextView) {
            self.parent = parent
            self.appliedForcedTextUpdateID = parent.forcedTextUpdateID
            self.appliedFocusRequestID = parent.focusRequestID
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }

        func requestFocus(for textView: CustomTextView) {
            requestFocus(for: textView, attempt: 0)
        }

        private func requestFocus(for textView: CustomTextView, attempt: Int) {
            let delay: DispatchTimeInterval
            switch attempt {
            case 0:
                delay = .milliseconds(0)
            case 1:
                delay = .milliseconds(20)
            case 2:
                delay = .milliseconds(60)
            default:
                delay = .milliseconds(120)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak textView] in
                guard let self, let textView, self.parent.isFocused else {
                    return
                }

                if textView.window?.firstResponder != textView {
                    textView.window?.makeFirstResponder(textView)
                }

                if attempt < 3, textView.window?.firstResponder != textView {
                    self.requestFocus(for: textView, attempt: attempt + 1)
                }
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                return parent.onMoveUp()
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                return parent.onMoveDown()
            }
            return false
        }
    }
}

enum SearchTextViewTextUpdatePolicy {
    static func shouldApplyProgrammaticTextUpdate(
        currentText: String,
        targetText: String,
        isFocused: Bool,
        hasMarkedText: Bool,
        isForced: Bool
    ) -> Bool {
        guard currentText != targetText else {
            return false
        }

        if isForced {
            return true
        }

        return !isFocused && !hasMarkedText
    }
}

final class CustomTextView: NSTextView {
    var placeholder: String = ""
    var placeholderColor: NSColor = .placeholderTextColor
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onFocusChange?(true)
            needsDisplay = true // redraw for placeholder if needed
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            onFocusChange?(false)
            needsDisplay = true
        }
        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if string.isEmpty && !placeholder.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: placeholderColor
            ]
            let size = placeholder.size(withAttributes: attributes)
            // Align with text container inset
            let rect = NSRect(x: textContainerInset.width,
                              y: textContainerInset.height,
                              width: size.width,
                              height: size.height)
            placeholder.draw(in: rect, withAttributes: attributes)
        }
    }
    
    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
}
