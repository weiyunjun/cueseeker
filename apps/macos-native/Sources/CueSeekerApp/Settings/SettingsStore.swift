import AppKit
import Foundation
import SwiftUI
import CueSeekerPlayback

@MainActor
final class SettingsStore: ObservableObject {
    private static let appAppearanceModeKey = "appAppearanceMode"
    private static let primarySearchLanguageKey = "primarySearchLanguage"
    private static let playbackDecodeModeKey = "playbackDecodeMode"
    private static let searchE2ELoggingEnabledKey = "searchE2ELoggingEnabled"
    private static let searchFTSVocabularyDiagnosticsEnabledKey = "searchFTSVocabularyDiagnosticsEnabled"
    private static let aiChunkingEnabledKey = "aiChunkingEnabled"
    private static let aiChunkingTranslationLanguageKey = "aiChunkingTranslationLanguage"
    private static let aiChunkingPromptTemplateKey = "aiChunkingPromptTemplate"
    private static let aiChunkingPromptDefaultVersionKey = "aiChunkingPromptDefaultVersion"
    private static let aiChunkingPromptDefaultVersion = "20260528-multi-plan-merge"

    @Published var appAppearanceMode: AppAppearanceMode {
        didSet {
            userDefaults.set(appAppearanceMode.rawValue, forKey: Self.appAppearanceModeKey)
            Self.applyAppAppearanceMode(appAppearanceMode)
        }
    }

    @Published var primarySearchLanguage: PrimarySearchLanguage {
        didSet {
            userDefaults.set(primarySearchLanguage.rawValue, forKey: Self.primarySearchLanguageKey)
        }
    }

    @Published var playbackDecodeMode: PlaybackDecodeMode {
        didSet {
            userDefaults.set(playbackDecodeMode.rawValue, forKey: Self.playbackDecodeModeKey)
        }
    }

    @Published var searchE2ELoggingEnabled: Bool {
        didSet {
            userDefaults.set(searchE2ELoggingEnabled, forKey: Self.searchE2ELoggingEnabledKey)
        }
    }

    @Published var searchFTSVocabularyDiagnosticsEnabled: Bool {
        didSet {
            userDefaults.set(
                searchFTSVocabularyDiagnosticsEnabled,
                forKey: Self.searchFTSVocabularyDiagnosticsEnabledKey
            )
        }
    }

    @Published var aiChunkingEnabled: Bool {
        didSet {
            userDefaults.set(aiChunkingEnabled, forKey: Self.aiChunkingEnabledKey)
        }
    }

    @Published var aiChunkingTranslationLanguage: AIChunkingTranslationLanguage {
        didSet {
            userDefaults.set(
                aiChunkingTranslationLanguage.rawValue,
                forKey: Self.aiChunkingTranslationLanguageKey
            )
        }
    }

    @Published private(set) var aiChunkingPromptTemplate: String

    @Published private(set) var deepSeekAPIKeyConfigured: Bool

    private let userDefaults: UserDefaults
    private let credentialStore: KeychainCredentialStore

    init(
        userDefaults: UserDefaults,
        credentialStore: KeychainCredentialStore = KeychainCredentialStore()
    ) {
        self.userDefaults = userDefaults
        self.credentialStore = credentialStore
        userDefaults.register(defaults: [
            Self.appAppearanceModeKey: AppAppearanceMode.auto.rawValue,
            Self.primarySearchLanguageKey: PrimarySearchLanguage.defaultValue.rawValue,
            Self.playbackDecodeModeKey: PlaybackDecodeMode.auto.rawValue,
            Self.searchE2ELoggingEnabledKey: true,
            Self.searchFTSVocabularyDiagnosticsEnabledKey: true,
            Self.aiChunkingEnabledKey: false,
            Self.aiChunkingTranslationLanguageKey: AIChunkingTranslationLanguage.defaultValue.rawValue,
            Self.aiChunkingPromptTemplateKey: AIChunkingPromptConfiguration.defaultTemplate
        ])
        Self.resetAIChunkingPromptTemplateForCurrentDefaultIfNeeded(userDefaults)

        let loadedAppearance = Self.loadAppAppearanceMode(from: userDefaults)
        self.appAppearanceMode = loadedAppearance
        self.primarySearchLanguage = Self.loadPrimarySearchLanguage(from: userDefaults)
        self.playbackDecodeMode = Self.loadPlaybackDecodeMode(from: userDefaults)
        self.searchE2ELoggingEnabled = userDefaults.bool(forKey: Self.searchE2ELoggingEnabledKey)
        self.searchFTSVocabularyDiagnosticsEnabled = userDefaults.bool(
            forKey: Self.searchFTSVocabularyDiagnosticsEnabledKey
        )
        self.aiChunkingEnabled = userDefaults.bool(forKey: Self.aiChunkingEnabledKey)
        self.aiChunkingTranslationLanguage = Self.loadAIChunkingTranslationLanguage(from: userDefaults)
        self.aiChunkingPromptTemplate = Self.loadAIChunkingPromptTemplate(from: userDefaults)
        self.deepSeekAPIKeyConfigured = Self.isAPIKeyConfigured(
            for: .deepSeek,
            credentialStore: credentialStore
        )

        Self.applyAppAppearanceMode(loadedAppearance)
    }

