import AppKit
import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@Suite
@MainActor
struct FileRouteNavigationTests {
    @Test
    func fileThreeLevelNavigationAndHistoryFlow() {
        let defaults = UserDefaults(suiteName: "FileRouteNavigationTests-\(UUID().uuidString)")!
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
        let defaults = UserDefaults(suiteName: "FileRouteNavigationTests-\(UUID().uuidString)")!
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
        let homeTitle = "Home"
        let directSuffix = " (Direct Content)"

        // 1. Level 1: Home
        let level1Nodes = FileBreadcrumbResolver.nodes(
            for: .file,
            homeTitle: homeTitle,
            directContentSuffix: directSuffix
        )
        #expect(level1Nodes.count == 1)
        #expect(level1Nodes[0].id == "home")
        #expect(level1Nodes[0].title == "Home")
        #expect(level1Nodes[0].destination == nil)

        // 2. Level 2: Home > Anime
        let rootPath = "/Volumes/Media/Anime"
        let level2Nodes = FileBreadcrumbResolver.nodes(
            for: .fileFolder(rootPath: rootPath),
            homeTitle: homeTitle,
            directContentSuffix: directSuffix
        )
        #expect(level2Nodes.count == 2)
        #expect(level2Nodes[0].id == "home")
        #expect(level2Nodes[0].title == "Home")
        #expect(level2Nodes[0].destination == .file)
        #expect(level2Nodes[1].id == "root")
        #expect(level2Nodes[1].title == "Anime")
        #expect(level2Nodes[1].destination == nil)

        // 3. Level 3: Home > Anime > SeriesA
        let folderPath = "/Volumes/Media/Anime/SeriesA"
        let level3Nodes = FileBreadcrumbResolver.nodes(
            for: .fileFiles(rootPath: rootPath, folderPath: folderPath),
            homeTitle: homeTitle,
            directContentSuffix: directSuffix
        )
        #expect(level3Nodes.count == 3)
        #expect(level3Nodes[0].id == "home")
        #expect(level3Nodes[0].title == "Home")
        #expect(level3Nodes[0].destination == .file)
        #expect(level3Nodes[1].id == "root")
        #expect(level3Nodes[1].title == "Anime")
        #expect(level3Nodes[1].destination == .fileFolder(rootPath: rootPath))
        #expect(level3Nodes[2].id == "folder")
        #expect(level3Nodes[2].title == "SeriesA")
        #expect(level3Nodes[2].destination == nil)

        // 4. Level 3 Direct Content: Home > Anime > Anime (Direct Content)
        let directContentNodes = FileBreadcrumbResolver.nodes(
            for: .fileFiles(rootPath: rootPath, folderPath: rootPath),
            homeTitle: homeTitle,
            directContentSuffix: directSuffix
        )
        #expect(directContentNodes.count == 3)
        #expect(directContentNodes[2].id == "folder")
        #expect(directContentNodes[2].title == "Anime (Direct Content)")
        #expect(directContentNodes[2].destination == nil)
    }

    @Test
    func indexingStoreLastIndexedDatePersistence() {
        _ = NSApplication.shared
        let suiteName = "IndexingStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = SettingsStore(userDefaults: defaults)

        let store = IndexingStore(userDefaults: defaults, settings: settings)
        #expect(store.lastIndexedDate == nil)

        let now = Date(timeIntervalSince1970: 1727856000) // Fixed timestamp for determinism
        store.recordLastIndexedDate(now)
        #expect(store.lastIndexedDate == now)

        // Rehydration test
        let restoredStore = IndexingStore(userDefaults: defaults, settings: settings)
        #expect(restoredStore.lastIndexedDate == now)

        // Status transition test
        let newStore = IndexingStore(userDefaults: UserDefaults(suiteName: "IndexingStatusTest-\(UUID().uuidString)")!, settings: settings)
        #expect(newStore.lastIndexedDate == nil)
        newStore.indexingStatus = .completedAll(folderCount: 1, SubtitleIndexingResult())
        #expect(newStore.lastIndexedDate != nil)
    }
}
