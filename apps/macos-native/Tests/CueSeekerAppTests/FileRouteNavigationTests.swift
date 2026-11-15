import AppKit
import Combine
import CueSeekerCore
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite
@MainActor
struct FileRouteNavigationTests {
    @Test
    func fileThreeLevelNavigationAndHistoryFlow() {
        let suiteName = "FileRouteNavigationTests-\(UUID().uuidString)"
        let defaults = UserDefaults.temporary(suiteName: suiteName)!
        defer { defaults.removePersistentDomainAndPlist(forName: suiteName) }
        let layoutState = WorkbenchLayoutState(userDefaults: defaults)

        // 1. Initial navigation to File (Level 1)
        layoutState.navigate(to: .file)
        #expect(layoutState.currentRoute == .file)
        #expect(layoutState.panelMode == .file)
        #expect(layoutState.selectedFileRootPath == nil)
        #expect(layoutState.selectedFileFolderPath == nil)

        // 2. Drill down to Level 2 (Subfolders)
        let rootPath = "/Volumes/Media/Anime"
        layoutState.navigate(to: .fileFolder(rootPath: rootPath))
        #expect(layoutState.currentRoute == .fileFolder(rootPath: rootPath))
        #expect(layoutState.panelMode == .file)
        #expect(layoutState.selectedFileRootPath == rootPath)
        #expect(layoutState.selectedFileFolderPath == nil)
        #expect(layoutState.route.canGoBack)

        // 3. Drill down to Level 3 (Files)
        let folderPath = "/Volumes/Media/Anime/SeriesA"
        layoutState.navigate(to: .fileFiles(rootPath: rootPath, folderPath: folderPath))
        #expect(layoutState.currentRoute == .fileFiles(rootPath: rootPath, folderPath: folderPath))
        #expect(layoutState.panelMode == .file)
        #expect(layoutState.selectedFileRootPath == rootPath)
        #expect(layoutState.selectedFileFolderPath == folderPath)

        // 4. Go Back: Level 3 -> Level 2
        layoutState.goBack()
        #expect(layoutState.currentRoute == .fileFolder(rootPath: rootPath))
        #expect(layoutState.selectedFileRootPath == rootPath)
        #expect(layoutState.selectedFileFolderPath == nil)
        #expect(layoutState.route.canGoForward)

        // 5. Go Back: Level 2 -> Level 1
        layoutState.goBack()
        #expect(layoutState.currentRoute == .file)
        #expect(layoutState.selectedFileRootPath == nil)
        #expect(layoutState.selectedFileFolderPath == nil)

        // 6. Go Forward: Level 1 -> Level 2
        layoutState.goForward()
        #expect(layoutState.currentRoute == .fileFolder(rootPath: rootPath))

        // 7. Go Forward: Level 2 -> Level 3
        layoutState.goForward()
        #expect(layoutState.currentRoute == .fileFiles(rootPath: rootPath, folderPath: folderPath))
    }

    @Test
    func fileSidebarSwitchingBehavior() {
        let suiteName = "FileRouteNavigationTests-\(UUID().uuidString)"
        let defaults = UserDefaults.temporary(suiteName: suiteName)!
        defer { defaults.removePersistentDomainAndPlist(forName: suiteName) }
        let layoutState = WorkbenchLayoutState(userDefaults: defaults)

        let rootPath = "/Volumes/Media/Anime"
        let folderPath = "/Volumes/Media/Anime/SeriesA"
        layoutState.navigate(to: .fileFiles(rootPath: rootPath, folderPath: folderPath))
        #expect(layoutState.currentRoute == .fileFiles(rootPath: rootPath, folderPath: folderPath))
        #expect(layoutState.panelMode == .file)

        // 1. While on File level 3, clicking File in sidebar does not re-navigate (panelMode == .file)
        if layoutState.panelMode != .file {
            layoutState.navigate(to: .firstLevel(of: .file))
        }
        #expect(layoutState.currentRoute == .fileFiles(rootPath: rootPath, folderPath: folderPath))

        // 2. Switching to another sidebar mode (e.g. Search)
        layoutState.navigate(to: .firstLevel(of: .search))
        #expect(layoutState.currentRoute == .search)
        #expect(layoutState.panelMode == .search)

        // 3. From Search, clicking File in sidebar navigates to Level 1 (.file)
        layoutState.navigate(to: .firstLevel(of: .file))
        #expect(layoutState.currentRoute == .file)
        #expect(layoutState.panelMode == .file)
    }

