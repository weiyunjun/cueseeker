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
