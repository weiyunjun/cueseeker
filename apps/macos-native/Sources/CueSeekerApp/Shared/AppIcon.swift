import AppKit
import SwiftUI

/// Every icon the interface can draw.
///
/// Views name a case here rather than a graphic, so the drawing can change
/// without touching the interface. Each raw value is the Phosphor asset that
/// backs the case; the assets live under `Resources/Icons`.
enum AppIcon: String, CaseIterable, Sendable {
    case caretLeft = "caret-left"
    case caretRight = "caret-right"
    case caretDown = "caret-down"
    case sidebarSimple = "sidebar-simple"
    case arrowLeft = "arrow-left"
    case arrowRight = "arrow-right"
    case x = "x"
    case check = "check"
    case magnifyingGlass = "magnifying-glass"
    case funnel = "funnel"
    case arrowElbowDownLeft = "arrow-elbow-down-left"
    case squaresFour = "squares-four"
    case folder = "folder"
    case bookmarkSimple = "bookmark-simple"
    case clock = "clock"
    case gear = "gear"
    case listChecks = "list-checks"
    case folderPlus = "folder-plus"
    case arrowClockwise = "arrow-clockwise"
    case arrowCounterClockwise = "arrow-counter-clockwise"
    case minusCircle = "minus-circle"
    case stack = "stack"
    case video = "video"
    case subtitles = "subtitles"
    case warning = "warning"
    case warningCircle = "warning-circle"
    case checkCircle = "check-circle"
    case circle = "circle"
    case playCircle = "play-circle"
    case clockCounterClockwise = "clock-counter-clockwise"
    case question = "question"
    case pencilSimple = "pencil-simple"
    case notePencil = "note-pencil"
    case trash = "trash"
    case copy = "copy"
    case export = "export"
    case linkSimple = "link-simple"
    case play = "play"
    case pause = "pause"
    case skipBack = "skip-back"
    case skipForward = "skip-forward"
    case repeatIcon = "repeat"
    case image = "image"
    case speedometer = "speedometer"
    case cornersOut = "corners-out"
    case cornersIn = "corners-in"
    case speakerX = "speaker-x"
    case speakerLow = "speaker-low"
    case speakerHigh = "speaker-high"
    case textAa = "text-aa"
    case globe = "globe"
    case eye = "eye"
    case circleHalf = "circle-half"
    case hardDrives = "hard-drives"
    case hammer = "hammer"
    case keyboard = "keyboard"
    case fileArrowDown = "file-arrow-down"
}

/// Which cut of an icon to draw.
///
/// `regular` is the stroke master, whose line width follows the size the call
/// site asks for. `fill` is the solid state variant; it has no line to adjust,
/// so the call site asks for it directly.
enum AppIconWeight: String, Sendable {
    case regular
    case fill
}

/// The line width drawn at each display size, in points.
///
/// Mirrors the line width table in `docs/human/design/Icon Registry.md`. A
/// size missing here has no documented width and has to be added there before
/// an icon is drawn at it.
enum AppIconLineWidth {
    static let bySize: [CGFloat: CGFloat] = [
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
    ]

    /// Every stroke master draws its lines 16 units wide on a 256-unit grid.
    static let master: CGFloat = 16

    /// The master width that shows `bySize[size]` points of line once the
    /// 256-unit grid is drawn `size` points wide.
    static func units(forSize size: CGFloat) -> CGFloat {
        guard let points = bySize[size] else {
            assertionFailure("No documented line width for a \(size)pt icon")
            return master
        }
        return points * 256 / size
    }
}

@MainActor
enum AppIconStore {
    private static var cache: [String: NSImage] = [:]

    static func image(
        _ icon: AppIcon,
        size: CGFloat,
        weight: AppIconWeight = .regular
    ) -> NSImage? {
        let name = assetName(icon, weight: weight)
        let key = "\(name)-\(size)"

        if let cached = cache[key] {
            return cached
        }

        guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
              let master = try? String(contentsOf: url, encoding: .utf8),
              let image = NSImage(data: Data(settingLineWidth(of: master, forSize: size).utf8))
        else {
            return nil
        }

        // The assets carry no colour of their own; the interface tints them
        // through the same foreground styles the symbols used.
        image.isTemplate = true
        cache[key] = image
        return image
    }

    /// The master with its line width replaced by the one documented for
    /// `size`. The fill cut draws no lines and passes through unchanged.
    private static func settingLineWidth(of master: String, forSize size: CGFloat) -> String {
        master.replacingOccurrences(
            of: "stroke-width=\"\(Int(AppIconLineWidth.master))\"",
            with: "stroke-width=\"\(AppIconLineWidth.units(forSize: size))\""
        )
    }

    /// The same glyph already filled with one colour, for the places that
    /// draw through AppKit instead of SwiftUI. Table rows redraw these while
    /// scrolling, so each icon/size/colour combination is rasterised once.
    static func tintedImage(
        _ icon: AppIcon,
        size: CGFloat,
        color: NSColor,
        weight: AppIconWeight = .regular
    ) -> NSImage? {
        let key = "\(assetName(icon, weight: weight))-\(size)-\(color.hashValue)"

        if let cached = tintedCache[key] {
            return cached
        }

        guard let base = image(icon, size: size, weight: weight) else {
            return nil
        }

        let bounds = NSRect(x: 0, y: 0, width: size, height: size)
        let tinted = NSImage(size: bounds.size)
        tinted.lockFocus()
        base.draw(in: bounds)
        color.set()
        bounds.fill(using: .sourceAtop)
        tinted.unlockFocus()

        tintedCache[key] = tinted
        return tinted
    }

    private static var tintedCache: [String: NSImage] = [:]

    private static func assetName(_ icon: AppIcon, weight: AppIconWeight) -> String {
        switch weight {
        case .regular:
            icon.rawValue
        case .fill:
            "\(icon.rawValue)-fill"
        }
    }
}

/// One icon drawn at a fixed size, tinted by the surrounding foreground style.
struct AppIconImage: View {
    let icon: AppIcon
    let size: CGFloat
    var weight: AppIconWeight?

    init(_ icon: AppIcon, size: CGFloat, weight: AppIconWeight? = nil) {
        self.icon = icon
        self.size = size
        self.weight = weight
    }

    var body: some View {
        if let image = AppIconStore.image(icon, size: size, weight: weight ?? .regular) {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .frame(width: size, height: size)
        }
    }
}
