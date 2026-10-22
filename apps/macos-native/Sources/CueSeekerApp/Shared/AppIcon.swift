import AppKit
import SwiftUI

/// Every icon the interface can draw.
///
/// Views name a case here rather than a graphic, so the drawing can change
/// without touching the interface. Each raw value is the asset that backs the
/// case — Phosphor's, or one drawn to the same spec; the assets live under
/// `Resources/Icons`.
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
    case funnelSimple = "funnel-simple"
    case arrowElbowDownLeft = "arrow-elbow-down-left"
    case squaresFour = "squares-four"
    case folder = "folder"
    case folderWebdav = "folder-webdav"
    case folderSmb = "folder-smb"
    case folderFtp = "folder-ftp"
    case folderNfs = "folder-nfs"
    case cloud = "cloud"
    case bookmarkSimple = "bookmark-simple"
    case clock = "clock"
    case gear = "gear"
    case gearFine = "gear-fine"
    case tray = "tray"
    case listChecks = "list-checks"
    case folderPlus = "folder-plus"
    case folderMinus = "folder-minus"
    case plus = "plus"
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
    case info = "info"
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
    case camera = "camera"
    case imagesSquare = "images-square"
    case speedometer = "speedometer"
    case cornersOut = "corners-out"
    case cornersIn = "corners-in"
    case dotsThreeVertical = "dots-three-vertical"
    case dotsThree = "dots-three"
    case dotsSixVertical = "dots-six-vertical"
    case speakerX = "speaker-x"
    case speakerLow = "speaker-low"
    case speakerHigh = "speaker-high"
    case textAa = "text-aa"
    case globe = "globe"
    case eye = "eye"
    case hardDrives = "hard-drives"
    case hammer = "hammer"
    case keyboard = "keyboard"
    case fileArrowDown = "file-arrow-down"
    case signOut = "sign-out"
    case ankiStar = "anki-star"

    var folderProtocolBadge: String? {
        switch self {
        case .folderWebdav:
            return "DAV"
        case .folderSmb:
            return "SMB"
        case .folderFtp:
            return "FTP"
        case .folderNfs:
            return "NFS"
        default:
            return nil
        }
    }
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

        guard let url = Bundle.appResources.url(forResource: name, withExtension: "svg"),
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
        ensureSystemColorObserver()
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
    private static var isObservingSystemColors = false

    private static func ensureSystemColorObserver() {
        guard !isObservingSystemColors else { return }
        isObservingSystemColors = true
        NotificationCenter.default.addObserver(
            forName: NSColor.systemColorsDidChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    tintedCache.removeAll()
                }
            } else {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        tintedCache.removeAll()
                    }
                }
            }
        }
    }

    #if DEBUG
    static func clearTintedCacheForTesting() {
        tintedCache.removeAll()
    }

    static func tintedCacheCountForTesting() -> Int {
        tintedCache.count
    }
    #endif

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
        if let badge = icon.folderProtocolBadge, (weight ?? .regular) == .regular {
            ProtocolFolderIconView(badge: badge, size: size)
                .frame(width: size, height: size)
        } else if let image = AppIconStore.image(icon, size: size, weight: weight ?? .regular) {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .frame(width: size, height: size)
        }
    }
}

private struct ProtocolFolderIconView: View {
    let badge: String
    let size: CGFloat

    var body: some View {
        let scale = size / 20.0
        let folderWidth = 17.0 * scale
        let folderHeight = folderWidth * 0.78
        let strokeWidth = AppIconLineWidth.bySize[size] ?? (1.30 * scale)
        let labelFontSize: CGFloat = {
            if badge.count > 4 {
                return size >= 20 ? (7.5 * scale) : (5.4 * (size / 18.0))
            }
            return 8.5 * scale
        }()

        VStack(spacing: 1.0 * scale) {
            ProtocolFolderOutlineShape()
                .stroke(
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: folderWidth, height: folderHeight)

            Text(badge)
                .font(.system(size: labelFontSize, weight: .bold))
                .kerning(-0.2 * scale)
                .lineLimit(1)
                .fixedSize()
        }
        .fixedSize()
    }
}

