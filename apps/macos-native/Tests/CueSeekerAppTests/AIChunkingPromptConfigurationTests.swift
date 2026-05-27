import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@Test
func defaultAIChunkingPromptTemplateRendersSimplifiedChinesePrompt() throws {
    let prompt = try AIChunkingPromptConfiguration.defaultConfiguration.renderedPrompt(
        for: "運も実力のうちだ"
    )

    #expect(prompt.contains("你是日语学习检索分词器"))
    #expect(prompt.contains("\"plans\""))
    #expect(prompt.contains("\"items\""))
    #expect(prompt.contains("简体中文翻译"))
    #expect(prompt.contains("句子：運も実力のうちだ"))
    #expect(!prompt.contains(AIChunkingPromptConfiguration.sentencePlaceholder))
    #expect(!prompt.contains(AIChunkingPromptConfiguration.languagePlaceholder))
}

@Test
func aiChunkingPromptTemplateRendersConfiguredLanguageEverywhere() throws {
    let configuration = AIChunkingPromptConfiguration(
        template: "{{language}}: {{sentence}} -> {{language}}",
        translationLanguage: .japanese
    )

    let prompt = try configuration.renderedPrompt(for: "運も実力のうちだ")

    #expect(prompt == "日本語: 運も実力のうちだ -> 日本語")
}

@Test
func aiChunkingPromptCacheVersionFollowsLanguageButIgnoresTemplate() {
    let baseVersion = DeepSeekChunkingClient.promptVersion
    let simplifiedChinese = AIChunkingPromptConfiguration(
        template: "{{sentence}} -> {{language}}",
        translationLanguage: .simplifiedChinese
    )
    let japanese = AIChunkingPromptConfiguration(
        template: "{{sentence}} -> {{language}}",
        translationLanguage: .japanese
    )
    let expandedTemplate = AIChunkingPromptConfiguration(
        template: "Translate {{sentence}} into {{language}}.",
        translationLanguage: .simplifiedChinese
    )

    let simplifiedChineseVersion = simplifiedChinese.cachePromptVersion(baseVersion: baseVersion)

    #expect(DeepSeekChunkingClient.promptVersion == "chunk-v2")
    #expect(simplifiedChineseVersion == "chunk-v2-lang-zh-hans")
    #expect(japanese.cachePromptVersion(baseVersion: baseVersion) == "chunk-v2-lang-ja")
    #expect(simplifiedChineseVersion != japanese.cachePromptVersion(baseVersion: baseVersion))
    #expect(simplifiedChineseVersion == expandedTemplate.cachePromptVersion(baseVersion: baseVersion))
}

@Test
func aiChunkingPromptTemplateRequiresSentenceAndLanguagePlaceholders() {
    expectAIChunkingPromptTemplateError(
        try AIChunkingPromptConfiguration.validateTemplate("Only {{sentence}}"),
        equals: .missingRequiredPlaceholder(AIChunkingPromptConfiguration.languagePlaceholder)
    )
    expectAIChunkingPromptTemplateError(
        try AIChunkingPromptConfiguration.validateTemplate("Only {{language}}"),
        equals: .missingRequiredPlaceholder(AIChunkingPromptConfiguration.sentencePlaceholder)
    )
}

@Test
func aiChunkingPromptTemplateRejectsUnsupportedPlaceholders() {
    expectAIChunkingPromptTemplateError(
        try AIChunkingPromptConfiguration.validateTemplate("{{sentence}} {{language}} {{tone}}"),
        equals: .unsupportedPlaceholder("{{tone}}")
    )
    expectAIChunkingPromptTemplateError(
        try AIChunkingPromptConfiguration.validateTemplate("{{sentence}} {{language}} {{tone}"),
        equals: .unsupportedPlaceholder("{{tone}")
    )
}

