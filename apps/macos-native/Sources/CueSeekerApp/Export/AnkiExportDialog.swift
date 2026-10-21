import AppKit
import SwiftUI
import CueSeekerCore

enum AnkiExportSide: String, Sendable {
    case front
    case back
}

/// One open Export to Anki dialog: the cues it exports and what the reader has
/// chosen so far. Presented like the other dialog sessions: the coordinator
/// writes it, the window presents it.
///
/// See `docs/human/requirements/20261017-UI-Export To Anki Card Layout And Drag Redesign.md`.
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

    func items(for side: AnkiExportSide) -> [AnkiCardItem] {
        switch side {
        case .front:
            options.frontItems
        case .back:
            options.backItems
        }
    }

    func remainingItems(for side: AnkiExportSide) -> [AnkiCardItem] {
        options.remainingItems(for: side)
    }

    func addItem(_ item: AnkiCardItem, to side: AnkiExportSide) {
        switch side {
        case .front:
            guard !options.frontItems.contains(item) else { return }
            options.frontItems.append(item)
            frontValidationError = nil
        case .back:
            guard !options.backItems.contains(item) else { return }
            options.backItems.append(item)
            backValidationError = nil
        }
    }

    func removeItem(_ item: AnkiCardItem, from side: AnkiExportSide) {
        switch side {
        case .front:
            options.frontItems.removeAll { $0 == item }
        case .back:
            options.backItems.removeAll { $0 == item }
        }
    }

    func moveItem(_ item: AnkiCardItem, on side: AnkiExportSide, to targetIndex: Int) {
        switch side {
        case .front:
            guard let fromIndex = options.frontItems.firstIndex(of: item) else { return }
            let clampedIndex = min(max(0, targetIndex), options.frontItems.count - 1)
            guard fromIndex != clampedIndex else { return }
            var updated = options.frontItems
            updated.remove(at: fromIndex)
            updated.insert(item, at: clampedIndex)
            options.frontItems = updated
        case .back:
            guard let fromIndex = options.backItems.firstIndex(of: item) else { return }
            let clampedIndex = min(max(0, targetIndex), options.backItems.count - 1)
            guard fromIndex != clampedIndex else { return }
            var updated = options.backItems
            updated.remove(at: fromIndex)
            updated.insert(item, at: clampedIndex)
            options.backItems = updated
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

private struct AnkiAddMenuState: Identifiable {
    let id = UUID()
    let side: AnkiExportSide
    let anchorFrame: CGRect
    let menuFrame: CGRect
    let items: [AnkiCardItem]
}

private struct AnkiRowDragState: Equatable {
    let side: AnkiExportSide
    let item: AnkiCardItem
    let startIndex: Int
    var targetIndex: Int
}

/// The Export to Anki dialog: what goes on the cards, and where the package
/// goes. Between the title and the buttons it scrolls when the window is too
/// short for it.
struct AnkiExportDialog: View {
    private static let menuCoordinateSpaceName = "AnkiExportDialog.menuCoordinateSpace"
    private static let rowStepHeight: CGFloat =
        WorkbenchControlMetrics.redesignFilterChipHeight + WorkbenchControlMetrics.redesignSpacing2

    @ObservedObject var session: AnkiExportSession
    var menuGate: MenuGate? = nil
    let onChooseFolder: () -> Void
    let onExport: () -> Void
    let onClose: () -> Void

    @FocusState private var isFileNameFocused: Bool
    @FocusState private var isLocationFocused: Bool
    @State private var isLocationFieldFocused = false
    @Environment(\.workbenchDialogAvailableSize) private var availableSize

    @State private var activeMenu: AnkiAddMenuState?
    @StateObject private var menuHighlight = MenuHighlightModel()
    @State private var dragState: AnkiRowDragState?
    @State private var dragTranslationY: CGFloat = 0

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

    private static func cardListCoordinateSpaceName(for side: AnkiExportSide) -> String {
        "AnkiExportDialog.cardList.\(side.rawValue)"
    }

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
                    // Section 1: Front & Back Card Columns
                    HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                        cardSideColumn(side: .front)
                        cardSideColumn(side: .back)
                    }

                    // Section 2 & 3: File Name and Location (horizontal form rows)
                    VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                        WorkbenchDialogFormTextField(
                            label: L("anki_export.file_name"),
                            placeholder: "",
                            text: $session.fileName,
                            validationMessage: session.validationMessage,
                            reservesValidationLine: true,
                            focus: $isFileNameFocused
                        )

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
        .coordinateSpace(name: Self.menuCoordinateSpaceName)
        .overlay(alignment: .topLeading) {
            if let activeMenu {
                let menuFrame = activeMenu.menuFrame
                ZStack(alignment: .topLeading) {
                    MenuGateClientView(
                        gate: menuGate,
                        owner: .dialog,
                        kind: .cardMenu,
                        menuFrame: menuFrame,
                        anchorFrame: activeMenu.anchorFrame,
                        handleKey: { keyCode, _ in
                            switch keyCode {
                            case 53:
                                dismissMenu()
                                return true
                            case 126:
                                _ = menuHighlight.moveHighlight(by: -1)
                                return true
                            case 125:
                                _ = menuHighlight.moveHighlight(by: 1)
                                return true
                            case 123, 124:
                                return true
                            case 36, 76:
                                return activateHighlightedItem(in: activeMenu)
                            default:
                                return false
                            }
                        },
                        dismiss: { _ in
                            dismissMenu()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    AnkiCardItemMenuPopover(
                        items: activeMenu.items,
                        highlight: menuHighlight,
                        onSelect: { item in
                            selectMenuItem(item, for: activeMenu.side)
                        }
                    )
                    .offset(x: menuFrame.minX, y: menuFrame.minY)
                }
                .zIndex(1000)
            }
        }
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthLarge)
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(onClose: {
            dismissMenu()
            onClose()
        })
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
        .onChange(of: isFileNameFocused) { focused in
            if focused {
                isLocationFocused = false
                isLocationFieldFocused = false
            }
        }
        .onChange(of: isLocationFocused) { focused in
            if focused {
                isFileNameFocused = false
            }
        }
        .onDisappear {
            dismissMenu()
        }
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    /// One side column (Front or Back) with header row (`Front`/`Back` + `+` button)
    /// and a fixed-height 288px white card box below.
    private func cardSideColumn(side: AnkiExportSide) -> some View {
        let items = session.items(for: side)
        let remaining = session.remainingItems(for: side)
        let validationError = side == .front ? session.frontValidationError : session.backValidationError

        return VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                Text(side == .front ? L("anki_export.side.front") : L("anki_export.side.back"))
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .semibold
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .padding(.leading, WorkbenchControlMetrics.redesignSpacing2)

                GeometryReader { buttonProxy in
                    WorkbenchIconButton(
                        icon: .plus,
                        isRedesign: true,
                        isOpen: activeMenu?.side == side,
                        iconSize: WorkbenchControlMetrics.redesignAnkiExportAddIconSize,
                        boxSize: WorkbenchControlMetrics.redesignAnkiExportAddButtonSize,
                        action: {
                            let frame = buttonProxy.frame(in: .named(Self.menuCoordinateSpaceName))
                            handleAddButtonTap(for: side, anchorFrame: frame)
                        }
                    )
                    .disabled(remaining.isEmpty)
                    .workbenchTooltip(
                        scenarioID: "anki_export.card.add_item",
                        isActive: activeMenu?.side != side,
                        label: remaining.isEmpty
                            ? L("tooltip.disabled.anki_export.all_items_added")
                            : L("tooltip.anki_export.add_item")
                    )
                    .accessibilityIdentifier("anki-export-add-\(side.rawValue)")
                }
                .frame(
                    width: WorkbenchControlMetrics.redesignAnkiExportAddButtonSize,
                    height: WorkbenchControlMetrics.redesignAnkiExportAddButtonSize
                )

                Spacer(minLength: 0)
            }

            ZStack {
                if items.isEmpty {
                    if let error = validationError {
                        Text(error)
                            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                            .foregroundStyle(WorkbenchRedesignColors.dangerText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let isDragging = isDraggingRow(side: side, item: item)
                            AnkiCardBadgeRow(
                                item: item,
                                onRemove: {
                                    dismissMenu()
                                    session.removeItem(item, from: side)
                                }
                            )
                            .offset(y: rowVerticalOffset(side: side, index: index, item: item))
                            .opacity(isDragging ? WorkbenchControlMetrics.redesignAnkiExportDraggingOpacity : 1.0)
                            .zIndex(isDragging ? 10 : 0)
                            .gesture(
                                rowDragGesture(
                                    side: side,
                                    startIndex: index,
                                    item: item,
                                    itemCount: items.count
                                )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .coordinateSpace(name: Self.cardListCoordinateSpaceName(for: side))
                }
            }
            .padding(WorkbenchControlMetrics.redesignSpacing2)
            .frame(maxWidth: .infinity)
            .frame(height: WorkbenchControlMetrics.redesignAnkiExportCardBoxHeight)
            .background(WorkbenchRedesignColors.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius)
                    .stroke(
                        validationError != nil
                            ? WorkbenchRedesignColors.dangerText
                            : WorkbenchRedesignColors.borderControl,
                        lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                    )
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func isDraggingRow(side: AnkiExportSide, item: AnkiCardItem) -> Bool {
        dragState?.side == side && dragState?.item == item
    }

    private func rowVerticalOffset(
        side: AnkiExportSide,
        index: Int,
        item: AnkiCardItem
    ) -> CGFloat {
        guard let currentDrag = dragState, currentDrag.side == side else {
            return 0
        }
        if currentDrag.item == item {
            return dragTranslationY
        }
        if currentDrag.startIndex < currentDrag.targetIndex,
           index > currentDrag.startIndex,
           index <= currentDrag.targetIndex {
            return -Self.rowStepHeight
        }
        if currentDrag.startIndex > currentDrag.targetIndex,
           index < currentDrag.startIndex,
           index >= currentDrag.targetIndex {
            return Self.rowStepHeight
        }
        return 0
    }

    private func rowDragGesture(
        side: AnkiExportSide,
        startIndex: Int,
        item: AnkiCardItem,
        itemCount: Int
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 3,
            coordinateSpace: .named(Self.cardListCoordinateSpaceName(for: side))
        )
        .onChanged { value in
            if activeMenu != nil {
                dismissMenu()
            }
            guard itemCount > 1 else { return }

            let minDeltaY = -CGFloat(startIndex) * Self.rowStepHeight
            let maxDeltaY = CGFloat(itemCount - 1 - startIndex) * Self.rowStepHeight
            let clampedDeltaY = min(max(value.translation.height, minDeltaY), maxDeltaY)
            let offsetSteps = Int((clampedDeltaY / Self.rowStepHeight).rounded())
            let targetIndex = min(max(0, startIndex + offsetSteps), itemCount - 1)

            dragTranslationY = clampedDeltaY

            if dragState?.side != side || dragState?.item != item {
                dragState = AnkiRowDragState(
                    side: side,
                    item: item,
                    startIndex: startIndex,
                    targetIndex: targetIndex
                )
            } else if dragState?.targetIndex != targetIndex {
                withAnimation(.easeInOut(duration: 0.15)) {
                    dragState?.targetIndex = targetIndex
                }
            }
        }
        .onEnded { _ in
            guard let currentDrag = dragState,
                  currentDrag.side == side,
                  currentDrag.item == item
            else {
                return
            }
            let destinationIndex = currentDrag.targetIndex
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragState = nil
                dragTranslationY = 0
                session.moveItem(item, on: side, to: destinationIndex)
            }
        }
    }

    private func handleAddButtonTap(for side: AnkiExportSide, anchorFrame: CGRect) {
        clearInputFocus()
        let remaining = session.remainingItems(for: side)
        guard !remaining.isEmpty else { return }

        if remaining.count == 1 {
            dismissMenu()
            session.addItem(remaining[0], to: side)
            return
        }

        if activeMenu?.side == side {
            dismissMenu()
        } else {
            openMenu(for: side, anchorFrame: anchorFrame, items: remaining)
        }
    }

    private func clearInputFocus() {
        isFileNameFocused = false
        isLocationFocused = false
        isLocationFieldFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private func openMenu(
        for side: AnkiExportSide,
        anchorFrame: CGRect,
        items: [AnkiCardItem]
    ) {
        let naturalSize = measuredMenuSize(for: items)
        let menuFrame = CGRect(
            x: anchorFrame.minX,
            y: anchorFrame.maxY + WorkbenchControlMetrics.redesignSpacing1,
            width: naturalSize.width,
            height: naturalSize.height
        )
        activeMenu = AnkiAddMenuState(
            side: side,
            anchorFrame: anchorFrame,
            menuFrame: menuFrame,
            items: items
        )
        menuHighlight.open(selectablePositions: Array(items.indices))
    }

    private func dismissMenu() {
        activeMenu = nil
        menuHighlight.close()
    }

    private func selectMenuItem(_ item: AnkiCardItem, for side: AnkiExportSide) {
        dismissMenu()
        session.addItem(item, to: side)
    }

    private func activateHighlightedItem(in menu: AnkiAddMenuState) -> Bool {
        guard let position = menuHighlight.highlightedPosition,
              menu.items.indices.contains(position)
        else {
            return false
        }
        let item = menu.items[position]
        selectMenuItem(item, for: menu.side)
        return true
    }

    private func measuredMenuSize(for items: [AnkiCardItem]) -> CGSize {
        let host = NSHostingView(
            rootView: AnkiCardItemMenuPopover(
                items: items,
                highlight: menuHighlight,
                onSelect: { _ in }
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    private var locationRow: some View {
        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing3) {
            WorkbenchFormLabel(text: L("anki_export.location"))
                .frame(
                    width: WorkbenchControlMetrics.redesignFormLabelWidth,
                    height: WorkbenchControlMetrics.redesignFieldHeight,
                    alignment: .leading
                )

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
                        onFocusChange: { focused in
                            isLocationFieldFocused = focused
                            if focused {
                                isFileNameFocused = false
                            }
                        }
                    )
                    .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
                    .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
                    .workbenchFormFieldChrome(
                        hasError: session.locationValidationMessage != nil,
                        isFocused: isLocationFieldFocused || isLocationFocused
                    )
                    .overlay(WorkbenchSingleLineContainerOverlay(isEnabled: true))
                    .accessibilityIdentifier("anki-export-location")

                    WorkbenchIconButton(
                        icon: .folder,
                        isRedesign: true,
                        action: {
                            dismissMenu()
                            onChooseFolder()
                        }
                    )
                    .workbenchTooltip(
                        scenarioID: "anki_export.location.choose_folder",
                        label: L("tooltip.anki_export.choose_folder")
                    )
                    .accessibilityLabel(L("anki_export.choose_folder"))
                    .padding(.trailing, -Self.folderButtonTrailingSlack)
                }

                WorkbenchValidationMessage(text: session.locationValidationMessage)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isRedesign: true,
                action: {
                    dismissMenu()
                    onClose()
                }
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
        dismissMenu()
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

private struct AnkiCardItemMenuPopover: View {
    let items: [AnkiCardItem]
    @ObservedObject var highlight: MenuHighlightModel
    let onSelect: (AnkiCardItem) -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            isRedesign: true,
            maximumHeight: MenuMetrics.maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { position, item in
                    WorkbenchPopoverRow(
                        title: item.title,
                        isHighlighted: highlight.highlightedPosition == position,
                        isRedesign: true,
                        showsCheckmarkSlot: false,
                        action: {
                            onSelect(item)
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
            .frame(minWidth: 160, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A badge row within Front or Back card area, featuring a 6-dot drag handle on
/// the left and an 'x' remove button on the right.
private struct AnkiCardBadgeRow: View {
    let item: AnkiCardItem
    let onRemove: () -> Void

    @State private var isRemoveHovered = false
    @State private var isRemovePressed = false

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
                        .fill(
                            isRemovePressed
                                ? WorkbenchRedesignColors.bgPressed
                                : (isRemoveHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
                        )
                        .frame(
                            width: WorkbenchControlMetrics.redesignAnkiExportBadgeRemoveButtonSize,
                            height: WorkbenchControlMetrics.redesignAnkiExportBadgeRemoveButtonSize
                        )

                    AppIconImage(
                        .x,
                        size: WorkbenchControlMetrics.redesignAnkiExportBadgeRemoveIconSize
                    )
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(isPressed: $isRemovePressed, isHovered: $isRemoveHovered))
            .focusable(false)
            .onPointerHover { isRemoveHovered = $0 }
            .workbenchTooltip(
                scenarioID: "anki_export.card.remove_item",
                label: L("tooltip.anki_export.remove_item")
            )
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
        .contentShape(Rectangle())
    }
}
