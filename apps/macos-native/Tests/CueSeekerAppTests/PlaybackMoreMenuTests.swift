import AppKit
import CueSeekerCore
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@Test
func audioTrackNamesListWhatTheFileRecordsSeparatedByCommas() {
    let chinese = Locale(identifier: "zh-Hans")
    #expect(
        PlaybackAudioTrackName.name(
            for: VideoAudioTrack(language: "jpn", title: nil, codec: "opus", channels: 2),
            at: 0,
            locale: chinese
        ) == "#1 日语, opus, 2ch"
    )
    #expect(
        PlaybackAudioTrackName.name(
            for: VideoAudioTrack(language: "jpn", title: "Commentary", codec: "aac", channels: 2),
            at: 1,
            locale: Locale(identifier: "en")
        ) == "#2 Japanese, Commentary, aac, 2ch"
    )
    // A language the system cannot name keeps its tag; nothing recorded
    // leaves the number alone.
    #expect(
        PlaybackAudioTrackName.name(
            for: VideoAudioTrack(language: "xyz", title: nil, codec: nil, channels: 6),
            at: 2,
            locale: chinese
        ) == "#3 xyz, 6ch"
    )
    #expect(
        PlaybackAudioTrackName.name(
            for: VideoAudioTrack(language: nil, title: nil, codec: nil, channels: nil),
            at: 3,
            locale: chinese
        ) == "#4"
    )
}

@Test
func subtitleNamesKeepTheLastTwoExtensionsAtMost() {
    #expect(PlaybackSubtitleName.name(forSubtitlePath: "/Media/Show/a.sc.ass") == ".sc.ass")
    #expect(PlaybackSubtitleName.name(forSubtitlePath: "/Media/Show/a.srt") == ".srt")
    #expect(PlaybackSubtitleName.name(forSubtitlePath: "/Media/Show/Show.S01E01.1080p.ass") == ".1080p.ass")
}

@Test
func moreMenuExposesOnlyAudioTrackAndTagsDefault() {
    #expect(PlaybackMoreSubmenu.allCases == [.audioTrack])
    let menu = PlaybackMoreMenu(
        audioTracks: PlaybackMoreMenuList(names: ["#1", "#2", "#3"], currentIndex: 1, defaultIndex: 0)
    )

    #expect(menu.enabledSubmenus == [.audioTrack])
    #expect(menu.checkedIndex(in: .audioTrack) == 1)
    #expect(menu.tag(in: .audioTrack).index == 0)
    #expect(menu.tag(in: .audioTrack).title == L("playback.more.default_tag"))
}

@Test
func subtitleMenuChecksActiveSubtitleWhenVisibleAndOffWhenHidden() {
    let list = PlaybackMoreMenuList(names: [".ass", ".srt", ".en.ass"], currentIndex: 2, defaultIndex: 1)

    let visibleMenu = PlaybackSubtitleMenu(subtitles: list, areSubtitlesVisible: true)
    #expect(visibleMenu.offPosition == 3)
    #expect(visibleMenu.selectablePositions == [0, 1, 2, 3])
    #expect(visibleMenu.checkedPosition == 2)
    #expect(!visibleMenu.isChecked(at: 0))
    #expect(!visibleMenu.isChecked(at: 1))
    #expect(visibleMenu.isChecked(at: 2))
    #expect(!visibleMenu.isChecked(at: 3))
    #expect(visibleMenu.tag(at: 0) == nil)
    #expect(visibleMenu.tag(at: 1) == L("playback.more.default_tag"))
    #expect(visibleMenu.tag(at: 2) == nil)
    #expect(visibleMenu.tag(at: 3) == nil)

    let hiddenMenu = PlaybackSubtitleMenu(subtitles: list, areSubtitlesVisible: false)
    #expect(hiddenMenu.checkedPosition == 3)
    #expect(!hiddenMenu.isChecked(at: 2))
    #expect(hiddenMenu.isChecked(at: 3))
    #expect(hiddenMenu.tag(at: 1) == L("playback.more.default_tag"))
}

