import CueSeekerCore
import Foundation
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
func audioTrackSubmenusCheckAndTagTheOppositeTracks() {
    let menu = PlaybackAudioTrackMenu(
        trackNames: ["#1", "#2", "#3"],
        currentIndex: 1,
        defaultIndex: 0
    )

    #expect(menu.checkedIndex(in: .audioTrack) == 1)
    #expect(menu.tag(in: .audioTrack).index == 0)
    #expect(menu.checkedIndex(in: .defaultAudioTrack) == 0)
    #expect(menu.tag(in: .defaultAudioTrack).index == 1)
}

@MainActor
@Test
func moreMenuKeysOpenSubmenusOnTheirFirstTrackAndPickWithEnter() {
    // The store ignores its defaults.
    let store = PlaybackStore(userDefaults: .standard)
    var picks: [(PlaybackMoreSubmenu, Int)] = []
    let pick: (PlaybackMoreSubmenu, Int) -> Void = { picks.append(($0, $1)) }
    store.openMoreMenu(
        PlaybackAudioTrackMenu(
            trackNames: ["#1", "#2", "#3"],
            currentIndex: 2,
            defaultIndex: 2
        )
    )
    #expect(store.moreMenuHighlight.highlightedPosition == PlaybackMoreSubmenu.audioTrack.rawValue)

    // Down, then right opens Default Audio Track on its first track.
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.handleMoreMenuKey(124, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuState.openParent == .defaultAudioTrack)
    #expect(store.moreSubmenuHighlight.highlightedPosition == 0)

    // Up and down now move in the submenu; left closes it.
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuHighlight.highlightedPosition == 1)
    #expect(store.handleMoreMenuKey(123, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuState.openParent == nil)
    #expect(store.moreMenuHighlight.highlightedPosition == PlaybackMoreSubmenu.defaultAudioTrack.rawValue)

    // Enter opens the submenu again, at its first track, and picks there.
    #expect(store.handleMoreMenuKey(36, isRepeat: false, onSelect: pick))
    #expect(store.moreSubmenuHighlight.highlightedPosition == 0)
    #expect(store.handleMoreMenuKey(125, isRepeat: false, onSelect: pick))
    #expect(store.handleMoreMenuKey(36, isRepeat: false, onSelect: pick))
    #expect(picks.count == 1)
    #expect(picks.first?.0 == .defaultAudioTrack)
    #expect(picks.first?.1 == 1)
    #expect(store.moreMenu == nil)
    #expect(!store.handleMoreMenuKey(36, isRepeat: false, onSelect: pick))
}

@MainActor
@Test
func moreMenuWithoutRecordedTracksHighlightsNothing() {
    // The store ignores its defaults.
    let store = PlaybackStore(userDefaults: .standard)
    store.openMoreMenu(
        PlaybackAudioTrackMenu(trackNames: [], currentIndex: 0, defaultIndex: 0)
    )
    #expect(store.moreMenuHighlight.highlightedPosition == nil)
    #expect(store.handleMoreMenuKey(124, isRepeat: false, onSelect: { _, _ in }))
    #expect(store.moreSubmenuState.openParent == nil)
    #expect(store.handleMoreMenuKey(53, isRepeat: false, onSelect: { _, _ in }))
    #expect(store.moreMenu == nil)
}
