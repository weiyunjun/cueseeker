import SwiftUI
import CueSeekerCore

/// One open Export to Anki dialog: the cues it exports and what the reader has
/// chosen so far. Presented like the other dialog sessions: the coordinator
/// writes it, the window presents it.
///
/// See `docs/human/requirements/20260912-Feature-Export To Anki Dialog And
/// Card Content.md`.
@MainActor
final class AnkiExportSession: ObservableObject, Identifiable {
    let id = UUID()
    let items: [AnkiExportItem]
    /// Kept as the reader changes it, not only on Export, so the next dialog
    /// opens on the choices this one was left with.
    @Published var options: AnkiExportOptions {
        didSet {
            onOptionsChange(options)
        }
    }
    @Published var fileName = AnkiPackageExporter.defaultFileName()
    @Published var folderURL: URL
    @Published private(set) var validationMessage: String?
    @Published private(set) var hasAttemptedValidation = false
    private let onOptionsChange: (AnkiExportOptions) -> Void

    init(
        items: [AnkiExportItem],
        options: AnkiExportOptions,
        folderURL: URL,
        onOptionsChange: @escaping (AnkiExportOptions) -> Void
    ) {
        self.items = items
        self.options = options
        self.folderURL = folderURL
        self.onOptionsChange = onOptionsChange
    }

    /// The package the export writes: the typed name, given `.apkg` when it
    /// does not end with it.
    var destinationURL: URL {
        let name = fileName.lowercased().hasSuffix(".apkg") ? fileName : fileName + ".apkg"
        return folderURL.appendingPathComponent(name)
    }

    /// Applies Rename's name rules and shows the first one broken. From the
    /// first attempt on, every keystroke is checked again.
    @discardableResult
    func validate() -> Bool {
        hasAttemptedValidation = true
        // A new file has no current name, so the unchanged rule never applies.
        switch LibraryRenameNameValidator.validate(fileName, currentName: "") {
        case nil:
            validationMessage = nil
            return true
        case .empty:
            validationMessage = L("rename.validation.empty")
        case .invalid, .unchanged:
            validationMessage = L("rename.validation.invalid")
        }
        return false
    }
}

/// The Export to Anki dialog: what goes on the cards, and where the package
/// goes. Between the title and the buttons it scrolls when the window is too
/// short for it.
struct AnkiExportDialog: View {
    @ObservedObject var session: AnkiExportSession
    let onChooseFolder: () -> Void
    let onExport: () -> Void
    let onClose: () -> Void

    @FocusState private var isFileNameFocused: Bool
    @Environment(\.workbenchDialogAvailableSize) private var availableSize

    /// The folder glyph's ink stops short of its button's box. The button
    /// reaches past the content's edge by that much, so the ink lands on the
    /// edge, where the dialog measures an icon button.
    private static let folderButtonTrailingSlack: CGFloat = {
        let iconSize = WorkbenchControlMetrics.redesignControlIconSize
        let lineWidth = AppIconLineWidth.bySize[iconSize] ?? 0
        // Phosphor's folder draws its right side at 224 of its 256-unit grid.
        let inkTrailingEdge = iconSize * 224 / 256 + lineWidth / 2
        return (WorkbenchControlMetrics.redesignIconButtonSize - iconSize) / 2
            + iconSize - inkTrailingEdge
    }()

