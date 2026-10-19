import AppKit
import SwiftUI
import CueSeekerCore

@MainActor
final class WebDAVFolderDialogSession: ObservableObject, Identifiable {
    enum Step: Equatable {
        case connection
        case browser
    }

    struct BreadcrumbNode: Identifiable, Equatable {
        let url: URL
        let title: String

        var id: String {
            url.mediaPath
        }

        init(url: URL, title: String? = nil) {
            let normalized = url.standardizedMediaURL
            self.url = normalized
            self.title = title ?? WebDAVAddress.defaultDisplayName(for: normalized)
        }
    }

    let id = UUID()
    @Published var step: Step = .connection
    @Published var address: String = "" {
        didSet {
            let decoded = WebDAVAddress.decodedDisplayAddress(address)
            if address != decoded {
                address = decoded
            }
        }
    }
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var validationMessage: String? = nil
    @Published var isSubmitting: Bool = false

    @Published var baseConfig: WebDAVRootConfig? = nil
    @Published var breadcrumbNodes: [BreadcrumbNode] = []
    @Published var items: [WebDAVBrowserItem] = []
    @Published var selectedFolderPaths: Set<String> = []
    @Published var isLoadingDirectory: Bool = false
    @Published var directoryErrorMessage: String? = nil

    var validationTask: Task<Void, Never>?
    var directoryTask: Task<Void, Never>?

    var currentDirectoryURL: URL? {
        breadcrumbNodes.last?.url ?? baseConfig?.rootURL
    }

    var canAddInBrowser: Bool {
        step == .browser
            && !isLoadingDirectory
            && directoryErrorMessage == nil
            && currentDirectoryURL != nil
            && baseConfig != nil
    }

    func enterBrowser(config: WebDAVRootConfig, initialItems: [WebDAVBrowserItem]) {
        baseConfig = config
        breadcrumbNodes = [BreadcrumbNode(url: config.rootURL, title: config.name)]
        items = initialItems
        selectedFolderPaths.removeAll()
        isLoadingDirectory = false
        directoryErrorMessage = nil
        step = .browser
    }

    func toggleFolderSelection(_ item: WebDAVBrowserItem) {
        guard item.kind == .folder else {
            return
        }
        if selectedFolderPaths.contains(item.id) {
            selectedFolderPaths.remove(item.id)
        } else {
            selectedFolderPaths.insert(item.id)
        }
    }

    func targetFoldersToAdd() -> [URL] {
        guard let currentDirectoryURL else {
            return []
        }
        if selectedFolderPaths.isEmpty {
            return [currentDirectoryURL.standardizedMediaURL]
        }
        return items
            .filter { $0.kind == .folder && selectedFolderPaths.contains($0.id) }
            .map { $0.url.standardizedMediaURL }
    }

    func returnToConnection() {
        directoryTask?.cancel()
        directoryTask = nil
        selectedFolderPaths.removeAll()
        isLoadingDirectory = false
        directoryErrorMessage = nil
        step = .connection
    }

    func cancelValidation() {
        validationTask?.cancel()
        validationTask = nil
        directoryTask?.cancel()
        directoryTask = nil
        isSubmitting = false
        isLoadingDirectory = false
    }
}

struct WebDAVFolderDialog: View {
    @ObservedObject var session: WebDAVFolderDialogSession
    let onConfirm: () -> Void
    let onClose: () -> Void
    var onBack: (() -> Void)? = nil
    var onOpenFolder: ((WebDAVBrowserItem) -> Void)? = nil
    var onSelectBreadcrumb: ((WebDAVFolderDialogSession.BreadcrumbNode) -> Void)? = nil