    @Test
    func fileBreadcrumbResolution() {
        let rootTitle = "All Folders"

        // 1. Level 1: No breadcrumb nodes (header is rendered directly in Level 1)
        let level1Nodes = FileBreadcrumbResolver.nodes(
            for: .file,
            rootTitle: rootTitle
        )
        #expect(level1Nodes.isEmpty)

        // 2. Level 2 (Local folder): All Folders > Anime
        let localRootPath = "/Volumes/Media/Anime"
        let level2SingleFolderNodes = FileBreadcrumbResolver.nodes(
            for: .fileFolder(rootPath: localRootPath),
            rootTitle: rootTitle
        )
        #expect(level2SingleFolderNodes.count == 2)
        #expect(level2SingleFolderNodes[0].id == "all")
        #expect(level2SingleFolderNodes[0].title == "All Folders")
        #expect(level2SingleFolderNodes[0].destination == .file)
        #expect(level2SingleFolderNodes[1].id == "root")
        #expect(level2SingleFolderNodes[1].title == "Anime")
        #expect(level2SingleFolderNodes[1].destination == nil)

        // 3. Level 2 (WebDAV): All Folders > MyCloud
        let webdavRootPath = "https://dav.example.com/dav/MyCloud"
        let level2WebDAVNodes = FileBreadcrumbResolver.nodes(
            for: .fileFolder(rootPath: webdavRootPath),
            rootTitle: rootTitle
        )
        #expect(level2WebDAVNodes.count == 2)
        #expect(level2WebDAVNodes[0].id == "all")
        #expect(level2WebDAVNodes[0].title == "All Folders")
        #expect(level2WebDAVNodes[0].destination == .file)
        #expect(level2WebDAVNodes[1].id == "root")
        #expect(level2WebDAVNodes[1].title == "MyCloud")
        #expect(level2WebDAVNodes[1].destination == nil)

        // 4. Level 3: All Folders > Anime > SeriesA
        let folderPath = "/Volumes/Media/Anime/SeriesA"
        let level3Nodes = FileBreadcrumbResolver.nodes(
            for: .fileFiles(rootPath: localRootPath, folderPath: folderPath),
            rootTitle: rootTitle
        )
        #expect(level3Nodes.count == 3)
        #expect(level3Nodes[0].id == "all")
        #expect(level3Nodes[0].title == "All Folders")
        #expect(level3Nodes[0].destination == .file)
        #expect(level3Nodes[1].id == "root")
        #expect(level3Nodes[1].title == "Anime")
        #expect(level3Nodes[1].destination == .fileFolder(rootPath: localRootPath))
        #expect(level3Nodes[2].id == "folder")
        #expect(level3Nodes[2].title == "SeriesA")
        #expect(level3Nodes[2].destination == nil)
    }

