import Foundation
import CueSeekerCore

@MainActor
extension AppCoordinator {
    // MARK: - WebDAV Folder Dialog

    func openWebDAVFolderDialog() {
        openRemoteFolderDialog(\.webdavDialogSession) {
            WebDAVFolderDialogSession()
        }
    }

    func closeWebDAVFolderDialog() {
        closeRemoteFolderDialog(\.webdavDialogSession)
    }

    func confirmWebDAVFolderDialog(_ session: WebDAVFolderDialogSession) {
        switch session.step {
        case .connection:
            connectWebDAVFolderDialog(session)
        case .browser:
            confirmWebDAVBrowserAdd(session)
        }
    }

    func connectWebDAVFolderDialog(_ session: WebDAVFolderDialogSession) {
        guard canStartRemoteConnection(session, sessionKeyPath: \.webdavDialogSession) else {
            return
        }

        guard WebDAVAddress.parseURL(from: session.address) != nil else {
            session.validationMessage = L("webdav.error.invalid_address")
            return
        }

        let trimmedUsername = session.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = session.password
        let rawAddress = session.address

        runRemoteConnectionValidation(session, sessionKeyPath: \.webdavDialogSession) {
            try await WebDAVClient.shared.connectAndBrowseDirectory(
                address: rawAddress,
                username: trimmedUsername,
                password: password
            )
        }
    }

    func navigateBackInWebDAVFolderDialog(_ session: WebDAVFolderDialogSession) {
        navigateBackInRemoteFolderDialog(session, sessionKeyPath: \.webdavDialogSession)
    }

    func openWebDAVSubfolder(
        _ item: WebDAVBrowserItem,
        in session: WebDAVFolderDialogSession
    ) {
        openRemoteSubfolder(item, in: session, sessionKeyPath: \.webdavDialogSession) { folderURL, baseConfig in
            try await WebDAVClient.shared.browseDirectory(
                at: folderURL,
                baseConfig: baseConfig
            )
        }
    }

    func navigateWebDAVBreadcrumb(
        to node: WebDAVFolderDialogSession.BreadcrumbNode,
        in session: WebDAVFolderDialogSession
    ) {
        navigateRemoteBreadcrumb(to: node, in: session, sessionKeyPath: \.webdavDialogSession) { folderURL, baseConfig in
            try await WebDAVClient.shared.browseDirectory(
                at: folderURL,
                baseConfig: baseConfig
            )
        }
    }

    func confirmWebDAVBrowserAdd(_ session: WebDAVFolderDialogSession) {
        confirmRemoteBrowserAdd(session, sessionKeyPath: \.webdavDialogSession) { scopedConfig in
            WebDAVConfigurationStore.shared.save(scopedConfig)
        }
    }

    // MARK: - SMB Folder Dialog

    func openSMBFolderDialog() {
        openRemoteFolderDialog(\.smbDialogSession) {
            SMBFolderDialogSession()
        }
    }

    func closeSMBFolderDialog() {
        closeRemoteFolderDialog(\.smbDialogSession)
    }

    func confirmSMBFolderDialog(_ session: SMBFolderDialogSession) {
        switch session.step {
        case .connection:
            connectSMBFolderDialog(session)
        case .browser:
            confirmSMBBrowserAdd(session)
        }
    }

    func connectSMBFolderDialog(_ session: SMBFolderDialogSession) {
        guard canStartRemoteConnection(session, sessionKeyPath: \.smbDialogSession) else {
            return
        }

        let trimmedAddress = session.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            session.validationMessage = L("smb.error.invalid_address")
            return
        }
        guard let parsedPort = SMBAddress.parsePort(session.port) else {
            session.validationMessage = L("smb.error.invalid_port")
            return
        }
        guard SMBAddress.parseURL(from: trimmedAddress, portOverride: parsedPort) != nil else {
            session.validationMessage = L("smb.error.invalid_address")
            return
        }

        let trimmedUsername = session.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = session.password
        let rawAddress = session.address
        let rawPort = session.port