@MainActor
@Test
func moreMenuKeysOpenAudioTrackSubmenuAndPickWithEnter() {
    let suiteName = "PlaybackMoreMenuTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }
    let store = PlaybackStore(userDefaults: userDefaults)
    var picks: [(PlaybackMoreSubmenu, Int)] = []
    let pick: (PlaybackMoreSubmenu, Int) -> Void = { picks.append(($0, $1)) }
    store.openMoreMenu(
        PlaybackMoreMenu(
            audioTracks: PlaybackMoreMenuList(names: ["#1", "#2", "#3"], currentIndex: 2, defaultIndex: 0)
        )
    )
    #expect(store.moreMenuHighlight.highlightedPosition == nil)

    // Down highlights Audio Track (0); Right opens Audio Track with no default item highlighted.
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.moreMenuHighlight.highlightedPosition == PlaybackMoreSubmenu.audioTrack.rawValue)
    #expect(store.handleMoreMenuKey(124, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuState.openParent == .audioTrack)
    #expect(store.moreSubmenuHighlight.highlightedPosition == nil)

    // Pressing Enter in a submenu with no highlighted item does nothing and
    // keeps the menu open.
    #expect(store.handleMoreMenuKey(36, isRepeat: false, onSelect: pick))
    #expect(picks.isEmpty)
    #expect(store.moreSubmenuState.openParent == .audioTrack)

    // Up and down move in the submenu; Left closes it and keeps Audio Track
    // highlighted in the parent menu.
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuHighlight.highlightedPosition == 0)
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuHighlight.highlightedPosition == 1)
    #expect(store.handleMoreMenuKey(123, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuState.openParent == nil)
    #expect(store.moreMenuHighlight.highlightedPosition == PlaybackMoreSubmenu.audioTrack.rawValue)

    // Enter reopens Audio Track with no item highlighted; Down + Down selects index 1 and Enter picks it.
    #expect(store.handleMoreMenuKey(36, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuHighlight.highlightedPosition == nil)
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuHighlight.highlightedPosition == 0)
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuHighlight.highlightedPosition == 1)
    #expect(store.handleMoreMenuKey(36, isRepeat: false, onSelect: pick))
    #expect(picks.count == 1)
    #expect(picks.first?.0 == .audioTrack)
    #expect(picks.first?.1 == 1)
    #expect(store.moreMenu == nil)
    #expect(!store.handleMoreMenuKey(36, isRepeat: false, onSelect: pick))
}

@MainActor
@Test
func moreMenuWithoutAudioTracksStillExpandsToNonSelectableSubmenu() {
    let suiteName = "PlaybackMoreMenuTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }
    let store = PlaybackStore(userDefaults: userDefaults)
    let empty = PlaybackMoreMenuList(names: [], currentIndex: 0, defaultIndex: 0)
    let menu = PlaybackMoreMenu(audioTracks: empty)
    #expect(menu.enabledSubmenus == [.audioTrack])

    var picks: [(PlaybackMoreSubmenu, Int)] = []
    let pick: (PlaybackMoreSubmenu, Int) -> Void = { picks.append(($0, $1)) }
    store.openMoreMenu(menu)
    #expect(store.moreMenuHighlight.highlightedPosition == nil)

    // Audio Track is still enabled and opens its submenu, whose disabled
    // `No Audio Tracks` item has no selectable positions.
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.moreMenuHighlight.highlightedPosition == PlaybackMoreSubmenu.audioTrack.rawValue)
    #expect(store.handleMoreMenuKey(124, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuState.openParent == .audioTrack)
    #expect(store.moreSubmenuHighlight.selectablePositions.isEmpty)
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuHighlight.highlightedPosition == nil)
    #expect(store.handleMoreMenuKey(36, isRepeat: false, onSelect: pick))
    #expect(picks.isEmpty)
    #expect(store.moreMenu != nil)

    #expect(store.handleMoreMenuKey(53, isRepeat: false, onSelect: pick))
    #expect(store.moreMenu == nil)
}

