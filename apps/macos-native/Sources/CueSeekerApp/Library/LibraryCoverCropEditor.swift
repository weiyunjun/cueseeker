import CoreGraphics
import SwiftUI

enum LibraryCoverCropCorner: CaseIterable, Equatable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

enum LibraryCoverCropGeometry {
    static let aspectRatio = CGFloat(LibraryUserCoverProcessor.aspectRatio)

    static func initialCropRect(imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }
        let imageAspectRatio = imageSize.width / imageSize.height
        if imageAspectRatio >= aspectRatio {
            let height = imageSize.height
            let width = height * aspectRatio
            return CGRect(
                x: (imageSize.width - width) / 2,
                y: 0,
                width: width,
                height: height
            )
        }

        let width = imageSize.width
        let height = width / aspectRatio
        return CGRect(
            x: 0,
            y: (imageSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    static func movedCropRect(
        _ cropRect: CGRect,
        translation: CGSize,
        imageSize: CGSize
    ) -> CGRect {
        guard cropRect.width > 0, cropRect.height > 0 else {
            return initialCropRect(imageSize: imageSize)
        }
        return CGRect(
            x: min(
                max(0, cropRect.minX + translation.width),
                max(0, imageSize.width - cropRect.width)
            ),
            y: min(
                max(0, cropRect.minY + translation.height),
                max(0, imageSize.height - cropRect.height)
            ),
            width: cropRect.width,
            height: cropRect.height
        )
    }

    static func resizedCropRect(
        _ cropRect: CGRect,
        corner: LibraryCoverCropCorner,
        translation: CGSize,
        minimumWidth: CGFloat,
        imageSize: CGSize
    ) -> CGRect {
        guard cropRect.width > 0, cropRect.height > 0,
              imageSize.width > 0, imageSize.height > 0
        else {
            return initialCropRect(imageSize: imageSize)
        }

        let configuration = resizeConfiguration(for: corner, cropRect: cropRect)
        let movedCorner = CGPoint(
            x: configuration.corner.x + translation.width,
            y: configuration.corner.y + translation.height
        )
        let vectorX = movedCorner.x - configuration.anchor.x
        let vectorY = movedCorner.y - configuration.anchor.y
        let ratioSquared = aspectRatio * aspectRatio
        let projectedHeight = (
            vectorX * configuration.horizontalDirection * aspectRatio
                + vectorY * configuration.verticalDirection
        ) / (ratioSquared + 1)

        let horizontalAvailable = configuration.horizontalDirection > 0
            ? imageSize.width - configuration.anchor.x
            : configuration.anchor.x
        let verticalAvailable = configuration.verticalDirection > 0
            ? imageSize.height - configuration.anchor.y
            : configuration.anchor.y
        let maximumHeight = max(
            0,
            min(horizontalAvailable / aspectRatio, verticalAvailable)
        )
        let requestedMinimumHeight = max(1, minimumWidth) / aspectRatio
        let minimumHeight = min(requestedMinimumHeight, maximumHeight)
        let height = min(max(projectedHeight, minimumHeight), maximumHeight)
        let width = height * aspectRatio
        let resizedCorner = CGPoint(
            x: configuration.anchor.x + configuration.horizontalDirection * width,
            y: configuration.anchor.y + configuration.verticalDirection * height
        )

        return CGRect(
            x: min(configuration.anchor.x, resizedCorner.x),
            y: min(configuration.anchor.y, resizedCorner.y),
            width: width,
            height: height
        )
    }

    static func contains(_ cropRect: CGRect, in imageSize: CGSize) -> Bool {
        let values = [
            cropRect.minX,
            cropRect.minY,
            cropRect.width,
            cropRect.height,
            cropRect.maxX,
            cropRect.maxY
        ]
        return values.allSatisfy(\.isFinite)
            && cropRect.minX >= 0
            && cropRect.minY >= 0
            && cropRect.width > 0
            && cropRect.height > 0
            && cropRect.maxX <= imageSize.width
            && cropRect.maxY <= imageSize.height
            && abs((cropRect.width / cropRect.height) - aspectRatio) <= 0.001
    }

    private static func resizeConfiguration(
        for corner: LibraryCoverCropCorner,
        cropRect: CGRect
    ) -> (
        corner: CGPoint,
        anchor: CGPoint,
        horizontalDirection: CGFloat,
        verticalDirection: CGFloat
    ) {
        switch corner {
        case .topLeft:
            (
                CGPoint(x: cropRect.minX, y: cropRect.maxY),
                CGPoint(x: cropRect.maxX, y: cropRect.minY),
                -1,
                1
            )
        case .topRight:
            (
                CGPoint(x: cropRect.maxX, y: cropRect.maxY),
                CGPoint(x: cropRect.minX, y: cropRect.minY),
                1,
                1
            )
        case .bottomLeft:
            (
                CGPoint(x: cropRect.minX, y: cropRect.minY),
                CGPoint(x: cropRect.maxX, y: cropRect.maxY),
                -1,
                -1
            )
        case .bottomRight:
            (
                CGPoint(x: cropRect.maxX, y: cropRect.minY),
                CGPoint(x: cropRect.minX, y: cropRect.maxY),
                1,
                -1
            )
        }
    }
}

private struct LibraryCoverCropLayout {
    let imageSize: CGSize
    let imageFrame: CGRect
    let scale: CGFloat

    init(imageSize: CGSize, containerSize: CGSize) {
        self.imageSize = imageSize
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0
        else {
            imageFrame = .zero
            scale = 1
            return
        }
        scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let fittedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        imageFrame = CGRect(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    func viewRect(for cropRect: CGRect) -> CGRect {
        CGRect(
            x: imageFrame.minX + cropRect.minX * scale,
            y: imageFrame.minY + (imageSize.height - cropRect.maxY) * scale,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )
    }

    func imageTranslation(for viewTranslation: CGSize) -> CGSize {
        CGSize(
            width: viewTranslation.width / scale,
            height: -viewTranslation.height / scale
        )
    }
}

struct LibraryCoverCropEditor: View {
    private static let borderWidth: CGFloat = 2
    private static let handleVisualSize: CGFloat = 14
    private static let handleHitSize: CGFloat = 30
    private static let minimumCropViewWidth: CGFloat = 96

    let source: LibraryUserCoverSource
    @Binding var cropRect: CGRect

    @State private var moveStartCropRect: CGRect?
    @State private var resizeStartCropRect: CGRect?
    @State private var activeCorner: LibraryCoverCropCorner?

    var body: some View {
        GeometryReader { proxy in
            let layout = LibraryCoverCropLayout(
                imageSize: source.pixelSize,
                containerSize: proxy.size
            )
            let displayedCropRect = layout.viewRect(for: cropRect)

            ZStack(alignment: .topLeading) {
                Image(decorative: source.image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: layout.imageFrame.width, height: layout.imageFrame.height)
                    .position(x: layout.imageFrame.midX, y: layout.imageFrame.midY)

                cropMaskPath(
                    imageFrame: layout.imageFrame,
                    cropRect: displayedCropRect
                )
                .fill(WorkbenchRedesignColors.libraryCoverCropMask)
                .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: displayedCropRect.width, height: displayedCropRect.height)
                    .position(x: displayedCropRect.midX, y: displayedCropRect.midY)
                    .gesture(moveGesture(layout: layout))

                Rectangle()
                    .stroke(
                        WorkbenchRedesignColors.libraryCoverCropAccent,
                        lineWidth: Self.borderWidth
                    )
                    .frame(width: displayedCropRect.width, height: displayedCropRect.height)
                    .position(x: displayedCropRect.midX, y: displayedCropRect.midY)
                    .allowsHitTesting(false)

                ForEach(LibraryCoverCropCorner.allCases, id: \.self) { corner in
                    cropHandle
                        .position(handlePosition(corner, in: displayedCropRect))
                        .gesture(resizeGesture(corner: corner, layout: layout))
                }
            }
            .onAppear {
                if !LibraryCoverCropGeometry.contains(cropRect, in: source.pixelSize) {
                    cropRect = LibraryCoverCropGeometry.initialCropRect(
                        imageSize: source.pixelSize
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cover crop editor")
    }

    private var cropHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: Self.handleHitSize, height: Self.handleHitSize)
            .overlay {
                Rectangle()
                    .fill(WorkbenchRedesignColors.bgSurface)
                    .overlay {
                        Rectangle()
                            .stroke(
                                WorkbenchRedesignColors.libraryCoverCropAccent,
                                lineWidth: Self.borderWidth
                            )
                    }
                    .frame(
                        width: Self.handleVisualSize,
                        height: Self.handleVisualSize
                    )
            }
            .contentShape(Rectangle())
    }

    private func moveGesture(layout: LibraryCoverCropLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if moveStartCropRect == nil {
                    moveStartCropRect = cropRect
                }
                guard let moveStartCropRect else {
                    return
                }
                cropRect = LibraryCoverCropGeometry.movedCropRect(
                    moveStartCropRect,
                    translation: layout.imageTranslation(for: value.translation),
                    imageSize: source.pixelSize
                )
            }
            .onEnded { _ in
                moveStartCropRect = nil
            }
    }

    private func resizeGesture(
        corner: LibraryCoverCropCorner,
        layout: LibraryCoverCropLayout
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeCorner != corner || resizeStartCropRect == nil {
                    activeCorner = corner
                    resizeStartCropRect = cropRect
                }
                guard let resizeStartCropRect else {
                    return
                }
                cropRect = LibraryCoverCropGeometry.resizedCropRect(
                    resizeStartCropRect,
                    corner: corner,
                    translation: layout.imageTranslation(for: value.translation),
                    minimumWidth: min(
                        resizeStartCropRect.width,
                        Self.minimumCropViewWidth / layout.scale
                    ),
                    imageSize: source.pixelSize
                )
            }
            .onEnded { _ in
                activeCorner = nil
                resizeStartCropRect = nil
            }
    }

    private func handlePosition(
        _ corner: LibraryCoverCropCorner,
        in cropRect: CGRect
    ) -> CGPoint {
        switch corner {
        case .topLeft:
            CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:
            CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:
            CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight:
            CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    private func cropMaskPath(imageFrame: CGRect, cropRect: CGRect) -> Path {
        var path = Path()
        path.addRect(
            CGRect(
                x: imageFrame.minX,
                y: imageFrame.minY,
                width: imageFrame.width,
                height: max(0, cropRect.minY - imageFrame.minY)
            )
        )
        path.addRect(
            CGRect(
                x: imageFrame.minX,
                y: cropRect.maxY,
                width: imageFrame.width,
                height: max(0, imageFrame.maxY - cropRect.maxY)
            )
        )
        path.addRect(
            CGRect(
                x: imageFrame.minX,
                y: cropRect.minY,
                width: max(0, cropRect.minX - imageFrame.minX),
                height: cropRect.height
            )
        )
        path.addRect(
            CGRect(
                x: cropRect.maxX,
                y: cropRect.minY,
                width: max(0, imageFrame.maxX - cropRect.maxX),
                height: cropRect.height
            )
        )
        return path
    }
}
