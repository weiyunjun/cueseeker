import Foundation
import CueSeekerCore

enum ApplicationPersistence {
    private static let legacyDomainNames = [
        ApplicationInfo.bundleIdentifier,
        ApplicationInfo.name
    ]
    private static let migrationKey = "sharedPersistenceDomainMigrationCompleted"

    static func sharedUserDefaults() -> UserDefaults {
        guard let sharedDefaults = UserDefaults(
            suiteName: ApplicationInfo.preferencesSuiteIdentifier
        ) else {
            return .standard
        }

        let legacyDomains = legacyDomainNames.map {
            UserDefaults.standard.persistentDomain(forName: $0) ?? [:]
        }
        migrateLegacyDefaultsIfNeeded(legacyDomains, into: sharedDefaults)
        return sharedDefaults
    }

    static func migrateLegacyDefaultsIfNeeded(
        _ legacyDomains: [[String: Any]],
        into sharedDefaults: UserDefaults
    ) {
        guard !sharedDefaults.bool(forKey: migrationKey) else {
            return
        }

        for legacyValues in legacyDomains {
            for (key, value) in legacyValues where sharedDefaults.object(forKey: key) == nil {
                sharedDefaults.set(value, forKey: key)
            }
        }
        sharedDefaults.set(true, forKey: migrationKey)
    }
}
