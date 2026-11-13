import Foundation
import Testing
import CueSeekerCore

@Test
func applicationInfoDefinesNativeAppName() {
    #expect(ApplicationInfo.name == "CueSeeker")
}

@Test
func applicationInfoSeparatesDebugAndReleasePreferencesAndDirectories() {
    #expect(ApplicationInfo.bundleIdentifier == "com.cueseeker.app")
    #expect(ApplicationInfo.preferencesSuiteIdentifier(for: .debug) == "com.cueseeker.debug")
    #expect(ApplicationInfo.preferencesSuiteIdentifier(for: .release) == "com.cueseeker.release")
    #expect(
        ApplicationInfo.preferencesSuiteIdentifier
            == ApplicationInfo.preferencesSuiteIdentifier(for: .current)
    )

    let fakeAppSupport = URL(fileURLWithPath: "/Users/testuser/Library/Application Support", isDirectory: true)
    #expect(
        ApplicationInfo.applicationSupportDirectoryURL(
            for: .debug,
            baseApplicationSupportDirectoryURL: fakeAppSupport
        ).path == "/Users/testuser/Library/Application Support/CueSeeker/debug"
    )
    #expect(
        ApplicationInfo.applicationSupportDirectoryURL(
            for: .release,
            baseApplicationSupportDirectoryURL: fakeAppSupport
        ).path == "/Users/testuser/Library/Application Support/CueSeeker/release"
    )

    let fakeCaches = URL(fileURLWithPath: "/Users/testuser/Library/Caches", isDirectory: true)
    #expect(
        ApplicationInfo.cachesDirectoryURL(
            for: .debug,
            baseCachesDirectoryURL: fakeCaches
        ).path == "/Users/testuser/Library/Caches/CueSeeker/debug"
    )
    #expect(
        ApplicationInfo.cachesDirectoryURL(
            for: .release,
            baseCachesDirectoryURL: fakeCaches
        ).path == "/Users/testuser/Library/Caches/CueSeeker/release"
    )

    let tempRootPath = FileManager.default.temporaryDirectory.standardizedFileURL.path
    #expect(ApplicationInfo.unitTestApplicationSupportDirectoryURL.standardizedFileURL.path.hasPrefix(tempRootPath))
    #expect(ApplicationInfo.unitTestSubtitleCacheDirectoryURL.standardizedFileURL.path.hasPrefix(tempRootPath))
    #expect(ApplicationInfo.unitTestCachesDirectoryURL.standardizedFileURL.path.hasPrefix(tempRootPath))
}

@Test
func applicationInfoDefinesMinimumMacOSVersion() {
    #expect(ApplicationInfo.minimumMacOSVersion == "13.0")
}
