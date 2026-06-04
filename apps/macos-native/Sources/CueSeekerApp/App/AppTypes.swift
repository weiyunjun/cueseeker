import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

enum IndexingStatus: Equatable {
    case idle
    case indexing(URL)
    case indexingAll(currentFolder: URL, completedFolders: Int, totalFolders: Int)
    case completed(URL, SubtitleIndexingResult)
    case completedAll(folderCount: Int, SubtitleIndexingResult)
    case failed(URL, String)

    var isIndexing: Bool {
        switch self {
        case .indexing, .indexingAll:
            return true
        case .idle, .completed, .completedAll, .failed:
            return false
        }
    }
}

enum SearchStatus: Equatable {
    case idle
    case searching
    case completed
    case failed(String)
}

enum SearchResultPresentationState: Equatable {
    case initial
    case collapsed
}

enum LibraryStatus: Equatable {
    case idle
    case loading
    case completed
    case failed(String)
}

enum DatabaseMaintenanceStatus: Equatable {
    case idle
    case loadingStats
    case compacting
    case completed(String)
    case failed(String)

    var isCompacting: Bool {
        if case .compacting = self {
            return true
        }

        return false
    }
}

enum SearchFTSVocabularyDiagnosticsStatus: Equatable {
    case idle
    case loading
    case completed(Date)
    case failed(String)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}

enum PlaybackStatus: Equatable {
    case idle
    case opening
    case playing
    case paused
    case failed(String)

    var isOpening: Bool {
        if case .opening = self {
            return true
        }

        return false
    }
}

enum ActivePlaybackSource: Equatable {
    case none
    case library(videoPath: String)
    case search
    case shiori
}

enum SearchResultNavigationDirection: Equatable {
    case previous
    case next
}

enum PlaybackDrawerKind: Equatable {
    case results
    case subtitles
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case auto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light:
            "Light"
        case .dark:
            "Dark"
        case .auto:
            "Auto"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        case .auto:
            nil
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        case .auto:
            nil
        }
    }
}

enum PrimarySearchLanguage: String, CaseIterable, Identifiable, Sendable {
    case all
    case japanese = "ja"
    case english = "en"
    case chinese = "zh"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    static let defaultValue: Self = .all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            "All"
        case .japanese:
            "日本語"
        case .english:
            "English"
        case .chinese:
            "中文"
        case .simplifiedChinese:
            "简体中文"
        case .traditionalChinese:
            "繁体中文"
        }
    }

    var searchLanguageFilter: SubtitleSearchLanguageFilter {
        switch self {
        case .all:
            .all
        case .japanese:
            .japanese
        case .english:
            .english
        case .chinese:
            .chinese
        case .simplifiedChinese:
            .simplifiedChinese
        case .traditionalChinese:
            .traditionalChinese
        }
    }
}

struct SearchResultFileGroup: Identifiable, Equatable {
    let subtitlePath: String
    let subtitleDisplayTitle: String
    let totalCount: Int
    let results: [SubtitleSearchResult]
    let isCollapsed: Bool

    var id: String { subtitlePath }

    var displayCount: String {
        totalCount > 99 ? "99+" : "\(totalCount)"
    }
}

struct ShioriFileGroup: Identifiable, Equatable {
    let subtitlePath: String
    let subtitleDisplayTitle: String
    let shioris: [Shiori]
    let isCollapsed: Bool

    var id: String { subtitlePath }
    var totalCount: Int { shioris.count }
}

struct LibraryVideoRow: Identifiable {
    let video: LibraryVideo
    let displayTitle: String
    let fileExtension: String
    let duration: Double?

    var id: String {
        video.videoPath
    }
}

struct LibraryFolderGroup: Identifiable {
    let folderPath: String
    let folderTitle: String
    let videos: [LibraryVideoRow]

    var id: String {
        folderPath
    }
}
