import Foundation
import Testing
@testable import CueSeekerApp

@Test
func defaultAIChunkingPromptTemplateRendersSimplifiedChinesePrompt() throws {
    let prompt = try AIChunkingPromptConfiguration.defaultConfiguration.renderedPrompt(
        for: "運も実力のうちだ"
    )

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
