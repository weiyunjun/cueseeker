import AppKit
import SwiftUI

/// The dialog layer: Edit Cover, the Excerpt List Editor, Rename, Export to
/// Anki, the Task panel and Confirmation, drawn inside the main window rather
/// than as system sheets. A sheet holds its window's red light and the App's
/// quit, and only a Confirmation may do that — by the App's own rule, not by a
/// sheet.
///
/// Everything the sheet gave a dialog is drawn here instead, as measured from
/// the sheet on macOS 15.5: the veil over the whole window, the dialog centred
/// in it, its corner, edge and shadow, and its motion in and out. The window
/// controls stay above the veil, and the band where the page's top bar lies
/// still moves and zooms the window.
///
/// Only a Confirmation stacks on another dialog. The dialog under it takes a
/// veil of its own, and the page under both stays veiled once, as the nested
/// sheet left it.
///
/// See `docs/human/requirements/20260911-UI-In-Window Dialogs And Only
/// Confirmation Blocks Closing.md`.
struct WorkbenchDialogLayer<Dialogs: View>: View {
    /// The open dialogs, bottom first. A change to it is what animates.
    let dialogIDs: [AnyHashable]
    /// The height of the page's top bar.
    let topBandHeight: CGFloat
    @ViewBuilder let dialogs: () -> Dialogs
    /// A file panel dims the whole window itself, as the sheet over a sheet
    /// did, so the veil steps aside for it and the page is dimmed once.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isSystemSheetAttached) private var isSystemSheetAttached
    @Environment(\.interfaceLayers) private var interfaceLayers

    var body: some View {
        let hasOpenDialogs = !dialogIDs.isEmpty
        let showsScrim = WorkbenchDialogMotion.showsScrim(
            hasOpenDialogs: hasOpenDialogs,
            isSystemSheetAttached: isSystemSheetAttached
        )

        GeometryReader { proxy in
            ZStack {
                // Keep the scrim mounted across open/sheet transitions so toggling
                // `showsScrim` always crossfades opacity smoothly instead of snapping
                // when an attached system sheet begins dismissing.
                WorkbenchRedesignColors.dialogScrim
                    .opacity(showsScrim ? 1 : 0)
                    .allowsHitTesting(hasOpenDialogs)
                    .accessibilityHidden(true)
                    .animation(
                        WorkbenchDialogMotion.scrimAnimation(reducesMotion: reduceMotion),
                        value: showsScrim
                    )
                    .zIndex(0)

                if hasOpenDialogs {
                    // Moving and zooming the window belong to the window, not to
                    // the veil covering the page below. Keeping it separate avoids
                    // tearing down or fading the band during scrim/sheet switches.
                    TitlebarBackgroundView(
                        backgroundColor: Color.clear,
                        onDoubleClickZoom: { window in
                            NotificationCenter.default.post(
                                name: .topbarTitlebarZoomRequested,
                                object: window
                            )
                            return true
                        }
                    )
                    .frame(height: topBandHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(0.5)
                }

                // Isolate the dialog stack animation from scrim/sheet state so
                // system sheet dismissal never interferes with dialog transitions
                // while preserving sibling `.zIndex(level)` ordering inside `dialogs()`.
                ZStack {
                    dialogs()
                }
                .animation(
                    WorkbenchDialogMotion.dialogTransactionAnimation(reducesMotion: reduceMotion),
                    value: dialogIDs
                )
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .environment(\.workbenchDialogLayerSize, proxy.size)
            .environment(
                \.workbenchDialogAvailableSize,
                CGSize(
                    width: max(0, proxy.size.width - 2 * WorkbenchControlMetrics.redesignDialogWindowMargin),
                    height: max(0, proxy.size.height - 2 * WorkbenchControlMetrics.redesignDialogWindowMargin)
                )
            )
        }
        // This is where the dialogs are drawn over the page, so this is where
        // the dialog layer is registered: open while the list has a dialog in
        // it, closed once it is empty. A dialog added to the list needs
        // nothing else to be registered.
        .onAppear {
            interfaceLayers?.setOpen(.dialog, !dialogIDs.isEmpty)
        }
        .onChange(of: dialogIDs) { newDialogIDs in
            if let lastID = newDialogIDs.last {
                DebugInteractionLatencyProbe.beginDialogOpenIfNeeded(
                    dialogID: String(describing: lastID),
                    trigger: "dialog_layer"
                )
            }
        }
        .onChange(of: dialogIDs.isEmpty) { isEmpty in
            interfaceLayers?.setOpen(.dialog, !isEmpty)
        }
    }
}

private struct WorkbenchDialogLayerSizeKey: EnvironmentKey {
    static let defaultValue = CGSize.zero
}

private struct WorkbenchDialogAvailableSizeKey: EnvironmentKey {
    /// Outside the layer nothing narrows a dialog.
    static let defaultValue = CGSize(width: CGFloat.infinity, height: .infinity)
}

private struct IsWorkbenchDialogCoveredKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var workbenchDialogLayerSize: CGSize {
        get { self[WorkbenchDialogLayerSizeKey.self] }
        set { self[WorkbenchDialogLayerSizeKey.self] = newValue }
    }
}

extension EnvironmentValues {
    /// The most a dialog may take: the window less `--spacing-6` on every side.
    var workbenchDialogAvailableSize: CGSize {
        get { self[WorkbenchDialogAvailableSizeKey.self] }
        set { self[WorkbenchDialogAvailableSizeKey.self] = newValue }
    }

