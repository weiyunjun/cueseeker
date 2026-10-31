import SwiftUI
import CueSeekerCore

@MainActor
final class SMBFolderDialogSession: RemoteFolderDialogSessionProtocol {
    typealias Config = SMBRootConfig

    let id = UUID()
    @Published var step: Step = .connection
    @Published var address: String = "" {
        didSet {
            let decoded = SMBAddress.decodedDisplayAddress(address)
            if address != decoded {
                address = decoded
            }
        }
    }
    @Published var port: String = SMBAddress.defaultPortString
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var validationMessage: String? = nil
    @Published var isSubmitting: Bool = false

    @Published var baseConfig: SMBRootConfig? = nil
    @Published var breadcrumbNodes: [BreadcrumbNode] = []
    @Published var items: [WebDAVBrowserItem] = []
    @Published var selectedFolderPaths: Set<String> = []
    @Published var existingRootFolders: [URL] = []
    @Published var isLoadingDirectory: Bool = false
    @Published var directoryErrorMessage: String? = nil

    var validationTask: Task<Void, Never>?
    var directoryTask: Task<Void, Never>?

    var isAtHostRoot: Bool {
        guard let currentDirectoryURL else { return false }
        return SMBAddress.isHostRoot(currentDirectoryURL)
    }
}

struct SMBFolderDialog: View {
    private static let dialogStyle = RemoteFolderDialogStyle(
        titleKey: "smb.dialog.title",
        connectTitleKey: "smb.connect",
        addTitleKey: "smb.add",
        emptyFolderItemsKey: "smb.empty_folder_items",
        folderIcon: .folderSmb,
        connectAccessibilityID: "smb-connect",
        backAccessibilityID: "smb-back",
        addAccessibilityID: "smb-add",
        browserFallbackID: "smb-browser"
    )

    @ObservedObject var session: SMBFolderDialogSession
    let onConfirm: () -> Void
    let onClose: () -> Void
    var onBack: (() -> Void)? = nil
    var onOpenFolder: ((WebDAVBrowserItem) -> Void)? = nil
    var onSelectBreadcrumb: ((SMBFolderDialogSession.BreadcrumbNode) -> Void)? = nil

    @FocusState private var isAddressFocused: Bool
    @FocusState private var isPortFocused: Bool
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        RemoteFolderDialogContainer(
            session: session,
            style: Self.dialogStyle,
            onConfirm: onConfirm,
            onClose: onClose,
            onBack: onBack,
            onOpenFolder: onOpenFolder,
            onSelectBreadcrumb: onSelectBreadcrumb
        ) {
            WorkbenchDialogFormTextField(
                label: L("smb.field.address"),
                placeholder: "",
                text: $session.address,
                focus: $isAddressFocused,
                normalizeDraft: SMBAddress.decodedDisplayAddress,
                dialogInputKind: .remoteAddress
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("smb-address")

            WorkbenchDialogFormTextField(
                label: L("smb.field.port"),
                placeholder: "",
                text: $session.port,
                focus: $isPortFocused,
                dialogInputKind: .remotePort
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("smb-port")

            WorkbenchDialogFormTextField(
                label: L("smb.field.username"),
                placeholder: "",
                text: $session.username,
                focus: $isUsernameFocused,
                dialogInputKind: .remoteUsername
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("smb-username")

            WorkbenchDialogFormPasswordField(
                label: L("smb.field.password"),
                placeholder: "",
                text: $session.password,
                validationMessage: session.validationMessage,
                reservesValidationLine: true,
                focus: $isPasswordFocused,
                dialogInputKind: .remotePassword
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("smb-password")
        }
    }
}