@MainActor
@Test
func subtitleMenuKeysNavigateSubtitlesAndOffItemAndMutuallyExcludeOtherPlayerMenus() {
    let suiteName = "PlaybackMoreMenuTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }
    let store = PlaybackStore(userDefaults: userDefaults)
    let menu = PlaybackSubtitleMenu(
        subtitles: PlaybackMoreMenuList(names: [".sc.ass", ".en.srt"], currentIndex: 0, defaultIndex: 0),
        areSubtitlesVisible: true
    )

    store.openSpeedMenu(defaultPosition: 2)
    #expect(store.isSpeedMenuOpen)
    store.openSubtitleMenu(menu)
    #expect(!store.isSpeedMenuOpen)
    #expect(store.subtitleMenu == menu)
    #expect(store.subtitleMenuHighlight.highlightedPosition == nil)

    var pickedPositions: [Int] = []
    let pick: (Int) -> Void = { pickedPositions.append($0) }

    // Enter without highlight does nothing.
    #expect(store.handleSubtitleMenuKey(36, isRepeat: false, onSelect: pick))
    #expect(pickedPositions.isEmpty)
    #expect(store.subtitleMenu != nil)

    // Down moves through subtitle 0, subtitle 1, and Off (position 2).
    #expect(store.handleSubtitleMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.subtitleMenuHighlight.highlightedPosition == 0)
    #expect(store.handleSubtitleMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.subtitleMenuHighlight.highlightedPosition == 1)
    #expect(store.handleSubtitleMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.subtitleMenuHighlight.highlightedPosition == 2)
    #expect(store.handleSubtitleMenuKey(36, isRepeat: false, onSelect: pick))
    #expect(pickedPositions == [2])
    #expect(store.subtitleMenu == nil)
}

@MainActor
@Test
func audioTrackSubmenuTakesItsNamesWidthUpToTheCapOnTheSideWithRoom() {
    let padding = MenuMetrics.padding * 2
    let bounds = CGRect(x: 24, y: 45, width: 1000, height: 600)
    let trigger = CGRect(x: 6, y: 6, width: 100, height: 32)

    // Room on the right: it opens there, as wide as its names.
    let rightMenu = CGRect(x: 100, y: 300, width: 124, height: 84)
    let right = PlaybackChromeMoreMenuOverlay.submenuLayout(
        naturalItemWidth: 150,
        itemStackHeight: { _ in 62 },
        menuFrame: rightMenu,
        triggerFrame: trigger,
        bounds: bounds
    )
    #expect(right.frame.minX == rightMenu.maxX)
    #expect(right.frame.width == 150 + padding)
    #expect(right.itemWidth == 150)

    // Against the right edge it opens to the left, and long names stop at the
    // cap.
    let leftMenu = CGRect(x: bounds.maxX - 124, y: 300, width: 124, height: 84)
    let left = PlaybackChromeMoreMenuOverlay.submenuLayout(
        naturalItemWidth: 600,
        itemStackHeight: { _ in 62 },
        menuFrame: leftMenu,
        triggerFrame: trigger,
        bounds: bounds
    )
    #expect(left.frame.maxX == leftMenu.minX)
    #expect(left.frame.width == PlaybackChromeMetrics.audioTrackMenuMaxWidth)
    #expect(left.itemWidth == PlaybackChromeMetrics.audioTrackMenuMaxWidth - padding)
}

