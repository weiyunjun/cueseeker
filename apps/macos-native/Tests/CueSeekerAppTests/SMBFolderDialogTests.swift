import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

private final class MockDialogSMBBackend: SMBBackendProtocol, @unchecked Sendable {
    var shares: [String] = []
    var entriesByPath: [String: [SMBDirectoryEntry]] = [:]
    var shouldFailAuth = false

    func listShares(
        host _: String,
        port _: Int,
        username _: String,
        password _: String
    ) throws -> [String] {
        if shouldFailAuth {
            throw SMBError.authenticationFailed
        }
        return shares
    }

    func listDirectory(
        host _: String,
        port _: Int,
        share: String,
        relativePath: String,
        username _: String,
        password _: String
    ) throws -> [SMBDirectoryEntry] {
        if shouldFailAuth {
            throw SMBError.authenticationFailed
        }
        let key = relativePath.isEmpty ? share : "\(share)/\(relativePath)"
        guard let entries = entriesByPath[key] else {
            throw SMBError.directoryNotFound
        }
        return entries
    }

    func stat(
        host _: String,
        port _: Int,
        share _: String,
        relativePath _: String,
        username _: String,
        password _: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        (true, 0, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func readRange(
        host _: String,
        port _: Int,
        share _: String,
        relativePath _: String,
        offset _: UInt64,
        maxLength _: UInt64,
        username _: String,
        password _: String
    ) throws -> (data: Data, totalSize: UInt64) {
        (Data(), 0)
    }

    func rename(
        host _: String,
        port _: Int,
        share _: String,
        oldRelativePath _: String,
        newRelativePath _: String,
        username _: String,
        password _: String
    ) throws {}
}

@Suite(.serialized)
@MainActor
struct SMBFolderDialogTests {
    private struct DialogTestFixture {
        let root: URL
        let databaseURL: URL
        let suiteName: String
        let userDefaults: UserDefaults

        init() throws {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(
                "CueSeekerSMBDialogTests-\(UUID().uuidString)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
            try DatabaseBootstrap.prepare(at: databaseURL)
            let suiteName = "CueSeeker.SMBDialogTests.\(UUID().uuidString)"
            let userDefaults = try #require(UserDefaults(suiteName: suiteName))
            self.root = root
            self.databaseURL = databaseURL
            self.suiteName = suiteName
            self.userDefaults = userDefaults
        }

        func cleanUp() {
            SMBClient.shared.setCustomBackendForTesting(nil)
            userDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }
    }

    @Test
    func dialogDefaultsPortTo445AutoCompletesSchemeAndShowsInlineValidationWithoutToast() async throws {
        let fixture = try DialogTestFixture()
        defer { fixture.cleanUp() }

        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: fixture.userDefaults,
            databaseURL: fixture.databaseURL
        )

        app.openSMBFolderDialog()
        let session = try #require(app.library.smbDialogSession)
        #expect(session.step == .connection)
        #expect(session.address.isEmpty)
        #expect(session.port == "445")
        #expect(session.username.isEmpty)
        #expect(session.password.isEmpty)
        #expect(session.validationMessage == nil)

        // Empty address -> inline invalid address message, no toast
        app.confirmSMBFolderDialog(session)
        #expect(session.step == .connection)
        #expect(session.validationMessage == L("smb.error.invalid_address"))
        #expect(app.toast.visibleItems.isEmpty)

        // Setting address without smb:// auto-prepends smb:// and decodes percent-encoding
        session.address = "nas.local/Media/%E5%8A%A8%E6%BC%AB"
        #expect(session.address == "smb://nas.local/Media/动漫")

        // Invalid port -> inline invalid port message, no toast
        session.port = "70000"
        app.confirmSMBFolderDialog(session)
        #expect(session.step == .connection)
        #expect(session.validationMessage == L("smb.error.invalid_port"))
        #expect(app.toast.visibleItems.isEmpty)

        // Auth failure -> stays on Step 1 with inline auth error
        let backend = MockDialogSMBBackend()
        backend.shouldFailAuth = true
        SMBClient.shared.setCustomBackendForTesting(backend)

        session.port = "445"
        app.confirmSMBFolderDialog(session)
        await session.validationTask?.value
        #expect(session.step == .connection)
        #expect(!session.isSubmitting)
        #expect(session.validationMessage == SMBError.authenticationFailed.errorDescription)
        #expect(app.toast.visibleItems.isEmpty)
    }

    @Test
    func hostRootBrowsingListsTopLevelSharesDisablesAddWhenUnselectedAndQueuesSelectedFoldersInOrder() async throws {
        let fixture = try DialogTestFixture()
        defer { fixture.cleanUp() }

        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: fixture.userDefaults,
            databaseURL: fixture.databaseURL
        )

        let backend = MockDialogSMBBackend()
        backend.shares = ["Media", "Archive", "IPC$"]
        backend.entriesByPath["Media"] = [
            SMBDirectoryEntry(name: "01. Series A", isDirectory: true, fileSize: 0, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)),
            SMBDirectoryEntry(name: "02. Series B", isDirectory: true, fileSize: 0, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)),
            SMBDirectoryEntry(name: "Preview.mp4", isDirectory: false, fileSize: 1024, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)),
        ]
        SMBClient.shared.setCustomBackendForTesting(backend)

        let seriesAURL = try #require(SMBAddress.parseURL(from: "smb://nas.local/Media/01. Series A"))
        let seriesBURL = try #require(SMBAddress.parseURL(from: "smb://nas.local/Media/02. Series B"))
        defer {
            SMBConfigurationStore.shared.remove(url: seriesAURL)
            SMBConfigurationStore.shared.remove(url: seriesBURL)
        }

        app.openSMBFolderDialog()
        let session = try #require(app.library.smbDialogSession)
        session.address = "nas.local"
        session.username = "mediauser"
        session.password = "secret"

        // Connect to host-only address -> enters Step 2 at top-level share list
        app.confirmSMBFolderDialog(session)
        await session.validationTask?.value

        #expect(session.step == .browser)
        #expect(session.isAtHostRoot)
        #expect(session.breadcrumbNodes.map(\.title) == ["nas.local"])
        #expect(session.items.map(\.name) == ["Archive", "Media"])
        // At host root with no share selected -> Add is disabled
        #expect(!session.canAddInBrowser)
        #expect(session.targetFoldersToAdd().isEmpty)

        // Selecting a share at host root enables Add
        let mediaShareItem = try #require(session.items.first(where: { $0.name == "Media" }))
        session.toggleFolderSelection(mediaShareItem)
        #expect(session.canAddInBrowser)

        // Double-clicking Media share drills into smb://nas.local/Media and enables Add even with no selection
        app.openSMBSubfolder(mediaShareItem, in: session)
        await session.directoryTask?.value

        #expect(!session.isAtHostRoot)
        #expect(session.breadcrumbNodes.map(\.title) == ["nas.local", "Media"])
        #expect(session.selectedFolderPaths.isEmpty)
        #expect(session.canAddInBrowser)
        #expect(session.items.map(\.name) == ["01. Series A", "02. Series B", "Preview.mp4"])

        // Back button returns to Step 1 and preserves inputs
        app.navigateBackInSMBFolderDialog(session)
        #expect(session.step == .connection)
        #expect(session.address == "smb://nas.local")
        #expect(session.port == "445")
        #expect(session.username == "mediauser")
        #expect(session.password == "secret")

        // Reconnect directly to smb://nas.local/Media and select Series B then Series A -> queues in display order (A then B)
        session.address = "nas.local/Media"
        app.confirmSMBFolderDialog(session)
        await session.validationTask?.value

        session.toggleFolderSelection(session.items[1]) // 02. Series B
        session.toggleFolderSelection(session.items[0]) // 01. Series A
        #expect(session.targetFoldersToAdd() == [seriesAURL.standardizedMediaURL, seriesBURL.standardizedMediaURL])

        let gate = DispatchSemaphore(value: 0)
        var startedFolders: [URL] = []
        app.tasks.runAddFolder = { folders, _ in
            let folder = folders[0]
            await MainActor.run {
                startedFolders.append(folder)
            }
            if startedFolders.count == 1 {
                await Task.detached {
                    _ = gate.wait(timeout: .now() + 5)
                }.value
            }
            await MainActor.run {
                app.indexing.appendFolder(folder)
            }
            return 1
        }

        app.confirmSMBFolderDialog(session)
        #expect(app.library.smbDialogSession == nil)
        #expect(app.tasks.current.count == 2)
        #expect(app.tasks.current[0].record.kind == .addFolder)
        #expect(app.tasks.current[0].record.state == .running)
        #expect(app.tasks.current[0].record.oldPaths == [seriesAURL.mediaPath])
        #expect(app.tasks.current[1].record.kind == .addFolder)
        #expect(app.tasks.current[1].record.state == .queued)
        #expect(app.tasks.current[1].record.oldPaths == [seriesBURL.mediaPath])

        gate.signal()
        await app.tasks.waitUntilIdle()
        #expect(startedFolders == [seriesAURL.standardizedMediaURL, seriesBURL.standardizedMediaURL])
    }
}
