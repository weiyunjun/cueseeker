import AppKit
import SwiftUI
import CueSeekerCore

enum ShioriTagComposerInputRules {
    static let maximumCharacters = 20

    static func normalizedInput(_ text: String) -> String {
        let filtered = String(
            String.UnicodeScalarView(text.unicodeScalars.filter { !isInvalidShioriTagScalar($0) })
        )
        return String(filtered.prefix(maximumCharacters))
    }

    static func isValidTrimmedTagText(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= maximumCharacters else { return false }
        return !text.unicodeScalars.contains(where: isInvalidShioriTagScalar)
    }

    private static func isInvalidShioriTagScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .format:
            return true
        default:
            return false
        }
    }
}

struct ShioriTagPopoverView: View {
    let row: SubtitleTableRow
    let appState: AppCoordinator
    @ObservedObject var rowStore: TableSandboxRowModelStore
    var onDismiss: () -> Void
    var onRequestLayout: () -> Void = {}
    var onRequestDeleteConfirmation: (
        ShioriTag,
        @escaping () -> Void,
        @escaping () -> Void
    ) -> Void = { _, _, _ in }

    @State private var allTags: [ShioriTag] = []
    @State private var currentTags: [ShioriTag] = []
    @State private var inputText = ""
    @State private var inputFocusToken = 0