    var isWorkbenchDialogCovered: Bool {
        get { self[IsWorkbenchDialogCoveredKey.self] }
        set { self[IsWorkbenchDialogCoveredKey.self] = newValue }
    }
}

extension View {
    /// Sizes a dialog to its width tier, narrowed to what the window leaves it.
    func workbenchDialogWidth(_ width: CGFloat) -> some View {
        modifier(WorkbenchDialogWidth(width: width))
    }
}

private struct WorkbenchDialogWidth: ViewModifier {
    let width: CGFloat
    @Environment(\.workbenchDialogAvailableSize) private var availableSize

    func body(content: Content) -> some View {
        content.frame(width: min(width, availableSize.width), alignment: .topLeading)
    }
}

/// A dialog's header, content and footer, top to bottom. When the three would
/// be taller than `maxHeight`, the header and the footer keep their height and
/// the content, a scroll view, gives up the difference: the title and the
/// buttons stay in view and the content scrolls between them. A scroll view
/// asked for no particular height answers with its content's, so a content
/// that fits takes exactly its own height.
struct WorkbenchDialogColumn: Layout {
    let spacing: CGFloat
    let maxHeight: CGFloat

    struct Cache {
        var width: CGFloat?
        var maxHeight: CGFloat?
        var subviewCount: Int = 0
        var heights: [CGFloat] = []
    }

    func makeCache(subviews _: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width
            ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max()
            ?? 0
        let heights = resolvedHeights(width: width, subviews: subviews, cache: &cache)
        return CGSize(
            width: width,
            height: heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        var y = bounds.minY
        let heights = resolvedHeights(width: bounds.width, subviews: subviews, cache: &cache)
        for (subview, height) in zip(subviews, heights) {
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                proposal: ProposedViewSize(width: bounds.width, height: height)
            )
            y += height + spacing
        }
    }

