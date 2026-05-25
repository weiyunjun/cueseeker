import AppKit
import Foundation
import SwiftUI
import CueSeekerPlayback

@MainActor
final class SettingsStore: ObservableObject {
    private static let appAppearanceModeKey = "appAppearanceMode"
    private static let playbackDecodeModeKey = "playbackDecodeMode"
    private static let searchE2ELoggingEnabledKey = "searchE2ELoggingEnabled"
    private static let searchFTSVocabularyDiagnosticsEnabledKey = "searchFTSVocabularyDiagnosticsEnabled"
    private static let aiChunkingEnabledKey = "aiChunkingEnabled"

    @Published var appAppearanceMode: AppAppearanceMode {
        didSet {
            userDefaults.set(appAppearanceMode.rawValue, forKey: Self.appAppearanceModeKey)
            Self.applyAppAppearanceMode(appAppearanceMode)
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
            Self.playbackDecodeModeKey: PlaybackDecodeMode.auto.rawValue,
            Self.searchE2ELoggingEnabledKey: true,
            Self.searchFTSVocabularyDiagnosticsEnabledKey: true,
            Self.aiChunkingEnabledKey: false
        ])

        let loadedAppearance = Self.loadAppAppearanceMode(from: userDefaults)
        self.appAppearanceMode = loadedAppearance
        self.playbackDecodeMode = Self.loadPlaybackDecodeMode(from: userDefaults)
        self.searchE2ELoggingEnabled = userDefaults.bool(forKey: Self.searchE2ELoggingEnabledKey)
        self.searchFTSVocabularyDiagnosticsEnabled = userDefaults.bool(
            forKey: Self.searchFTSVocabularyDiagnosticsEnabledKey
        )
        self.aiChunkingEnabled = userDefaults.bool(forKey: Self.aiChunkingEnabledKey)
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

    private static func loadAppAppearanceMode(from userDefaults: UserDefaults) -> AppAppearanceMode {
        guard let rawValue = userDefaults.string(forKey: appAppearanceModeKey),
              let mode = AppAppearanceMode(rawValue: rawValue)
        else {
            return .auto
        }
        return mode
    }

    private static func loadPlaybackDecodeMode(from userDefaults: UserDefaults) -> PlaybackDecodeMode {
        guard let rawValue = userDefaults.string(forKey: playbackDecodeModeKey),
              let mode = PlaybackDecodeMode(rawValue: rawValue)
        else {
            return .auto
        }
        return mode
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