    @Test
    func fileFolderGroupingProtocolIconsAndDecodedWebDAVSubtitles() {
        let localURL1 = URL(fileURLWithPath: "/Volumes/Media/Anime")
        let localURL2 = URL(fileURLWithPath: "/Volumes/Media/Movies")
        let encodedWebDAVAddress = "http://192.168.1.173:5244/dav/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/%5BDHR%26Airota%5D%5BKonoSuba%5D/%E4%B8%BA%E7%BE%8E%E5%A5%BD%E7%9A%84%E4%B8%96%E7%95%8C%E7%8C%AE%E4%B8%8A%E7%A5%9D%E7%A6%8F%EF%BC%81S1"
        let webdavURL = URL.fromMediaPath(encodedWebDAVAddress)

        // 1. Unified root folders list (no Local / WebDav split)
        #expect(FileFolderGroupingResolver.rootFolders(for: []).isEmpty)
        let unifiedFolders = FileFolderGroupingResolver.rootFolders(for: [localURL1, webdavURL, localURL2])
        #expect(unifiedFolders == [localURL1, webdavURL, localURL2])

        // 2. Folder protocol icon resolution (Local -> .folder, WebDAV -> .folderWebdav) and reserved protocol badges
        #expect(FileFolderGroupingResolver.folderIcon(for: localURL1) == .folder)
        #expect(FileFolderGroupingResolver.folderIcon(for: webdavURL) == .folderWebdav)
        #expect(FileFolderGroupingResolver.folderIcon(forFolderPath: "/Volumes/Media/Anime/Season1") == .folder)
        #expect(FileFolderGroupingResolver.folderIcon(forFolderPath: encodedWebDAVAddress) == .folderWebdav)
        #expect(AppIcon.folder.folderProtocolBadge == nil)
        #expect(AppIcon.folderWebdav.folderProtocolBadge == "DAV")
        #expect(AppIcon.folderSmb.folderProtocolBadge == "SMB")
        #expect(AppIcon.folderFtp.folderProtocolBadge == "FTP")
        #expect(AppIcon.folderNfs.folderProtocolBadge == "NFS")

        // 3. Decoded human-readable WebDAV subtitle on Level 1 & Level 2
        let expectedDecoded = "http://192.168.1.173:5244/dav/115/云下载/[DHR&Airota][KonoSuba]/为美好的世界献上祝福！S1"
        #expect(FileFolderGroupingResolver.rootSubtitle(for: localURL1) == "/Volumes/Media/Anime")
        #expect(FileFolderGroupingResolver.rootSubtitle(for: webdavURL) == expectedDecoded)
        #expect(FileFolderGroupingResolver.subfolderSubtitle(for: encodedWebDAVAddress) == expectedDecoded)

        // 4. Level 2 partition unwraps direct content folder entry and preserves subfolders + direct episode groups
        let rootPath = "/Volumes/Media/Anime"
        let directFolder = IndexedContentFolder(
            id: 1,
            relativePath: "",
            folderPath: rootPath,
            objects: []
        )
        let subFolder = IndexedContentFolder(
            id: 2,
            relativePath: "Ave Mujica",
            folderPath: "/Volumes/Media/Anime/Ave Mujica",
            objects: []
        )
        let directEpisode = IndexedContentObject(
            id: 10,
            displayTitle: "Ave Mujica - EP01",
            videoPath: "/Volumes/Media/Anime/EP01.mkv",
            videoName: "EP01.mkv",
            fileSize: 1024,
            subtitles: []
        )
        let emptyEpisode = IndexedContentObject(
            id: 11,
            displayTitle: "Empty",
            videoPath: "",
            videoName: "",
            fileSize: 0,
            subtitles: []
        )

        let partition = FileFolderGroupingResolver.level2Partition(
            folders: [directFolder, subFolder],
            objects: [directEpisode, emptyEpisode],
            rootPath: rootPath
        )
        #expect(partition.subfolders.count == 1)
        #expect(partition.subfolders[0].id == 2)
        #expect(partition.subfolders[0].folderPath == "/Volumes/Media/Anime/Ave Mujica")
        #expect(partition.directEpisodeGroups.count == 1)
        #expect(partition.directEpisodeGroups[0].id == 10)
        #expect(partition.directEpisodeGroups[0].displayTitle == "Ave Mujica - EP01")
    }

    @Test
    func indexingStoreLastUpdatedDatePersistence() {
        _ = NSApplication.shared
        let suiteName = "IndexingStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults.temporary(suiteName: suiteName)!
        let statusSuite = "IndexingStatusTest-\(UUID().uuidString)"
        let statusDefaults = UserDefaults.temporary(suiteName: statusSuite)!
        defer {
            defaults.removePersistentDomainAndPlist(forName: suiteName)
            statusDefaults.removePersistentDomainAndPlist(forName: statusSuite)
        }
        let settings = SettingsStore(userDefaults: defaults)

        let store = IndexingStore(userDefaults: defaults, settings: settings)
        #expect(store.lastUpdatedDate == nil)
        #expect(store.lastIndexedDate == nil)

        let now = Date(timeIntervalSince1970: 1727856000) // Fixed timestamp for determinism
        store.recordLastUpdatedDate(now)
        #expect(store.lastUpdatedDate == now)
        #expect(store.lastIndexedDate == now)

        // Rehydration test
        let restoredStore = IndexingStore(userDefaults: defaults, settings: settings)
        #expect(restoredStore.lastUpdatedDate == now)
        #expect(restoredStore.lastIndexedDate == now)

        // Status transition test
        let newStore = IndexingStore(userDefaults: statusDefaults, settings: settings)
        #expect(newStore.lastUpdatedDate == nil)
        newStore.indexingStatus = .completedAll(folderCount: 1, SubtitleIndexingResult())
        #expect(newStore.lastUpdatedDate != nil)
    }

