import SwiftUI
import CueSeekerCore
import UniformTypeIdentifiers

enum AnkiExportSide: String, Sendable {
    case front
    case back
}

/// One open Export to Anki dialog: the cues it exports and what the reader has
/// chosen so far. Presented like the other dialog sessions: the coordinator
/// writes it, the window presents it.
///
/// See `docs/human/requirements/20261009-Feature-Export To Anki Interactive Card Layout.md`.
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
    @Published var folderURL: URL {
        didSet {
            if locationPath != folderURL.path {
                locationPath = folderURL.path
            }
            if hasAttemptedValidation {
                validate()
            }
        }
    }
    @Published var locationPath: String
    @Published private(set) var validationMessage: String?
    @Published private(set) var locationValidationMessage: String?
    @Published private(set) var frontValidationError: String?
    @Published private(set) var backValidationError: String?
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
        self.locationPath = folderURL.path
        self.onOptionsChange = onOptionsChange
    }

    static func isValidExportFolderPath(_ rawPath: String) -> Bool {
        let trimmed = (rawPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString)
            .expandingTildeInPath
        guard !trimmed.isEmpty else {
            return false
        }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory)
            && isDirectory.boolValue
            && FileManager.default.isWritableFile(atPath: trimmed)
    }

    /// The package the export writes: the typed name, given `.apkg` when it
    /// does not end with it.
    var destinationURL: URL {
        let name = fileName.lowercased().hasSuffix(".apkg") ? fileName : fileName + ".apkg"
        let trimmedLocation = (locationPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString)
            .expandingTildeInPath
        let baseFolder = trimmedLocation.isEmpty
            ? folderURL
            : URL(fileURLWithPath: trimmedLocation, isDirectory: true)
        return baseFolder.appendingPathComponent(name)
    }

    func removeItem(_ item: AnkiCardItem) {
        options.frontItems.removeAll { $0 == item }
        options.backItems.removeAll { $0 == item }
    }

    func moveItem(_ item: AnkiCardItem, to side: AnkiExportSide, at targetIndex: Int) {
        switch side {
        case .front:
            let oldIndex = options.frontItems.firstIndex(of: item)
            var newFront = options.frontItems.filter { $0 != item }
            options.backItems.removeAll { $0 == item }

            let adjustedIndex: Int
            if let oldIndex, oldIndex < targetIndex {
                adjustedIndex = max(0, targetIndex - 1)
            } else {
                adjustedIndex = targetIndex
            }
            let clampedIndex = min(max(0, adjustedIndex), newFront.count)
            newFront.insert(item, at: clampedIndex)
            options.frontItems = newFront
            frontValidationError = nil
        case .back:
            let oldIndex = options.backItems.firstIndex(of: item)
            var newBack = options.backItems.filter { $0 != item }
            options.frontItems.removeAll { $0 == item }

            let adjustedIndex: Int
            if let oldIndex, oldIndex < targetIndex {
                adjustedIndex = max(0, targetIndex - 1)
            } else {
                adjustedIndex = targetIndex
            }
            let clampedIndex = min(max(0, adjustedIndex), newBack.count)
            newBack.insert(item, at: clampedIndex)
            options.backItems = newBack
            backValidationError = nil
        }
    }

    /// Applies Rename's name rules, location folder rules, and layout rules.
    /// From the first attempt on, every change is checked again.
    @discardableResult
    func validate() -> Bool {
        hasAttemptedValidation = true
        var isValid = true

        // 1. File Name validation
        switch LibraryRenameNameValidator.validate(fileName, currentName: "") {
        case nil:
            validationMessage = nil
        case .empty:
            validationMessage = L("rename.validation.empty")
            isValid = false
        case .invalid, .unchanged:
            validationMessage = L("rename.validation.invalid")
            isValid = false
        }

        // 2. Location validation
        let trimmedLocation = (locationPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString)
            .expandingTildeInPath
        if Self.isValidExportFolderPath(trimmedLocation) {
            let resolvedURL = URL(fileURLWithPath: trimmedLocation, isDirectory: true)
            if folderURL.standardizedFileURL != resolvedURL.standardizedFileURL {
                folderURL = resolvedURL
            }
            locationValidationMessage = nil
        } else {
            locationValidationMessage = L("anki_export.validation.location_invalid")
            isValid = false
        }

        // 3. Card Layout validation (Front and Back cannot be empty)
        if options.frontItems.isEmpty {
            frontValidationError = L("anki_export.validation.front_empty")
            isValid = false
        } else {
            frontValidationError = nil
        }

        if options.backItems.isEmpty {
            backValidationError = L("anki_export.validation.back_empty")
            isValid = false
        } else {
            backValidationError = nil
        }

        return isValid
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
    @FocusState private var isLocationFocused: Bool
    @State private var isLocationFieldFocused = false
    @Environment(\.workbenchDialogAvailableSize) private var availableSize

    @State private var isAvailablePoolTargeted = false
    @State private var isFrontBoxTargeted = false
    @State private var isBackBoxTargeted = false

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
                    // Section 1: Available Items (Fixed 96px height)
                    group(L("anki_export.available_items")) {
                        availablePool
                    }

                    // Section 2: Card Layout (Front & Back)
                    group(L("anki_export.card_layout")) {
                        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                            cardSideBox(side: .front)
                            cardSideBox(side: .back)
                        }
                    }

                    // Section 3: File Name
                    WorkbenchFormTextField(
                        label: L("anki_export.file_name"),
                        placeholder: "",
                        text: $session.fileName,
                        validationMessage: session.validationMessage,
                        focus: $isFileNameFocused
                    )

                    // Section 4: Location
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
        .onChange(of: session.locationPath) { _ in
            if session.hasAttemptedValidation {
                session.validate()
            }
        }
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    /// Available Items pool: fixed height 96px container, showing remaining badges
    /// or empty state.
    private var availablePool: some View {
        ZStack {
            if session.options.availableItems.isEmpty {
                Text(L("anki_export.available.empty"))
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                    .foregroundStyle(WorkbenchRedesignColors.textPlaceholder)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                WrappingFlowLayout(
                    alignment: .leading,
                    horizontalSpacing: WorkbenchControlMetrics.redesignSpacing2,
                    verticalSpacing: WorkbenchControlMetrics.redesignSpacing2
                ) {
                    ForEach(session.options.availableItems) { item in
                        AnkiAvailableBadge(item: item)
                            .onDrag {
                                NSItemProvider(object: item.rawValue as NSString)
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(WorkbenchControlMetrics.redesignSpacing3)
        .frame(maxWidth: .infinity)
        .frame(height: WorkbenchControlMetrics.redesignAnkiExportAvailablePoolHeight)
        .background(WorkbenchRedesignColors.settingsGroupBg)
        .clipShape(RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius)
                .stroke(
                    isAvailablePoolTargeted ? WorkbenchRedesignColors.borderFocus : WorkbenchRedesignColors.borderDivider,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
        )
        .onDrop(of: [UTType.text.identifier], isTargeted: $isAvailablePoolTargeted) { providers in
            handleDropToAvailable(providers: providers)
        }
    }

    /// One side box (Front or Back) within Card Layout.
    private func cardSideBox(side: AnkiExportSide) -> some View {
        let items = side == .front ? session.options.frontItems : session.options.backItems
        let validationError = side == .front ? session.frontValidationError : session.backValidationError
        let isTargeted = side == .front ? isFrontBoxTargeted : isBackBoxTargeted

        return VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Text(side == .front ? L("anki_export.side.front") : L("anki_export.side.back"))
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)

            ZStack {
                if items.isEmpty {
                    ZStack {
                        if let error = validationError {
                            Text(error)
                                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                                .foregroundStyle(WorkbenchRedesignColors.dangerText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing2)
                        } else {
                            Text(L("anki_export.card.empty_hint"))
                                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                                .foregroundStyle(WorkbenchRedesignColors.textPlaceholder)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: WorkbenchControlMetrics.redesignAnkiExportCardBoxMinHeight - WorkbenchControlMetrics.redesignSpacing1 * 2)
                } else {
                    VStack(spacing: 0) {
                        dropSlot(side: side, index: 0)
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            AnkiCardBadgeRow(
                                item: item,
                                onRemove: {
                                    session.removeItem(item)
                                }
                            )
                            .onDrag {
                                NSItemProvider(object: item.rawValue as NSString)
                            }

                            dropSlot(side: side, index: index + 1)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(minHeight: WorkbenchControlMetrics.redesignAnkiExportCardBoxMinHeight - WorkbenchControlMetrics.redesignSpacing1 * 2)
                }
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing2)
            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing1)
            .background(WorkbenchRedesignColors.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius)
                    .stroke(
                        validationError != nil
                            ? WorkbenchRedesignColors.dangerText
                            : (isTargeted ? WorkbenchRedesignColors.borderFocus : WorkbenchRedesignColors.borderDivider),
                        lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                    )
            )
            .onDrop(of: [UTType.text.identifier], isTargeted: sideBinding(for: side)) { providers in
                handleDrop(providers: providers, to: side, at: items.count)
            }
        }
        .padding(WorkbenchControlMetrics.redesignSpacing3)
        .frame(maxWidth: .infinity)
        .background(WorkbenchRedesignColors.settingsGroupBg)
        .clipShape(RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius)
                .stroke(WorkbenchRedesignColors.borderDivider, lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth)
        )
    }

    private func dropSlot(side: AnkiExportSide, index: Int) -> some View {
        AnkiDropSlot(
            side: side,
            index: index,
            onDrop: { item in
                session.moveItem(item, to: side, at: index)
            }
        )
    }

    private func sideBinding(for side: AnkiExportSide) -> Binding<Bool> {
        side == .front ? $isFrontBoxTargeted : $isBackBoxTargeted
    }

    private func handleDrop(providers: [NSItemProvider], to side: AnkiExportSide, at index: Int) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { string, _ in
            guard let rawValue = string as? String,
                  let item = AnkiCardItem(rawValue: rawValue) else { return }
            DispatchQueue.main.async {
                session.moveItem(item, to: side, at: index)
            }
        }
        return true
    }

    private func handleDropToAvailable(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { string, _ in
            guard let rawValue = string as? String,
                  let item = AnkiCardItem(rawValue: rawValue) else { return }
            DispatchQueue.main.async {
                session.removeItem(item)
            }
        }
        return true
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
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                WorkbenchSingleLineTextInput(
                    placeholder: "",
                    text: $session.locationPath,
                    placeholderColor: WorkbenchRedesignColors.textPlaceholder,
                    textColor: WorkbenchRedesignColors.textPrimary,
                    fontSize: WorkbenchControlMetrics.redesignFontSizeControl,
                    focus: $isLocationFocused,
                    accessibilityLabel: L("anki_export.location"),
                    onFocusChange: { isLocationFieldFocused = $0 }
                )
                .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
                .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
                .workbenchFormFieldChrome(
                    hasError: session.locationValidationMessage != nil,
                    isFocused: isLocationFieldFocused || isLocationFocused
                )
                .overlay(WorkbenchSingleLineContainerOverlay(isEnabled: true))
                .accessibilityIdentifier("anki-export-location")

                WorkbenchIconButton(icon: .folder, isRedesign: true, action: onChooseFolder)
                    .accessibilityLabel(L("anki_export.choose_folder"))
                    .padding(.trailing, -Self.folderButtonTrailingSlack)
            }

            WorkbenchValidationMessage(text: session.locationValidationMessage)
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
            if session.validationMessage != nil {
                isFileNameFocused = true
            } else if session.locationValidationMessage != nil {
                isLocationFocused = true
            }
            return
        }
        onExport()
    }
}

