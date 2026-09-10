import CoreGraphics
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func everyIconResolvesAtEveryDocumentedSize() {
    for icon in AppIcon.allCases {
        for size in AppIconLineWidth.bySize.keys {
            #expect(
                AppIconStore.image(icon, size: size) != nil,
                "missing \(icon.rawValue) at \(size)pt"
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
        #expect(
            AppIconStore.image(icon, size: 16, weight: .fill) != nil,
            "missing fill asset for \(icon.rawValue)"
        )
    }
}

/// Drawing swaps the master's one line width for the documented one, so a
/// line drawn at any other width would stay fixed while the rest follow.
@Test
func everyStrokeMasterDrawsAllItsLinesAtTheMasterWidth() throws {
    let icons = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/CueSeekerApp/Resources/Icons")

    for icon in AppIcon.allCases {
        let master = try String(
            contentsOf: icons.appendingPathComponent("\(icon.rawValue).svg"),
            encoding: .utf8
        )
        let widths = Set(master.matches(of: #/stroke-width="([^"]*)"/#).map { String($0.1) })
        #expect(widths == ["16"], "\(icon.rawValue) draws lines at \(widths)")
    }
}

@Test
func theTwentyFourPointWidthDrawsTheMasterUnchanged() {
    // 1.5pt of line at 24pt is Phosphor's own Regular: 16 units of 256.
    #expect(AppIconLineWidth.units(forSize: 24) == AppIconLineWidth.master)
    #expect(AppIconLineWidth.units(forSize: 14) > AppIconLineWidth.master)
}
