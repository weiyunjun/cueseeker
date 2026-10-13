import AppKit
import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct WebDAVFolderDialogTests {
    private struct DialogTestFixture {
        let root: URL
        let databaseURL: URL
        let suiteName: String
        let userDefaults: UserDefaults

        init() throws {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(
                "CueSeekerWebDAVDialogTests-\(UUID().uuidString)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
            try DatabaseBootstrap.prepare(at: databaseURL)
            let suiteName = "CueSeeker.WebDAVDialogTests.\(UUID().uuidString)"
            let userDefaults = try #require(UserDefaults(suiteName: suiteName))
            self.root = root
            self.databaseURL = databaseURL
            self.suiteName = suiteName
            self.userDefaults = userDefaults
        }

        func cleanUp() {
            WebDAVClient.shared.setCustomHTTPHandlerForTesting(nil)
            userDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }
    }

    @Test
    func dialogValidatesInputsAndShowsToastWithoutClosingOnFailure() async throws {
        let fixture = try DialogTestFixture()
        defer { fixture.cleanUp() }

        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: fixture.userDefaults,
            databaseURL: fixture.databaseURL
        )

        app.openWebDAVFolderDialog()
        let session = try #require(app.library.webdavDialogSession)
        #expect(session.name.isEmpty)
        #expect(session.address.isEmpty)
        #expect(session.username.isEmpty)
        #expect(session.password.isEmpty)
        #expect(!session.isSubmitting)

        // Empty name triggers toast and keeps dialog open
        app.confirmWebDAVFolderDialog(session)
        #expect(app.library.webdavDialogSession?.id == session.id)
        #expect(!session.isSubmitting)
        #expect(app.toast.visibleItems.last?.request.scenarioID == "webdav.add.failed")

        // Invalid address triggers toast and keeps dialog open
        session.name = "NieR"
        session.address = "not-a-valid-url"
        session.username = "admin"
        session.password = "secret"
        app.confirmWebDAVFolderDialog(session)
        #expect(app.library.webdavDialogSession?.id == session.id)
        #expect(!session.isSubmitting)
        #expect(app.toast.visibleItems.last?.request.scenarioID == "webdav.add.failed")

        // 401 authentication failure from server restores input state and shows toast
        WebDAVClient.shared.setCustomHTTPHandlerForTesting { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(), response)
        }

        session.address = "http://192.168.1.173:5244/115/云下载/NieR:Automata"
        app.confirmWebDAVFolderDialog(session)
        await session.validationTask?.value

        #expect(app.library.webdavDialogSession?.id == session.id)
        #expect(!session.isSubmitting)
        #expect(app.toast.visibleItems.last?.request.scenarioID == "webdav.add.failed")
    }

    @Test
    func dialogDisablesInputsWhileWaitingAndAllowsImmediateCancel() async throws {
        let fixture = try DialogTestFixture()
        defer { fixture.cleanUp() }

        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: fixture.userDefaults,
            databaseURL: fixture.databaseURL
        )

        let gate = DispatchSemaphore(value: 0)
        WebDAVClient.shared.setCustomHTTPHandlerForTesting { request in
            _ = gate.wait(timeout: .now() + 5)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 207,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(), response)
        }

        app.openWebDAVFolderDialog()
        let session = try #require(app.library.webdavDialogSession)
        session.name = "NieR"
        session.address = "http://192.168.1.173:5244/115/云下载/NieR:Automata"
        session.username = "admin"
        session.password = "secret"

        app.confirmWebDAVFolderDialog(session)
        #expect(session.isSubmitting)
        #expect(session.validationTask != nil)

        // Cancel while validation is in flight immediately closes dialog
        app.closeWebDAVFolderDialog()
        gate.signal()

        #expect(app.library.webdavDialogSession == nil)
        #expect(!session.isSubmitting)
    }

    @Test
    func dialogSuccessClosesDialogSavesConfigAndStartsAddFolderTask() async throws {
        let fixture = try DialogTestFixture()
        defer { fixture.cleanUp() }

        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: fixture.userDefaults,
            databaseURL: fixture.databaseURL
        )

        let rootAddress = "http://192.168.1.173:5244/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata"
        let rootURL = try #require(WebDAVAddress.parseURL(from: rootAddress))
        defer { WebDAVConfigurationStore.shared.remove(url: rootURL) }

        WebDAVClient.shared.setCustomHTTPHandlerForTesting { request in
            let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:href>/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata/</D:href>
                <D:propstat>
                  <D:prop>
                    <D:resourcetype><D:collection/></D:resourcetype>
                  </D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
            </D:multistatus>
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 207,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/xml"]
            )!
            return (Data(xml.utf8), response)
        }

        app.openWebDAVFolderDialog()
        let session = try #require(app.library.webdavDialogSession)
        session.name = "NieR Custom Name"
        session.address = rootAddress
        session.username = "alist"
        session.password = "pass123"

        app.confirmWebDAVFolderDialog(session)
        await session.validationTask?.value
        await app.tasks.waitUntilIdle()

        #expect(app.library.webdavDialogSession == nil)
        #expect(WebDAVConfigurationStore.shared.config(for: rootURL)?.name == "NieR Custom Name")
        #expect(IndexingStore.displayName(for: rootURL) == "NieR Custom Name")
        #expect(app.indexing.selectedFolders.contains(rootURL.standardizedMediaURL))
    }
}