        runRemoteConnectionValidation(session, sessionKeyPath: \.smbDialogSession) {
            try await SMBClient.shared.connectAndBrowseDirectory(
                address: rawAddress,
                port: rawPort,
                username: trimmedUsername,
                password: password
            )
        }
    }

    func navigateBackInSMBFolderDialog(_ session: SMBFolderDialogSession) {
        navigateBackInRemoteFolderDialog(session, sessionKeyPath: \.smbDialogSession)
    }

    func openSMBSubfolder(
        _ item: WebDAVBrowserItem,
        in session: SMBFolderDialogSession
    ) {
        openRemoteSubfolder(item, in: session, sessionKeyPath: \.smbDialogSession) { folderURL, baseConfig in
            try await SMBClient.shared.browseDirectory(
                at: folderURL,
                baseConfig: baseConfig
            )
        }
    }

    func navigateSMBBreadcrumb(
        to node: SMBFolderDialogSession.BreadcrumbNode,
        in session: SMBFolderDialogSession
    ) {
        navigateRemoteBreadcrumb(to: node, in: session, sessionKeyPath: \.smbDialogSession) { folderURL, baseConfig in
            try await SMBClient.shared.browseDirectory(
                at: folderURL,
                baseConfig: baseConfig
            )
        }
    }

    func confirmSMBBrowserAdd(_ session: SMBFolderDialogSession) {
        confirmRemoteBrowserAdd(session, sessionKeyPath: \.smbDialogSession) { scopedConfig in
            SMBConfigurationStore.shared.save(scopedConfig)
        }
    }

    // MARK: - FTP Folder Dialog

    func openFTPFolderDialog() {
        openRemoteFolderDialog(\.ftpDialogSession) {
            FTPFolderDialogSession()
        }
    }

    func closeFTPFolderDialog() {
        closeRemoteFolderDialog(\.ftpDialogSession)
    }

    func confirmFTPFolderDialog(_ session: FTPFolderDialogSession) {
        switch session.step {
        case .connection:
            connectFTPFolderDialog(session)
        case .browser:
            confirmFTPBrowserAdd(session)
        }
    }

    func connectFTPFolderDialog(_ session: FTPFolderDialogSession) {
        guard canStartRemoteConnection(session, sessionKeyPath: \.ftpDialogSession) else {
            return
        }

        let trimmedAddress = session.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            session.validationMessage = L("ftp.error.invalid_address")
            return
        }
        guard let parsedPort = FTPAddress.parsePort(session.port) else {
            session.validationMessage = L("ftp.error.invalid_port")
            return
        }
        guard FTPAddress.parseURL(from: trimmedAddress, portOverride: parsedPort) != nil else {
            session.validationMessage = L("ftp.error.invalid_address")
            return
        }

        let trimmedUsername = session.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = session.password
        let rawAddress = session.address
        let rawPort = session.port

        runRemoteConnectionValidation(session, sessionKeyPath: \.ftpDialogSession) {
            try await FTPClient.shared.connectAndBrowseDirectory(
                address: rawAddress,
                port: rawPort,
                username: trimmedUsername,
                password: password
            )
        }
    }

    func navigateBackInFTPFolderDialog(_ session: FTPFolderDialogSession) {
        navigateBackInRemoteFolderDialog(session, sessionKeyPath: \.ftpDialogSession)
    }

    func openFTPSubfolder(
        _ item: WebDAVBrowserItem,
        in session: FTPFolderDialogSession
    ) {
        openRemoteSubfolder(item, in: session, sessionKeyPath: \.ftpDialogSession) { folderURL, baseConfig in
            try await FTPClient.shared.browseDirectory(
                at: folderURL,
                baseConfig: baseConfig
            )
        }
    }

    func navigateFTPBreadcrumb(
        to node: FTPFolderDialogSession.BreadcrumbNode,
        in session: FTPFolderDialogSession
    ) {
        navigateRemoteBreadcrumb(to: node, in: session, sessionKeyPath: \.ftpDialogSession) { folderURL, baseConfig in
            try await FTPClient.shared.browseDirectory(
                at: folderURL,
                baseConfig: baseConfig
            )
        }
    }

    func confirmFTPBrowserAdd(_ session: FTPFolderDialogSession) {
        confirmRemoteBrowserAdd(session, sessionKeyPath: \.ftpDialogSession) { scopedConfig in
            FTPConfigurationStore.shared.save(scopedConfig)
        }
    }

    // MARK: - NFS Folder Dialog

    func openNFSFolderDialog() {
        openRemoteFolderDialog(\.nfsDialogSession) {
            NFSFolderDialogSession()
        }
    }

    func closeNFSFolderDialog() {
        closeRemoteFolderDialog(\.nfsDialogSession)
    }

    func confirmNFSFolderDialog(_ session: NFSFolderDialogSession) {
        switch session.step {
        case .connection:
            connectNFSFolderDialog(session)
        case .browser:
            confirmNFSBrowserAdd(session)
        }
    }

    func connectNFSFolderDialog(_ session: NFSFolderDialogSession) {
        guard canStartRemoteConnection(session, sessionKeyPath: \.nfsDialogSession) else {
            return
        }

        let trimmedAddress = session.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty,
              NFSAddress.parseURL(from: trimmedAddress) != nil
        else {
            session.validationMessage = L("nfs.error.invalid_address")
            return
        }

        let rawAddress = session.address

        runRemoteConnectionValidation(session, sessionKeyPath: \.nfsDialogSession) {
            try await NFSClient.shared.connectAndBrowseDirectory(
                address: rawAddress
            )
        }
    }

    func navigateBackInNFSFolderDialog(_ session: NFSFolderDialogSession) {
        navigateBackInRemoteFolderDialog(session, sessionKeyPath: \.nfsDialogSession)
    }

    func openNFSSubfolder(
        _ item: WebDAVBrowserItem,
        in session: NFSFolderDialogSession
    ) {
        openRemoteSubfolder(item, in: session, sessionKeyPath: \.nfsDialogSession) { folderURL, baseConfig in
            try await NFSClient.shared.browseDirectory(
                at: folderURL,
                baseConfig: baseConfig
            )
        }
    }

    func navigateNFSBreadcrumb(
        to node: NFSFolderDialogSession.BreadcrumbNode,
        in session: NFSFolderDialogSession
    ) {
        navigateRemoteBreadcrumb(to: node, in: session, sessionKeyPath: \.nfsDialogSession) { folderURL, baseConfig in
            try await NFSClient.shared.browseDirectory(
                at: folderURL,
                baseConfig: baseConfig
            )
        }
    }

    func confirmNFSBrowserAdd(_ session: NFSFolderDialogSession) {
        confirmRemoteBrowserAdd(session, sessionKeyPath: \.nfsDialogSession) { scopedConfig in
            NFSConfigurationStore.shared.save(scopedConfig)
        }
    }

    // MARK: - Shared Remote Dialog State Machine

    private func openRemoteFolderDialog<Session: RemoteFolderDialogSessionProtocol>(
        _ sessionKeyPath: ReferenceWritableKeyPath<LibraryStore, Session?>,
        makeSession: () -> Session
    ) {
        let startedAt = DebugInteractionLatencyProbe.now()
        guard !tasks.hasLibraryTask, !indexing.databaseMaintenanceStatus.isCompacting else {
            return
        }
        let session = makeSession()
        session.existingRootFolders = indexing.selectedFolders
        library[keyPath: sessionKeyPath] = session
        DebugInteractionLatencyProbe.beginDialogOpen(
            dialogID: "remote_folder_\(String(describing: Session.self))",
            trigger: "open_remote_dialog",
            startedAt: startedAt,
            syncPrepFinishedAt: DebugInteractionLatencyProbe.now()
        )
    }

    private func closeRemoteFolderDialog<Session: RemoteFolderDialogSessionProtocol>(
        _ sessionKeyPath: ReferenceWritableKeyPath<LibraryStore, Session?>
    ) {
        library[keyPath: sessionKeyPath]?.cancelValidation()
        library[keyPath: sessionKeyPath] = nil
    }

    private func canStartRemoteConnection<Session: RemoteFolderDialogSessionProtocol>(
        _ session: Session,
        sessionKeyPath: ReferenceWritableKeyPath<LibraryStore, Session?>
    ) -> Bool {
        library[keyPath: sessionKeyPath]?.id == session.id
            && session.step == .connection
            && !session.isSubmitting
            && !tasks.hasLibraryTask
            && !indexing.databaseMaintenanceStatus.isCompacting
    }

    private func runRemoteConnectionValidation<Session: RemoteFolderDialogSessionProtocol>(
        _ session: Session,
        sessionKeyPath: ReferenceWritableKeyPath<LibraryStore, Session?>,
        connect: @escaping @Sendable () async throws -> (config: Session.Config, items: [WebDAVBrowserItem])
    ) {
        let startedAt = DebugInteractionLatencyProbe.now()
        session.validationMessage = nil
        session.isSubmitting = true
        let syncPrepFinishedAt = DebugInteractionLatencyProbe.now()
        session.validationTask = Task { @MainActor [weak self, weak session] in
            do {
                let connected = try await connect()
                guard !Task.isCancelled,
                      let self,
                      let session,
                      self.library[keyPath: sessionKeyPath]?.id == session.id
                else {
                    return
                }
                session.isSubmitting = false
                session.validationTask = nil
                session.existingRootFolders = self.indexing.selectedFolders
                session.enterBrowser(config: connected.config, initialItems: connected.items)
                DebugInteractionLatencyProbe.recordDialogInternalTransition(
                    dialogID: "remote_folder_\(String(describing: Session.self))",
                    transition: "step1_to_step2_browser",
                    trigger: "connect",
                    startedAt: startedAt,
                    syncPrepFinishedAt: syncPrepFinishedAt,
                    asyncLoadFinishedAt: DebugInteractionLatencyProbe.now()
                )
                AppLogger.shared.info(
                    .network,
                    "Remote folder connected",
                    details: "scheme=\(connected.config.rootURL.scheme ?? "unknown") items=\(connected.items.count)"
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      let self,
                      let session,
                      self.library[keyPath: sessionKeyPath]?.id == session.id
                else {
                    return
                }
                session.isSubmitting = false
                session.validationTask = nil
                let errorText = Self.errorMessage(for: error)
                session.validationMessage = errorText
                DebugInteractionLatencyProbe.recordDialogInternalTransition(
                    dialogID: "remote_folder_\(String(describing: Session.self))",
                    transition: "step1_connect_failed",
                    trigger: "connect",
                    startedAt: startedAt,
                    syncPrepFinishedAt: syncPrepFinishedAt,
                    asyncLoadFinishedAt: DebugInteractionLatencyProbe.now()
                )
                AppLogger.shared.warn(
                    .network,
                    "Remote folder connection failed",
                    details: "error=\"\(errorText)\""
                )
            }
        }
    }

    private func navigateBackInRemoteFolderDialog<Session: RemoteFolderDialogSessionProtocol>(
        _ session: Session,
        sessionKeyPath: ReferenceWritableKeyPath<LibraryStore, Session?>
    ) {
        let startedAt = DebugInteractionLatencyProbe.now()
        guard library[keyPath: sessionKeyPath]?.id == session.id else {
            return
        }
        session.returnToConnection()
        DebugInteractionLatencyProbe.recordDialogInternalTransition(
            dialogID: "remote_folder_\(String(describing: Session.self))",
            transition: "step2_to_step1_connection",
            trigger: "back_button",
            startedAt: startedAt,
            syncPrepFinishedAt: DebugInteractionLatencyProbe.now()
        )
    }

    private func openRemoteSubfolder<Session: RemoteFolderDialogSessionProtocol>(
        _ item: WebDAVBrowserItem,
        in session: Session,
        sessionKeyPath: ReferenceWritableKeyPath<LibraryStore, Session?>,
        browseDirectory: @escaping @Sendable (URL, Session.Config) async throws -> [WebDAVBrowserItem]
    ) {
        guard library[keyPath: sessionKeyPath]?.id == session.id,
              session.step == .browser,
              item.kind == .folder,
              let baseConfig = session.baseConfig
        else {
            return
        }

        session.existingRootFolders = indexing.selectedFolders
        let targetNode = RemoteFolderBreadcrumbNode(
            url: item.url,
            title: item.name
        )
        if let existingIndex = session.breadcrumbNodes.firstIndex(where: { $0.id == targetNode.id }) {
            session.breadcrumbNodes = Array(session.breadcrumbNodes.prefix(existingIndex + 1))
        } else {
            session.breadcrumbNodes.append(targetNode)
        }
        loadRemoteBrowserDirectory(
            at: targetNode.url,
            baseConfig: baseConfig,
            in: session,
            sessionKeyPath: sessionKeyPath,
            trigger: "open_subfolder",
            browseDirectory: browseDirectory
        )
    }

    private func navigateRemoteBreadcrumb<Session: RemoteFolderDialogSessionProtocol>(
        to node: RemoteFolderBreadcrumbNode,
        in session: Session,
        sessionKeyPath: ReferenceWritableKeyPath<LibraryStore, Session?>,
        browseDirectory: @escaping @Sendable (URL, Session.Config) async throws -> [WebDAVBrowserItem]
    ) {
        guard library[keyPath: sessionKeyPath]?.id == session.id,
              session.step == .browser,
              let baseConfig = session.baseConfig,
              let targetIndex = session.breadcrumbNodes.firstIndex(where: { $0.id == node.id })
        else {
            return
        }

        session.existingRootFolders = indexing.selectedFolders
        session.breadcrumbNodes = Array(session.breadcrumbNodes.prefix(targetIndex + 1))
        loadRemoteBrowserDirectory(
            at: node.url,
            baseConfig: baseConfig,
            in: session,
            sessionKeyPath: sessionKeyPath,
            trigger: "breadcrumb_click",
            browseDirectory: browseDirectory
        )
    }

    private func loadRemoteBrowserDirectory<Session: RemoteFolderDialogSessionProtocol>(
        at folderURL: URL,
        baseConfig: Session.Config,
        in session: Session,
        sessionKeyPath: ReferenceWritableKeyPath<LibraryStore, Session?>,
        trigger: String,
        browseDirectory: @escaping @Sendable (URL, Session.Config) async throws -> [WebDAVBrowserItem]
    ) {
        let startedAt = DebugInteractionLatencyProbe.now()
        session.directoryTask?.cancel()
        session.selectedFolderPaths.removeAll()
        session.directoryErrorMessage = nil
        session.isLoadingDirectory = true
        let syncPrepFinishedAt = DebugInteractionLatencyProbe.now()
        let targetID = folderURL.standardizedMediaURL.mediaPath

        session.directoryTask = Task { @MainActor [weak self, weak session] in
            do {
                let loadedItems = try await browseDirectory(folderURL, baseConfig)
                guard !Task.isCancelled,
                      let self,
                      let session,
                      self.library[keyPath: sessionKeyPath]?.id == session.id,
                      session.step == .browser,
                      session.currentDirectoryURL?.mediaPath == targetID
                else {
                    return
                }
                session.items = loadedItems
                session.isLoadingDirectory = false
                session.directoryErrorMessage = nil
                session.directoryTask = nil
                DebugInteractionLatencyProbe.recordDialogInternalTransition(
                    dialogID: "remote_folder_\(String(describing: Session.self))",
                    transition: "browse_directory",
                    trigger: trigger,
                    startedAt: startedAt,
                    syncPrepFinishedAt: syncPrepFinishedAt,
                    asyncLoadFinishedAt: DebugInteractionLatencyProbe.now()
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      let self,
                      let session,
                      self.library[keyPath: sessionKeyPath]?.id == session.id,
                      session.step == .browser,
                      session.currentDirectoryURL?.mediaPath == targetID
                else {
                    return
                }
                session.items = []
                session.isLoadingDirectory = false
                let errorText = Self.errorMessage(for: error)
                session.directoryErrorMessage = errorText
                session.directoryTask = nil
                DebugInteractionLatencyProbe.recordDialogInternalTransition(
                    dialogID: "remote_folder_\(String(describing: Session.self))",
                    transition: "browse_directory_failed",
                    trigger: trigger,
                    startedAt: startedAt,
                    syncPrepFinishedAt: syncPrepFinishedAt,
                    asyncLoadFinishedAt: DebugInteractionLatencyProbe.now()
                )
                AppLogger.shared.warn(
                    .network,
                    "Remote directory browse failed",
                    details: "folder=\"\(folderURL.lastPathComponent)\" error=\"\(errorText)\""
                )
            }
        }
    }

    private func confirmRemoteBrowserAdd<Session: RemoteFolderDialogSessionProtocol>(
        _ session: Session,
        sessionKeyPath: ReferenceWritableKeyPath<LibraryStore, Session?>,
        saveScopedConfig: (Session.Config) -> Void
    ) {
        guard library[keyPath: sessionKeyPath]?.id == session.id,
              session.canAddInBrowser,
              let baseConfig = session.baseConfig,
              !tasks.hasLibraryTask,
              !indexing.databaseMaintenanceStatus.isCompacting
        else {
            return
        }

        let targetFolders = session.targetFoldersToAdd()
        guard !targetFolders.isEmpty else {
            return
        }

        for folder in targetFolders {
            let scopedConfig = baseConfig.scopedConfig(for: folder)
            saveScopedConfig(scopedConfig)
        }

        session.cancelValidation()
        library[keyPath: sessionKeyPath] = nil
        addFolders(targetFolders)
    }
}
