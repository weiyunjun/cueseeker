import AppKit
import SwiftUI
import CueSeekerCore

@MainActor
final class FTPFolderDialogSession: ObservableObject, Identifiable {
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
            self.title = title ?? FTPAddress.defaultDisplayName(for: normalized)
        }
    }

    let id = UUID()
    @Published var step: Step = .connection
    @Published var address: String = "" {
        didSet {
            let decoded = FTPAddress.decodedDisplayAddress(address)
            if address != decoded {
                address = decoded
            }
        }
    }
    @Published var port: String = FTPAddress.defaultPortString
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var validationMessage: String? = nil
    @Published var isSubmitting: Bool = false

    @Published var baseConfig: FTPRootConfig? = nil
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
        guard step == .browser,
              !isLoadingDirectory,
              directoryErrorMessage == nil,
              currentDirectoryURL != nil,
              baseConfig != nil else {
            return false
        }
        return true
    }

    func enterBrowser(config: FTPRootConfig, initialItems: [WebDAVBrowserItem]) {
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

struct FTPFolderDialog: View {
    @ObservedObject var session: FTPFolderDialogSession
    let onConfirm: () -> Void
    let onClose: () -> Void
    var onBack: (() -> Void)? = nil
    var onOpenFolder: ((WebDAVBrowserItem) -> Void)? = nil
    var onSelectBreadcrumb: ((FTPFolderDialogSession.BreadcrumbNode) -> Void)? = nil

    @Environment(\.workbenchDialogAvailableSize) private var availableSize
    @FocusState private var isAddressFocused: Bool
    @FocusState private var isPortFocused: Bool
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
            WorkbenchDialogHeader(title: L("ftp.dialog.title"))

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                WorkbenchDialogFormTextField(
                    label: L("ftp.field.address"),
                    placeholder: "",
                    text: $session.address,
                    focus: $isAddressFocused,
                    normalizeDraft: FTPAddress.decodedDisplayAddress
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("ftp-address")

                WorkbenchDialogFormTextField(
                    label: L("ftp.field.port"),
                    placeholder: "",
                    text: $session.port,
                    focus: $isPortFocused
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("ftp-port")

                WorkbenchDialogFormTextField(
                    label: L("ftp.field.username"),
                    placeholder: "",
                    text: $session.username,
                    focus: $isUsernameFocused
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("ftp-username")

                WorkbenchDialogFormPasswordField(
                    label: L("ftp.field.password"),
                    placeholder: "",
                    text: $session.password,
                    validationMessage: session.validationMessage,
                    reservesValidationLine: true,
                    focus: $isPasswordFocused
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("ftp-password")
            }

            connectionActions
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthMedium)
    }

    private var connectionActions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isRedesign: true,
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L("ftp.connect"),
                showsSpinner: session.isSubmitting,
                action: submitConnectionIfIdle
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("ftp-connect")
        }
    }

    private var browserStepView: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L("ftp.dialog.title"))
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
                WorkbenchSpinner()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = session.directoryErrorMessage {
            WorkbenchEmptyHint(message: errorMessage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if session.items.isEmpty {
            WorkbenchEmptyHint(message: L("ftp.empty_folder_items"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WorkbenchScrollView {
                LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    ForEach(session.items) { item in
                        WebDAVBrowserCard(
                            item: item,
                            folderIcon: .folderFtp,
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
            .id(session.currentDirectoryURL?.mediaPath ?? "ftp-browser")
        }
    }

    private var browserActions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
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
            .accessibilityIdentifier("ftp-back")

            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isRedesign: true,
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L("ftp.add"),
                action: submitAddIfReady
            )
            .disabled(!session.canAddInBrowser)
            .accessibilityIdentifier("ftp-add")
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
