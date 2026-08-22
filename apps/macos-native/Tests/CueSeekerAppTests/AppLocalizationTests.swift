import AppKit
import Combine
import Foundation
import Testing
@testable import CueSeekerApp

@Test
func eachLanguageResolvesItsOwnLocalizationBundle() {
    let expectedTitles: [AppLanguage: String] = [
        .english: "Language",
        .simplifiedChinese: "语言",
        .traditionalChinese: "語言"
    ]

    for (language, expectedTitle) in expectedTitles {
        let bundle = AppLocalization._bundleForTesting(language)
        #expect(
            bundle.localizedString(
                forKey: "settings.category.language",
                value: "",
                table: nil
            ) == expectedTitle
        )
    }
}

@Test
func followSystemResolvesToABundledLocalization() {
    let bundle = AppLocalization._bundleForTesting(.followSystem)
    let title = bundle.localizedString(
        forKey: "settings.category.language",
        value: "",
        table: nil
    )
    #expect(["Language", "语言", "語言"].contains(title))
}

@MainActor
@Test
func changingTheLanguagePublishesOnlyOnTheLocalizationStore() {
    withTemporaryLocalizationUserDefaults { userDefaults in
        let settings = SettingsStore(userDefaults: userDefaults)
        var settingsUpdates = 0
        var localizationUpdates = 0
        let settingsSubscription = settings.objectWillChange.sink { _ in
            settingsUpdates += 1
        }
        let localizationSubscription = settings.localization.objectWillChange.sink { _ in
            localizationUpdates += 1
        }

        settings.localization.set(.simplifiedChinese)

        // Only the localization store invalidates, so a language switch cannot
        // re-render every surface that observes SettingsStore.
        #expect(localizationUpdates == 1)
        #expect(settingsUpdates == 0)
        #expect(settings.localization.language == .simplifiedChinese)
        #expect(userDefaults.string(forKey: "appLanguage") == "zh-Hans")
        #expect(L("settings.category.language") == "语言")

        settings.localization.set(.followSystem)
        settingsSubscription.cancel()
        localizationSubscription.cancel()
    }
}

@MainActor
private func withTemporaryLocalizationUserDefaults(_ body: (UserDefaults) -> Void) {
    _ = NSApplication.shared
    let suiteName = "CueSeekerLocalizationTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}

@Test
func everyBundledLanguageDefinesTheSameKeys() {
    let english = localizableKeys(for: .english)

    #expect(!english.isEmpty)
    #expect(localizableKeys(for: .simplifiedChinese) == english)
    #expect(localizableKeys(for: .traditionalChinese) == english)
}

/// Reads the keys a language actually ships, so a translation that is added to
/// one language but forgotten in another fails the build instead of silently
/// falling back to the key name at runtime.
private func localizableKeys(for language: AppLanguage) -> Set<String> {
    let bundle = AppLocalization._bundleForTesting(language)
    guard let path = bundle.path(forResource: "Localizable", ofType: "strings"),
          let entries = NSDictionary(contentsOfFile: path) as? [String: String]
    else {
        return []
    }
    return Set(entries.keys)
}
