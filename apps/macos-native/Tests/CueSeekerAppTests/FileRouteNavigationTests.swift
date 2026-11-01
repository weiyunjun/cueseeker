import AppKit
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
        let singularTitle = "All Folder"
        let pluralTitle = "All Folders"

        // 1. Level 1 header title singular vs plural
        #expect(
            FileBreadcrumbResolver.allFoldersTitle(
                folderCount: 1,
                singularTitle: singularTitle,
                pluralTitle: pluralTitle
            ) == "All Folder"
        )
        #expect(
            FileBreadcrumbResolver.allFoldersTitle(
                folderCount: 2,
                singularTitle: singularTitle,
                pluralTitle: pluralTitle
            ) == "All Folders"
        )

        // 2. Level 1: No breadcrumb nodes (header is rendered directly in Level 1)
        let level1Nodes = FileBreadcrumbResolver.nodes(
            for: .file,
            folderCount: 1,
            singularRootTitle: singularTitle,
            pluralRootTitle: pluralTitle
        )
        #expect(level1Nodes.isEmpty)

        // 3. Level 2 (1 folder total): All Folder > Anime
        let localRootPath = "/Volumes/Media/Anime"
        let level2SingleFolderNodes = FileBreadcrumbResolver.nodes(
            for: .fileFolder(rootPath: localRootPath),
            folderCount: 1,
            singularRootTitle: singularTitle,
            pluralRootTitle: pluralTitle
        )
        #expect(level2SingleFolderNodes.count == 2)
        #expect(level2SingleFolderNodes[0].id == "all")
        #expect(level2SingleFolderNodes[0].title == "All Folder")
        #expect(level2SingleFolderNodes[0].destination == .file)
        #expect(level2SingleFolderNodes[1].id == "root")
        #expect(level2SingleFolderNodes[1].title == "Anime")
        #expect(level2SingleFolderNodes[1].destination == nil)

        // 4. Level 2 (WebDAV with >1 folders total): All Folders > MyCloud
        let webdavRootPath = "https://dav.example.com/dav/MyCloud"
        let level2WebDAVNodes = FileBreadcrumbResolver.nodes(
            for: .fileFolder(rootPath: webdavRootPath),
            folderCount: 2,
            singularRootTitle: singularTitle,
            pluralRootTitle: pluralTitle
        )
        #expect(level2WebDAVNodes.count == 2)
        #expect(level2WebDAVNodes[0].id == "all")
        #expect(level2WebDAVNodes[0].title == "All Folders")
        #expect(level2WebDAVNodes[0].destination == .file)
        #expect(level2WebDAVNodes[1].id == "root")
        #expect(level2WebDAVNodes[1].title == "MyCloud")
        #expect(level2WebDAVNodes[1].destination == nil)

        // 5. Level 3 (>1 folders total): All Folders > Anime > SeriesA
        let folderPath = "/Volumes/Media/Anime/SeriesA"
        let level3Nodes = FileBreadcrumbResolver.nodes(
            for: .fileFiles(rootPath: localRootPath, folderPath: folderPath),
            folderCount: 3,
            singularRootTitle: singularTitle,
            pluralRootTitle: pluralTitle
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
}

