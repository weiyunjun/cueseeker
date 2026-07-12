import AppKit
import Foundation
import SwiftUI
import CueSeekerPlayback

@MainActor
final class CueGroupPresentationStore: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private let userDefaults: UserDefaults
    private let userDefaultsKey: String
    private let uiProbeScope: String

    init(
        isEnabled: Bool,
        userDefaults: UserDefaults,
        userDefaultsKey: String,
        uiProbeScope: String
    ) {
        self.isEnabled = isEnabled
        self.userDefaults = userDefaults
        self.userDefaultsKey = userDefaultsKey
        self.uiProbeScope = uiProbeScope
    }

    func set(_ isEnabled: Bool) {
        guard self.isEnabled != isEnabled else {
            return
        }
        self.isEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: userDefaultsKey)
    }

    func setFromUser(_ isEnabled: Bool) {
        guard self.isEnabled != isEnabled else {
            return
        }
        UIInvalidationProbe.mark(
            "ACTION UI.ShowCueGroup.changed",
            scope: uiProbeScope,
            details: "enabled=\(isEnabled)"
        )
        set(isEnabled)
    }
}

struct CueGroupPresentationGate: View {
    @ObservedObject var store: CueGroupPresentationStore
    let isActive: Bool
    @Binding var appliedValue: Bool?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onAppear {
                applyCurrentValueIfActive()
            }
            .onChange(of: store.isEnabled) { _ in
                applyCurrentValueIfActive()
            }
            .onChange(of: isActive) { isActive in
                if isActive {
                    appliedValue = store.isEnabled
                }
            }
    }

    private func applyCurrentValueIfActive() {
        guard isActive else {
            return
        }
        appliedValue = store.isEnabled
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private static let appAppearanceModeKey = "appAppearanceMode"
    private static let primarySearchLanguageKey = "primarySearchLanguage"
    private static let searchScopeKey = "searchScope"
    private static let showCueGroupKey = "showCueGroup"
    private static let playbackDecodeModeKey = "playbackDecodeMode"
    private static let autoPlayCueSequenceEnabledKey = "autoPlayCueSequenceEnabled"
    private static let autoPlayCueSequenceGapMillisecondsKey = "autoPlayCueSequenceGapMilliseconds"
    private static let playbackSpeakerDisplayEnabledKey = "playbackSpeakerDisplayEnabled"
    private static let searchE2ELoggingEnabledKey = "searchE2ELoggingEnabled"
    private static let searchFTSVocabularyDiagnosticsEnabledKey = "searchFTSVocabularyDiagnosticsEnabled"
    private static let searchFilterSetsKey = "searchFilterSets"
    private static let urlSchemePlayFirstSearchResultEnabledKey = "urlSchemePlayFirstSearchResultEnabled"
    private static let aiChunkingEnabledKey = "aiChunkingEnabled"
    private static let aiChunkingTranslationLanguageKey = "aiChunkingTranslationLanguage"
    private static let aiChunkingPromptTemplateKey = "aiChunkingPromptTemplate"
    private static let aiChunkingPromptDefaultVersionKey = "aiChunkingPromptDefaultVersion"
    private static let aiChunkingPromptDefaultVersion = "20260528-multi-plan-merge"
    static let autoPlayCueSequenceGapDefaultMilliseconds = 500
    static let autoPlayCueSequenceGapMinimumMilliseconds = 0
    static let autoPlayCueSequenceGapMaximumMilliseconds = 10_000

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

    @Published var searchScope: SearchScope {
        didSet {
            userDefaults.set(searchScope.rawValue, forKey: Self.searchScopeKey)
        }
    }

    let cueGroupPresentation: CueGroupPresentationStore

    var showCueGroup: Bool {
        get { cueGroupPresentation.isEnabled }
        set { cueGroupPresentation.set(newValue) }
    }

    @Published var playbackDecodeMode: PlaybackDecodeMode {
        didSet {
            userDefaults.set(playbackDecodeMode.rawValue, forKey: Self.playbackDecodeModeKey)
        }
    }

    @Published var autoPlayCueSequenceEnabled: Bool {
        didSet {
            userDefaults.set(autoPlayCueSequenceEnabled, forKey: Self.autoPlayCueSequenceEnabledKey)
        }
    }

    @Published private(set) var autoPlayCueSequenceGapMilliseconds: Int

    @Published var playbackSpeakerDisplayEnabled: Bool {
        didSet {
            userDefaults.set(playbackSpeakerDisplayEnabled, forKey: Self.playbackSpeakerDisplayEnabledKey)
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

    @Published var searchFilterSets: [SchemaWorkbenchFilterSet] {
        didSet {
            Self.saveSearchFilterSets(searchFilterSets, to: userDefaults)
        }
    }

    @Published var urlSchemePlayFirstSearchResultEnabled: Bool {
        didSet {
            userDefaults.set(
                urlSchemePlayFirstSearchResultEnabled,
                forKey: Self.urlSchemePlayFirstSearchResultEnabledKey
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
        credentialStore: KeychainCredentialStore = KeychainCredentialStore(),
        uiProbeScope: String = UUID().uuidString
    ) {
        self.userDefaults = userDefaults
        self.credentialStore = credentialStore
        userDefaults.register(defaults: [
            Self.appAppearanceModeKey: AppAppearanceMode.auto.rawValue,
            Self.primarySearchLanguageKey: PrimarySearchLanguage.defaultValue.rawValue,
            Self.searchScopeKey: SearchScope.defaultValue.rawValue,
            Self.showCueGroupKey: false,
            Self.playbackDecodeModeKey: PlaybackDecodeMode.auto.rawValue,
            Self.autoPlayCueSequenceEnabledKey: false,
            Self.autoPlayCueSequenceGapMillisecondsKey: Self.autoPlayCueSequenceGapDefaultMilliseconds,
            Self.playbackSpeakerDisplayEnabledKey: false,
            Self.searchE2ELoggingEnabledKey: true,
            Self.searchFTSVocabularyDiagnosticsEnabledKey: true,
            Self.urlSchemePlayFirstSearchResultEnabledKey: false,
            Self.aiChunkingEnabledKey: false,
            Self.aiChunkingTranslationLanguageKey: AIChunkingTranslationLanguage.defaultValue.rawValue,
            Self.aiChunkingPromptTemplateKey: AIChunkingPromptConfiguration.defaultTemplate
        ])
        self.cueGroupPresentation = CueGroupPresentationStore(
            isEnabled: userDefaults.bool(forKey: Self.showCueGroupKey),
            userDefaults: userDefaults,
            userDefaultsKey: Self.showCueGroupKey,
            uiProbeScope: uiProbeScope
        )
        Self.resetAIChunkingPromptTemplateForCurrentDefaultIfNeeded(userDefaults)

        let loadedAppearance = Self.loadAppAppearanceMode(from: userDefaults)
        self.appAppearanceMode = loadedAppearance
        self.primarySearchLanguage = Self.loadPrimarySearchLanguage(from: userDefaults)
        self.searchScope = Self.loadSearchScope(from: userDefaults)
        self.playbackDecodeMode = Self.loadPlaybackDecodeMode(from: userDefaults)
        self.autoPlayCueSequenceEnabled = userDefaults.bool(forKey: Self.autoPlayCueSequenceEnabledKey)
        self.autoPlayCueSequenceGapMilliseconds = Self.loadAutoPlayCueSequenceGapMilliseconds(from: userDefaults)
        self.playbackSpeakerDisplayEnabled = userDefaults.bool(forKey: Self.playbackSpeakerDisplayEnabledKey)
        self.searchE2ELoggingEnabled = userDefaults.bool(forKey: Self.searchE2ELoggingEnabledKey)
        self.searchFTSVocabularyDiagnosticsEnabled = userDefaults.bool(
            forKey: Self.searchFTSVocabularyDiagnosticsEnabledKey
        )
        self.searchFilterSets = Self.loadSearchFilterSets(from: userDefaults)
        self.urlSchemePlayFirstSearchResultEnabled = userDefaults.bool(
            forKey: Self.urlSchemePlayFirstSearchResultEnabledKey
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

    func setAutoPlayCueSequenceGapMilliseconds(_ milliseconds: Int) {
        autoPlayCueSequenceGapMilliseconds = Self.clampedAutoPlayCueSequenceGapMilliseconds(milliseconds)
        userDefaults.set(
            autoPlayCueSequenceGapMilliseconds,
            forKey: Self.autoPlayCueSequenceGapMillisecondsKey
        )
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

    private static func loadSearchScope(from userDefaults: UserDefaults) -> SearchScope {
        guard let rawValue = userDefaults.string(forKey: searchScopeKey),
              let scope = SearchScope(rawValue: rawValue)
        else {
            return .defaultValue
        }
        return scope
    }

    private static func loadPlaybackDecodeMode(from userDefaults: UserDefaults) -> PlaybackDecodeMode {
        guard let rawValue = userDefaults.string(forKey: playbackDecodeModeKey),
              let mode = PlaybackDecodeMode(rawValue: rawValue)
        else {
            return .auto
        }
        return mode
    }

    private static func loadAutoPlayCueSequenceGapMilliseconds(from userDefaults: UserDefaults) -> Int {
        clampedAutoPlayCueSequenceGapMilliseconds(
            userDefaults.integer(forKey: autoPlayCueSequenceGapMillisecondsKey)
        )
    }

    static func clampedAutoPlayCueSequenceGapMilliseconds(_ milliseconds: Int) -> Int {
        min(
            max(milliseconds, autoPlayCueSequenceGapMinimumMilliseconds),
            autoPlayCueSequenceGapMaximumMilliseconds
        )
    }

    private static func loadSearchFilterSets(from userDefaults: UserDefaults) -> [SchemaWorkbenchFilterSet] {
        guard let data = userDefaults.data(forKey: searchFilterSetsKey),
              let filterSets = try? JSONDecoder().decode([SchemaWorkbenchFilterSet].self, from: data)
        else {
            return []
        }

        return filterSets
    }

    private static func saveSearchFilterSets(
        _ filterSets: [SchemaWorkbenchFilterSet],
        to userDefaults: UserDefaults
    ) {
        guard let data = try? JSONEncoder().encode(filterSets) else {
            return
        }

        userDefaults.set(data, forKey: searchFilterSetsKey)
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
