import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func everyIconResolvesAtBothStrokeTiers() {
    for icon in AppIcon.allCases {
        #expect(AppIconStore.image(icon, weight: .light) != nil, "missing light asset for \(icon.rawValue)")
        #expect(AppIconStore.image(icon, weight: .regular) != nil, "missing regular asset for \(icon.rawValue)")
    }
}

@MainActor
@Test
func stateVariantIconsResolveFilled() {
    let filled: [AppIcon] = [
        .checkCircle, .minusCircle, .bookmarkSimple,
        .play, .pause, .skipBack, .skipForward
    ]

    for icon in filled {
        #expect(AppIconStore.image(icon, weight: .fill) != nil, "missing fill asset for \(icon.rawValue)")
    }
}

@Test
func strokeTierFollowsTheRequestedSize() {
    #expect(AppIconWeight.tier(forSize: 12) == .light)
    #expect(AppIconWeight.tier(forSize: 18) == .light)
    #expect(AppIconWeight.tier(forSize: 24) == .regular)
    #expect(AppIconWeight.tier(forSize: 32) == .regular)
}
