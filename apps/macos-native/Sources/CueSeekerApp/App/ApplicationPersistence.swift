import Foundation
import Security
import CueSeekerCore

enum ApplicationPersistence {
    private static let obsoleteFeaturePreferenceKeys = [
        "aiChunkingEnabled",
        "aiChunkingTranslationLanguage",
        "aiChunkingPromptTemplate",
        "aiChunkingPromptDefaultVersion",
        "aiChunkingPromptAwareCacheCleared",
        "playbackSpeakerDisplayEnabled",
        "hasCompletedFileOnboarding"
    ]

    static func sharedUserDefaults(
        for configuration: AppBuildConfiguration = .current
    ) -> UserDefaults {
        if ApplicationInfo.isRunningInUnitTestProcess {
            return ApplicationInfo.defaultSharedUserDefaults(for: configuration)
        }
        guard let sharedDefaults = UserDefaults(
            suiteName: ApplicationInfo.preferencesSuiteIdentifier(for: configuration)
        ) else {
            removeObsoleteFeatureState(from: .standard)
            return .standard
        }

        removeObsoleteFeatureState(from: sharedDefaults)
        return sharedDefaults
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
