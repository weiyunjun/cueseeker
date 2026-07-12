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
            "existing": "legacy",
            "selectedFolderPaths": ["/tmp/Library"]
        ],
        into: sharedDefaults
    )

    #expect(sharedDefaults.string(forKey: "existing") == "shared")
    #expect(sharedDefaults.stringArray(forKey: "selectedFolderPaths") == ["/tmp/Library"])

    ApplicationPersistence.migrateLegacyDefaultsIfNeeded(
        ["selectedFolderPaths": ["/tmp/Changed"]],
        into: sharedDefaults
    )
    #expect(sharedDefaults.stringArray(forKey: "selectedFolderPaths") == ["/tmp/Library"])
}
