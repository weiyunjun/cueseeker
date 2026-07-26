import Foundation
import Security
import CueSeekerCore

enum ApplicationPersistence {
    private static let legacyDomainNames = [
        ApplicationInfo.bundleIdentifier,
        ApplicationInfo.name
    ]
    private static let migrationKey = "sharedPersistenceDomainMigrationCompleted"
    private static let obsoleteFeaturePreferenceKeys = [
        "aiChunkingEnabled",
        "aiChunkingTranslationLanguage",
        "aiChunkingPromptTemplate",
        "aiChunkingPromptDefaultVersion",
        "aiChunkingPromptAwareCacheCleared",
        "playbackSpeakerDisplayEnabled"
    ]

    static func sharedUserDefaults() -> UserDefaults {
        guard let sharedDefaults = UserDefaults(
            suiteName: ApplicationInfo.preferencesSuiteIdentifier
        ) else {
            removeObsoleteFeatureState(from: .standard)
            return .standard
        }

        let legacyDomains = legacyDomainNames.map {
            UserDefaults.standard.persistentDomain(forName: $0) ?? [:]
        }
        migrateLegacyDefaultsIfNeeded(legacyDomains, into: sharedDefaults)
        removeObsoleteFeatureState(from: sharedDefaults)
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

    static func removeObsoleteFeatureState(
        from userDefaults: UserDefaults,
        credentialDeletion: () -> Void = { ApplicationPersistence.deleteDeepSeekCredential() }
    ) {
        obsoleteFeaturePreferenceKeys.forEach(userDefaults.removeObject(forKey:))
        credentialDeletion()
    }

    private static func deleteDeepSeekCredential() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CueSeekerAI",
            kSecAttrAccount as String: "deepseek"
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}
