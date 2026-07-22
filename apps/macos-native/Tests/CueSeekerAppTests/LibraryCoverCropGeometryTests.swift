import AppKit
import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func libraryCoverCropInitialRectIsLargestSixteenByNineArea() {
    let wide = LibraryCoverCropGeometry.initialCropRect(
        imageSize: CGSize(width: 2_000, height: 1_000)
    )
    #expect(abs(wide.width - (1_000 * 16 / 9)) < 0.001)
    #expect(wide.height == 1_000)
    #expect(abs(wide.midX - 1_000) < 0.001)
    #expect(wide.minY == 0)

    let square = LibraryCoverCropGeometry.initialCropRect(
        imageSize: CGSize(width: 1_000, height: 1_000)
    )
    #expect(square.width == 1_000)
    #expect(abs(square.height - (1_000 * 9 / 16)) < 0.001)
    #expect(abs(square.midY - 500) < 0.001)
    #expect(square.minX == 0)
}

@Test
func libraryCoverCropMoveStaysInsideImage() {
    let imageSize = CGSize(width: 1_000, height: 600)
    let cropRect = CGRect(x: 100, y: 75, width: 640, height: 360)

    let upperRight = LibraryCoverCropGeometry.movedCropRect(
        cropRect,
        translation: CGSize(width: 2_000, height: 2_000),
        imageSize: imageSize
    )
    #expect(upperRight.maxX == imageSize.width)
    #expect(upperRight.maxY == imageSize.height)
    #expect(upperRight.size == cropRect.size)

    let lowerLeft = LibraryCoverCropGeometry.movedCropRect(
        cropRect,
        translation: CGSize(width: -2_000, height: -2_000),
        imageSize: imageSize
    )
    #expect(lowerLeft.minX == 0)
    #expect(lowerLeft.minY == 0)
    #expect(lowerLeft.size == cropRect.size)
}

@Test
func libraryCoverCropCornerResizeKeepsAspectAnchorBoundsAndMinimum() {
    let imageSize = CGSize(width: 1_000, height: 600)
    let cropRect = CGRect(x: 100, y: 75, width: 640, height: 360)

    for corner in LibraryCoverCropCorner.allCases {
        let originalAnchor = libraryCoverOppositeAnchor(for: corner, in: cropRect)
        let expanded = LibraryCoverCropGeometry.resizedCropRect(
            cropRect,
            corner: corner,
            translation: libraryCoverOutwardTranslation(for: corner, distance: 2_000),
            minimumWidth: 160,
            imageSize: imageSize
        )
        #expect(LibraryCoverCropGeometry.contains(expanded, in: imageSize))
        #expect(libraryCoverPointsAreEqual(
            libraryCoverOppositeAnchor(for: corner, in: expanded),
            originalAnchor
        ))

        let contracted = LibraryCoverCropGeometry.resizedCropRect(
            cropRect,
            corner: corner,
            translation: libraryCoverOutwardTranslation(for: corner, distance: -2_000),
            minimumWidth: 160,
            imageSize: imageSize
        )
        #expect(LibraryCoverCropGeometry.contains(contracted, in: imageSize))
        #expect(abs(contracted.width - 160) < 0.001)
        #expect(libraryCoverPointsAreEqual(
            libraryCoverOppositeAnchor(for: corner, in: contracted),
            originalAnchor
        ))
    }
}

@Test
func libraryCoverCropColorsUseSystemAccentAndTranslucentShadowTokens() {
    #expect(WorkbenchRedesignColors.NS.libraryCoverCropAccent == NSColor.controlAccentColor)
    #expect(
        WorkbenchRedesignColors.NS.libraryCoverCropMask
            == NSColor.shadowColor.withAlphaComponent(0.55)
    )
    #expect(
        abs(WorkbenchRedesignColors.NS.libraryCoverCropMask.alphaComponent - 0.55)
            < 0.001
    )
}

private func libraryCoverOppositeAnchor(
    for corner: LibraryCoverCropCorner,
    in cropRect: CGRect
) -> CGPoint {
    switch corner {
    case .topLeft:
        CGPoint(x: cropRect.maxX, y: cropRect.minY)
    case .topRight:
        CGPoint(x: cropRect.minX, y: cropRect.minY)
    case .bottomLeft:
        CGPoint(x: cropRect.maxX, y: cropRect.maxY)
    case .bottomRight:
        CGPoint(x: cropRect.minX, y: cropRect.maxY)
    }
}

private func libraryCoverOutwardTranslation(
    for corner: LibraryCoverCropCorner,
    distance: CGFloat
) -> CGSize {
    switch corner {
    case .topLeft:
        CGSize(width: -distance, height: distance)
    case .topRight:
        CGSize(width: distance, height: distance)
    case .bottomLeft:
        CGSize(width: -distance, height: -distance)
    case .bottomRight:
        CGSize(width: distance, height: -distance)
    }
}

private func libraryCoverPointsAreEqual(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
    abs(lhs.x - rhs.x) < 0.001 && abs(lhs.y - rhs.y) < 0.001
}
