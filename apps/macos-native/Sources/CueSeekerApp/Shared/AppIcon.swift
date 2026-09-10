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
    case caretUpDown = "caret-up-down"
    case sidebarSimple = "sidebar-simple"
    case arrowLeft = "arrow-left"
    case arrowRight = "arrow-right"
    case x = "x"
    case check = "check"
    case magnifyingGlass = "magnifying-glass"
    case funnel = "funnel"
    case plus = "plus"
    case arrowElbowDownLeft = "arrow-elbow-down-left"
    case squaresFour = "squares-four"
    case folder = "folder"
    case bookmarkSimple = "bookmark-simple"
    case clock = "clock"
    case gear = "gear"
    case listChecks = "list-checks"
    case folderPlus = "folder-plus"
    case arrowClockwise = "arrow-clockwise"
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
    case fileArrowDown = "file-arrow-down"
    case tray = "tray"
    case listBullets = "list-bullets"
}

/// Which cut of an icon to draw.
///
/// `light` and `regular` are the two stroke tiers; the tier follows the size
/// the call site asks for, so one icon stays visually even across the sizes it
/// appears at. `fill` is a state variant instead of a tier, and the call site
/// asks for it directly.
enum AppIconWeight: String, Sendable {
    case light
    case regular
    case bold
    case fill

    /// Below 24px the glyph sits beside body text and needs the heavier cut
    /// to hold its own; from 24px up the drawn stroke is already thick enough
    /// at Regular.
    static func tier(forSize size: CGFloat) -> AppIconWeight {
        size < 24 ? .bold : .regular
    }
}

@MainActor
enum AppIconStore {
    private static var cache: [String: NSImage] = [:]

    static func image(_ icon: AppIcon, weight: AppIconWeight) -> NSImage? {
        let name = assetName(icon, weight: weight)

        if let cached = cache[name] {
            return cached
        }

        guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        // The assets carry no colour of their own; the interface tints them
        // through the same foreground styles the symbols used.
        image.isTemplate = true
        cache[name] = image
        return image
    }

    /// The same glyph already filled with one colour, for the places that
    /// draw through AppKit instead of SwiftUI. Table rows redraw these while
    /// scrolling, so each icon/size/colour combination is rasterised once.
    static func tintedImage(
        _ icon: AppIcon,
        size: CGFloat,
        color: NSColor,
        weight: AppIconWeight? = nil
    ) -> NSImage? {
        let resolved = weight ?? .tier(forSize: size)
        let key = "\(assetName(icon, weight: resolved))-\(size)-\(color.hashValue)"

        if let cached = tintedCache[key] {
            return cached
        }

        guard let base = image(icon, weight: resolved) else {
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
        case .light, .bold, .fill:
            "\(icon.rawValue)-\(weight.rawValue)"
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
        if let image = AppIconStore.image(icon, weight: weight ?? .tier(forSize: size)) {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .frame(width: size, height: size)
        }
    }
}
