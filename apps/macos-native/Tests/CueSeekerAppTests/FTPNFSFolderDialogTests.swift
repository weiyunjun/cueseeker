import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

private final class MockDialogFTPBackend: FTPBackendProtocol, @unchecked Sendable {
    var entriesByPath: [String: [FTPDirectoryEntry]] = [:]
    var shouldFailAuth = false
    var lastConnectedUsername: String?
    var lastConnectedPassword: String?

    func listDirectory(
        host _: String,
        port _: Int,
        relativePath: String,
        username: String,
        password: String
    ) throws -> [FTPDirectoryEntry] {
        lastConnectedUsername = username
        lastConnectedPassword = password
        if shouldFailAuth {
            throw FTPError.authenticationFailed
        }
        guard let entries = entriesByPath[relativePath] else {
            throw FTPError.directoryNotFound
        }
        return entries
    }

    func stat(
        host _: String,
        port _: Int,
        relativePath _: String,
        username _: String,
        password _: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        (true, 0, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func readRange(
        host _: String,
        port _: Int,
        relativePath _: String,
        offset _: UInt64,
        maxLength _: UInt64,
        username _: String,
        password _: String
    ) throws -> (data: Data, totalSize: UInt64) {
        (Data(), 0)
    }

    func streamRange(
        host _: String,
        port _: Int,
        relativePath _: String,
        offset _: UInt64,
        maxLength _: UInt64,
        username _: String,
        password _: String,
        writeChunk _: (UnsafeRawPointer, Int) -> Bool
    ) throws {}

    func rename(
        host _: String,
        port _: Int,
        oldRelativePath _: String,
        newRelativePath _: String,
        username _: String,
        password _: String
    ) throws {}
}

private final class MockDialogNFSBackend: NFSBackendProtocol, @unchecked Sendable {
    var exports: [String] = []
    var entriesByPath: [String: [NFSDirectoryEntry]] = [:]
    var shouldFailPermission = false

    func listExports(host _: String) throws -> [String] {
        if shouldFailPermission {
            throw NFSError.authenticationFailed
        }
        return exports
    }

    func listDirectory(
        host _: String,
        relativePath: String
    ) throws -> [NFSDirectoryEntry] {
        if shouldFailPermission {
            throw NFSError.authenticationFailed
        }
        guard let entries = entriesByPath[relativePath] else {
            throw NFSError.directoryNotFound
        }
        return entries
    }

    func stat(
        host _: String,
        relativePath _: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        (true, 0, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func readRange(
        host _: String,
        relativePath _: String,
        offset _: UInt64,
        maxLength _: UInt64
    ) throws -> (data: Data, totalSize: UInt64) {
        (Data(), 0)
    }

    func streamRange(
        host _: String,
        relativePath _: String,
        offset _: UInt64,
        maxLength _: UInt64,
        writeChunk _: (UnsafeRawPointer, Int) -> Bool
    ) throws {}

    func rename(
        host _: String,
        oldRelativePath _: String,
        newRelativePath _: String
    ) throws {}
}

@Suite(.serialized)
@MainActor
struct FTPNFSFolderDialogTests {
    private struct DialogTestFixture {
        let root: URL
        let databaseURL: URL
        let suiteName: String
        let userDefaults: UserDefaults

        init() throws {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(
                "CueSeekerFTPNFSDialogTests-\(UUID().uuidString)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
            try DatabaseBootstrap.prepare(at: databaseURL)
            let suiteName = "CueSeeker.FTPNFSDialogTests.\(UUID().uuidString)"
            let userDefaults = try #require(UserDefaults(suiteName: suiteName))
            self.root = root
            self.databaseURL = databaseURL
            self.suiteName = suiteName
            self.userDefaults = userDefaults
        }

        func cleanUp() {
            FTPClient.shared.setCustomBackendForTesting(nil, forHost: "dialog-ftp.local")
            NFSClient.shared.setCustomBackendForTesting(nil, forHost: "192.168.1.200")
            userDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }
    }

    @Test
    func ftpDialogDefaultsPortTo21SupportsAnonymousLoginAndAllowsAddingFTPRootDirectly() async throws {
        let fixture = try DialogTestFixture()
        defer { fixture.cleanUp() }

        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: fixture.userDefaults,
            databaseURL: fixture.databaseURL
        )

        app.openFTPFolderDialog()
        let session = try #require(app.library.ftpDialogSession)
        #expect(session.step == .connection)
        #expect(session.address.isEmpty)
        #expect(session.port == "21")
        #expect(session.username.isEmpty)
        #expect(session.password.isEmpty)
        #expect(session.validationMessage == nil)

        // Empty address -> inline invalid address message, no toast
        app.confirmFTPFolderDialog(session)
        #expect(session.step == .connection)
        #expect(session.validationMessage == L("ftp.error.invalid_address"))
        #expect(app.toast.visibleItems.isEmpty)

        // Setting address without ftp:// preserves user input without inserting ftp://, while decoding percent-encoding
        session.address = "nas.local/Media/%E5%8A%A8%E6%BC%AB"
        #expect(session.address == "nas.local/Media/动漫")

        // Invalid port -> inline invalid port message, no toast
        session.port = "70000"
        app.confirmFTPFolderDialog(session)
        #expect(session.step == .connection)
        #expect(session.validationMessage == L("ftp.error.invalid_port"))
        #expect(app.toast.visibleItems.isEmpty)

        // Connect anonymously to FTP root ("dialog-ftp.local" with empty username/password)
        let backend = MockDialogFTPBackend()
        backend.entriesByPath[""] = [
            FTPDirectoryEntry(name: "Movies", isDirectory: true, fileSize: 0, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)),
            FTPDirectoryEntry(name: "Preview.mp4", isDirectory: false, fileSize: 1024, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)),
        ]
        FTPClient.shared.setCustomBackendForTesting(backend, forHost: "dialog-ftp.local")

        session.address = "dialog-ftp.local"
        session.port = "21"
        session.username = ""
        session.password = ""

        app.confirmFTPFolderDialog(session)
        await session.validationTask?.value

        #expect(session.step == .browser)
        #expect(backend.lastConnectedUsername == "")
        #expect(backend.lastConnectedPassword == "")
        #expect(session.breadcrumbNodes.map(\.title) == ["dialog-ftp.local"])
        #expect(session.items.map(\.name) == ["Movies", "Preview.mp4"])
        // Unlike SMB/NFS, FTP root is a directly indexable directory so Add is enabled even with no subfolder selected
        #expect(session.selectedFolderPaths.isEmpty)
        #expect(session.canAddInBrowser)
        let ftpRootURL = try #require(FTPAddress.parseURL(from: "ftp://dialog-ftp.local"))
        #expect(session.targetFoldersToAdd() == [ftpRootURL.standardizedMediaURL])
    }

    @Test
    func nfsDialogSupportsColonAndSlashAddressesListsTopLevelExportsAndDisablesAddAtHostRootUntilSelected() async throws {
        let fixture = try DialogTestFixture()
        defer { fixture.cleanUp() }

        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: fixture.userDefaults,
            databaseURL: fixture.databaseURL
        )

        let backend = MockDialogNFSBackend()
        backend.exports = ["/volume1/video", "/volume2/archive"]
        backend.entriesByPath["volume1/video"] = [
            NFSDirectoryEntry(name: "01. Anime", isDirectory: true, fileSize: 0, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)),
            NFSDirectoryEntry(name: "02. Drama", isDirectory: true, fileSize: 0, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)),
            NFSDirectoryEntry(name: "Sample.mkv", isDirectory: false, fileSize: 2048, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)),
        ]
        NFSClient.shared.setCustomBackendForTesting(backend, forHost: "192.168.1.200")

        app.openNFSFolderDialog()
        let session = try #require(app.library.nfsDialogSession)
        #expect(session.step == .connection)
        #expect(session.address.isEmpty)
        #expect(session.validationMessage == nil)

        // Empty address -> inline invalid address message, no toast
        app.confirmNFSFolderDialog(session)
        #expect(session.step == .connection)
        #expect(session.validationMessage == L("nfs.error.invalid_address"))
        #expect(app.toast.visibleItems.isEmpty)

        // Host-only connection lists top-level NFS exports
        session.address = "192.168.1.200"
        app.confirmNFSFolderDialog(session)
        await session.validationTask?.value

        #expect(session.step == .browser)
        #expect(session.isAtHostRoot)
        #expect(session.breadcrumbNodes.map(\.title) == ["192.168.1.200"])
        #expect(session.items.map(\.name) == ["volume1/video", "volume2/archive"])
        // At host root with no export selected -> Add is disabled
        #expect(!session.canAddInBrowser)
        #expect(session.targetFoldersToAdd().isEmpty)

        // Selecting an export at host root enables Add
        let videoExportItem = try #require(session.items.first(where: { $0.name == "volume1/video" }))
        session.toggleFolderSelection(videoExportItem)
        #expect(session.canAddInBrowser)

        // Double-clicking export drills into nfs://192.168.1.200/volume1/video and enables Add even with no selection
        app.openNFSSubfolder(videoExportItem, in: session)
        await session.directoryTask?.value

        #expect(!session.isAtHostRoot)
        #expect(session.breadcrumbNodes.map(\.title) == ["192.168.1.200", "volume1/video"])
        #expect(session.selectedFolderPaths.isEmpty)
        #expect(session.canAddInBrowser)
        #expect(session.items.map(\.name) == ["01. Anime", "02. Drama", "Sample.mkv"])

        // Back button returns to Step 1 and preserves exact user input
        app.navigateBackInNFSFolderDialog(session)
        #expect(session.step == .connection)
        #expect(session.address == "192.168.1.200")

        // Connect using NAS colon syntax (192.168.1.200:/volume1/video) without mutating input field
        session.address = "192.168.1.200:/volume1/video"
        app.confirmNFSFolderDialog(session)
        await session.validationTask?.value

        #expect(session.step == .browser)
        #expect(!session.isAtHostRoot)
        #expect(session.currentDirectoryURL?.mediaPath == "nfs://192.168.1.200/volume1/video")
        #expect(session.items.map(\.name) == ["01. Anime", "02. Drama", "Sample.mkv"])
    }
}
