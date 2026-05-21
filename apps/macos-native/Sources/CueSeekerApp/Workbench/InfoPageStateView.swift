import SwiftUI

/// Single shared owner of the info-page non-steady states (rewrite-plan
/// Phase 5, step P5.1, owner option (a)).
///
/// This centralizes the App-condition → state copy/mapping for the Search /
/// Library / Shiori surfaces so the text is defined in one place (doc 12
/// §6.1 / §7.1 / §8). The visual is intentionally unchanged: it renders the
/// existing `EmptyStateView`. The demo-aligned, native-leaning state-view
/// visual is deferred to a later visual pass per the proposal "P5.0 C2"
/// owner scope ruling. Callers keep their own surrounding `.font` / `.frame`
/// / loading-spinner overlay exactly as before, so layout and the
/// architecture §7 invalidation behavior are unchanged.
///
/// Settings is out of Phase 5 scope and keeps its own `EmptyStateView` usage.
enum InfoPageState: Equatable {
    case searchNoQuery
    case searching
    case searchFailed(String)
    case searchNoResults
    case libraryNoLibrary
    case libraryLoading
    case libraryFailed(String)
    case libraryNoVideos
    case shioriEmpty

    /// Verbatim from the prior `SearchView.swift` call sites.
    var title: String {
        switch self {
        case .searchNoQuery: return "No Search Query"
        case .searching: return "Searching"
        case .searchFailed: return "Search Failed"
        case .searchNoResults: return "No Results"
        case .libraryNoLibrary: return "No Library"
        case .libraryLoading: return "Loading Library"
        case .libraryFailed: return "Library Failed"
        case .libraryNoVideos: return "No Videos"
        case .shioriEmpty: return "No Shiori"
        }
    }

    var systemImage: String {
        switch self {
        case .searchNoQuery: return "text.magnifyingglass"
        case .searching: return "magnifyingglass"
        case .searchFailed, .libraryFailed: return "exclamationmark.triangle"
        case .searchNoResults: return "tray"
        case .libraryNoLibrary, .libraryLoading: return "folder"
        case .libraryNoVideos: return "play.rectangle"
        case .shioriEmpty: return "bookmark"
        }
    }

    var message: String {
        switch self {
        case .searchNoQuery:
            return "Type a query in the topbar Search field and press Return."
        case .searching:
            return "Looking through indexed subtitle text."
        case .searchFailed(let message):
            return message
        case .searchNoResults:
            return "No indexed subtitle entries matched this query."
        case .libraryNoLibrary:
            return "Add subtitle folders in CueSeeker > Settings..., then reindex."
        case .libraryLoading:
            return "Reading indexed videos."
        case .libraryFailed(let message):
            return message
        case .libraryNoVideos:
            return "Reindex subtitle folders to populate Library videos."
        case .shioriEmpty:
            return "Save subtitles from playback to collect Shiori."
        }
    }

    /// The App shows a loading spinner over these states. Spinner placement
    /// stays at the call site (layout unchanged in P5.1); this flag documents
    /// the mapping so the later visual pass has a single source.
    var showsLoadingSpinner: Bool {
        switch self {
        case .searching, .libraryLoading: return true
        default: return false
        }
    }
}

struct InfoPageStateView: View {
    let state: InfoPageState

    var body: some View {
        EmptyStateView(
            title: state.title,
            systemImage: state.systemImage,
            message: state.message
        )
    }
}
