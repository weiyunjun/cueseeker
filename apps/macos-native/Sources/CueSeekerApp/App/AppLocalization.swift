import Foundation
import SwiftUI

/// The interface language the user selected in Settings.
///
/// `followSystem` resolves against the localizations that ship with the app and
/// falls back to English when the system preference matches none of them.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case followSystem
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    /// Concrete language names are written in their own language so they read
    /// the same regardless of the current interface language.
    var displayName: String {
        switch self {
        case .followSystem:
            L("settings.language.follow_system")
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        case .traditionalChinese:
            "繁體中文"
        }
    }
}

/// Resolves interface strings from the `.lproj` bundle for the selected
/// language.
///
/// `activeBundle` is only written from the main thread, from `SettingsStore`.
enum AppLocalization {
    static let availableLocalizations = ["en", "zh-Hans", "zh-Hant"]

    nonisolated(unsafe) private static var activeBundle = fallbackBundle
    nonisolated(unsafe) private static var activeLocalization = "en"

    static var bundle: Bundle {
        activeBundle
    }

    /// The interface language, for names the system localizes, such as
    /// language names.
    static var locale: Locale {
        Locale(identifier: activeLocalization)
    }

    static func apply(_ language: AppLanguage) {
        activeLocalization = resolvedLocalization(for: language)
        activeBundle = resolvedBundle(for: language)
    }

    private static var fallbackBundle: Bundle {
        bundle(forLocalization: "en") ?? .module
    }

    static func _bundleForTesting(_ language: AppLanguage) -> Bundle {
        resolvedBundle(for: language)
    }

    private static func resolvedBundle(for language: AppLanguage) -> Bundle {
        bundle(forLocalization: resolvedLocalization(for: language)) ?? fallbackBundle
    }

    private static func resolvedLocalization(for language: AppLanguage) -> String {
        switch language {
        case .followSystem:
            Bundle.preferredLocalizations(
                from: availableLocalizations
            ).first ?? "en"
        case .english, .simplifiedChinese, .traditionalChinese:
            language.rawValue
        }
    }

    /// SwiftPM lowercases `.lproj` directory names when it builds the resource
    /// bundle, so the on-disk name is matched case-insensitively against the
    /// canonical BCP-47 identifier.
    private static func bundle(forLocalization localization: String) -> Bundle? {
        guard let resourceName = Bundle.module.localizations.first(where: {
            $0.caseInsensitiveCompare(localization) == .orderedSame
        }),
        let path = Bundle.module.path(forResource: resourceName, ofType: "lproj")
        else {
            return nil
        }
        return Bundle(path: path)
    }
}

/// Publishes interface-language changes to the views that render localized
/// text.
///
/// Only views that observe this store are invalidated when the language
/// changes, so a language switch does not re-render unrelated surfaces and does
/// not rebuild the interface.
@MainActor
final class AppLocalizationStore: ObservableObject {
    @Published private(set) var language: AppLanguage

    private let userDefaults: UserDefaults
    private let userDefaultsKey: String

    init(
        language: AppLanguage,
        userDefaults: UserDefaults,
        userDefaultsKey: String
    ) {
        self.language = language
        self.userDefaults = userDefaults
        self.userDefaultsKey = userDefaultsKey
        AppLocalization.apply(language)
    }

    func set(_ language: AppLanguage) {
        guard self.language != language else {
            return
        }
        // Resolve the new bundle before publishing so every view that re-renders
        // reads the new language.
        AppLocalization.apply(language)
        self.language = language
        userDefaults.set(language.rawValue, forKey: userDefaultsKey)
        // The menu bar is built with AppKit and does not participate in SwiftUI
        // invalidation, so it is rebuilt explicitly.
        NotificationCenter.default.post(
            name: .cueSeekerAppLanguageChanged,
            object: nil
        )
    }
}

/// Looks up an interface string for the current language.
func L(_ key: String) -> String {
    AppLocalization.bundle.localizedString(forKey: key, value: key, table: nil)
}

/// Looks up an interface string and fills in its format arguments.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}