    @Test
    func databaseOperationNoticesAndLifecycle() {
        let suiteName = "DatabaseOperationNotices-\(UUID().uuidString)"
        let defaults = UserDefaults.temporary(suiteName: suiteName)!
        defer { defaults.removePersistentDomainAndPlist(forName: suiteName) }
        let settings = SettingsStore(userDefaults: defaults)
        let store = IndexingStore(userDefaults: defaults, settings: settings)

        let testFolder = URL(fileURLWithPath: "/Volumes/Media/Anime")

        // 1. Indexing completion sets operationNotice and lastUpdatedDate
        store.indexingStatus = .completed(testFolder, SubtitleIndexingResult())
        #expect(store.operationNotice == .indexed(folderName: "Anime"))
        #expect(store.lastUpdatedDate != nil)

        // 2. Clear transient notice resets operationNotice
        store.clearTransientNotice()
        #expect(store.operationNotice == nil)

        // 3. Indexing all completion sets operationNotice
        store.indexingStatus = .completedAll(folderCount: 3, SubtitleIndexingResult())
        #expect(store.operationNotice == .indexedAll)

        // 4. Index failure sets operationNotice
        store.indexingStatus = .failed(testFolder, "disk error")
        #expect(store.operationNotice == .indexFailed(folderName: "Anime"))

        // 5. Folder removal sets operationNotice
        store.removedFolderNotice = testFolder
        #expect(store.operationNotice == .removed(folderName: "Anime"))

        // 6. Clearing notice
        store.clearTransientNotice()
        #expect(store.operationNotice == nil)
        #expect(store.removedFolderNotice == nil)
    }

    @Test
    func fileStatusResolverAllDatabaseOperationsAndTransitions() {
        let testFolder = URL(fileURLWithPath: "/Volumes/Media/Movies")
        let now = Date(timeIntervalSince1970: 1727856000)

        // 1. In Progress: Folder removal
        let removalProgress = FileStatusResolver.resolve(
            indexingStatus: .idle,
            folderRemovalStatus: .removing(testFolder),
            operationNotice: nil,
            lastUpdatedDate: now
        )
        if case .inProgress(let text) = removalProgress {
            #expect(text.contains("Movies"))
        } else {
            Issue.record("Expected inProgress for removal, got \(removalProgress)")
        }

        // 2. In Progress: Indexing single folder
        let indexingProgress = FileStatusResolver.resolve(
            indexingStatus: .indexing(testFolder),
            folderRemovalStatus: .idle,
            operationNotice: nil,
            lastUpdatedDate: now
        )
        if case .inProgress(let text) = indexingProgress {
            #expect(text.contains("Movies"))
        } else {
            Issue.record("Expected inProgress for indexing, got \(indexingProgress)")
        }

        // 3. Completed: Indexed folder
        let indexedCompleted = FileStatusResolver.resolve(
            indexingStatus: .idle,
            folderRemovalStatus: .idle,
            operationNotice: .indexed(folderName: "Movies"),
            lastUpdatedDate: now
        )
        if case .completed(let text) = indexedCompleted {
            #expect(text.contains("Movies"))
        } else {
            Issue.record("Expected completed for indexed notice, got \(indexedCompleted)")
        }

        // 4. Completed: Removed folder
        let removedCompleted = FileStatusResolver.resolve(
            indexingStatus: .idle,
            folderRemovalStatus: .idle,
            operationNotice: .removed(folderName: "Movies"),
            lastUpdatedDate: now
        )
        if case .completed(let text) = removedCompleted {
            #expect(text.contains("Movies"))
        } else {
            Issue.record("Expected completed for removed notice, got \(removedCompleted)")
        }

        // 5. Failed: Removal failed
        let removalFailed = FileStatusResolver.resolve(
            indexingStatus: .idle,
            folderRemovalStatus: .idle,
            operationNotice: .removalFailed(folderName: "Movies"),
            lastUpdatedDate: now
        )
        if case .failed(let text) = removalFailed {
            #expect(text.contains("Movies"))
        } else {
            Issue.record("Expected failed for removalFailed notice, got \(removalFailed)")
        }

        // 6. Idle: With last updated timestamp formatted as yyyy-MM-dd HH:mm:ss
        let idleWithDate = FileStatusResolver.resolve(
            indexingStatus: .idle,
            folderRemovalStatus: .idle,
            operationNotice: nil,
            lastUpdatedDate: now
        )
        if case .idle(let text) = idleWithDate {
            let formattedExpected = FileStatusResolver.dateFormatter.string(from: now)
            #expect(text.contains(formattedExpected))
            #expect(FileStatusResolver.dateFormatter.dateFormat == "yyyy-MM-dd HH:mm:ss")
        } else {
            Issue.record("Expected idle with date, got \(idleWithDate)")
        }

        // 7. Idle: Never updated
        let idleNever = FileStatusResolver.resolve(
            indexingStatus: .idle,
            folderRemovalStatus: .idle,
            operationNotice: nil,
            lastUpdatedDate: nil
        )
        if case .idle(let text) = idleNever {
            #expect(text.hasSuffix("-"))
            #expect(!text.contains("--"))
        } else {
            Issue.record("Expected idle never with '-', got \(idleNever)")
        }
    }

