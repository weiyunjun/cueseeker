import CoreGraphics
import Foundation
import SwiftUI

enum MenuJitterProbe {
    static let logFilePath = "/Users/weiyunjun/Documents/Code/CueSeeker/logs/menu-jitter.log"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var didInitialize = false
    nonisolated(unsafe) private static var startUptimeSeconds: Double?
    nonisolated(unsafe) private static var lastValues: [String: String] = [:]

    static func log(_ category: String, _ message: String) {
        lock.lock()
        defer { lock.unlock() }
        writeLocked(category: category, message: message)
    }

    static func logIfChanged(key: String, category: String, value: String) {
        lock.lock()
        defer { lock.unlock() }
        guard lastValues[key] != value else {
            return
        }
        let previous = lastValues[key]
        lastValues[key] = value
        if let previous {
            writeLocked(category: category, message: "\(key) CHANGED: [\(previous)] -> [\(value)]")
        } else {
            writeLocked(category: category, message: "\(key) INIT: [\(value)]")
        }
    }

    static func resetKeys(prefix: String) {
        lock.lock()
        defer { lock.unlock() }
        for key in Array(lastValues.keys) where key.hasPrefix(prefix) {
            lastValues.removeValue(forKey: key)
        }
    }

    static func fmt(_ rect: CGRect) -> String {
        String(
            format: "(x:%.2f, y:%.2f, w:%.2f, h:%.2f)",
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height
        )
    }

    static func fmt(_ size: CGSize) -> String {
        String(format: "(w:%.2f, h:%.2f)", size.width, size.height)
    }

    static func fmt(_ point: CGPoint) -> String {
        String(format: "(x:%.2f, y:%.2f)", point.x, point.y)
    }

    private static func writeLocked(category: String, message: String) {
        let nowSeconds = ProcessInfo.processInfo.systemUptime
        let baseSeconds: Double
        if let existing = startUptimeSeconds {
            baseSeconds = existing
        } else {
            startUptimeSeconds = nowSeconds
            baseSeconds = nowSeconds
        }
        let url = URL(fileURLWithPath: logFilePath)
        if !didInitialize {
            didInitialize = true
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let header = "=== MenuJitterProbe started at \(ISO8601DateFormatter().string(from: Date())) ===\n"
            try? header.data(using: .utf8)?.write(to: url)
        }
        let elapsedMs = max(0.0, (nowSeconds - baseSeconds) * 1_000.0)
        let line = String(format: "[+%9.3fms] [%@] %@\n", elapsedMs, category, message)
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}

/// The measurements every menu shares.
enum MenuMetrics {
    /// The ring of space between a menu's edge and its items.
    ///
    /// It no longer stands in for the scrollbar's width. A menu that scrolls
    /// widens by `scrollbarStrip` instead, so this is the gap the items keep
    /// from the menu's edge when nothing scrolls and the gap they keep from the
    /// scrollbar when something does — the same distance either way.
    static let padding: CGFloat = 6

    /// What a menu's scrollbar keeps clear of the menu's own edge, on every
    /// side of its track.
    static let scrollbarOuterGap: CGFloat = 6

    /// How much wider a menu gets while its scrollbar is up: the scrollbar and
    /// the gap outside it. The items keep the width they had.
    static let scrollbarStrip: CGFloat = TableScrollbarPrimitiveMetrics.size
        + scrollbarOuterGap

    /// How tall a menu may grow before its content starts scrolling instead.
    static let maximumHeight: CGFloat = 480
}

/// Lays a menu's items inside the menu's padding, and reserves the strip its
/// scrollbar needs when — and only when — the items outgrow the cap.
///
/// The reservation belongs here rather than around the scroll view. The
/// scrollbar is drawn against the scroll view's own trailing edge, so the room
/// it needs has to come out of the item stack; taking it off the menu's width
/// afterwards would leave the scrollbar sitting over the items. An item's
/// height does not depend on the room reserved beside it, so measuring once is
/// enough and nothing oscillates.
struct MenuItemStack: Layout {
    let padding: CGFloat
    let strip: CGFloat
    let cap: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return .zero
        }
        let wanted = subview.sizeThatFits(.unspecified)
        let contentWidth = ceil(wanted.width)
        let contentHeight = ceil(wanted.height)
        let result = CGSize(
            width: contentWidth + 2 * padding + reserve(forContentHeight: contentHeight),
            height: contentHeight + 2 * padding
        )
        MenuJitterProbe.logIfChanged(
            key: "MenuItemStack.sizeThatFits",
            category: "Layout",
            value: "wanted=\(MenuJitterProbe.fmt(wanted)) result=\(MenuJitterProbe.fmt(result)) cap=\(String(format: "%.2f", cap))"
        )
        return result
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else {
            return
        }
        let wanted = subview.sizeThatFits(.unspecified)
        let contentHeight = ceil(wanted.height)
        let reserved = reserve(forContentHeight: contentHeight)
        let placedSize = CGSize(
            width: max(0, bounds.width - 2 * padding - reserved),
            height: contentHeight
        )
        MenuJitterProbe.logIfChanged(
            key: "MenuItemStack.placeSubviews",
            category: "Layout",
            value: "bounds=\(MenuJitterProbe.fmt(bounds)) wanted=\(MenuJitterProbe.fmt(wanted)) placedSize=\(MenuJitterProbe.fmt(placedSize))"
        )
        subview.place(
            at: CGPoint(x: bounds.minX + padding, y: bounds.minY + padding),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: placedSize.width,
                height: placedSize.height
            )
        )
    }

    private func reserve(forContentHeight height: CGFloat) -> CGFloat {
        height + 2 * padding > floor(cap) ? strip : 0
    }
}

/// Makes a menu as tall as its content, and no taller than the cap.
///
/// A `maxHeight` frame cannot do this. `maxHeight` means "you may grow this
/// large", so a menu sitting in a full-page overlay — every card's right-click
/// menu — grew straight to the cap no matter how few items it had. The menus
/// hung off an AppKit host escaped it only because nothing offers them a height
/// to grow into.
///
/// So the content is asked how tall it wants to be, and is then given that,
/// or the cap, whichever is smaller. The scroll view inside is handed a
/// definite height either way: its own content's height, in which case there is
/// nothing to scroll, or the cap, in which case it scrolls.
struct MenuHeightCap: Layout {
    let height: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return .zero
        }
        let wanted = subview.sizeThatFits(.unspecified)
        let result = CGSize(
            width: ceil(wanted.width),
            height: max(0, min(ceil(wanted.height), floor(height)))
        )
        MenuJitterProbe.logIfChanged(
            key: "MenuHeightCap.sizeThatFits",
            category: "Layout",
            value: "wanted=\(MenuJitterProbe.fmt(wanted)) result=\(MenuJitterProbe.fmt(result)) cap=\(String(format: "%.2f", height))"
        )
        return result
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else {
            return
        }
        MenuJitterProbe.logIfChanged(
            key: "MenuHeightCap.placeSubviews",
            category: "Layout",
            value: "bounds=\(MenuJitterProbe.fmt(bounds))"
        )
        subview.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(bounds.size)
        )
    }
}
