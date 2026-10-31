import SwiftUI
import CueSeekerCore

@MainActor
final class WebDAVFolderDialogSession: RemoteFolderDialogSessionProtocol {
    typealias Config = WebDAVRootConfig

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
    @Published var existingRootFolders: [URL] = []
    @Published var isLoadingDirectory: Bool = false
    @Published var directoryErrorMessage: String? = nil

    var validationTask: Task<Void, Never>?
    var directoryTask: Task<Void, Never>?
}

struct WebDAVFolderDialog: View {
    private static let dialogStyle = RemoteFolderDialogStyle(
        titleKey: "webdav.dialog.title",
        connectTitleKey: "webdav.connect",
        addTitleKey: "webdav.add",
        emptyFolderItemsKey: "webdav.empty_folder_items",
        folderIcon: .folderWebdav,
        connectAccessibilityID: "webdav-connect",
        backAccessibilityID: "webdav-back",
        addAccessibilityID: "webdav-add",
        browserFallbackID: "webdav-browser"
    )

    @ObservedObject var session: WebDAVFolderDialogSession
    let onConfirm: () -> Void
    let onClose: () -> Void
    var onBack: (() -> Void)? = nil
    var onOpenFolder: ((WebDAVBrowserItem) -> Void)? = nil
    var onSelectBreadcrumb: ((WebDAVFolderDialogSession.BreadcrumbNode) -> Void)? = nil

    @FocusState private var isAddressFocused: Bool
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
                label: L("webdav.field.address"),
                placeholder: "",
                text: $session.address,
                focus: $isAddressFocused,
                normalizeDraft: WebDAVAddress.decodedDisplayAddress,
                dialogInputKind: .remoteAddress
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("webdav-address")

            WorkbenchDialogFormTextField(
                label: L("webdav.field.username"),
                placeholder: "",
                text: $session.username,
                focus: $isUsernameFocused,
                dialogInputKind: .remoteUsername
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("webdav-username")

            WorkbenchDialogFormPasswordField(
                label: L("webdav.field.password"),
                placeholder: "",
                text: $session.password,
                validationMessage: session.validationMessage,
                reservesValidationLine: true,
                focus: $isPasswordFocused,
                dialogInputKind: .remotePassword
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("webdav-password")
        }
    }
}