    private var shioriID: Int64 { Int64(row.id) }

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true) {
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3 * 2) {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    Text("Current Tags")
                        .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTable, weight: .medium))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)

                    composerField
                }

                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    Text("Select a tag or create one")
                        .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTable, weight: .medium))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)

                    ScrollView {
                        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
                            ShioriTagWrapLayout(
                                horizontalSpacing: WorkbenchControlMetrics.redesignSpacing2,
                                verticalSpacing: WorkbenchControlMetrics.redesignSpacing2
                            ) {
                                ForEach(filteredTags, id: \.id) { tag in
                                    let isAssigned = isCurrentTag(tag)
                                    ShioriTagChip(
                                        title: tag.name,
                                        isRemovable: true,
                                        isBodyInteractive: !isAssigned,
                                        onBody: isAssigned ? {
                                            focusInput()
                                        } : {
                                            addExistingTag(tag)
                                        },
                                        onRemove: {
                                            requestDeleteTag(tag)
                                        }
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if showsCreateOption {
                                ShioriTagCreateOption(title: trimmedInput) {
                                    createTag()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                    }
                    .frame(minHeight: hasGlobalPoolContent ? 36 : 0, maxHeight: 280)
                }
            }
            .padding(12)
            .frame(width: 420, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                focusInput()
            }
        }
        .onAppear {
            loadState()
            DispatchQueue.main.async {
                focusInput()
                onRequestLayout()
            }
        }
        .onExitCommand {
            onDismiss()
        }
    }

    private var composerField: some View {
        ShioriTagWrapLayout(
            horizontalSpacing: WorkbenchControlMetrics.redesignSpacing2,
            verticalSpacing: WorkbenchControlMetrics.redesignSpacing2
        ) {
            ForEach(currentTags, id: \.id) { tag in
                ShioriTagChip(
                    title: tag.name,
                    isRemovable: true,
                    isBodyInteractive: false,
                    onBody: {
                        focusInput()
                    },
                    onRemove: {
                        removeCurrentTag(tag)
                    }
                )
            }

            ShioriTagInlineTextField(
                text: $inputText,
                placeholder: currentTags.isEmpty ? "Add a tag" : "",
                focusToken: inputFocusToken,
                onTextChanged: {
                    let normalized = ShioriTagComposerInputRules.normalizedInput(inputText)
                    if normalized != inputText {
                        inputText = normalized
                    }
                    onRequestLayout()
                }
            )
            .frame(minWidth: 90, idealWidth: 140, maxWidth: 180, minHeight: 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredTags: [ShioriTag] {
        guard !trimmedInput.isEmpty else { return allTags }
        return allTags.filter { $0.name.localizedCaseInsensitiveContains(trimmedInput) }
    }

    private var showsCreateOption: Bool {
        !trimmedInput.isEmpty &&
            ShioriTagComposerInputRules.isValidTrimmedTagText(trimmedInput) &&
            !allTags.contains { $0.name == trimmedInput }
    }

    private var hasGlobalPoolContent: Bool {
        showsCreateOption || !filteredTags.isEmpty
    }

    private func isCurrentTag(_ tag: ShioriTag) -> Bool {
        currentTags.contains { $0.id == tag.id }
    }

    private func focusInput() {
        inputFocusToken += 1
    }

    private func loadState() {
        guard let state = appState.shioriTagPopoverState(forShioriID: shioriID) else {
            return
        }
        apply(state)
    }

    private func apply(_ state: ShioriTagPopoverState) {
        allTags = state.allTags
        applyCurrentTags(state.currentTags)
        onRequestLayout()
    }

    private func applyCurrentTags(_ tags: [ShioriTag]) {
        currentTags = tags
        rowStore.updateShioriTags(tags, forShioriID: shioriID, tableName: "shiori")
        onRequestLayout()
    }

    private func addExistingTag(_ tag: ShioriTag) {
        guard !isCurrentTag(tag),
              let tags = appState.assignShioriTag(tagID: tag.id, toShioriID: shioriID)
        else {
            focusInput()
            return
        }
        applyCurrentTags(tags)
        inputText = ""
        focusInput()
    }

    private func createTag() {
        guard showsCreateOption,
              let state = appState.createAndAssignShioriTag(named: trimmedInput, toShioriID: shioriID)
        else {
            focusInput()
            return
        }
        apply(state)
        inputText = ""
        focusInput()
    }

    private func removeCurrentTag(_ tag: ShioriTag) {
        guard let tags = appState.removeShioriTagAssignment(tagID: tag.id, fromShioriID: shioriID) else {
            focusInput()
            return
        }
        applyCurrentTags(tags)
        focusInput()
    }

    private func requestDeleteTag(_ tag: ShioriTag) {
        onRequestDeleteConfirmation(
            tag,
            {
                deleteTag(tag)
                focusInput()
            },
            {
                focusInput()
            }
        )
    }

    private func deleteTag(_ tag: ShioriTag) {
        guard let outcome = appState.deleteShioriTagGlobally(tagID: tag.id, currentShioriID: shioriID) else {
            onRequestLayout()
            return
        }
        allTags = outcome.popoverState.allTags
        currentTags = outcome.popoverState.currentTags
        rowStore.removeShioriTagFromVisibleRows(
            tagID: tag.id,
            affectedShioriIDs: outcome.deletionResult.affectedShioriIDs,
            tableName: "shiori"
        )
        onRequestLayout()
    }
}

private struct ShioriTagInlineTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusToken: Int
    var onTextChanged: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = textFont()
        textField.textColor = WorkbenchRedesignColors.NS.textPrimary
        textField.placeholderAttributedString = placeholderString(placeholder)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.commitEditing(_:))
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        context.coordinator.parent = self
        if textField.stringValue != text {
            textField.stringValue = text
        }
        textField.placeholderAttributedString = placeholderString(placeholder)
        textField.font = textFont()
        textField.textColor = WorkbenchRedesignColors.NS.textPrimary

        guard context.coordinator.lastFocusToken != focusToken else { return }
        context.coordinator.lastFocusToken = focusToken
        DispatchQueue.main.async {
            guard textField.window != nil else { return }
            textField.window?.makeFirstResponder(textField)
            if let editor = textField.currentEditor() {
                editor.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func textFont() -> NSFont {
        .systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
    }

    private func placeholderString(_ value: String) -> NSAttributedString {
        NSAttributedString(string: value, attributes: [
            .foregroundColor: WorkbenchRedesignColors.NS.textPlaceholder,
            .font: textFont(),
        ])
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ShioriTagInlineTextField
        var lastFocusToken = -1

        init(parent: ShioriTagInlineTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
            parent.onTextChanged()
        }

        @objc func commitEditing(_: NSTextField) {}
    }
}

private struct ShioriTagChip: View {
    let title: String
    var isRemovable: Bool
    var isBodyInteractive: Bool = false
    var onBody: (() -> Void)?
    var onRemove: (() -> Void)?

    private let style = SubtitleTableTagStyle.resolve(isRedesign: true)

    var body: some View {
        HStack(spacing: 0) {
            if let onBody {
                Button(action: onBody) {
                    chipLabel
                        .padding(.leading, style.horizontalInset)
                        .padding(.trailing, isRemovable ? 6 : style.horizontalInset)
                        .padding(.vertical, style.verticalInset)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerOnHover(isEnabled: isBodyInteractive)
            } else {
                chipLabel
                    .padding(.leading, style.horizontalInset)
                    .padding(.trailing, isRemovable ? 6 : style.horizontalInset)
                    .padding(.vertical, style.verticalInset)
            }

            if isRemovable {
                Button(action: {
                    onRemove?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WorkbenchRedesignColors.iconMuted)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .padding(.trailing, style.horizontalInset)
                .padding(.vertical, style.verticalInset)
                .pointerOnHover(isEnabled: true)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(Color(nsColor: WorkbenchTagColorID.gray.redesignFillColor()))
        )
        .frame(maxWidth: 260, alignment: .leading)
    }

    private var chipLabel: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(nsColor: WorkbenchTagColorID.gray.redesignForegroundColor()))
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

private struct ShioriTagCreateOption: View {
    let title: String
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Text("Create")
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeControl, weight: .regular))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)

                ShioriTagChip(
                    title: title,
                    isRemovable: false,
                    isBodyInteractive: false,
                    onBody: nil,
                    onRemove: nil
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing2)
            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing1)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerOnHover(isEnabled: true)
    }
}

private struct ShioriTagWrapLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let width = proposal.width ?? subviews.reduce(CGFloat.zero) { partial, subview in
            partial + subview.sizeThatFits(.unspecified).width + horizontalSpacing
        }
        return layout(subviews: subviews, width: max(0, width)).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }

            origins.append(CGPoint(x: x, y: y))
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, x - horizontalSpacing)
        }

        return (
            origins,
            CGSize(width: maxX, height: y + lineHeight)
        )
    }
}

private struct PointerOnHoverModifier: ViewModifier {
    let isEnabled: Bool
    @State private var hasPushedCursor = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                guard isEnabled else { return }
                if inside {
                    if !hasPushedCursor {
                        NSCursor.pointingHand.push()
                        hasPushedCursor = true
                    }
                } else if hasPushedCursor {
                    NSCursor.pop()
                    hasPushedCursor = false
                }
            }
            .onDisappear {
                if hasPushedCursor {
                    NSCursor.pop()
                    hasPushedCursor = false
                }
            }
    }
}

private extension View {
    func pointerOnHover(isEnabled: Bool) -> some View {
        modifier(PointerOnHoverModifier(isEnabled: isEnabled))
    }
}