    func saveDeepSeekAPIKey(_ apiKey: String) throws {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw SettingsCredentialError.emptyAPIKey
        }

        try credentialStore.save(
            trimmedAPIKey,
            account: AIProvider.deepSeek.keychainAccount
        )
        deepSeekAPIKeyConfigured = true
    }

    func clearDeepSeekAPIKey() throws {
        try credentialStore.delete(account: AIProvider.deepSeek.keychainAccount)
        deepSeekAPIKeyConfigured = false
    }

    func deepSeekAPIKey() throws -> String? {
        try credentialStore.read(account: AIProvider.deepSeek.keychainAccount)
    }

    func refreshDeepSeekAPIKeyStatus() {
        deepSeekAPIKeyConfigured = Self.isAPIKeyConfigured(
            for: .deepSeek,
            credentialStore: credentialStore
        )
    }

    func saveAIChunkingPromptTemplate(_ template: String) throws {
        try AIChunkingPromptConfiguration.validateTemplate(template)

        aiChunkingPromptTemplate = template
        userDefaults.set(template, forKey: Self.aiChunkingPromptTemplateKey)
        userDefaults.set(Self.aiChunkingPromptDefaultVersion, forKey: Self.aiChunkingPromptDefaultVersionKey)
    }

    func restoreDefaultAIChunkingPromptTemplate() {
        aiChunkingPromptTemplate = AIChunkingPromptConfiguration.defaultTemplate
        userDefaults.removeObject(forKey: Self.aiChunkingPromptTemplateKey)
        userDefaults.set(Self.aiChunkingPromptDefaultVersion, forKey: Self.aiChunkingPromptDefaultVersionKey)
    }

    var aiChunkingPromptConfiguration: AIChunkingPromptConfiguration {
        AIChunkingPromptConfiguration(
            template: aiChunkingPromptTemplate,
            translationLanguage: aiChunkingTranslationLanguage
        )
    }

    private static func loadAppAppearanceMode(from userDefaults: UserDefaults) -> AppAppearanceMode {
        guard let rawValue = userDefaults.string(forKey: appAppearanceModeKey),
              let mode = AppAppearanceMode(rawValue: rawValue)
        else {
            return .auto
        }
        return mode
    }

    private static func loadPrimarySearchLanguage(from userDefaults: UserDefaults) -> PrimarySearchLanguage {
        guard let rawValue = userDefaults.string(forKey: primarySearchLanguageKey),
              let language = PrimarySearchLanguage(rawValue: rawValue)
        else {
            return .defaultValue
        }
        return language
    }

    private static func loadPlaybackDecodeMode(from userDefaults: UserDefaults) -> PlaybackDecodeMode {
        guard let rawValue = userDefaults.string(forKey: playbackDecodeModeKey),
              let mode = PlaybackDecodeMode(rawValue: rawValue)
        else {
            return .auto
        }
        return mode
    }

    private static func loadAIChunkingTranslationLanguage(from userDefaults: UserDefaults) -> AIChunkingTranslationLanguage {
        guard let rawValue = userDefaults.string(forKey: aiChunkingTranslationLanguageKey),
              let language = AIChunkingTranslationLanguage(rawValue: rawValue)
        else {
            return .defaultValue
        }
        return language
    }

    private static func loadAIChunkingPromptTemplate(from userDefaults: UserDefaults) -> String {
        guard let template = userDefaults.string(forKey: aiChunkingPromptTemplateKey),
              (try? AIChunkingPromptConfiguration.validateTemplate(template)) != nil
        else {
            return AIChunkingPromptConfiguration.defaultTemplate
        }
        return template
    }

    private static func resetAIChunkingPromptTemplateForCurrentDefaultIfNeeded(_ userDefaults: UserDefaults) {
        guard userDefaults.string(forKey: aiChunkingPromptDefaultVersionKey) != aiChunkingPromptDefaultVersion else {
            return
        }

        userDefaults.set(AIChunkingPromptConfiguration.defaultTemplate, forKey: aiChunkingPromptTemplateKey)
        userDefaults.set(aiChunkingPromptDefaultVersion, forKey: aiChunkingPromptDefaultVersionKey)
    }

    private static func applyAppAppearanceMode(_ mode: AppAppearanceMode) {
        NSApp.appearance = mode.nsAppearance
    }

    private static func isAPIKeyConfigured(
        for provider: AIProvider,
        credentialStore: KeychainCredentialStore
    ) -> Bool {
        (try? credentialStore.contains(account: provider.keychainAccount)) ?? false
    }
}

enum SettingsCredentialError: LocalizedError {
    case emptyAPIKey

    var errorDescription: String? {
        switch self {
        case .emptyAPIKey:
            return "Enter an API key before saving."
        }
    }
}
