import CoreGraphics
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
func everySizeCurrentlyDrawsTheRegularStroke() {
    for size in [11.0, 14.0, 16.0, 18.0, 24.0, 32.0, 44.0] as [CGFloat] {
        #expect(AppIconWeight.tier(forSize: size) == .regular)
    }
}