@MainActor
@Test
func audioTrackSubmenuNarrowsToTheWiderSideWithoutCoveringTheMenu() {
    let padding = MenuMetrics.padding * 2
    let trigger = CGRect(x: 6, y: 6, width: 166, height: 32)
    // The narrowest window: neither side holds the cap.
    let bounds = CGRect(x: 24, y: 45, width: 432, height: 400)
    let menu = CGRect(x: bounds.maxX - 190, y: 300, width: 190, height: 84)
    let roomLeft = menu.minX - bounds.minX

    let layout = PlaybackChromeMoreMenuOverlay.submenuLayout(
        naturalItemWidth: 600,
        itemStackHeight: { _ in 62 },
        menuFrame: menu,
        triggerFrame: trigger,
        bounds: bounds
    )
    #expect(layout.frame.width == roomLeft)
    #expect(layout.frame.minX == bounds.minX)
    #expect(layout.frame.maxX == menu.minX)

    // Too tall for the room as well: the scrollbar's strip comes out of the
    // tracks, not out of the menu beside it.
    let scrolling = PlaybackChromeMoreMenuOverlay.submenuLayout(
        naturalItemWidth: 600,
        itemStackHeight: { _ in 2_000 },
        menuFrame: menu,
        triggerFrame: trigger,
        bounds: bounds
    )
    #expect(scrolling.frame.width == roomLeft)
    #expect(scrolling.itemWidth == roomLeft - padding - MenuMetrics.scrollbarStrip)
    #expect(scrolling.frame.maxX == menu.minX)
}

@MainActor
@Test
func audioTrackSubmenuScrollsBetweenTheTopBarAndTheButtons() {
    let padding = MenuMetrics.padding * 2
    let button = CGRect(x: 900, y: 500, width: 32, height: 32)
    let bounds = PlaybackChromeMoreMenuOverlay.bounds(
        stageSize: CGSize(width: 1_000, height: 558),
        buttonFrame: button
    )
    #expect(bounds.minY == WorkbenchControlMetrics.redesignAppTopbarHeight)
    #expect(bounds.maxY == button.minY - PlaybackChromeMetrics.speedMenuGap)

    let menu = CGRect(x: bounds.maxX - 124, y: bounds.maxY - 84, width: 124, height: 84)
    let layout = PlaybackChromeMoreMenuOverlay.submenuLayout(
        naturalItemWidth: 200,
        itemStackHeight: { _ in 2_000 },
        menuFrame: menu,
        triggerFrame: CGRect(x: 6, y: 6, width: 100, height: 32),
        bounds: bounds
    )
    #expect(layout.maximumHeight == bounds.height)
    #expect(layout.frame.minY == bounds.minY)
    #expect(layout.frame.maxY == bounds.maxY)
    // With room to spare the scrollbar widens the menu.
    #expect(layout.itemWidth == 200)
    #expect(layout.frame.width == 200 + padding + MenuMetrics.scrollbarStrip)
}

