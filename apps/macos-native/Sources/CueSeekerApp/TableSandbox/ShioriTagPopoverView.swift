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

    @State private var allTags: [ShioriTag] = []
    @State private var currentTags: [ShioriTag] = []
    @State private var inputText = ""
    @State private var pendingDeleteTag: ShioriTag?
    @FocusState private var isInputFocused: Bool

    private var shioriID: Int64 { Int64(row.id) }

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true) {
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    composerField
                        .padding(12)

                    Divider()

                    VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                        Text("Select a tag or create one")
                            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTable, weight: .medium))
                            .foregroundStyle(WorkbenchRedesignColors.textMuted)

                        ScrollView {
                            ShioriTagWrapLayout(
                                horizontalSpacing: WorkbenchControlMetrics.redesignSpacing2,
                                verticalSpacing: WorkbenchControlMetrics.redesignSpacing2
                            ) {
                                ForEach(filteredTags, id: \.id) { tag in
                                    ShioriTagChip(
                                        title: tag.name,
                                        isRemovable: true,
                                        onBody: isCurrentTag(tag) ? nil : {
                                            addExistingTag(tag)
                                        },
                                        onRemove: {
                                            pendingDeleteTag = tag
                                        }
                                    )
                                }

                                if showsCreateOption {
                                    ShioriTagCreateOption(title: trimmedInput) {
                                        createTag()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                        }
                        .frame(maxHeight: 280)
                    }
                    .padding(12)
                }
                .frame(width: 420, alignment: .leading)

                if let pendingDeleteTag {
                    ShioriTagDeleteConfirmationDialog(
                        tag: pendingDeleteTag,
                        onDelete: {
                            deleteTag(pendingDeleteTag)
                        },
                        onCancel: {
                            self.pendingDeleteTag = nil
                        }
                    )
                }
            }
        }
        .onAppear {
            loadState()
            DispatchQueue.main.async {
                isInputFocused = true
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
                    onBody: nil,
                    onRemove: {
                        removeCurrentTag(tag)
                    }
                )
            }

            TextField(
                "",
                text: $inputText,
                prompt: Text(currentTags.isEmpty ? "Add a tag" : "")
                    .foregroundColor(WorkbenchRedesignColors.textPlaceholder)
            )
            .textFieldStyle(.plain)
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeControl, weight: .regular))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .focused($isInputFocused)
            .frame(minWidth: 90, idealWidth: 140, maxWidth: 180)
            .onChange(of: inputText) { nextValue in
                let normalized = ShioriTagComposerInputRules.normalizedInput(nextValue)
                if normalized != nextValue {
                    inputText = normalized
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(WorkbenchRedesignColors.bgHover)
        )
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

    private func isCurrentTag(_ tag: ShioriTag) -> Bool {
        currentTags.contains { $0.id == tag.id }
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
    }

    private func applyCurrentTags(_ tags: [ShioriTag]) {
        currentTags = tags
        rowStore.updateShioriTags(tags, forShioriID: shioriID, tableName: "shiori")
    }

    private func addExistingTag(_ tag: ShioriTag) {
        guard !isCurrentTag(tag),
              let tags = appState.assignShioriTag(tagID: tag.id, toShioriID: shioriID)
        else {
            return
        }
        applyCurrentTags(tags)
        inputText = ""
    }

    private func createTag() {
        guard showsCreateOption,
              let state = appState.createAndAssignShioriTag(named: trimmedInput, toShioriID: shioriID)
        else {
            return
        }
        apply(state)
        inputText = ""
    }

    private func removeCurrentTag(_ tag: ShioriTag) {
        guard let tags = appState.removeShioriTagAssignment(tagID: tag.id, fromShioriID: shioriID) else {
            return
        }
        applyCurrentTags(tags)
    }

    private func deleteTag(_ tag: ShioriTag) {
        guard let outcome = appState.deleteShioriTagGlobally(tagID: tag.id, currentShioriID: shioriID) else {
            pendingDeleteTag = nil
            return
        }
        pendingDeleteTag = nil
        allTags = outcome.popoverState.allTags
        currentTags = outcome.popoverState.currentTags
        rowStore.removeShioriTagFromVisibleRows(
            tagID: tag.id,
            affectedShioriIDs: outcome.deletionResult.affectedShioriIDs,
            tableName: "shiori"
        )
    }

}

private struct ShioriTagChip: View {
    let title: String
    var isRemovable: Bool
    var onBody: (() -> Void)?
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            if let onBody {
                Button(action: onBody) {
                    chipLabel
                        .padding(.leading, WorkbenchControlMetrics.redesignSpacing2)
                        .padding(.trailing, isRemovable ? 6 : WorkbenchControlMetrics.redesignSpacing2)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerOnHover(isEnabled: true)
            } else {
                chipLabel
                    .padding(.leading, WorkbenchControlMetrics.redesignSpacing2)
                    .padding(.trailing, isRemovable ? 6 : WorkbenchControlMetrics.redesignSpacing2)
                    .padding(.vertical, 4)
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
                .padding(.trailing, WorkbenchControlMetrics.redesignSpacing2)
                .padding(.vertical, 4)
                .pointerOnHover(isEnabled: true)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: SubtitleTableMetrics.tagCornerRadius, style: .continuous)
                .fill(WorkbenchRedesignColors.bgHover)
        )
        .frame(maxWidth: 260, alignment: .leading)
    }

    private var chipLabel: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(WorkbenchRedesignColors.textSecondary)
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

private struct ShioriTagDeleteConfirmationDialog: View {
    let tag: ShioriTag
    var onDelete: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                Text("Delete Tag")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)

                Text("Are you sure you want to delete this tag? This will remove the tag from all cues. This action cannot be undone.")
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody, weight: .regular))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    Spacer(minLength: 0)

                    WorkbenchButton(
                        title: "Cancel",
                        isRedesign: true,
                        action: onCancel
                    )
                    .keyboardShortcut(.defaultAction)
                    .keyboardShortcut(.cancelAction)

                    WorkbenchDestructiveButton(
                        title: "Delete",
                        action: onDelete
                    )
                }
            }
            .padding(24)
            .frame(width: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .fill(WorkbenchRedesignColors.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .strokeBorder(WorkbenchRedesignColors.borderControl, lineWidth: 1)
            )
        }
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
