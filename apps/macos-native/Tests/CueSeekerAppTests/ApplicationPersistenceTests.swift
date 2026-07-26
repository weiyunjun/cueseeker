import Foundation
import Testing
@testable import CueSeekerApp

@Test
func sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues() {
    let suiteName = "ApplicationPersistenceTests-\(UUID().uuidString)"
    let sharedDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        sharedDefaults.removePersistentDomain(forName: suiteName)
    }

    sharedDefaults.set("shared", forKey: "existing")
    ApplicationPersistence.migrateLegacyDefaultsIfNeeded(
        [
            [
                "existing": "packaged",
                "workbenchPanelMode": "shiori"
            ],
            [
                "existing": "debug",
                "selectedFolderPaths": ["/tmp/Library"]
            ]
        ],
        into: sharedDefaults
    )

    #expect(sharedDefaults.string(forKey: "existing") == "shared")
    #expect(sharedDefaults.string(forKey: "workbenchPanelMode") == "shiori")
    #expect(sharedDefaults.stringArray(forKey: "selectedFolderPaths") == ["/tmp/Library"])

    ApplicationPersistence.migrateLegacyDefaultsIfNeeded(
        [["selectedFolderPaths": ["/tmp/Changed"]]],
        into: sharedDefaults
    )
    #expect(sharedDefaults.stringArray(forKey: "selectedFolderPaths") == ["/tmp/Library"])
}

@Test
func obsoleteFeatureStateCleanupRemovesDefaultsAndDeletesCredential() {
    let suiteName = "ApplicationPersistenceCleanupTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
    let keys = [
        "aiChunkingEnabled",
        "aiChunkingTranslationLanguage",
        "aiChunkingPromptTemplate",
        "aiChunkingPromptDefaultVersion",
        "aiChunkingPromptAwareCacheCleared",
        "playbackSpeakerDisplayEnabled"
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
