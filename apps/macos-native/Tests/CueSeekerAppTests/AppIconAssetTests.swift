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
func masterUnitsDrawTheDocumentedWidthAtEverySize() {
    // The master's 256-unit grid is drawn `size` points wide, so the rewritten
    // width has to come back out as the documented points.
    for (size, points) in AppIconLineWidth.bySize {
        let drawn = AppIconLineWidth.units(forSize: size) * size / 256
        #expect(abs(drawn - points) < 0.0001, "\(size)pt draws \(drawn)pt, not \(points)pt")
    }
}
