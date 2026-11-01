import SwiftUI
import CueSeekerCore

@MainActor
final class FTPFolderDialogSession: RemoteFolderDialogSessionProtocol {
    typealias Config = FTPRootConfig

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
    @Published var existingRootFolders: [URL] = []
    @Published var isLoadingDirectory: Bool = false
    @Published var directoryErrorMessage: String? = nil

    var validationTask: Task<Void, Never>?
    var directoryTask: Task<Void, Never>?
}

struct FTPFolderDialog: View {
    private static let dialogStyle = RemoteFolderDialogStyle(
        titleKey: "ftp.dialog.title",
        connectTitleKey: "ftp.connect",
        emptyFolderItemsKey: "ftp.empty_folder_items",
        folderIcon: .folderFtp,
        connectAccessibilityID: "ftp-connect",
        backAccessibilityID: "ftp-back",
        addAccessibilityID: "ftp-add",
        browserFallbackID: "ftp-browser"
    )

    @ObservedObject var session: FTPFolderDialogSession
    let onConfirm: () -> Void
    let onClose: () -> Void
    var onBack: (() -> Void)? = nil
    var onOpenFolder: ((WebDAVBrowserItem) -> Void)? = nil
    var onSelectBreadcrumb: ((FTPFolderDialogSession.BreadcrumbNode) -> Void)? = nil

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
                label: L("ftp.field.address"),
                placeholder: "",
                text: $session.address,
                focus: $isAddressFocused,
                normalizeDraft: FTPAddress.decodedDisplayAddress,
                dialogInputKind: .remoteAddress
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("ftp-address")

            WorkbenchDialogFormTextField(
                label: L("ftp.field.port"),
                placeholder: "",
                text: $session.port,
                focus: $isPortFocused,
                dialogInputKind: .remotePort
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("ftp-port")

            WorkbenchDialogFormTextField(
                label: L("ftp.field.username"),
                placeholder: "",
                text: $session.username,
                focus: $isUsernameFocused,
                dialogInputKind: .remoteUsername
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("ftp-username")

            WorkbenchDialogFormPasswordField(
                label: L("ftp.field.password"),
                placeholder: "",
                text: $session.password,
                validationMessage: session.validationMessage,
                reservesValidationLine: true,
                focus: $isPasswordFocused,
                dialogInputKind: .remotePassword
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("ftp-password")
        }
    }
}