    @Test
    func fileOnDemandStoreCachingAndInvalidation() {
        let store = LibraryStore()

        let rootPath = "/Volumes/Media/Anime"
        let folderPath = "/Volumes/Media/Anime/SeriesA"

        // 1. Initial state is empty and idle
        #expect(store.fileSubfolders(for: rootPath).isEmpty)
        #expect(store.fileSubfolderStatus(for: rootPath) == .idle)
        #expect(store.fileObjects(for: folderPath).isEmpty)
        #expect(store.fileObjectStatus(for: folderPath) == .idle)

        // 2. Populate cache
        let dummyFolder = IndexedContentFolder(
            id: 10,
            relativePath: "SeriesA",
            folderPath: folderPath,
            objects: []
        )
        store.fileSubfoldersByRootPath[rootPath] = [dummyFolder]
        store.fileSubfolderStatusByRootPath[rootPath] = .completed

        let dummyObject = IndexedContentObject(
            id: 100,
            displayTitle: "Episode 1",
            videoPath: "\(folderPath)/EP01.mkv",
            videoName: "EP01.mkv",
            fileSize: 1024,
            subtitles: []
        )
        store.fileObjectsByFolderPath[folderPath] = [dummyObject]
        store.fileObjectStatusByFolderPath[folderPath] = .completed

        // 3. Test standardized path lookup (e.g. with trailing slash)
        #expect(store.fileSubfolders(for: "\(rootPath)/").count == 1)
        #expect(store.fileSubfolderStatus(for: "\(rootPath)/") == .completed)
        #expect(store.fileObjects(for: "\(folderPath)/").count == 1)
        #expect(store.fileObjectStatus(for: "\(folderPath)/") == .completed)

        // 4. Invalidation clears cache and bumps revision
        let initialRevision = store.fileTreeRevision
        store.fileSubfoldersByRootPath.removeAll(keepingCapacity: false)
        store.fileObjectsByFolderPath.removeAll(keepingCapacity: false)
        store.fileSubfolderStatusByRootPath.removeAll(keepingCapacity: false)
        store.fileObjectStatusByFolderPath.removeAll(keepingCapacity: false)
        store.fileTreeRevision += 1

        #expect(store.fileTreeRevision == initialRevision + 1)
        #expect(store.fileSubfolders(for: rootPath).isEmpty)
        #expect(store.fileObjects(for: folderPath).isEmpty)
        #expect(store.fileSubfolderStatus(for: rootPath) == .idle)
        #expect(store.fileObjectStatus(for: folderPath) == .idle)
    }

