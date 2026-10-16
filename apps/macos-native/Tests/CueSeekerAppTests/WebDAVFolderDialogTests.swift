import AppKit
import Foundation
import SwiftUI
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
    func dialogValidatesInputsWithInlineMessageWithoutShowingToastOrClosingOnFailure() async throws {
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
        #expect(session.validationMessage == nil)
        #expect(!session.isSubmitting)

        // Invalid/empty address sets inline validation message and never shows a toast
        app.confirmWebDAVFolderDialog(session)
        #expect(app.library.webdavDialogSession?.id == session.id)
        #expect(!session.isSubmitting)
        #expect(session.validationMessage == L("webdav.error.invalid_address"))
        #expect(app.toast.visibleItems.isEmpty)

        // Empty username sets inline validation message
        session.address = "http://192.168.1.173:5244/115/云下载/NieR:Automata"
        app.confirmWebDAVFolderDialog(session)
        #expect(app.library.webdavDialogSession?.id == session.id)
        #expect(!session.isSubmitting)
        #expect(session.validationMessage == L("webdav.error.username_empty"))
        #expect(app.toast.visibleItems.isEmpty)

        // Empty password sets inline validation message
        session.username = "admin"
        app.confirmWebDAVFolderDialog(session)
        #expect(app.library.webdavDialogSession?.id == session.id)
        #expect(!session.isSubmitting)
        #expect(session.validationMessage == L("webdav.error.password_empty"))
        #expect(app.toast.visibleItems.isEmpty)

        // 401 authentication failure from server restores input state and shows inline validation message without toast
        WebDAVClient.shared.setCustomHTTPHandlerForTesting { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(), response)
        }

        session.password = "secret"
        app.confirmWebDAVFolderDialog(session)
        await session.validationTask?.value

        #expect(app.library.webdavDialogSession?.id == session.id)
        #expect(!session.isSubmitting)
        #expect(session.validationMessage == WebDAVError.authenticationFailed.errorDescription)
        #expect(app.toast.visibleItems.isEmpty)
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
    func dialogSuccessClosesDialogSavesConfigAndStartsAddFolderTaskWithOptionalNameDefault() async throws {
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

        // Leave Name blank -> defaults to folder name ("NieR:Automata")
        app.openWebDAVFolderDialog()
        let session = try #require(app.library.webdavDialogSession)
        session.name = "   "
        session.address = rootAddress
        session.username = "alist"
        session.password = "pass123"

        app.confirmWebDAVFolderDialog(session)
        await session.validationTask?.value
        await app.tasks.waitUntilIdle()

        #expect(app.library.webdavDialogSession == nil)
        #expect(WebDAVConfigurationStore.shared.config(for: rootURL)?.name == "NieR:Automata")
        #expect(IndexingStore.displayName(for: rootURL) == "NieR:Automata")
        #expect(app.indexing.selectedFolders.contains(rootURL.standardizedMediaURL))
    }

    @Test
    func dialogOpensUnfocusedAndLongAddressPastePreservesFocusSwitchingAcrossFields() throws {
        _ = NSApplication.shared
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isWorkbenchCovered = { true }
        window.dialogSize = { CGSize(width: 420, height: 360) }

        let session = WebDAVFolderDialogSession()
        let hostingView = NSHostingView(
            rootView: ZStack {
                Color.clear
                WebDAVFolderDialog(
                    session: session,
                    onConfirm: {},
                    onClose: {}
                )
            }
            .frame(width: 1200, height: 800)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 1200, height: 800)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        // Requirement 2.1: Dialog does not auto-focus any text field on open
        #expect(window.firstResponder === window || window.firstResponder == nil)

        func collectEditableTextFields(in view: NSView) -> [NSTextField] {
            var result: [NSTextField] = []
            if let field = view as? NSTextField, field.isEditable {
                result.append(field)
            }
            for subview in view.subviews {
                result.append(contentsOf: collectEditableTextFields(in: subview))
            }
            return result
        }

        let fields = collectEditableTextFields(in: hostingView)
            .sorted { $0.convert($0.bounds, to: nil).midY > $1.convert($1.bounds, to: nil).midY }
        #expect(fields.count == 4)
        let nameField = fields[0]
        let addressField = fields[1]
        let usernameField = fields[2]
        let passwordField = fields[3]

        // Focus Address and simulate pasting a long URL that expands the shared field editor > 420pt
        #expect(window.makeFirstResponder(addressField))
        let fieldEditor = try #require(window.firstResponder as? NSTextView)
        #expect(fieldEditor.isFieldEditor)
        let longAddress = "http://192.168.1.173:5244/dav/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata.Ver1.22474487139/Season01/Subtitles/VeryLongDirectoryPathSegmentForTestingFieldEditorWidth"
        fieldEditor.string = longAddress
        fieldEditor.layoutManager?.ensureLayout(for: fieldEditor.textContainer!)
        #expect(fieldEditor.bounds.width > 420)

        // Switching focus to Name, Username, and Password must still succeed
        #expect(window.makeFirstResponder(nameField))
        #expect((window.firstResponder as? NSTextView)?.delegate as? NSTextField === nameField)

        #expect(window.makeFirstResponder(usernameField))
        #expect((window.firstResponder as? NSTextView)?.delegate as? NSTextField === usernameField)

        #expect(window.makeFirstResponder(passwordField))
        #expect(window.firstResponder === passwordField || (window.firstResponder as? NSTextView)?.delegate as? NSTextField === passwordField)
    }

    @Test
    func dialogReturnKeyAndFocusChangesNeverTriggerAddOrSelectAllText() throws {
        _ = NSApplication.shared
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isWorkbenchCovered = { true }
        window.dialogSize = { CGSize(width: 480, height: 360) }

        let session = WebDAVFolderDialogSession()
        var confirmCallCount = 0
        let hostingView = NSHostingView(
            rootView: ZStack {
                Color.clear
                WebDAVFolderDialog(
                    session: session,
                    onConfirm: { confirmCallCount += 1 },
                    onClose: {}
                )
            }
            .frame(width: 1200, height: 800)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 1200, height: 800)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        func collectEditableTextFields(in view: NSView) -> [NSTextField] {
            var result: [NSTextField] = []
            if let field = view as? NSTextField, field.isEditable {
                result.append(field)
            }
            for subview in view.subviews {
                result.append(contentsOf: collectEditableTextFields(in: subview))
            }
            return result
        }

        let fields = collectEditableTextFields(in: hostingView)
            .sorted { $0.convert($0.bounds, to: nil).midY > $1.convert($1.bounds, to: nil).midY }
        #expect(fields.count == 4)

        for (index, field) in fields.enumerated() {
            #expect(window.makeFirstResponder(field))
            let editor = try #require(field.currentEditor() as? NSTextView)
            editor.insertText("line1\r\nline2\n\(index)", replacementRange: editor.selectedRange())
            #expect(editor.string == "line1 line2 \(index)")
            #expect(!editor.string.contains("\n"))
            #expect(editor.selectedRange() == NSRange(location: editor.string.utf16.count, length: 0))

            editor.setSelectedRange(NSRange(location: 5, length: 0))
            editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
            #expect(confirmCallCount == 0)
            #expect(editor.selectedRange() == NSRange(location: 5, length: 0))

            editor.doCommand(by: #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)))
            editor.doCommand(by: #selector(NSResponder.insertLineBreak(_:)))
            #expect(editor.string == "line1 line2 \(index)")
            #expect(confirmCallCount == 0)
        }

        // Switching focus across fields also must not trigger Add
        #expect(window.makeFirstResponder(fields[0]))
        #expect(window.makeFirstResponder(fields[1]))
        #expect(confirmCallCount == 0)
    }

    @Test
    func dialogAddressFieldImmediatelyDecodesPercentEncodedURLOnPaste() throws {
        _ = NSApplication.shared
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isWorkbenchCovered = { true }
        window.dialogSize = { CGSize(width: 480, height: 360) }

        let session = WebDAVFolderDialogSession()
        let hostingView = NSHostingView(
            rootView: ZStack {
                Color.clear
                WebDAVFolderDialog(
                    session: session,
                    onConfirm: {},
                    onClose: {}
                )
            }
            .frame(width: 1200, height: 800)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 1200, height: 800)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        func collectEditableTextFields(in view: NSView) -> [NSTextField] {
            var result: [NSTextField] = []
            if let field = view as? NSTextField, field.isEditable {
                result.append(field)
            }
            for subview in view.subviews {
                result.append(contentsOf: collectEditableTextFields(in: subview))
            }
            return result
        }

        let fields = collectEditableTextFields(in: hostingView)
            .sorted { $0.convert($0.bounds, to: nil).midY > $1.convert($1.bounds, to: nil).midY }
        #expect(fields.count == 4)
        let addressField = fields[1]

        #expect(window.makeFirstResponder(addressField))
        let editor = try #require(addressField.currentEditor() as? NSTextView)

        let pastedEncodedURL = "http://192.168.1.173:5244/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/%5BDHR%26Airota%5D%5BKonoSuba%5D/%E4%B8%BA%E7%BE%8E%E5%A5%BD%E7%9A%84%E4%B8%96%E7%95%8C%E7%8C%AE%E4%B8%8A%E7%A5%9D%E7%A6%8F%EF%BC%81S1"
        let expectedDecodedURL = "http://192.168.1.173:5244/115/云下载/[DHR&Airota][KonoSuba]/为美好的世界献上祝福！S1"

        editor.insertText(pastedEncodedURL, replacementRange: editor.selectedRange())

        #expect(session.address == expectedDecodedURL)
        #expect(addressField.stringValue == expectedDecodedURL)
        #expect(editor.string == expectedDecodedURL)
    }
}