@MainActor
@Test
func moreMenuFitsItsTriggersAndSubmenusStayInTheirRoom() {
    let suiteName = "PlaybackMoreMenuTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }
    let store = PlaybackStore(userDefaults: userDefaults)
    let menu = PlaybackMoreMenu(
        audioTracks: PlaybackMoreMenuList(
            names: (1...40).map { "#\($0) Japanese, オーディオコメンタリー, flac, 2ch" },
            currentIndex: 0,
            defaultIndex: 1
        )
    )
    store.openMoreMenu(menu)
    // The narrowest window, the More button left of the fullscreen button.
    let stage = CGSize(width: 480, height: 560)
    let button = CGRect(x: 480 - 24 - 32 - 4 - 32, y: 560 - 50, width: 32, height: 32)
    let overlay = PlaybackChromeMoreMenuOverlay(
        playback: store,
        submenuState: store.moreSubmenuState,
        menu: menu,
        buttonFrame: button,
        suppressesInteraction: false,
        onSelect: { _, _ in }
    )
    let layout = overlay.measuredLayout(stageSize: stage)
    let bounds = PlaybackChromeMoreMenuOverlay.bounds(stageSize: stage, buttonFrame: button)

    // The trigger's label, the gap, the caret and both paddings all fit.
    let label = PlaybackMoreSubmenu.allCases.map { submenu in
        NSHostingView(
            rootView: Text(submenu.title)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeControl, weight: .medium))
        ).fittingSize.width
    }.max() ?? 0
    let trigger = label
        + WorkbenchControlMetrics.redesignMenuItemHorizontalPadding
        + WorkbenchControlMetrics.redesignMenuItemTrailingIconPadding
        + WorkbenchControlMetrics.redesignSpacing2
        + WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
    #expect(layout.menuFrame.width >= trigger + MenuMetrics.padding * 2)
    #expect(bounds.contains(layout.menuFrame))

    for submenu in PlaybackMoreSubmenu.allCases {
        guard let frame = layout.submenus[submenu]?.frame else {
            Issue.record("No layout for \(submenu)")
            continue
        }
        #expect(bounds.contains(frame))
        #expect(frame.maxX <= layout.menuFrame.minX || frame.minX >= layout.menuFrame.maxX)
    }

    // Also verify the empty-audio-tracks submenu layout stays within bounds.
    let emptyMenu = PlaybackMoreMenu(
        audioTracks: PlaybackMoreMenuList(names: [], currentIndex: 0, defaultIndex: 0)
    )
    let emptyOverlay = PlaybackChromeMoreMenuOverlay(
        playback: store,
        submenuState: store.moreSubmenuState,
        menu: emptyMenu,
        buttonFrame: button,
        suppressesInteraction: false,
        onSelect: { _, _ in }
    )
    let emptyLayout = emptyOverlay.measuredLayout(stageSize: stage)
    if let emptySubmenuFrame = emptyLayout.submenus[.audioTrack]?.frame {
        #expect(bounds.contains(emptySubmenuFrame))
    } else {
        Issue.record("No layout for empty audioTrack submenu")
    }

    // And verify the Player Subtitle Menu layout stays within stage bounds.
    let subtitleMenu = PlaybackSubtitleMenu(
        subtitles: PlaybackMoreMenuList(
            names: (1...40).map { ".s\($0).ass" },
            currentIndex: 1,
            defaultIndex: 0
        ),
        areSubtitlesVisible: true
    )
    store.openSubtitleMenu(subtitleMenu)
    let subtitleButton = CGRect(x: 316, y: 510, width: 32, height: 32)
    let subtitleOverlay = PlaybackChromeSubtitleMenuOverlay(
        playback: store,
        menu: subtitleMenu,
        buttonFrame: subtitleButton,
        suppressesInteraction: false,
        onSelect: { _ in }
    )
    let subtitleLayout = subtitleOverlay.measuredLayout(stageSize: stage)
    let subtitleBounds = PlaybackChromeMoreMenuOverlay.bounds(stageSize: stage, buttonFrame: subtitleButton)
    #expect(subtitleBounds.contains(subtitleLayout.frame))
}

@Test
func playerTopbarCenterMaxWidthRespectsWiderControlSideAndSpacing3SafetyGap() {
    // Bar width 600, leading occupied 123, trailing occupied 160 (e.g. Task badge 99+):
    // available centered width = 600 - 2 * (160 + 12) = 256.
    let width = PlaybackChromeMetrics.topbarCenterMaxWidth(
        barWidth: 600,
        leadingOccupiedWidth: 123,
        trailingOccupiedWidth: 160
    )
    #expect(width == 256)
}

@Test
func progressTimeCapsulePlacementClampsWithinScrubberBounds() {
    #expect(
        PlaybackProgressTimeCapsulePlacementLayout.clampedX(
            targetX: 0,
            capsuleWidth: 42,
            containerWidth: 300
        ) == 0
    )
    #expect(
        PlaybackProgressTimeCapsulePlacementLayout.clampedX(
            targetX: 150,
            capsuleWidth: 42,
            containerWidth: 300
        ) == 129
    )
    #expect(
        PlaybackProgressTimeCapsulePlacementLayout.clampedX(
            targetX: 300,
            capsuleWidth: 42,
            containerWidth: 300
        ) == 258
    )
}