    @Test
    func fileStatusTaskDetailTargetMappingAndDeletedRecordToast() async throws {
        defer { AppLocalization.apply(.english) }
        AppLocalization.apply(.english)

        let suiteName = "FileStatusTaskDetailTests-\(UUID().uuidString)"
        let defaults = UserDefaults.temporary(suiteName: suiteName)!
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerFileStatusTaskDetailTests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer {
            defaults.removePersistentDomainAndPlist(forName: suiteName)
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-shm"))
        }

        let app = AppCoordinator(userDefaults: defaults, databaseURL: databaseURL)

        // 1. TaskRecordKind.isFileStatusTask classification (4 library tasks vs Rename/Export)
        #expect(TaskRecordKind.index.isFileStatusTask == true)
        #expect(TaskRecordKind.addFolder.isFileStatusTask == true)
        #expect(TaskRecordKind.removeFolder.isFileStatusTask == true)
        #expect(TaskRecordKind.ankiExport.isFileStatusTask == false)
        #expect(TaskRecordKind.renameFolder.isFileStatusTask == false)
        #expect(TaskRecordKind.renameFiles.isFileStatusTask == false)

        // 2. Never indexed state (Last Updated: --) is non-interactive: no task target, no dialog, no toast
        #expect(app.indexing.lastUpdatedDate == nil)
        #expect(app.fileStatusTargetTaskID(for: .idle("Last Updated: --")) == nil)
        app.openFileStatusTaskDetail(for: .idle("Last Updated: --"))
        #expect(app.tasks.detailTaskID == nil)
        #expect(app.toast.visibleItems.isEmpty)

        // 3. In Progress state opens the currently running File status task without opening TaskPanel
        app.tasks.runIndexFolder = { _, _ in
            try await Task.sleep(nanoseconds: 3_600_000_000_000)
            return 0
        }
        _ = app.tasks.enqueueIndexFolder(URL(fileURLWithPath: "/Volumes/Media/Anime"))
        let runningEntry = try #require(app.tasks.current.first)
        #expect(app.tasks.activeFileStatusTaskID == runningEntry.id)
        #expect(app.fileStatusTargetTaskID(for: .inProgress("Indexing Anime...")) == runningEntry.id)

        app.openFileStatusTaskDetail(for: .inProgress("Indexing Anime..."))
        #expect(app.tasks.detailTaskID == runningEntry.id)
        #expect(app.tasks.isPanelOpen == false)

        app.tasks.removeCurrentTask(id: runningEntry.id)
        await app.tasks.waitUntilIdle()
        app.tasks.closeTaskDetail()

        // 4. Completed task updates both lastFileStatusNoticeTaskID and indexing.lastUpdatedTaskID
        app.tasks.runIndexFolder = { _, _ in 5 }
        app.indexing.recordLastUpdatedDate(Date(timeIntervalSince1970: 1_727_856_000))
        _ = app.tasks.enqueueIndexFolder(URL(fileURLWithPath: "/Volumes/Media/Anime"))
        await app.tasks.waitUntilIdle()
        let completedRecord = try #require(app.tasks.completed.first)
        #expect(app.tasks.lastFileStatusNoticeTaskID == completedRecord.id)
        #expect(app.indexing.lastUpdatedTaskID == completedRecord.id)

        app.openFileStatusTaskDetail(for: .completed("Indexed Anime"))
        #expect(app.tasks.detailTaskID == completedRecord.id)
        app.tasks.closeTaskDetail()

        // 5. Subsequent failed task becomes the Failed notice target, while Idle still targets the completed task
        struct TestFailure: LocalizedError {
            var errorDescription: String? { "disk error" }
        }
        app.tasks.runRemoveFolder = { _ in
            throw TestFailure()
        }
        app.tasks.enqueueRemoveFolder(URL(fileURLWithPath: "/Volumes/Media/Movies"))
        await app.tasks.waitUntilIdle()
        let failedRecord = try #require(app.tasks.incomplete.first(where: { $0.id != runningEntry.id }))
        #expect(app.tasks.lastFileStatusNoticeTaskID == failedRecord.id)
        #expect(app.indexing.lastUpdatedTaskID == completedRecord.id)

        app.openFileStatusTaskDetail(for: .failed("Failed to remove Movies"))
        #expect(app.tasks.detailTaskID == failedRecord.id)

        app.tasks.closeTaskDetail()
        app.openFileStatusTaskDetail(for: .idle("Last Updated: 24-10-02 16:00"))
        #expect(app.tasks.detailTaskID == completedRecord.id)

        // 6. Deleting the task record and clicking the status text shows warning toast instead of opening Task Info
        app.tasks.closeTaskDetail()
        app.tasks.deleteRecord(id: completedRecord.id)
        app.openFileStatusTaskDetail(for: .idle("Last Updated: 24-10-02 16:00"))
        #expect(app.tasks.detailTaskID == nil)
        let toastRequest = try #require(app.toast.visibleItems.last?.request)
        #expect(toastRequest.scenarioID == "task.detail.record_not_found")
        #expect(toastRequest.icon == .warning)
        #expect(toastRequest.duration == ToastDuration.alert)
        #expect(toastRequest.message == "Task record no longer exists")
    }

