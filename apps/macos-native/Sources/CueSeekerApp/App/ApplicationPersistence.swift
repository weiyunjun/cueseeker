import Foundation
import Security
import CueSeekerCore

enum ApplicationPersistence {
    private static let legacyDomainNames = [
        ApplicationInfo.bundleIdentifier,
        ApplicationInfo.name
    ]
    private static let migrationKey = "sharedPersistenceDomainMigrationCompleted"
    private static let obsoleteAIChunkingKeys = [
        "aiChunkingEnabled",
        "aiChunkingTranslationLanguage",
        "aiChunkingPromptTemplate",
        "aiChunkingPromptDefaultVersion",
        "aiChunkingPromptAwareCacheCleared"
    ]

    static func sharedUserDefaults() -> UserDefaults {
        guard let sharedDefaults = UserDefaults(
            suiteName: ApplicationInfo.preferencesSuiteIdentifier
        ) else {
            removeObsoleteAIChunkingState(from: .standard)
            return .standard
        }

        let legacyDomains = legacyDomainNames.map {
            UserDefaults.standard.persistentDomain(forName: $0) ?? [:]
        }
        migrateLegacyDefaultsIfNeeded(legacyDomains, into: sharedDefaults)
        removeObsoleteAIChunkingState(from: sharedDefaults)
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

    static func removeObsoleteAIChunkingState(
        from userDefaults: UserDefaults,
        credentialDeletion: () -> Void = { ApplicationPersistence.deleteDeepSeekCredential() }
    ) {
        obsoleteAIChunkingKeys.forEach(userDefaults.removeObject(forKey:))
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
