import CoreGraphics
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func everyIconResolvesAtEveryStrokeCut() {
    for icon in AppIcon.allCases {
        for weight in [AppIconWeight.light, .regular, .bold] {
            #expect(
                AppIconStore.image(icon, weight: weight) != nil,
                "missing \(weight.rawValue) asset for \(icon.rawValue)"
            )
        }
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
func smallSizesDrawBoldAndLargeSizesDrawRegular() {
    for size in [11.0, 14.0, 16.0, 18.0] as [CGFloat] {
        #expect(AppIconWeight.tier(forSize: size) == .bold)
    }
    for size in [24.0, 32.0, 44.0] as [CGFloat] {
        #expect(AppIconWeight.tier(forSize: size) == .regular)
    }
}