/// A filter-chip style badge in the Available Items candidate pool.
private struct AnkiAvailableBadge: View {
    let item: AnkiCardItem

    var body: some View {
        Text(item.title)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: WorkbenchControlMetrics.redesignFontWeightControl
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
            .frame(height: WorkbenchControlMetrics.redesignFilterChipHeight)
            .background(WorkbenchRedesignColors.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius)
                    .stroke(
                        WorkbenchRedesignColors.borderControl,
                        lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                    )
            )
    }
}

/// A badge row within Front or Back card area, featuring a 6-dot drag handle on
/// the left and an 'x' remove button on the right.
private struct AnkiCardBadgeRow: View {
    let item: AnkiCardItem
    let onRemove: () -> Void

    @State private var isRemoveHovered = false

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            AppIconImage(
                .dotsSixVertical,
                size: WorkbenchControlMetrics.redesignAnkiExportDragHandleSize
            )
            .foregroundStyle(WorkbenchRedesignColors.textMuted)

            Text(item.title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onRemove) {
                ZStack {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignAnkiExportBadgeRemoveButtonRadius)
                        .fill(isRemoveHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
                        .frame(
                            width: WorkbenchControlMetrics.redesignAnkiExportBadgeRemoveButtonSize,
                            height: WorkbenchControlMetrics.redesignAnkiExportBadgeRemoveButtonSize
                        )

                    AppIconImage(
                        .x,
                        size: WorkbenchControlMetrics.redesignAnkiExportBadgeRemoveIconSize
                    )
                    .foregroundStyle(isRemoveHovered ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { isRemoveHovered = $0 }
            .help(L("common.remove"))
        }
        .padding(.leading, WorkbenchControlMetrics.redesignSpacing2 + 2)
        .padding(.trailing, WorkbenchControlMetrics.redesignSpacing2)
        .frame(height: WorkbenchControlMetrics.redesignFilterChipHeight)
        .background(WorkbenchRedesignColors.bgControl)
        .clipShape(RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius)
                .stroke(
                    WorkbenchRedesignColors.borderControl,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
        )
    }
}

/// Pre-reserved drop line slot between badges to highlight reorder drop locations.
private struct AnkiDropSlot: View {
    let side: AnkiExportSide
    let index: Int
    let onDrop: (AnkiCardItem) -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(height: WorkbenchControlMetrics.redesignAnkiExportDropSlotHeight)

            if isTargeted {
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignAnkiExportDropLineHeight / 2)
                    .fill(WorkbenchRedesignColors.borderFocus)
                    .frame(height: WorkbenchControlMetrics.redesignAnkiExportDropLineHeight)
            }
        }
        .frame(height: WorkbenchControlMetrics.redesignAnkiExportDropSlotHeight)
        .contentShape(Rectangle())
        .onDrop(of: [UTType.text.identifier], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                guard let rawValue = string as? String,
                      let item = AnkiCardItem(rawValue: rawValue) else { return }
                DispatchQueue.main.async {
                    onDrop(item)
                }
            }
            return true
        }
    }
}