    var body: some View {
        WorkbenchDialogColumn(
            spacing: WorkbenchControlMetrics.redesignSpacing4,
            maxHeight: availableSize.height
                - WorkbenchControlMetrics.redesignDialogTopPadding
                - WorkbenchControlMetrics.redesignDialogInset
        ) {
            WorkbenchDialogHeader(title: L("anki_export.title"))
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

            // The scroll view reaches the dialog's sides, so its scrollbar runs
            // in the inset rather than over the form.
            WorkbenchScrollView {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                    group(L("anki_export.cue_text_side")) {
                        WorkbenchSegmentedControl(
                            options: AnkiExportCueTextSide.allCases,
                            selection: $session.options.cueTextSide,
                            title: \.title,
                            accessibilityLabel: { L("anki_export.cue_text_side.accessibility", $0.title) }
                        )
                    }

                    group(L("anki_export.required")) {
                        AnkiExportCheckboxGrid(checkboxes: [
                            AnkiExportCheckbox(title: L("anki_export.item.cue_text"), isChecked: true, toggle: nil),
                            AnkiExportCheckbox(title: L("anki_export.item.audio"), isChecked: true, toggle: nil),
                        ])
                    }

                    group(L("anki_export.optional")) {
                        AnkiExportCheckboxGrid(checkboxes: AnkiExportOptionalItem.allCases.map { item in
                            AnkiExportCheckbox(
                                title: item.title,
                                isChecked: session.options.includes(item),
                                toggle: { session.options.toggle(item) }
                            )
                        })
                    }

                    WorkbenchFormTextField(
                        label: L("anki_export.file_name"),
                        placeholder: "",
                        text: $session.fileName,
                        validationMessage: session.validationMessage,
                        focus: $isFileNameFocused
                    )

                    group(L("anki_export.location")) {
                        locationRow
                    }
                }
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
            }

            actions
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthLarge)
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(onClose: onClose)
        .onChange(of: session.fileName) { _ in
            if session.hasAttemptedValidation {
                session.validate()
            }
        }
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    /// A group's title, with the Text Field label's type and gap, above its
    /// content.
    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchFormLabel(text: title)
            content()
        }
    }

    private var locationRow: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Text(session.folderURL.path)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeControl,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            WorkbenchIconButton(icon: .folder, isRedesign: true, action: onChooseFolder)
                .accessibilityLabel(L("anki_export.choose_folder"))
                .padding(.trailing, -Self.folderButtonTrailingSlack)
        }
    }

    private var actions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isRedesign: true,
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L("anki_export.export"),
                action: export
            )
            .keyboardShortcut(.defaultAction)
        }
    }

    private func export() {
        guard session.validate() else {
            isFileNameFocused = true
            return
        }
        onExport()
    }
}

/// Two equal columns of checkboxes, filled left to right, then top to bottom.
private struct AnkiExportCheckboxGrid: View {
    let checkboxes: [AnkiExportCheckbox]

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
            ForEach(Array(stride(from: 0, to: checkboxes.count, by: 2)), id: \.self) { start in
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
                    cell(start)
                    cell(start + 1)
                }
            }
        }
    }

    private func cell(_ index: Int) -> some View {
        Group {
            if checkboxes.indices.contains(index) {
                checkboxes[index]
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A checkbox and its label, which together are what a click toggles. One
/// without a toggle is locked on and reads as Checked + Disabled.
private struct AnkiExportCheckbox: View {
    let title: String
    let isChecked: Bool
    let toggle: (() -> Void)?

    var body: some View {
        if let toggle {
            Button(action: toggle) {
                label
                    .contentShape(Rectangle())
            }
            .buttonStyle(StaticButtonStyle())
            .focusable(false)
            .subtitleTableTextSelectionInteractiveRegion()
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchCheckboxGlyph(
                state: isChecked ? .checked : .unchecked,
                isEnabled: toggle != nil,
                size: WorkbenchControlMetrics.redesignCheckboxSize
            )

            Text(title)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                .foregroundStyle(
                    toggle == nil
                        ? WorkbenchRedesignColors.textDisabled
                        : WorkbenchRedesignColors.textPrimary
                )
                .lineLimit(1)
        }
    }
}

extension AnkiExportCueTextSide {
    var title: String {
        switch self {
        case .front:
            L("anki_export.side.front")
        case .back:
            L("anki_export.side.back")
        }
    }
}

extension AnkiExportOptionalItem {
    var title: String {
        switch self {
        case .screenshot:
            L("anki_export.item.screenshot")
        case .cueGroupText:
            L("anki_export.item.cue_group_text")
        case .displayTitle:
            L("anki_export.item.display_title")
        case .timeRange:
            L("anki_export.item.time_range")
        case .deepLink:
            L("anki_export.item.deep_link")
        case .subtitleFilePath:
            L("anki_export.item.subtitle_file_path")
        case .videoFilePath:
            L("anki_export.item.video_file_path")
        }
    }
}