    @Environment(\.workbenchDialogAvailableSize) private var availableSize
    @FocusState private var isAddressFocused: Bool
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        Group {
            switch session.step {
            case .connection:
                connectionStepView
            case .browser:
                browserStepView
            }
        }
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(onClose: onClose)
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    private var connectionStepView: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L("webdav.dialog.title"))

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                WorkbenchDialogFormTextField(
                    label: L("webdav.field.address"),
                    placeholder: "",
                    text: $session.address,
                    focus: $isAddressFocused,
                    normalizeDraft: WebDAVAddress.decodedDisplayAddress
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("webdav-address")

                WorkbenchDialogFormTextField(
                    label: L("webdav.field.username"),
                    placeholder: "",
                    text: $session.username,
                    focus: $isUsernameFocused
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("webdav-username")

                WorkbenchDialogFormPasswordField(
                    label: L("webdav.field.password"),
                    placeholder: "",
                    text: $session.password,
                    validationMessage: session.validationMessage,
                    reservesValidationLine: true,
                    focus: $isPasswordFocused
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("webdav-password")
            }

            connectionActions
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthMedium)
    }

    private var connectionActions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isRedesign: true,
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L("webdav.connect"),
                showsSpinner: session.isSubmitting,
                action: submitConnectionIfIdle
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("webdav-connect")
        }
    }

    private var browserStepView: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L("webdav.dialog.title"))
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

            if !session.breadcrumbNodes.isEmpty {
                breadcrumbRow
                    .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
            }

            browserContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            browserActions
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthXLarge)
        .frame(height: min(WorkbenchControlMetrics.redesignTaskPanelHeight, availableSize.height))
    }

    private var breadcrumbRow: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            ForEach(Array(session.breadcrumbNodes.enumerated()), id: \.element.id) { index, node in
                if index > 0 {
                    AppIconImage(
                        .caretRight,
                        size: WorkbenchControlMetrics.redesignBreadcrumbSeparatorSize
                    )
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                }

                if index < session.breadcrumbNodes.count - 1 {
                    BreadcrumbLink(title: node.title) {
                        onSelectBreadcrumb?(node)
                    }
                } else {
                    Text(node.title)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .semibold
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var browserContent: some View {
        if session.isLoadingDirectory {
            ZStack {
                WorkbenchSpinner(size: WorkbenchControlMetrics.redesignButtonIconSize)
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = session.directoryErrorMessage {
            WorkbenchEmptyHint(message: errorMessage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if session.items.isEmpty {
            WorkbenchEmptyHint(message: L("webdav.empty_folder_items"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WorkbenchScrollView {
                LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    ForEach(session.items) { item in
                        WebDAVBrowserCard(
                            item: item,
                            isSelected: item.kind == .folder && session.selectedFolderPaths.contains(item.id),
                            onToggleSelection: {
                                session.toggleFolderSelection(item)
                            },
                            onOpenFolder: {
                                onOpenFolder?(item)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
            }
            .id(session.currentDirectoryURL?.mediaPath ?? "webdav-browser")
        }
    }

    private var browserActions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchButton(
                title: L("common.back"),
                isRedesign: true,
                action: {
                    if let onBack {
                        onBack()
                    } else {
                        session.returnToConnection()
                    }
                }
            )
            .accessibilityIdentifier("webdav-back")

            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isRedesign: true,
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L("webdav.add"),
                action: submitAddIfReady
            )
            .disabled(!session.canAddInBrowser)
            .accessibilityIdentifier("webdav-add")
        }
    }

    private func submitConnectionIfIdle() {
        guard !session.isSubmitting else {
            return
        }
        onConfirm()
    }

    private func submitAddIfReady() {
        guard session.canAddInBrowser else {
            return
        }
        onConfirm()
    }
}

struct WebDAVBrowserCard: View {
    let item: WebDAVBrowserItem
    var folderIcon: AppIcon = .folderWebdav
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onOpenFolder: () -> Void

    @State private var isHovered = false

    var isFolder: Bool {
        item.kind == .folder
    }

    var icon: AppIcon {
        switch item.kind {
        case .folder:
            return folderIcon
        case .video:
            return .video
        case .subtitle:
            return .subtitles
        }
    }

    /// Selected folder cards use the accent tint background and have no hover effect;
    /// unselected folder cards use the standard row hover background on hover;
    /// file cards never highlight on hover.
    var backgroundFillColor: Color {
        Self.resolveBackgroundFillColor(
            isFolder: isFolder,
            isSelected: isSelected,
            isHovered: isHovered
        )
    }

    var borderStrokeColor: Color {
        Self.resolveBorderStrokeColor(
            isFolder: isFolder,
            isSelected: isSelected
        )
    }

    static func resolveBackgroundFillColor(
        isFolder: Bool,
        isSelected: Bool,
        isHovered: Bool
    ) -> Color {
        if isFolder && isSelected {
            return WorkbenchRedesignColors.libraryMediaCardHoverBg
        }
        if isFolder && isHovered {
            return WorkbenchRedesignColors.rowHover
        }
        return WorkbenchRedesignColors.tableBg
    }

    static func resolveBorderStrokeColor(
        isFolder: Bool,
        isSelected: Bool
    ) -> Color {
        if isFolder && isSelected {
            return WorkbenchRedesignColors.borderActive
        }
        return WorkbenchRedesignColors.borderControl
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            style: .continuous
        )

        HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchCardIcon(icon: icon)

            Text(item.name)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isFolder {
                AppIconImage(
                    .caretRight,
                    size: WorkbenchControlMetrics.redesignCardChevronSize
                )
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .frame(
                    width: WorkbenchControlMetrics.redesignCardChevronSize,
                    height: WorkbenchControlMetrics.redesignIconButtonSize
                )
                .allowsHitTesting(false)
            }
        }
        .padding(WorkbenchControlMetrics.redesignSpacing4)
        .frame(
            maxWidth: .infinity,
            minHeight: WorkbenchControlMetrics.redesignCardBaselineHeight,
            alignment: .leading
        )
        .background(shape.fill(backgroundFillColor))
        .overlay(
            shape.strokeBorder(
                borderStrokeColor,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
        .contentShape(shape)
        .onPointerHover { hovering in
            isHovered = isFolder ? hovering : false
        }
        .onTapGesture {
            guard isFolder else {
                return
            }
            if let event = NSApp.currentEvent,
               (event.type == .leftMouseUp || event.type == .leftMouseDown),
               event.clickCount >= 2 {
                onOpenFolder()
            } else {
                onToggleSelection()
            }
        }
    }
}