private struct ProtocolFolderOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 256.0
        let sy = rect.height / 200.0
        let rScale = min(sx, sy)

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()

        // Folder body (y: 64..184 on 256x200 grid)
        path.move(to: pt(32, 64))
        path.addArc(tangent1End: pt(224, 64), tangent2End: pt(224, 184), radius: 8 * rScale)
        path.addArc(tangent1End: pt(224, 184), tangent2End: pt(32, 184), radius: 7.11 * rScale)
        path.addArc(tangent1End: pt(32, 184), tangent2End: pt(32, 64), radius: 7.4 * rScale)
        path.addLine(to: pt(32, 64))
        path.closeSubpath()

        // Folder tab (y: 32..64 on 256x200 grid)
        path.move(to: pt(32, 64))
        path.addArc(tangent1End: pt(32, 32), tangent2End: pt(96, 32), radius: 8 * rScale)
        path.addArc(tangent1End: pt(96, 32), tangent2End: pt(128, 64), radius: 8 * rScale)
        path.addLine(to: pt(128, 64))

        return path
    }
}

enum AppAccentDuotoneIconMetrics {
    static let baseOpacity = WorkbenchControlMetrics.redesignCardIconAccentBaseOpacity
    static let folderTabOpacity = WorkbenchControlMetrics.redesignCardIconAccentFolderTabOpacity
    static let ankiLinesOpacity = WorkbenchControlMetrics.redesignCardIconAccentAnkiLineOpacity
    static let foregroundOpacity = WorkbenchControlMetrics.redesignCardIconAccentForegroundOpacity

    static let supportedIcons: Set<AppIcon> = [
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
    ]
}

/// Borderless monochrome-duotone large icon rendered with the system accent
/// color tokens (`cardIconAccentBase` / `cardIconAccentFolderTab` /
/// `cardIconAccentAnkiLine` / `cardIconAccentForeground`).
struct AppAccentDuotoneIconView: View {
    let icon: AppIcon
    let size: CGFloat

    private var s: CGFloat {
        size / 256.0
    }

    var body: some View {
        Group {
            switch icon {
            case .folder:
                folderIconView(symbol: .none)
            case .folderWebdav:
                folderIconView(symbol: .text("DAV"))
            case .folderSmb:
                folderIconView(symbol: .text("SMB"))
            case .folderFtp:
                folderIconView(symbol: .text("FTP"))
            case .folderNfs:
                folderIconView(symbol: .text("NFS"))
            case .folderPlus:
                folderIconView(symbol: .plus)
            case .folderMinus:
                folderIconView(symbol: .minus)
            case .video:
                videoIconView
            case .subtitles:
                subtitlesIconView
            case .ankiStar:
                ankiIconView
            case .arrowClockwise:
                indexIconView
            case .pencilSimple:
                renameIconView
            default:
                AppIconImage(icon, size: size)
                    .foregroundStyle(WorkbenchRedesignColors.cardIconAccentForeground)
            }
        }
        .frame(width: size, height: size)
    }

    private enum FolderCenterSymbol {
        case none
        case plus
        case minus
        case text(String)
    }

    private func folderIconView(symbol: FolderCenterSymbol) -> some View {
        ZStack {
            AccentDuotoneFolderTabShape()
                .fill(WorkbenchRedesignColors.cardIconAccentFolderTab)

            AccentDuotoneFolderBodyShape()
                .fill(WorkbenchRedesignColors.cardIconAccentBase)

            switch symbol {
            case .none:
                EmptyView()
            case .plus:
                AccentDuotoneFolderPlusSymbolShape()
                    .stroke(
                        WorkbenchRedesignColors.cardIconAccentForeground,
                        style: StrokeStyle(lineWidth: 15 * s, lineCap: .round)
                    )
            case .minus:
                AccentDuotoneFolderMinusSymbolShape()
                    .stroke(
                        WorkbenchRedesignColors.cardIconAccentForeground,
                        style: StrokeStyle(lineWidth: 15 * s, lineCap: .round)
                    )
            case .text(let badge):
                Text(badge)
                    .font(.system(size: 62 * s, weight: .heavy, design: .rounded))
                    .kerning(1.0 * s)
                    .foregroundStyle(WorkbenchRedesignColors.cardIconAccentForeground)
                    .lineLimit(1)
                    .fixedSize()
                    .position(x: 128 * s, y: 142 * s)
            }
        }
    }

    private var videoIconView: some View {
        ZStack {
            AccentDuotoneMediaRectShape()
                .fill(WorkbenchRedesignColors.cardIconAccentBase)

            AccentDuotonePlayTriangleShape()
                .fill(WorkbenchRedesignColors.cardIconAccentForeground)
        }
    }