    private func resolvedHeights(width: CGFloat?, subviews: Subviews, cache: inout Cache) -> [CGFloat] {
        if cache.width == width,
           cache.maxHeight == maxHeight,
           cache.subviewCount == subviews.count,
           cache.heights.count == subviews.count {
            return cache.heights
        }
        var heights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        if heights.count == 3 {
            heights[1] = max(0, min(heights[1], maxHeight - heights[0] - heights[2] - 2 * spacing))
        } else if heights.count == 2 {
            heights[1] = max(0, min(heights[1], maxHeight - heights[0] - spacing))
        }
        cache.width = width
        cache.maxHeight = maxHeight
        cache.subviewCount = subviews.count
        cache.heights = heights
        return heights
    }
}

private extension View {
    /// Centres a dialog on whole points the way the sheet was centred: its
    /// origin, counted from the window's bottom-left, rounded to the nearest
    /// point with halves going up.
    func workbenchDialogCentred(in layer: CGSize) -> some View {
        alignmentGuide(HorizontalAlignment.center) { dialog in
            layer.width / 2 - (((layer.width - dialog.width) / 2).rounded(.toNearestOrAwayFromZero))
        }
        .alignmentGuide(VerticalAlignment.center) { dialog in
            let bottom = ((layer.height - dialog.height) / 2).rounded(.toNearestOrAwayFromZero)
            return layer.height / 2 - (layer.height - dialog.height - bottom)
        }
    }
}

extension View {
    /// Places a dialog in the dialog layer, `level` above the veil. Only a
    /// Confirmation stacks on another dialog, so it alone takes the level
    /// above the rest. A dialog with another one above it is veiled and takes
    /// no input.
    func workbenchDialog(level: Double = 1, isCovered: Bool = false) -> some View {
        modifier(WorkbenchDialogChrome(isCovered: isCovered))
            .transition(.workbenchDialog)
            // A view on its way out loses its place in the stack unless it
            // carries one: the veil would cover a closing dialog, and a closing
            // Confirmation would drop under the Task panel.
            .zIndex(level)
    }
}

/// The corner, edge and shadow the system sheet drew around a dialog. The
/// dialogs draw their own background, and some their own border; the sheet
/// clipped them to its corner, kept a hairline just outside that corner, lit
/// the edge just inside it in dark, and cast the shadow.
private struct WorkbenchDialogChrome: ViewModifier {
    let isCovered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.workbenchDialogLayerSize) private var layerSize

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignDialogCornerRadius,
            style: .circular
        )

        WorkbenchDialogFrame {
            content
                // A dialog is the top layer; its own controls must not read
                // the freeze the dialog itself put on the page below.
                .interfaceLayer(.dialog)
                .environment(\.isWorkbenchDialogCovered, isCovered)
        }
            // What shows of the sheet itself where its whole points outgrow
            // the dialog.
            .background(WorkbenchRedesignColors.bgDialog)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(WorkbenchRedesignColors.dialogEdgeHighlight, lineWidth: 1)
            )
            .overlay(
                shape
                    .fill(WorkbenchRedesignColors.dialogScrim)
                    .opacity(isCovered ? 1 : 0)
                    .allowsHitTesting(isCovered)
                    .animation(
                        WorkbenchDialogMotion.scrimAnimation(reducesMotion: reduceMotion),
                        value: isCovered
                    )
            )
            // One device pixel wide, left showing strictly outside the circular
            // dialog shape so it never overlaps translucent layers behind it.
            .background(
                shape
                    .inset(by: -1 / displayScale)
                    .fill(WorkbenchRedesignColors.dialogOutline)
                    .clipShape(
                        WorkbenchExteriorClipShape(
                            cornerRadius: WorkbenchControlMetrics.redesignDialogCornerRadius,
                            outset: 1 / displayScale + 1,
                            cornerStyle: .circular
                        ),
                        style: FillStyle(eoFill: true)
                    )
            )
            .shadowToken(
                WorkbenchRedesignColors.shadowDialog,
                cornerRadius: WorkbenchControlMetrics.redesignDialogCornerRadius
            )
            // Keep one persistent offscreen compositing group across rest and
            // transition frames so finishing an enter transition never switches
            // composition paths and flashes.
            .compositingGroup()
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            noteSize(proxy.size, isCovered: isCovered)
                        }
                        .onChange(of: proxy.size) { size in
                            noteSize(size, isCovered: isCovered)
                        }
                        .onChange(of: isCovered) { isCovered in
                            noteSize(proxy.size, isCovered: isCovered)
                        }
                }
            )
            .workbenchDialogCentred(in: layerSize)
    }

    /// The window keeps the keyboard inside the top dialog, which it finds
    /// from this size: every dialog is centred in the window.
    private func noteSize(_ size: CGSize, isCovered: Bool) {
        guard !isCovered else {
            return
        }
        interfaceLayers?.topDialogSize = size
    }
}

/// A dialog at its own size, rounded up to whole points with the dialog centred
/// in it, which is the size the sheet window took.
private struct WorkbenchDialogFrame: Layout {
    func sizeThatFits(proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let size = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        return CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        subviews.first?.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: .unspecified
        )
    }
}

