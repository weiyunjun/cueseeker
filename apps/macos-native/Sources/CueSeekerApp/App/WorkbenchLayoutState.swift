import Foundation
import SwiftUI

@MainActor
enum WorkbenchPanelMode: String, CaseIterable {
    case library
    case search
    case shiori
}

/// Temporary sandbox pages used to prototype the table-style UI without
/// polluting the production Library/Search/Shiori views. Reachable only via the
/// top-bar test icons; intentionally not persisted across launches.
@MainActor
enum WorkbenchTestPage: String, CaseIterable {
    case recentWatching
    case library
    case search
}

@MainActor
final class WorkbenchLayoutState: ObservableObject {
    private static let panelModeKey = "workbenchPanelMode"

    @Published var panelMode: WorkbenchPanelMode
    @Published fileprivate(set) var isVideoSizeTransitionInProgress = false
    @Published var isAppFullscreen = false
    @Published var isSearchFocused = false
    @Published var activeTestPage: WorkbenchTestPage?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        panelMode = WorkbenchPanelMode(
            rawValue: userDefaults.string(forKey: Self.panelModeKey) ?? ""
        ) ?? .search
    }

    func selectPanelMode(_ mode: WorkbenchPanelMode) {
        guard panelMode != mode else {
            return
        }

        panelMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.panelModeKey)
    }

    func toggleTestPage(_ page: WorkbenchTestPage) {
        activeTestPage = (activeTestPage == page) ? nil : page
    }

    func clearTestPage() {
        guard activeTestPage != nil else {
            return
        }

        activeTestPage = nil
    }

    func beginVideoSizeTransition() -> Bool {
        guard !isVideoSizeTransitionInProgress else {
            return false
        }

        isVideoSizeTransitionInProgress = true
        return true
    }

    func endVideoSizeTransition() {
        isVideoSizeTransitionInProgress = false
    }

    func clearSearchFocus() {
        guard isSearchFocused else {
            return
        }

        AppPerformanceProbe.measure("WorkbenchLayoutState.clearSearchFocus", thresholdMilliseconds: 4) {
            isSearchFocused = false
            NotificationCenter.default.post(name: .topbarSearchFocusClearRequested, object: nil)
        }
    }
}
