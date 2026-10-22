import SwiftUI
import CueSeekerCore

@MainActor
final class NFSFolderDialogSession: RemoteFolderDialogSessionProtocol {
    typealias Config = NFSRootConfig

    let id = UUID()
    @Published var step: Step = .connection
    @Published var address: String = "" {
        didSet {
            let decoded = NFSAddress.decodedDisplayAddress(address)
            if address != decoded {
                address = decoded
            }
        }
    }
    @Published var validationMessage: String? = nil
    @Published var isSubmitting: Bool = false

    @Published var baseConfig: NFSRootConfig? = nil
    @Published var breadcrumbNodes: [BreadcrumbNode] = []
    @Published var items: [WebDAVBrowserItem] = []
    @Published var selectedFolderPaths: Set<String> = []
    @Published var isLoadingDirectory: Bool = false
    @Published var directoryErrorMessage: String? = nil

    var validationTask: Task<Void, Never>?
    var directoryTask: Task<Void, Never>?

    var isAtHostRoot: Bool {
        guard let currentDirectoryURL else { return false }
        return NFSAddress.isHostRoot(currentDirectoryURL)
    }
}

struct NFSFolderDialog: View {
    private static let dialogStyle = RemoteFolderDialogStyle(
        titleKey: "nfs.dialog.title",
        connectTitleKey: "nfs.connect",
        addTitleKey: "nfs.add",
        emptyFolderItemsKey: "nfs.empty_folder_items",
        folderIcon: .folderNfs,
        connectAccessibilityID: "nfs-connect",
        backAccessibilityID: "nfs-back",
        addAccessibilityID: "nfs-add",
        browserFallbackID: "nfs-browser"
    )

    @ObservedObject var session: NFSFolderDialogSession
    let onConfirm: () -> Void
    let onClose: () -> Void
    var onBack: (() -> Void)? = nil
    var onOpenFolder: ((WebDAVBrowserItem) -> Void)? = nil
    var onSelectBreadcrumb: ((NFSFolderDialogSession.BreadcrumbNode) -> Void)? = nil

    @FocusState private var isAddressFocused: Bool

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
                label: L("nfs.field.address"),
                placeholder: "",
                text: $session.address,
                validationMessage: session.validationMessage,
                reservesValidationLine: true,
                showsErrorBorder: false,
                focus: $isAddressFocused,
                normalizeDraft: NFSAddress.decodedDisplayAddress
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("nfs-address")
        }
    }
}
