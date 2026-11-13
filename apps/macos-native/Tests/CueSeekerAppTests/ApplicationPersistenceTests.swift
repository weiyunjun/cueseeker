import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@Test
func defaultDatabaseAndCoverDirectoriesSeparateDebugReleaseAndUnitTests() {
    let fakeAppSupport = URL(
        fileURLWithPath: "/Users/testuser/Library/Application Support",
        isDirectory: true
    )
    let debugDatabaseURL = AppCoordinator.defaultDatabaseURL(
        for: .debug,
        baseApplicationSupportDirectoryURL: fakeAppSupport
    )
    let releaseDatabaseURL = AppCoordinator.defaultDatabaseURL(
        for: .release,
        baseApplicationSupportDirectoryURL: fakeAppSupport
    )

    #expect(debugDatabaseURL.path == "/Users/testuser/Library/Application Support/CueSeeker/debug/CueSeeker.sqlite")
    #expect(
        debugDatabaseURL.deletingLastPathComponent().appendingPathComponent("Covers", isDirectory: true).path
            == "/Users/testuser/Library/Application Support/CueSeeker/debug/Covers"
    )
    #expect(releaseDatabaseURL.path == "/Users/testuser/Library/Application Support/CueSeeker/release/CueSeeker.sqlite")
    #expect(
        releaseDatabaseURL.deletingLastPathComponent().appendingPathComponent("Covers", isDirectory: true).path
            == "/Users/testuser/Library/Application Support/CueSeeker/release/Covers"
    )

    let unitTestDatabaseURL = AppCoordinator.defaultDatabaseURL()
    #expect(
        unitTestDatabaseURL.standardizedFileURL.path.hasPrefix(
            ApplicationInfo.unitTestApplicationSupportDirectoryURL.standardizedFileURL.path
        )
    )
}

@Test
func singleInstanceGuardAllowsParallelEnvironmentsAndBlocksDuplicateSameEnvironment() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("SingleInstanceGuardTests-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let releaseDirectory = ApplicationInfo.applicationSupportDirectoryURL(
        for: .release,
        baseApplicationSupportDirectoryURL: tempRoot
    )
    let debugDirectory = ApplicationInfo.applicationSupportDirectoryURL(
        for: .debug,
        baseApplicationSupportDirectoryURL: tempRoot
    )

    let firstRelease = SingleInstanceGuard.acquireLock(in: releaseDirectory, currentPID: 1001)
    guard case .acquired(let firstReleaseHandle) = firstRelease else {
        Issue.record("Expected initial release lock acquisition to succeed")
        return
    }
    #expect(firstReleaseHandle != nil)

    let firstDebug = SingleInstanceGuard.acquireLock(in: debugDirectory, currentPID: 2002)
    guard case .acquired(let firstDebugHandle) = firstDebug else {
        Issue.record("Expected debug lock acquisition to coexist with release lock")
        return
    }
    #expect(firstDebugHandle != nil)
    defer { firstDebugHandle?.release() }

    let duplicateRelease = SingleInstanceGuard.acquireLock(in: releaseDirectory, currentPID: 1003)
    switch duplicateRelease {
    case .alreadyRunning(let holderPID):
        #expect(holderPID == 1001)
    case .acquired(let unexpectedHandle):
        unexpectedHandle?.release()
        Issue.record("Expected second release lock acquisition to report alreadyRunning")
    }

    firstReleaseHandle?.release()

    let reacquiredRelease = SingleInstanceGuard.acquireLock(in: releaseDirectory, currentPID: 1004)
    switch reacquiredRelease {
    case .acquired(let reacquiredHandle):
        #expect(reacquiredHandle != nil)
        reacquiredHandle?.release()
    case .alreadyRunning(let holderPID):
        Issue.record("Expected release lock to succeed after previous handle released, got PID \(String(describing: holderPID))")
    }
}

@Test
func obsoleteFeatureStateCleanupRemovesDefaultsAndDeletesCredential() {
    let suiteName = "ApplicationPersistenceCleanupTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }
    let keys = [
        "aiChunkingEnabled",
        "aiChunkingTranslationLanguage",
        "aiChunkingPromptTemplate",
        "aiChunkingPromptDefaultVersion",
        "aiChunkingPromptAwareCacheCleared",
        "playbackSpeakerDisplayEnabled",
        "hasCompletedFileOnboarding"
    ]
    keys.forEach { userDefaults.set("legacy", forKey: $0) }
    var credentialWasDeleted = false

    ApplicationPersistence.removeObsoleteFeatureState(
        from: userDefaults,
        credentialDeletion: { credentialWasDeleted = true }
    )

    #expect(keys.allSatisfy { userDefaults.object(forKey: $0) == nil })
    #expect(credentialWasDeleted)
}
