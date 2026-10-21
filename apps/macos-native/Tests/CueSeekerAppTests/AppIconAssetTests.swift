import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

/// The table is a mirror of `docs/human/design/Icon Registry.md`, and a size it
/// is missing draws with the wrong line or trips an assertion. Update this
/// expectation with the document.
@Test
func lineWidthTableMirrorsTheIconRegistry() {
    #expect(AppIconLineWidth.bySize == [
        12: 1.15,
        14: 1.15,
        16: 1.20,
        18: 1.30,
        20: 1.30,
        21: 1.35,
        23: 1.40,
        24: 1.40,
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

@MainActor
@Test
func systemColorsDidChangeClearsTintedCache() {
    AppIconStore.clearTintedCacheForTesting()
    #expect(AppIconStore.tintedCacheCountForTesting() == 0)

    _ = AppIconStore.tintedImage(.checkCircle, size: 16, color: .controlAccentColor, weight: .fill)
    #expect(AppIconStore.tintedCacheCountForTesting() == 1)

    NotificationCenter.default.post(
        name: NSColor.systemColorsDidChangeNotification,
        object: nil
    )
    #expect(AppIconStore.tintedCacheCountForTesting() == 0)
}

@MainActor
@Test
func accentDuotoneCardIconsFollowFortyFourPercentHierarchyAndRenderAllTwelveIcons() {
    #expect(AppAccentDuotoneIconMetrics.baseOpacity == 0.44)
    #expect(AppAccentDuotoneIconMetrics.folderTabOpacity == 0.64)
    #expect(AppAccentDuotoneIconMetrics.ankiLinesOpacity == 0.71)
    #expect(AppAccentDuotoneIconMetrics.foregroundOpacity == 1.0)
    #expect(AppAccentDuotoneIconMetrics.supportedIcons.count == 12)
    #expect(AppAccentDuotoneIconMetrics.supportedIcons == [
        .folder,
        .folderWebdav,
        .folderSmb,
        .folderFtp,
        .folderNfs,
        .folderPlus,
        .folderMinus,
        .video,
        .subtitles,
        .ankiStar,
        .arrowClockwise,
        .pencilSimple,
    ])

    for icon in AppAccentDuotoneIconMetrics.supportedIcons {
        for size in [
            WorkbenchControlMetrics.redesignCardIconContainerSize,
            WorkbenchControlMetrics.redesignDetailFileIconContainerSize,
        ] {
            let host = NSHostingView(rootView: WorkbenchCardIcon(icon: icon, size: size))
            host.layoutSubtreeIfNeeded()
            #expect(host.fittingSize == CGSize(width: size, height: size))
        }
    }
}
