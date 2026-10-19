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
        #expect(session.step == .connection)
        #expect(session.address.isEmpty)
        #expect(session.username.isEmpty)
        #expect(session.password.isEmpty)
        #expect(session.validationMessage == nil)
        #expect(!session.isSubmitting)

        // Invalid/empty address sets inline validation message and never shows a toast
        app.confirmWebDAVFolderDialog(session)
        #expect(app.library.webdavDialogSession?.id == session.id)
        #expect(session.step == .connection)
        #expect(!session.isSubmitting)
        #expect(session.validationMessage == L("webdav.error.invalid_address"))
        #expect(app.toast.visibleItems.isEmpty)

        // Blank username/password is allowed (anonymous access); if server requires auth (401),
        // it stays on Step 1, restores input state, and shows inline authentication error without toast
        WebDAVClient.shared.setCustomHTTPHandlerForTesting { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
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
        #expect(session.step == .connection)
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
    func dialogConnectEntersBrowserStepAndAddingWithoutSelectionAddsCurrentDirectory() async throws {
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
        session.address = rootAddress
        session.username = ""
        session.password = ""

        // Step 1 Connect -> enters Step 2 Browser
        app.confirmWebDAVFolderDialog(session)
        await session.validationTask?.value

        #expect(app.library.webdavDialogSession?.id == session.id)
        #expect(session.step == .browser)
        #expect(session.breadcrumbNodes.map(\.title) == ["NieR:Automata"])
        #expect(session.canAddInBrowser)
        #expect(session.selectedFolderPaths.isEmpty)

        // Step 2 Add with nothing selected -> adds current directory ("NieR:Automata")
        app.confirmWebDAVFolderDialog(session)
        await app.tasks.waitUntilIdle()

        #expect(app.library.webdavDialogSession == nil)
        let savedConfig = try #require(WebDAVConfigurationStore.shared.config(for: rootURL))
        #expect(savedConfig.name == "NieR:Automata")
        #expect(savedConfig.username.isEmpty)
        #expect(savedConfig.password.isEmpty)
        #expect(savedConfig.basicAuthorizationValue == nil)
        #expect(IndexingStore.displayName(for: rootURL) == "NieR:Automata")
        #expect(app.indexing.selectedFolders.contains(rootURL.standardizedMediaURL))
    }

    @Test
    func stepTwoSupportsDrillDownBreadcrumbBackPreservingInputsAndMultiFolderQueueingInDisplayOrder() async throws {
        let fixture = try DialogTestFixture()
        defer { fixture.cleanUp() }

        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: fixture.userDefaults,
            databaseURL: fixture.databaseURL
        )

        let rootURL = try #require(WebDAVAddress.parseURL(from: "http://192.168.1.5:5244/dav/115/动漫"))
        let showAURL = try #require(WebDAVAddress.parseURL(from: "http://192.168.1.5:5244/dav/115/动漫/01. 进击的巨人"))
        let showBURL = try #require(WebDAVAddress.parseURL(from: "http://192.168.1.5:5244/dav/115/动漫/02. 葬送的芙莉莲"))
        let showCURL = try #require(WebDAVAddress.parseURL(from: "http://192.168.1.5:5244/dav/115/动漫/03. 孤独摇滚"))
        defer {
            WebDAVConfigurationStore.shared.remove(url: rootURL)
            WebDAVConfigurationStore.shared.remove(url: showAURL)
            WebDAVConfigurationStore.shared.remove(url: showBURL)
            WebDAVConfigurationStore.shared.remove(url: showCURL)
        }

        var shouldFailSubfolderLoad = false
        WebDAVClient.shared.setCustomHTTPHandlerForTesting { request in
            let decodedPath = (request.url?.path.removingPercentEncoding ?? request.url?.path ?? "")
                .precomposedStringWithCanonicalMapping
            if shouldFailSubfolderLoad && decodedPath.contains("01. 进击的巨人") {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                return (Data(), response)
            }

            let xml: String
            if decodedPath.contains("01. 进击的巨人") {
                xml = """
                <?xml version="1.0" encoding="utf-8"?>
                <D:multistatus xmlns:D="DAV:">
                  <D:response>
                    <D:href>/dav/115/动漫/01.%20进击的巨人/</D:href>
                    <D:propstat>
                      <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                  <D:response>
                    <D:href>/dav/115/动漫/01.%20进击的巨人/S01E01.mkv</D:href>
                    <D:propstat>
                      <D:prop><D:resourcetype/></D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                  <D:response>
                    <D:href>/dav/115/动漫/01.%20进击的巨人/S01E01.srt</D:href>
                    <D:propstat>
                      <D:prop><D:resourcetype/></D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                </D:multistatus>
                """
            } else {
                xml = """
                <?xml version="1.0" encoding="utf-8"?>
                <D:multistatus xmlns:D="DAV:">
                  <D:response>
                    <D:href>/dav/115/动漫/</D:href>
                    <D:propstat>
                      <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                  <D:response>
                    <D:href>/dav/115/动漫/01.%20进击的巨人/</D:href>
                    <D:propstat>
                      <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                  <D:response>
                    <D:href>/dav/115/动漫/02.%20葬送的芙莉莲/</D:href>
                    <D:propstat>
                      <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                  <D:response>
                    <D:href>/dav/115/动漫/03.%20孤独摇滚/</D:href>
                    <D:propstat>
                      <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                  <D:response>
                    <D:href>/dav/115/动漫/Preview.mp4</D:href>
                    <D:propstat>
                      <D:prop><D:resourcetype/></D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                </D:multistatus>
                """
            }

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
        session.address = rootURL.mediaPath
        session.username = "user1"
        session.password = "pass1"

        app.confirmWebDAVFolderDialog(session)
        await session.validationTask?.value

        #expect(session.step == .browser)
        #expect(session.breadcrumbNodes.map(\.title) == ["动漫"])
        #expect(session.items.map(\.name) == ["01. 进击的巨人", "02. 葬送的芙莉莲", "03. 孤独摇滚", "Preview.mp4"])

        // File items cannot be selected
        let fileItem = try #require(session.items.last)
        session.toggleFolderSelection(fileItem)
        #expect(session.selectedFolderPaths.isEmpty)

        // Select folders in reverse order (03 then 01) -> targetFoldersToAdd preserves top-to-bottom display order (01 then 03)
        let folder1 = session.items[0]
        let folder3 = session.items[2]
        session.toggleFolderSelection(folder3)
        session.toggleFolderSelection(folder1)
        #expect(session.targetFoldersToAdd() == [showAURL.standardizedMediaURL, showCURL.standardizedMediaURL])

        // Double-clicking a subfolder clears selection and updates breadcrumb; failure disables Add
        shouldFailSubfolderLoad = true
        app.openWebDAVSubfolder(folder1, in: session)
        #expect(session.selectedFolderPaths.isEmpty)
        await session.directoryTask?.value
        #expect(session.breadcrumbNodes.map(\.title) == ["动漫", "01. 进击的巨人"])
        #expect(session.directoryErrorMessage != nil)
        #expect(!session.canAddInBrowser)

        // Clicking root breadcrumb node navigates back to root and clears error
        shouldFailSubfolderLoad = false
        let rootNode = try #require(session.breadcrumbNodes.first)
        app.navigateWebDAVBreadcrumb(to: rootNode, in: session)
        await session.directoryTask?.value
        #expect(session.breadcrumbNodes.map(\.title) == ["动漫"])
        #expect(session.directoryErrorMessage == nil)
        #expect(session.canAddInBrowser)

        // Select a folder, then click Back -> returns to Step 1, clears selection, and preserves inputs
        session.toggleFolderSelection(folder1)
        #expect(!session.selectedFolderPaths.isEmpty)
        app.navigateBackInWebDAVFolderDialog(session)
        #expect(session.step == .connection)
        #expect(session.selectedFolderPaths.isEmpty)
        #expect(session.address == rootURL.mediaPath)
        #expect(session.username == "user1")
        #expect(session.password == "pass1")

        // Reconnect and select two folders (03 and 01) -> queues 2 Add Folder tasks in display order (01 running, 03 queued)
        app.confirmWebDAVFolderDialog(session)
        await session.validationTask?.value
        session.toggleFolderSelection(session.items[2])
        session.toggleFolderSelection(session.items[0])

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

        app.confirmWebDAVFolderDialog(session)
        #expect(app.library.webdavDialogSession == nil)
        #expect(app.tasks.current.count == 2)
        #expect(app.tasks.current[0].record.kind == .addFolder)
        #expect(app.tasks.current[0].record.state == .running)
        #expect(app.tasks.current[0].record.oldPaths == [showAURL.mediaPath])
        #expect(app.tasks.current[1].record.kind == .addFolder)
        #expect(app.tasks.current[1].record.state == .queued)
        #expect(app.tasks.current[1].record.oldPaths == [showCURL.mediaPath])

        gate.signal()
        await app.tasks.waitUntilIdle()

        #expect(startedFolders == [showAURL.standardizedMediaURL, showCURL.standardizedMediaURL])
        #expect(app.tasks.completed.count == 2)
    }

    @Test
    func browserCardSelectionStylingDisablesHoverWhenSelected() {
        // Selected folder card uses libraryMediaCardHoverBg and borderActive, and hover does not alter background
        let selectedUnHovered = WebDAVBrowserCard.resolveBackgroundFillColor(
            isFolder: true,
            isSelected: true,
            isHovered: false
        )
        let selectedHovered = WebDAVBrowserCard.resolveBackgroundFillColor(
            isFolder: true,
            isSelected: true,
            isHovered: true
        )
        #expect(selectedUnHovered == WorkbenchRedesignColors.libraryMediaCardHoverBg)
        #expect(selectedHovered == WorkbenchRedesignColors.libraryMediaCardHoverBg)
        #expect(
            WebDAVBrowserCard.resolveBorderStrokeColor(isFolder: true, isSelected: true)
                == WorkbenchRedesignColors.borderActive
        )

        // Unselected folder card uses rowHover on hover and tableBg otherwise
        #expect(
            WebDAVBrowserCard.resolveBackgroundFillColor(isFolder: true, isSelected: false, isHovered: true)
                == WorkbenchRedesignColors.rowHover
        )
        #expect(
            WebDAVBrowserCard.resolveBackgroundFillColor(isFolder: true, isSelected: false, isHovered: false)
                == WorkbenchRedesignColors.tableBg
        )

        // File card never changes background on hover
        #expect(
            WebDAVBrowserCard.resolveBackgroundFillColor(isFolder: false, isSelected: false, isHovered: true)
                == WorkbenchRedesignColors.tableBg
        )
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
        #expect(fields.count == 3)
        let addressField = fields[0]
        let usernameField = fields[1]
        let passwordField = fields[2]

        // Focus Address and simulate pasting a long URL that expands the shared field editor > 420pt
        #expect(window.makeFirstResponder(addressField))
        let fieldEditor = try #require(window.firstResponder as? NSTextView)
        #expect(fieldEditor.isFieldEditor)
        let longAddress = "http://192.168.1.173:5244/dav/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata.Ver1.22474487139/Season01/Subtitles/VeryLongDirectoryPathSegmentForTestingFieldEditorWidth"
        fieldEditor.string = longAddress
        fieldEditor.layoutManager?.ensureLayout(for: fieldEditor.textContainer!)
        #expect(fieldEditor.bounds.width > 420)

        // Switching focus to Username and Password must still succeed
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
        #expect(fields.count == 3)

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

        // Switching focus across fields also must not trigger Connect
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
        #expect(fields.count == 3)
        let addressField = fields[0]

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

