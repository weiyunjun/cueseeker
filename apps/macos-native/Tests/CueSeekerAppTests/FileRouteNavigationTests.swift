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
}
