import Foundation
import CueSeekerCore

enum ApplicationPersistence {
    private static let legacyDebugDomainName = ApplicationInfo.name
    private static let migrationKey = "sharedPersistenceMigrationFromLegacyDebugDefaultsCompleted"

    static func sharedUserDefaults() -> UserDefaults {
        guard let sharedDefaults = UserDefaults(
            suiteName: ApplicationInfo.persistenceIdentifier
        ) else {
            return .standard
        }

        let legacyValues = UserDefaults.standard.persistentDomain(
            forName: legacyDebugDomainName
        ) ?? [:]
        migrateLegacyDefaultsIfNeeded(legacyValues, into: sharedDefaults)
        return sharedDefaults
    }

    static func migrateLegacyDefaultsIfNeeded(
        _ legacyValues: [String: Any],
        into sharedDefaults: UserDefaults
    ) {
        guard !sharedDefaults.bool(forKey: migrationKey) else {
            return
        }

        for (key, value) in legacyValues where sharedDefaults.object(forKey: key) == nil {
            sharedDefaults.set(value, forKey: key)
        }
        sharedDefaults.set(true, forKey: migrationKey)
    }
}
