import SwiftUI
import AppKit

struct SearchTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isFocused: FocusState<Bool>.Binding

    func makeNSView(context: Context) -> CustomTextView {
        let textView = CustomTextView()
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 16)
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
        textView.onFocusChange = { focused in
            DispatchQueue.main.async {
                self.isFocused.wrappedValue = focused
            }
        }
        
        return textView
    }

    func updateNSView(_ textView: CustomTextView, context: Context) {
        if textView.string != text {
            // Keep cursor position if possible, but for simple search box this is fine
            textView.string = text
        }
        
        if isFocused.wrappedValue && textView.window?.firstResponder != textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        } else if !isFocused.wrappedValue && textView.window?.firstResponder == textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SearchTextView

        init(_ parent: SearchTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Prevent newlines
                return true
            }
            return false
        }
    }
}

final class CustomTextView: NSTextView {
    var placeholder: String = ""
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
                .font: font ?? NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.placeholderTextColor
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
