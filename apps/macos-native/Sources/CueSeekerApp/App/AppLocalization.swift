import Foundation

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

    static var bundle: Bundle {
        activeBundle
    }

    static func apply(_ language: AppLanguage) {
        activeBundle = resolvedBundle(for: language)
    }

    private static var fallbackBundle: Bundle {
        bundle(forLocalization: "en") ?? .module
    }

    static func _bundleForTesting(_ language: AppLanguage) -> Bundle {
        resolvedBundle(for: language)
    }

    private static func resolvedBundle(for language: AppLanguage) -> Bundle {
        let localization: String
        switch language {
        case .followSystem:
            localization = Bundle.preferredLocalizations(
                from: availableLocalizations
            ).first ?? "en"
        case .english, .simplifiedChinese, .traditionalChinese:
            localization = language.rawValue
        }
        return bundle(forLocalization: localization) ?? fallbackBundle
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

/// Looks up an interface string for the current language.
func L(_ key: String) -> String {
    AppLocalization.bundle.localizedString(forKey: key, value: key, table: nil)
}

/// Looks up an interface string and fills in its format arguments.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}