    @Test
    func remoteFolderDialogsIsolateInvalidationsAndLazyFileCardActionsRespectOwnerToken() {
        let suiteName = "RemoteDialogIsolationTests-\(UUID().uuidString)"
        let defaults = UserDefaults.temporary(suiteName: suiteName)!
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerRemoteDialogIsolationTests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer {
            defaults.removePersistentDomainAndPlist(forName: suiteName)
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-shm"))
        }

        let app = AppCoordinator(userDefaults: defaults, databaseURL: databaseURL)
        var libraryInvalidationCount = 0
        var remoteDialogInvalidationCount = 0
        let libraryCancellable = app.library.objectWillChange.sink { _ in
            libraryInvalidationCount += 1
        }
        let remoteDialogCancellable = app.library.remoteFolderDialog.objectWillChange.sink { _ in
            remoteDialogInvalidationCount += 1
        }
        _ = (libraryCancellable, remoteDialogCancellable)

        app.openWebDAVFolderDialog()
        #expect(app.library.webdavDialogSession != nil)
        #expect(libraryInvalidationCount == 0)
        #expect(remoteDialogInvalidationCount == 1)

        app.closeWebDAVFolderDialog()
        #expect(app.library.webdavDialogSession == nil)
        #expect(libraryInvalidationCount == 0)
        #expect(remoteDialogInvalidationCount == 2)

        // Verify lazy-stack ownerToken prevents stale onDisappear from unregistering a newer card action
        let coordinator = WorkbenchAccessibilityCoordinator()
        let firstOwnerObject = NSObject()
        let secondOwnerObject = NSObject()
        let firstOwner = ObjectIdentifier(firstOwnerObject)
        let secondOwner = ObjectIdentifier(secondOwnerObject)
        var triggeredBy = ""
        coordinator.registerFileCardAction(id: "folder-1", ownerToken: firstOwner) {
            triggeredBy = "first"
        }
        coordinator.registerFileCardAction(id: "folder-1", ownerToken: secondOwner) {
            triggeredBy = "second"
        }
        coordinator.unregisterFileCardAction(id: "folder-1", ownerToken: firstOwner)
        #expect(coordinator.activateFileCardAction(id: "folder-1") == true)
        #expect(triggeredBy == "second")
        coordinator.unregisterFileCardAction(id: "folder-1", ownerToken: secondOwner)
        #expect(coordinator.activateFileCardAction(id: "folder-1") == false)
    }

    @Test
    func fileCardSubtitleFormatterFormatsRichMetadataAndOmitsNullsPreservingZerosAcrossLanguages() {
        defer { AppLocalization.apply(.english) }
        AppLocalization.apply(.english)

        let completeVideo = IndexedContentObject(
            id: 1,
            displayTitle: "Show - 01",
            videoPath: "/Media/Show/EP01.mkv",
            videoName: "EP01.mkv",
            fileSize: 831_650_000,
            videoWidth: 1920,
            videoHeight: 1080,
            videoCodec: "hevc",
            duration: 1422.0
        )
        #expect(
            FileCardSubtitleFormatter.videoSubtitle(for: completeVideo)
                == "1080P  HEVC  23:42  831.65 MB"
        )

        let partialNullVideo = IndexedContentObject(
            id: 2,
            displayTitle: "Show - 02",
            videoPath: "/Media/Show/EP02.mkv",
            videoName: "EP02.mkv",
            fileSize: nil,
            videoWidth: nil,
            videoHeight: nil,
            videoCodec: nil,
            duration: 185.0
        )
        #expect(FileCardSubtitleFormatter.videoSubtitle(for: partialNullVideo) == "03:05")