/// Tokenized macOS dialog motion and backdrop scrim curves (`Dialog Motion` tokens).
/// Dialogs translate and fade on GPU-backed transitions matching native sheets,
/// falling back to pure opacity fade when Reduce Motion is active.
enum WorkbenchDialogMotion {
    /// --duration-dialog-motion
    static let duration = 0.27
    /// --duration-dialog-fade-in
    static let fadeInDuration = 0.12
    /// --duration-dialog-fade-out
    static let fadeOutDuration = 0.22
    /// --duration-dialog-reduce-motion
    static let reduceMotionDuration = 0.18
    /// --distance-dialog-motion: how far above its place a dialog enters from
    /// and leaves to.
    static let distance: CGFloat = 34
    /// --easing-dialog-enter
    static let enterEasing = UnitBezier(x1: 0.4, y1: 0.2, x2: 0.58, y2: 1)
    /// --easing-dialog-exit
    static let exitEasing = UnitBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1)
    /// --easing-dialog-fade-in
    static let fadeInEasing = UnitBezier(x1: 0, y1: 0, x2: 0.58, y2: 1)
    /// --easing-dialog-fade-out
    static let fadeOutEasing = UnitBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1)
    /// --easing-dialog-scrim
    static let scrimEasing = UnitBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1)
    /// Alias for callers referencing the primary dialog enter curve.
    static let easing = enterEasing

    static var enterAnimation: Animation {
        enterEasing.animation(duration: duration)
    }

    static var exitAnimation: Animation {
        exitEasing.animation(duration: duration)
    }

    static var fadeInAnimation: Animation {
        fadeInEasing.animation(duration: fadeInDuration)
    }

    static var fadeOutAnimation: Animation {
        fadeOutEasing.animation(duration: fadeOutDuration)
    }

    static var reduceMotionAnimation: Animation {
        .easeInOut(duration: reduceMotionDuration)
    }

    static func scrimAnimation(reducesMotion: Bool) -> Animation {
        reducesMotion ? reduceMotionAnimation : scrimEasing.animation(duration: duration)
    }

    static func dialogTransactionAnimation(reducesMotion: Bool) -> Animation {
        reducesMotion ? reduceMotionAnimation : .linear(duration: duration)
    }

    static var animation: Animation {
        dialogTransactionAnimation(reducesMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    static func showsScrim(hasOpenDialogs: Bool, isSystemSheetAttached: Bool) -> Bool {
        hasOpenDialogs && !isSystemSheetAttached
    }
}

/// A CSS `cubic-bezier` timing curve.
struct UnitBezier: Equatable {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double

    func animation(duration: TimeInterval) -> Animation {
        .timingCurve(x1, y1, x2, y2, duration: duration)
    }

    /// The curve's progress at `time`, both from 0 to 1.
    func value(at time: Double) -> Double {
        guard time > 0 else {
            return 0
        }
        guard time < 1 else {
            return 1
        }
        // The curve only moves forward in time, so halving finds the point.
        var lower = 0.0
        var upper = 1.0
        for _ in 0..<24 {
            let middle = (lower + upper) / 2
            if Self.sample(middle, x1, x2) < time {
                lower = middle
            } else {
                upper = middle
            }
        }
        return Self.sample((lower + upper) / 2, y1, y2)
    }

    private static func sample(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
        let inverse = 1 - s
        return 3 * inverse * inverse * s * p1 + 3 * inverse * s * s * p2 + s * s * s
    }
}

extension AnyTransition {
    static var workbenchDialog: AnyTransition {
        workbenchDialog(reducesMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    static func workbenchDialog(reducesMotion: Bool) -> AnyTransition {
        if reducesMotion {
            let fade = AnyTransition.opacity.animation(WorkbenchDialogMotion.reduceMotionAnimation)
            return .asymmetric(insertion: fade, removal: fade)
        }

        let slideTransition = AnyTransition.modifier(
            active: WorkbenchDialogSlideModifier(isActive: true),
            identity: WorkbenchDialogSlideModifier(isActive: false)
        )
        return .asymmetric(
            insertion: slideTransition
                .animation(WorkbenchDialogMotion.enterAnimation)
                .combined(
                    with: .opacity.animation(WorkbenchDialogMotion.fadeInAnimation)
                ),
            removal: slideTransition
                .animation(WorkbenchDialogMotion.exitAnimation)
                .combined(
                    with: .opacity.animation(WorkbenchDialogMotion.fadeOutAnimation)
                )
        )
    }
}

private struct WorkbenchDialogSlideModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.offset(
            y: (isActive && !reduceMotion) ? -WorkbenchDialogMotion.distance : 0
        )
    }
}
