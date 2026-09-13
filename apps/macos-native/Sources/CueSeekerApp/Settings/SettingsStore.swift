import AppKit
import Foundation
import SwiftUI
import CueSeekerCore
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
    private static let appLanguageKey = "appLanguage"
    private static let searchFacetExclusionsKey = "searchFacetExclusions"
    private static let excerptFacetExclusionsKey = "excerptFacetExclusionsByListID"
    private static let recentExcerptSaveListKey = "recentExcerptSaveListID"
    private static let ankiExportCueTextSideKey = "ankiExportCueTextSide"
    private static let ankiExportOptionalItemsKey = "ankiExportOptionalItems"
    private static let ankiExportFolderPathKey = "ankiExportFolderPath"
    private static let showCueGroupKey = "showCueGroup"
    private static let prefillCommandPanelWithFocusedCueKey =
        "prefillCommandPanelWithFocusedCue"
    private static let playbackDecodeModeKey = "playbackDecodeMode"
    private static let legacyAutoPlayCueSequenceEnabledKey = "autoPlayCueSequenceEnabled"
    private static let legacyOnlyPlayCuesInPlaylistEnabledKey = "onlyPlayCuesInPlaylistEnabled"
    private static let legacyAutoStopAfterCueFinishesEnabledKey = "autoStopAfterCueFinishesEnabled"
    private static let autoPauseAfterCueFinishesEnabledKey = "autoPauseAfterCueFinishesEnabled"
    private static let autoSwitchToNextCuesInPlaylistEnabledKey = "autoSwitchToNextCuesInPlaylistEnabled"
    private static let autoPlayCueSequenceGapMillisecondsKey = "autoPlayCueSequenceGapMilliseconds"
    private static let searchE2ELoggingEnabledKey = "searchE2ELoggingEnabled"
    private static let searchFTSVocabularyDiagnosticsEnabledKey = "searchFTSVocabularyDiagnosticsEnabled"
    private static let urlSchemePlayFirstSearchResultEnabledKey = "urlSchemePlayFirstSearchResultEnabled"
    private static let srtSubtitleStyleKey = "srtSubtitleStyle"
    static let autoSwitchCueSequenceGapDefaultMilliseconds = 500
    static let autoSwitchCueSequenceGapMinimumMilliseconds = 0
    static let autoSwitchCueSequenceGapMaximumMilliseconds = 10_000

    @Published var appAppearanceMode: AppAppearanceMode {
        didSet {
            userDefaults.set(appAppearanceMode.rawValue, forKey: Self.appAppearanceModeKey)
            Self.applyAppAppearanceMode(appAppearanceMode)
        }
    }

    var searchFacetFilter: CueFacetFilter {
        didSet {
            Self.saveSearchFacetFilter(searchFacetFilter, to: userDefaults)
        }
    }

    let cueGroupPresentation: CueGroupPresentationStore

    let localization: AppLocalizationStore

    let playbackShortcuts: PlaybackShortcutStore

    var showCueGroup: Bool {
        get { cueGroupPresentation.isEnabled }
        set { cueGroupPresentation.set(newValue) }
    }

    @Published var prefillCommandPanelWithFocusedCue: Bool {
        didSet {
            userDefaults.set(
                prefillCommandPanelWithFocusedCue,
                forKey: Self.prefillCommandPanelWithFocusedCueKey
            )
        }
    }

    @Published var playbackDecodeMode: PlaybackDecodeMode {
        didSet {
            userDefaults.set(playbackDecodeMode.rawValue, forKey: Self.playbackDecodeModeKey)
        }
    }

    @Published var autoPauseAfterCueFinishesEnabled: Bool {
        didSet {
            if !autoPauseAfterCueFinishesEnabled,
               autoSwitchToNextCuesInPlaylistEnabled {
                autoSwitchToNextCuesInPlaylistEnabled = false
            }
            userDefaults.set(
                autoPauseAfterCueFinishesEnabled,
                forKey: Self.autoPauseAfterCueFinishesEnabledKey
            )
        }
    }

    @Published var autoSwitchToNextCuesInPlaylistEnabled: Bool {
        didSet {
            if autoSwitchToNextCuesInPlaylistEnabled,
               !autoPauseAfterCueFinishesEnabled {
                autoSwitchToNextCuesInPlaylistEnabled = false
            }
            userDefaults.set(
                autoSwitchToNextCuesInPlaylistEnabled,
                forKey: Self.autoSwitchToNextCuesInPlaylistEnabledKey
            )
        }
    }

    @Published private(set) var autoSwitchCueSequenceGapMilliseconds: Int

    @Published var srtSubtitleStyle: SRTSubtitleStyle {
        didSet {
            userDefaults.set(
                try? JSONEncoder().encode(srtSubtitleStyle),
                forKey: Self.srtSubtitleStyleKey
            )
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

    @Published var urlSchemePlayFirstSearchResultEnabled: Bool {
        didSet {
            userDefaults.set(
                urlSchemePlayFirstSearchResultEnabled,
                forKey: Self.urlSchemePlayFirstSearchResultEnabledKey
            )
        }
    }

    private let userDefaults: UserDefaults

    init(
        userDefaults: UserDefaults,
        uiProbeScope: String = UUID().uuidString
    ) {
        self.userDefaults = userDefaults
        let hasStoredAutoPausePreference = userDefaults.object(
            forKey: Self.autoPauseAfterCueFinishesEnabledKey
        ) != nil
        let hasLegacyAutoStopPreference = userDefaults.object(
            forKey: Self.legacyAutoStopAfterCueFinishesEnabledKey
        ) != nil
        let hasLegacyOnlyPlayCuesPreference = userDefaults.object(
            forKey: Self.legacyOnlyPlayCuesInPlaylistEnabledKey
        ) != nil
        let hasStoredAutoSwitchPreference = userDefaults.object(
            forKey: Self.autoSwitchToNextCuesInPlaylistEnabledKey
        ) != nil
        let hasLegacyAutoSwitchPreference = userDefaults.object(
            forKey: Self.legacyAutoPlayCueSequenceEnabledKey
        ) != nil
        let legacyAutoSwitchWasEnabled = hasLegacyAutoSwitchPreference
            && userDefaults.bool(forKey: Self.legacyAutoPlayCueSequenceEnabledKey)
        let resolvedAutoPausePreference: Bool
        if hasStoredAutoPausePreference {
            resolvedAutoPausePreference = userDefaults.bool(
                forKey: Self.autoPauseAfterCueFinishesEnabledKey
            )
        } else if hasLegacyAutoStopPreference {
            resolvedAutoPausePreference = userDefaults.bool(
                forKey: Self.legacyAutoStopAfterCueFinishesEnabledKey
            )
        } else if hasLegacyOnlyPlayCuesPreference {
            resolvedAutoPausePreference = userDefaults.bool(
                forKey: Self.legacyOnlyPlayCuesInPlaylistEnabledKey
            )
        } else {
            resolvedAutoPausePreference = true
        }
        let requestedAutoSwitchPreference = legacyAutoSwitchWasEnabled
            || (hasStoredAutoSwitchPreference
                && userDefaults.bool(forKey: Self.autoSwitchToNextCuesInPlaylistEnabledKey))
        let resolvedAutoSwitchPreference = resolvedAutoPausePreference
            && requestedAutoSwitchPreference
        userDefaults.register(defaults: [
            Self.appAppearanceModeKey: AppAppearanceMode.auto.rawValue,
            Self.appLanguageKey: AppLanguage.followSystem.rawValue,
            Self.showCueGroupKey: false,
            Self.prefillCommandPanelWithFocusedCueKey: false,
            Self.playbackDecodeModeKey: PlaybackDecodeMode.auto.rawValue,
            Self.autoPlayCueSequenceGapMillisecondsKey: Self.autoSwitchCueSequenceGapDefaultMilliseconds,
            Self.searchE2ELoggingEnabledKey: true,
            Self.searchFTSVocabularyDiagnosticsEnabledKey: true,
            Self.urlSchemePlayFirstSearchResultEnabledKey: false
        ])
        self.cueGroupPresentation = CueGroupPresentationStore(
            isEnabled: userDefaults.bool(forKey: Self.showCueGroupKey),
            userDefaults: userDefaults,
            userDefaultsKey: Self.showCueGroupKey,
            uiProbeScope: uiProbeScope
        )
        self.localization = AppLocalizationStore(
            language: Self.loadAppLanguage(from: userDefaults),
            userDefaults: userDefaults,
            userDefaultsKey: Self.appLanguageKey
        )
        self.playbackShortcuts = PlaybackShortcutStore(userDefaults: userDefaults)
        let loadedAppearance = Self.loadAppAppearanceMode(from: userDefaults)
        self.appAppearanceMode = loadedAppearance
        self.searchFacetFilter = Self.loadSearchFacetFilter(from: userDefaults)
        self.prefillCommandPanelWithFocusedCue = userDefaults.bool(
            forKey: Self.prefillCommandPanelWithFocusedCueKey
        )
        self.playbackDecodeMode = Self.loadPlaybackDecodeMode(from: userDefaults)
        self.autoPauseAfterCueFinishesEnabled = resolvedAutoPausePreference
        self.autoSwitchToNextCuesInPlaylistEnabled = resolvedAutoSwitchPreference
        self.autoSwitchCueSequenceGapMilliseconds = Self.loadAutoSwitchCueSequenceGapMilliseconds(
            from: userDefaults
        )
        self.srtSubtitleStyle = userDefaults.data(forKey: Self.srtSubtitleStyleKey)
            .flatMap { try? JSONDecoder().decode(SRTSubtitleStyle.self, from: $0) }
            ?? SRTSubtitleStyle()
        self.searchE2ELoggingEnabled = userDefaults.bool(forKey: Self.searchE2ELoggingEnabledKey)
        self.searchFTSVocabularyDiagnosticsEnabled = userDefaults.bool(
            forKey: Self.searchFTSVocabularyDiagnosticsEnabledKey
        )
        self.urlSchemePlayFirstSearchResultEnabled = userDefaults.bool(
            forKey: Self.urlSchemePlayFirstSearchResultEnabledKey
        )
        userDefaults.set(
            resolvedAutoPausePreference,
            forKey: Self.autoPauseAfterCueFinishesEnabledKey
        )
        userDefaults.set(
            resolvedAutoSwitchPreference,
            forKey: Self.autoSwitchToNextCuesInPlaylistEnabledKey
        )
        if hasLegacyAutoSwitchPreference {
            userDefaults.removeObject(forKey: Self.legacyAutoPlayCueSequenceEnabledKey)
        }
        if hasLegacyOnlyPlayCuesPreference {
            userDefaults.removeObject(forKey: Self.legacyOnlyPlayCuesInPlaylistEnabledKey)
        }
        if hasLegacyAutoStopPreference {
            userDefaults.removeObject(forKey: Self.legacyAutoStopAfterCueFinishesEnabledKey)
        }

        Self.applyAppAppearanceMode(loadedAppearance)
    }

    func setAutoSwitchCueSequenceGapMilliseconds(_ milliseconds: Int) {
        autoSwitchCueSequenceGapMilliseconds = Self.clampedAutoSwitchCueSequenceGapMilliseconds(milliseconds)
        userDefaults.set(
            autoSwitchCueSequenceGapMilliseconds,
            forKey: Self.autoPlayCueSequenceGapMillisecondsKey
        )
    }

    func excerptFacetFilter(forListID listID: Int64) -> CueFacetFilter {
        let exclusionsByListID = userDefaults.dictionary(
            forKey: Self.excerptFacetExclusionsKey
        ) ?? [:]
        guard let exclusions = exclusionsByListID[String(listID)]
                as? [String: Any]
        else {
            return CueFacetFilter()
        }
        return Self.loadFacetFilter(exclusions: exclusions)
    }

    /// The list the last successful `Save to Excerpt` went to. Kept across
    /// launches so the destination menu opens on it again.
    var recentExcerptSaveListID: Int64? {
        (userDefaults.object(forKey: Self.recentExcerptSaveListKey) as? Int)
            .map(Int64.init)
    }

    func setRecentExcerptSaveListID(_ listID: Int64?) {
        guard let listID else {
            userDefaults.removeObject(forKey: Self.recentExcerptSaveListKey)
            return
        }
        userDefaults.set(Int(listID), forKey: Self.recentExcerptSaveListKey)
    }

    /// The Export to Anki dialog's Cue Text Side and Optional checkboxes, as
    /// the reader last left them. Search and Excerpt share them.
    var ankiExportOptions: AnkiExportOptions {
        get {
            var options = AnkiExportOptions()
            if let side = userDefaults.string(forKey: Self.ankiExportCueTextSideKey)
                .flatMap(AnkiExportCueTextSide.init(rawValue:)) {
                options.cueTextSide = side
            }
            if let items = userDefaults.stringArray(forKey: Self.ankiExportOptionalItemsKey) {
                options.optionalItems = Set(items.compactMap(AnkiExportOptionalItem.init(rawValue:)))
            }
            return options
        }
        set {
            userDefaults.set(newValue.cueTextSide.rawValue, forKey: Self.ankiExportCueTextSideKey)
            userDefaults.set(
                AnkiExportOptionalItem.allCases.filter(newValue.includes).map(\.rawValue),
                forKey: Self.ankiExportOptionalItemsKey
            )
        }
    }

    /// The folder the Export to Anki dialog's Location was last set to.
    var ankiExportFolderPath: String? {
        get { userDefaults.string(forKey: Self.ankiExportFolderPathKey) }
        set { userDefaults.set(newValue, forKey: Self.ankiExportFolderPathKey) }
    }

    func setExcerptFacetFilter(
        _ filter: CueFacetFilter,
        forListID listID: Int64
    ) {
        var exclusionsByListID = userDefaults.dictionary(
            forKey: Self.excerptFacetExclusionsKey
        ) ?? [:]
        exclusionsByListID[String(listID)] = Self.facetExclusions(for: filter)
        userDefaults.set(
            exclusionsByListID,
            forKey: Self.excerptFacetExclusionsKey
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

    private static func loadAppLanguage(from userDefaults: UserDefaults) -> AppLanguage {
        guard let rawValue = userDefaults.string(forKey: appLanguageKey),
              let language = AppLanguage(rawValue: rawValue)
        else {
            return .followSystem
        }
        return language
    }

    private static func loadSearchFacetFilter(from userDefaults: UserDefaults) -> CueFacetFilter {
        guard let exclusions = userDefaults.dictionary(
            forKey: searchFacetExclusionsKey
        ) else {
            return CueFacetFilter()
        }
        return loadFacetFilter(exclusions: exclusions)
    }

    private static func loadFacetFilter(
        exclusions: [String: Any]
    ) -> CueFacetFilter {
        let durations = Set(CueDurationFacet.allCases).subtracting(
            rawValues(for: "duration", in: exclusions).compactMap(CueDurationFacet.init(rawValue:))
        )
        let characters = Set(CueCharacterFacet.allCases).subtracting(
            rawValues(for: "character", in: exclusions).compactMap(CueCharacterFacet.init(rawValue:))
        )
        let languages = Set(SubtitleLanguageCode.allCases).subtracting(
            rawValues(for: "language", in: exclusions).compactMap(SubtitleLanguageCode.init(rawValue:))
        )
        let allWatchStates: Set<LibraryWatchState> = [.finished, .watching, .unwatched]
        let watchStates = allWatchStates.subtracting(
            rawValues(for: "watchState", in: exclusions).compactMap(LibraryWatchState.init(rawValue:))
        )
        return CueFacetFilter(
            durations: durations,
            characters: characters,
            languages: languages,
            watchStates: watchStates
        )
    }

    private static func saveSearchFacetFilter(
        _ filter: CueFacetFilter,
        to userDefaults: UserDefaults
    ) {
        userDefaults.set(
            facetExclusions(for: filter),
            forKey: searchFacetExclusionsKey
        )
    }

    private static func facetExclusions(
        for filter: CueFacetFilter
    ) -> [String: [String]] {
        let allWatchStates: Set<LibraryWatchState> = [.finished, .watching, .unwatched]
        return [
            "duration": Set(CueDurationFacet.allCases)
                .subtracting(filter.durations)
                .map(\.rawValue)
                .sorted(),
            "character": Set(CueCharacterFacet.allCases)
                .subtracting(filter.characters)
                .map(\.rawValue)
                .sorted(),
            "language": Set(SubtitleLanguageCode.allCases)
                .subtracting(filter.languages)
                .map(\.rawValue)
                .sorted(),
            "watchState": allWatchStates
                .subtracting(filter.watchStates)
                .map(\.rawValue)
                .sorted(),
        ]
    }

    private static func rawValues(
        for key: String,
        in dictionary: [String: Any]
    ) -> [String] {
        dictionary[key] as? [String] ?? []
    }

    private static func loadPlaybackDecodeMode(from userDefaults: UserDefaults) -> PlaybackDecodeMode {
        guard let rawValue = userDefaults.string(forKey: playbackDecodeModeKey),
              let mode = PlaybackDecodeMode(rawValue: rawValue)
        else {
            return .auto
        }
        return mode
    }

    private static func loadAutoSwitchCueSequenceGapMilliseconds(from userDefaults: UserDefaults) -> Int {
        clampedAutoSwitchCueSequenceGapMilliseconds(
            userDefaults.integer(forKey: autoPlayCueSequenceGapMillisecondsKey)
        )
    }

    static func clampedAutoSwitchCueSequenceGapMilliseconds(_ milliseconds: Int) -> Int {
        min(
            max(milliseconds, autoSwitchCueSequenceGapMinimumMilliseconds),
            autoSwitchCueSequenceGapMaximumMilliseconds
        )
    }

    private static func applyAppAppearanceMode(_ mode: AppAppearanceMode) {
        NSApp.appearance = mode.nsAppearance
    }

}
