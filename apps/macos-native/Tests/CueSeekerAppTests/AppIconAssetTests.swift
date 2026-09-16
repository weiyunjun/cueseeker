import CoreGraphics
import Foundation
import Testing
@testable import CueSeekerApp

/// The table is a mirror of `docs/human/design/Icon Registry.md`, and a size it
/// is missing draws with the wrong line or trips an assertion. Update this
/// expectation with the document.
@Test
func lineWidthTableMirrorsTheIconRegistry() {
    #expect(AppIconLineWidth.bySize == [
        14: 1.15,
        16: 1.20,
        18: 1.30,
        20: 1.30,
        21: 1.35,
        23: 1.40,
        31: 1.50,
        42: 1.90,
        47: 2.10,
        57: 2.50,
    ])
}

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
/// line drawn at any other width would stay fixed while the rest follow. A
/// master drawn only in fills, such as the three dots, has no line to swap.
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
        #expect(widths.isSubset(of: ["16"]), "\(icon.rawValue) draws lines at \(widths)")
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