@MainActor
@Test
func settingsStorePersistsAIChunkingLanguageAndPromptTemplate() throws {
    try withTemporarySettingsUserDefaults { userDefaults, service in
        let template = "Translate {{sentence}} into {{language}}."
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(store.aiChunkingTranslationLanguage == .simplifiedChinese)
        #expect(store.aiChunkingPromptTemplate == AIChunkingPromptConfiguration.defaultTemplate)

        store.aiChunkingTranslationLanguage = .japanese
        try store.saveAIChunkingPromptTemplate(template)

        let reloadedStore = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(reloadedStore.aiChunkingTranslationLanguage == .japanese)
        #expect(reloadedStore.aiChunkingPromptTemplate == template)
        #expect(try reloadedStore.aiChunkingPromptConfiguration.renderedPrompt(for: "雨") == "Translate 雨 into 日本語.")
    }
}

@MainActor
@Test
func settingsStoreForcesLegacyAIChunkingPromptTemplateToCurrentDefaultOnce() throws {
    try withTemporarySettingsUserDefaults { userDefaults, service in
        let legacyTemplate = "Legacy {{sentence}} -> {{language}}"
        userDefaults.set(legacyTemplate, forKey: "aiChunkingPromptTemplate")

        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(store.aiChunkingPromptTemplate == AIChunkingPromptConfiguration.defaultTemplate)

        let customTemplate = "Custom {{sentence}} -> {{language}}"
        try store.saveAIChunkingPromptTemplate(customTemplate)

        let reloadedStore = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(reloadedStore.aiChunkingPromptTemplate == customTemplate)
    }
}

@MainActor
@Test
func settingsStoreRejectsInvalidAIChunkingPromptTemplateWithoutChangingCurrentTemplate() throws {
    try withTemporarySettingsUserDefaults { userDefaults, service in
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )
        let validTemplate = "{{sentence}} -> {{language}}"
        try store.saveAIChunkingPromptTemplate(validTemplate)

        expectAIChunkingPromptTemplateError(
            try store.saveAIChunkingPromptTemplate("{{sentence}} -> {{tone}}"),
            equals: .unsupportedPlaceholder("{{tone}}")
        )

        #expect(store.aiChunkingPromptTemplate == validTemplate)
    }
}

@MainActor
@Test
func aiChunkingCacheClearRunsOnceForPromptAwareCacheMigration() throws {
    try withTemporarySettingsUserDefaults { userDefaults, _ in
        let databaseURL = temporarySettingsDatabaseURL()
        defer {
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
            try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
        }

        let database = try SubtitleDatabase(path: databaseURL)
        try database.migrate()
        let key = AIChunkCacheKey(
            normalizedSentence: "運も実力のうちだ",
            provider: "deepseek",
            model: "deepseek-v4-flash",
            promptVersion: "chunk-v1"
        )

        try database.upsertAIChunkCacheEntry(
            key: key,
            chunks: [AIChunkItem(item: "運", translation: "运")]
        )
        try AppCoordinator.clearAIChunkCacheForPromptAwareSettingsIfNeeded(
            database: database,
            userDefaults: userDefaults
        )

        #expect(try database.aiChunkCacheEntry(for: key) == nil)
        #expect(userDefaults.bool(forKey: AppCoordinator.aiChunkingPromptAwareCacheClearKey))

        try database.upsertAIChunkCacheEntry(
            key: key,
            chunks: [AIChunkItem(item: "実力", translation: "实力")]
        )
        try AppCoordinator.clearAIChunkCacheForPromptAwareSettingsIfNeeded(
            database: database,
            userDefaults: userDefaults
        )

        #expect(try database.aiChunkCacheEntry(for: key)?.chunks == [
            AIChunkItem(item: "実力", translation: "实力")
        ])
    }
}

private func expectAIChunkingPromptTemplateError(
    _ expression: @autoclosure () throws -> Void,
    equals expectedError: AIChunkingPromptTemplateError,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        try expression()
        Issue.record("Expected AIChunkingPromptTemplateError.", sourceLocation: sourceLocation)
    } catch let error as AIChunkingPromptTemplateError {
        #expect(error == expectedError, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Expected AIChunkingPromptTemplateError, got \(error).", sourceLocation: sourceLocation)
    }
}

private func withTemporarySettingsUserDefaults(_ body: (UserDefaults, String) throws -> Void) rethrows {
    let suiteName = "CueSeekerAppTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    try body(userDefaults, suiteName)
}

private func temporarySettingsDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerAppTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
}