    private var subtitlesIconView: some View {
        ZStack {
            AccentDuotoneMediaRectShape()
                .fill(WorkbenchRedesignColors.cardIconAccentBase)

            AccentDuotoneSubtitleBarsShape()
                .stroke(
                    WorkbenchRedesignColors.cardIconAccentForeground,
                    style: StrokeStyle(lineWidth: 20 * s, lineCap: .round)
                )
        }
    }

    private var ankiIconView: some View {
        ZStack {
            AccentDuotoneAnkiCardShape()
                .fill(WorkbenchRedesignColors.cardIconAccentBase)

            AccentDuotoneAnkiLinesShape()
                .stroke(
                    WorkbenchRedesignColors.cardIconAccentAnkiLine,
                    style: StrokeStyle(lineWidth: 15 * s, lineCap: .round)
                )

            AccentDuotoneAnkiStarShape()
                .fill(Color.black)
                .overlay(
                    AccentDuotoneAnkiStarShape()
                        .stroke(
                            Color.black,
                            style: StrokeStyle(
                                lineWidth: 38 * 0.62 * s,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                )
                .blendMode(.destinationOut)

            AccentDuotoneAnkiStarShape()
                .fill(WorkbenchRedesignColors.cardIconAccentForeground)
                .overlay(
                    AccentDuotoneAnkiStarShape()
                        .stroke(
                            WorkbenchRedesignColors.cardIconAccentForeground,
                            style: StrokeStyle(
                                lineWidth: 14 * 0.62 * s,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                )
        }
        .compositingGroup()
    }

    private var indexIconView: some View {
        ZStack {
            AccentDuotoneIndexCircleShape()
                .fill(WorkbenchRedesignColors.cardIconAccentBase)

            AccentDuotoneIndexArrowShape()
                .stroke(
                    WorkbenchRedesignColors.cardIconAccentForeground,
                    style: StrokeStyle(
                        lineWidth: 12.5 * s,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
        }
    }

    private var renameIconView: some View {
        AccentDuotoneRenamePencilShape()
            .fill(WorkbenchRedesignColors.cardIconAccentAnkiLine)
    }
}

private struct AccentDuotoneFolderTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        path.move(to: pt(20, 90))
        path.addLine(to: pt(20, 54))
        path.addArc(
            center: pt(38, 54),
            radius: 18 * s,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addArc(
            tangent1End: pt(98, 36),
            tangent2End: pt(128, 68),
            radius: 16 * s
        )
        path.addLine(to: pt(128, 68))
        path.addLine(to: pt(42, 68))
        path.addArc(
            center: pt(42, 90),
            radius: 22 * s,
            startAngle: .degrees(270),
            endAngle: .degrees(180),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

private struct AccentDuotoneFolderBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        path.move(to: pt(42, 68))
        path.addLine(to: pt(214, 68))
        path.addArc(
            center: pt(214, 90),
            radius: 22 * s,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: pt(236, 194))
        path.addArc(
            center: pt(214, 194),
            radius: 22 * s,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: pt(42, 216))
        path.addArc(
            center: pt(42, 194),
            radius: 22 * s,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: pt(20, 90))
        path.addArc(
            center: pt(42, 90),
            radius: 22 * s,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct AccentDuotoneFolderPlusSymbolShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        path.move(to: pt(128, 112))
        path.addLine(to: pt(128, 172))
        path.move(to: pt(98, 142))
        path.addLine(to: pt(158, 142))
        return path
    }
}

private struct AccentDuotoneFolderMinusSymbolShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        path.move(to: pt(96, 142))
        path.addLine(to: pt(160, 142))
        return path
    }
}

private struct AccentDuotoneMediaRectShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        let mediaRect = CGRect(
            x: rect.minX + 20 * s,
            y: rect.minY + 44 * s,
            width: 216 * s,
            height: 168 * s
        )
        return Path(roundedRect: mediaRect, cornerRadius: 26 * s, style: .circular)
    }
}

private struct AccentDuotonePlayTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        path.move(to: pt(106, 99))
        path.addCurve(to: pt(115, 94.2), control1: pt(106, 94.5), control2: pt(111, 91.8))
        path.addLine(to: pt(156, 120.2))
        path.addCurve(to: pt(156, 130.8), control1: pt(159.8, 122.6), control2: pt(159.8, 128.4))
        path.addLine(to: pt(115, 156.8))
        path.addCurve(to: pt(106, 152), control1: pt(111, 159.2), control2: pt(106, 156.5))
        path.closeSubpath()
        return path
    }
}

private struct AccentDuotoneSubtitleBarsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        path.move(to: pt(56, 132))
        path.addLine(to: pt(80, 132))
        path.move(to: pt(112, 132))
        path.addLine(to: pt(200, 132))
        path.move(to: pt(56, 168))
        path.addLine(to: pt(148, 168))
        path.move(to: pt(180, 168))
        path.addLine(to: pt(200, 168))
        return path
    }
}

private struct AccentDuotoneAnkiCardShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        let cardRect = CGRect(
            x: rect.minX + 24 * s,
            y: rect.minY + 24 * s,
            width: 204 * s,
            height: 204 * s
        )
        return Path(roundedRect: cardRect, cornerRadius: 36 * s, style: .circular)
    }
}

private struct AccentDuotoneAnkiLinesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        path.move(to: pt(56, 70))
        path.addLine(to: pt(90, 70))
        path.move(to: pt(112, 70))
        path.addLine(to: pt(148, 70))
        path.move(to: pt(56, 104))
        path.addLine(to: pt(122, 104))
        path.move(to: pt(56, 142))
        path.addLine(to: pt(100, 142))
        path.move(to: pt(56, 176))
        path.addLine(to: pt(82, 176))
        return path
    }
}

private struct AccentDuotoneAnkiStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func starPt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + (74.0 + x * 0.62) * s,
                y: rect.minY + (72.0 + y * 0.62) * s
            )
        }

        let points: [(CGFloat, CGFloat)] = [
            (107.5, 32),
            (152, 83),
            (218, 68),
            (183, 128),
            (218, 188),
            (152, 173),
            (107.5, 224),
            (101, 156),
            (38, 128),
            (101, 100),
        ]

        var path = Path()
        if let first = points.first {
            path.move(to: starPt(first.0, first.1))
            for point in points.dropFirst() {
                path.addLine(to: starPt(point.0, point.1))
            }
            path.closeSubpath()
        }
        return path
    }
}

private struct AccentDuotoneIndexCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        let circleRect = CGRect(
            x: rect.minX + 18 * s,
            y: rect.minY + 18 * s,
            width: 220 * s,
            height: 220 * s
        )
        return Path(ellipseIn: circleRect)
    }
}

private struct AccentDuotoneIndexArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        path.addArc(
            center: pt(128, 128),
            radius: 48 * s,
            startAngle: .degrees(45),
            endAngle: .degrees(316.3),
            clockwise: false
        )
        path.addLine(to: pt(178, 109))

        path.move(to: pt(145, 109))
        path.addLine(to: pt(178, 109))
        path.addLine(to: pt(178, 76))
        return path
    }
}

private struct AccentDuotoneRenamePencilShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()

        // Bottom-left pencil shaft (with 6-unit diagonal gap from head)
        path.move(to: pt(36, 208))
        path.addLine(to: pt(36, 156.5))
        path.addArc(
            center: pt(48, 156.5),
            radius: 12 * s,
            startAngle: .degrees(180),
            endAngle: .degrees(225),
            clockwise: false
        )
        path.addLine(to: pt(132, 55.5))
        path.addLine(to: pt(200.5, 124))
        path.addLine(to: pt(108, 216.5))
        path.addArc(
            center: pt(99.5, 208),
            radius: 12 * s,
            startAngle: .degrees(45),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: pt(48, 220))
        path.addArc(
            center: pt(48, 208),
            radius: 12 * s,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.closeSubpath()

        // Top-right pencil head (same 44% accent color, separated by diagonal gap)
        path.move(to: pt(144, 43.5))
        path.addLine(to: pt(164, 23.5))
        path.addArc(
            center: pt(175.3137, 34.8137),
            radius: 16 * s,
            startAngle: .degrees(225),
            endAngle: .degrees(315),
            clockwise: false
        )
        path.addLine(to: pt(232.5, 69.3726))
        path.addArc(
            center: pt(221.1863, 80.6863),
            radius: 16 * s,
            startAngle: .degrees(-45),
            endAngle: .degrees(45),
            clockwise: false
        )
        path.addLine(to: pt(212.5, 112))
        path.closeSubpath()

        return path
    }
}

