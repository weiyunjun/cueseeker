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

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        userDefaults.register(defaults: [
            Self.appAppearanceModeKey: AppAppearanceMode.auto.rawValue,
            Self.playbackDecodeModeKey: PlaybackDecodeMode.auto.rawValue,
            Self.searchE2ELoggingEnabledKey: true,
            Self.searchFTSVocabularyDiagnosticsEnabledKey: true
        ])

        let loadedAppearance = Self.loadAppAppearanceMode(from: userDefaults)
        self.appAppearanceMode = loadedAppearance
        self.playbackDecodeMode = Self.loadPlaybackDecodeMode(from: userDefaults)
        self.searchE2ELoggingEnabled = userDefaults.bool(forKey: Self.searchE2ELoggingEnabledKey)
        self.searchFTSVocabularyDiagnosticsEnabled = userDefaults.bool(
            forKey: Self.searchFTSVocabularyDiagnosticsEnabledKey
        )

        Self.applyAppAppearanceMode(loadedAppearance)
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
}