        let zeroByteVideo = IndexedContentObject(
            id: 3,
            displayTitle: "Show - 03",
            videoPath: "/Media/Show/EP03.mkv",
            videoName: "EP03.mkv",
            fileSize: 0,
            videoWidth: 3840,
            videoHeight: 1600,
            videoCodec: "h264",
            duration: 3930.0
        )
        #expect(
            FileCardSubtitleFormatter.videoSubtitle(for: zeroByteVideo)
                == "4K  AVC  01:05:30  0 B"
        )

        let completeSubtitle = IndexedContentSubtitle(
            id: 10,
            path: "/Media/Show/EP01.ass",
            name: "EP01.ass",
            fileSize: 128_400,
            rawCueCount: 523,
            validCueCount: 500
        )
        #expect(
            FileCardSubtitleFormatter.subtitleSubtitle(for: completeSubtitle)
                == "523 raw cues  500 valid cues  128.40 KB"
        )

        let singularSubtitle = IndexedContentSubtitle(
            id: 11,
            path: "/Media/Show/EP02.srt",
            name: "EP02.srt",
            fileSize: 0,
            rawCueCount: 1,
            validCueCount: 1
        )
        #expect(
            FileCardSubtitleFormatter.subtitleSubtitle(for: singularSubtitle)
                == "1 raw cue  1 valid cue  0 B"
        )

        let zeroAndNullSubtitle = IndexedContentSubtitle(
            id: 12,
            path: "/Media/Show/EP03.srt",
            name: "EP03.srt",
            fileSize: nil,
            rawCueCount: nil,
            validCueCount: 0
        )
        #expect(
            FileCardSubtitleFormatter.subtitleSubtitle(for: zeroAndNullSubtitle)
                == "0 valid cues"
        )

        AppLocalization.apply(.simplifiedChinese)
        #expect(
            FileCardSubtitleFormatter.subtitleSubtitle(for: completeSubtitle)
                == "523 条原始台词  500 条有效台词  128.40 KB"
        )
        #expect(
            FileCardSubtitleFormatter.subtitleSubtitle(for: singularSubtitle)
                == "1 条原始台词  1 条有效台词  0 B"
        )
        #expect(
            FileCardSubtitleFormatter.subtitleSubtitle(for: zeroAndNullSubtitle)
                == "0 条有效台词"
        )

        AppLocalization.apply(.traditionalChinese)
        #expect(
            FileCardSubtitleFormatter.subtitleSubtitle(for: completeSubtitle)
                == "523 條原始台詞  500 條有效台詞  128.40 KB"
        )
        #expect(
            FileCardSubtitleFormatter.subtitleSubtitle(for: singularSubtitle)
                == "1 條原始台詞  1 條有效台詞  0 B"
        )
        #expect(
            FileCardSubtitleFormatter.subtitleSubtitle(for: zeroAndNullSubtitle)
                == "0 條有效台詞"
        )
    }

    @Test
    func videoCardSubtitleInsertsHighestPriorityHDRAndRespondsToLocale() {
        let dvObject = IndexedContentObject(
            id: 1,
            displayTitle: "Movie",
            videoPath: "/Media/Movie.mkv",
            videoName: "Movie.mkv",
            fileSize: 18_420_000_000,
            videoWidth: 3840,
            videoHeight: 2160,
            videoCodec: "hevc",
            duration: 7100.0,
            hdrMetadata: VideoHDRMetadata(
                standards: [.hlg, .hdr10, .hdr10Plus, .dolbyVision],
                dolbyVisionProfile: 8,
                dolbyVisionCompatibilityID: 1
            )
        )
        #expect(
            FileCardSubtitleFormatter.videoSubtitle(for: dvObject, locale: Locale(identifier: "en"))
                == "4K  Dolby Vision  HEVC  01:58:20  18.42 GB"
        )
        #expect(
            FileCardSubtitleFormatter.videoSubtitle(for: dvObject, locale: Locale(identifier: "zh-Hans"))
                == "4K  杜比视界  HEVC  01:58:20  18.42 GB"
        )
        #expect(
            FileCardSubtitleFormatter.videoSubtitle(for: dvObject, locale: Locale(identifier: "zh-Hant"))
                == "4K  杜比視界  HEVC  01:58:20  18.42 GB"
        )

        let hdr10PlusObject = IndexedContentObject(
            id: 2,
            displayTitle: "Show - 01",
            videoPath: "/Media/Show01.mkv",
            videoName: "Show01.mkv",
            fileSize: 1_850_000_000,
            videoWidth: 3840,
            videoHeight: 2160,
            videoCodec: "hevc",
            duration: 1422.0,
            hdrMetadata: VideoHDRMetadata(standards: [.hdr10, .hdr10Plus])
        )
        #expect(
            FileCardSubtitleFormatter.videoSubtitle(for: hdr10PlusObject, locale: Locale(identifier: "zh-Hans"))
                == "4K  HDR10+  HEVC  23:42  1.85 GB"
        )

        let hlgOnlyObject = IndexedContentObject(
            id: 3,
            displayTitle: "Broadcast",
            videoPath: "/Media/Broadcast.ts",
            videoName: "Broadcast.ts",
            fileSize: nil,
            videoWidth: 1920,
            videoHeight: 1080,
            videoCodec: "hevc",
            duration: 300.0,
            hdrMetadata: VideoHDRMetadata(standards: [.hlg])
        )
        #expect(
            FileCardSubtitleFormatter.videoSubtitle(for: hlgOnlyObject, locale: Locale(identifier: "en"))
                == "1080P  HLG  HEVC  05:00"
        )
    }
}

