import AppKit
import SwiftUI

struct PlaybackSidebarVirtualList: NSViewRepresentable {
    var rowCount: Int
    var rowHeight: CGFloat
    var rowHeightForRow: ((Int, CGFloat) -> CGFloat)? = nil
    var rowsVersion: Int
    var scrollTargetRow: Int?
    var scrollTargetVersion: Int
    var contentInsets = EdgeInsets(top: 6, leading: 8, bottom: 14, trailing: 8)
    var overscanRows = 4
    var onVisibleRowsChange: (Range<Int>) -> Void = { _ in }
    var rowContent: (Int) -> AnyView

    func makeCoordinator() -> Coordinator {
        Coordinator(
            rowCount: rowCount,
            rowHeight: rowHeight,
            rowHeightForRow: rowHeightForRow,
            rowsVersion: rowsVersion,
            scrollTargetRow: scrollTargetRow,
            scrollTargetVersion: scrollTargetVersion,
            contentInsets: contentInsets,
            overscanRows: overscanRows,
            onVisibleRowsChange: onVisibleRowsChange,
            rowContent: rowContent
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let documentView = PlaybackSidebarVirtualDocumentView()
        documentView.coordinator = context.coordinator
        documentView.frame = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
        scrollView.documentView = documentView
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.attach(scrollView: scrollView, documentView: documentView)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollContentDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        configurePlaybackSidebarScrollView(scrollView)
        context.coordinator.resizeDocument()
        context.coordinator.layoutVisibleRows()
        context.coordinator.applyScrollTargetIfNeeded(force: true)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(
            rowCount: rowCount,
            rowHeight: rowHeight,
            rowHeightForRow: rowHeightForRow,
            rowsVersion: rowsVersion,
            scrollTargetRow: scrollTargetRow,
            scrollTargetVersion: scrollTargetVersion,
            contentInsets: contentInsets,
            overscanRows: overscanRows,
            onVisibleRowsChange: onVisibleRowsChange,
            rowContent: rowContent
        )
        configurePlaybackSidebarScrollView(scrollView)
    }

    @MainActor
    final class Coordinator: NSObject {
        private var rowCount: Int
        private var rowHeight: CGFloat
        private var rowHeightForRow: ((Int, CGFloat) -> CGFloat)?
        private var rowsVersion: Int
        private var scrollTargetRow: Int?
        private var scrollTargetVersion: Int
        private var contentInsets: EdgeInsets
        private var overscanRows: Int
        private var onVisibleRowsChange: (Range<Int>) -> Void
        private var rowContent: (Int) -> AnyView

        private weak var scrollView: NSScrollView?
        private weak var documentView: PlaybackSidebarVirtualDocumentView?
        private var rowHosts: [Int: NSHostingView<AnyView>] = [:]
        private var lastVisibleRows: Range<Int>?
        private var lastAppliedScrollTargetRow: Int?
        private var lastAppliedScrollTargetVersion: Int?
        private var rowOffsetCache: [CGFloat] = []
        private var rowOffsetCacheRowCount = -1
        private var rowOffsetCacheRowsVersion = -1
        private var rowOffsetCacheWidth: CGFloat = -1

        init(
            rowCount: Int,
            rowHeight: CGFloat,
            rowHeightForRow: ((Int, CGFloat) -> CGFloat)?,
            rowsVersion: Int,
            scrollTargetRow: Int?,
            scrollTargetVersion: Int,
            contentInsets: EdgeInsets,
            overscanRows: Int,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            rowContent: @escaping (Int) -> AnyView
        ) {
            self.rowCount = max(0, rowCount)
            self.rowHeight = max(1, rowHeight)
            self.rowHeightForRow = rowHeightForRow
            self.rowsVersion = rowsVersion
            self.scrollTargetRow = scrollTargetRow
            self.scrollTargetVersion = scrollTargetVersion
            self.contentInsets = contentInsets
            self.overscanRows = max(0, overscanRows)
            self.onVisibleRowsChange = onVisibleRowsChange
            self.rowContent = rowContent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(
            scrollView: NSScrollView,
            documentView: PlaybackSidebarVirtualDocumentView
        ) {
            self.scrollView = scrollView
            self.documentView = documentView
        }

        func update(
            rowCount: Int,
            rowHeight: CGFloat,
            rowHeightForRow: ((Int, CGFloat) -> CGFloat)?,
            rowsVersion: Int,
            scrollTargetRow: Int?,
            scrollTargetVersion: Int,
            contentInsets: EdgeInsets,
            overscanRows: Int,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            rowContent: @escaping (Int) -> AnyView
        ) {
            let nextRowCount = max(0, rowCount)
            let nextRowHeight = max(1, rowHeight)
            let rowsChanged = nextRowCount != self.rowCount
                || nextRowHeight != self.rowHeight
                || rowsVersion != self.rowsVersion

            self.rowCount = nextRowCount
            self.rowHeight = nextRowHeight
            self.rowHeightForRow = rowHeightForRow
            self.rowsVersion = rowsVersion
            self.scrollTargetRow = scrollTargetRow
            self.scrollTargetVersion = scrollTargetVersion
            self.contentInsets = contentInsets
            self.overscanRows = max(0, overscanRows)
            self.onVisibleRowsChange = onVisibleRowsChange
            self.rowContent = rowContent

            if rowsChanged {
                invalidateRowGeometryCache()
            }
            resizeDocument()
            if rowsChanged {
                rowHosts.values.forEach { $0.removeFromSuperview() }
                rowHosts.removeAll()
            }
            layoutVisibleRows()
            applyScrollTargetIfNeeded(force: false)
        }

        @objc func scrollContentDidChange() {
            layoutVisibleRows()
        }

        func resizeDocument() {
            guard let scrollView, let documentView else { return }
            let width = max(scrollView.contentSize.width, scrollView.bounds.width)
            let rowWidth = max(0, width - leadingInset - trailingInset)
            let height = max(
                scrollView.contentSize.height,
                documentHeight(rowWidth: rowWidth)
            )
            let nextSize = CGSize(width: width, height: max(1, height))
            guard documentView.frame.size != nextSize else { return }
            documentView.setFrameSize(nextSize)
        }

        func layoutVisibleRows() {
            resizeDocument()
            guard let documentView else { return }

            let visibleRows = visibleRowRange()
            if visibleRows != lastVisibleRows {
                lastVisibleRows = visibleRows
                onVisibleRowsChange(visibleRows)
            }

            let visibleSet = Set(visibleRows)
            let obsoleteRows = rowHosts.keys.filter { !visibleSet.contains($0) }
            for row in obsoleteRows {
                rowHosts[row]?.removeFromSuperview()
                rowHosts.removeValue(forKey: row)
            }

            for row in visibleRows {
                let host: NSHostingView<AnyView>
                if let existingHost = rowHosts[row] {
                    existingHost.rootView = rowContent(row)
                    host = existingHost
                } else {
                    let newHost = NSHostingView(rootView: rowContent(row))
                    newHost.translatesAutoresizingMaskIntoConstraints = true
                    newHost.wantsLayer = true
                    newHost.layer?.masksToBounds = true
                    documentView.addSubview(newHost)
                    rowHosts[row] = newHost
                    host = newHost
                }
                host.frame = rowFrame(row, width: documentView.bounds.width)
            }
        }

        func applyScrollTargetIfNeeded(force: Bool) {
            guard let row = boundedScrollTargetRow(),
                  let scrollView
            else {
                return
            }

            let targetChanged = lastAppliedScrollTargetRow != row
                || lastAppliedScrollTargetVersion != scrollTargetVersion
            guard force || targetChanged else {
                return
            }

            resizeDocument()
            let contentHeight = scrollView.contentView.bounds.height
            let rowWidth = currentRowWidth()
            let targetY = topInset
                + rowTop(row, rowWidth: rowWidth)
                - max(0, (contentHeight - effectiveRowHeight(row, rowWidth: rowWidth)) / 2)
            let maxY = max(0, documentHeight(rowWidth: rowWidth) - contentHeight)
            let clampedY = min(max(0, targetY), maxY)
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: clampedY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            lastAppliedScrollTargetRow = row
            lastAppliedScrollTargetVersion = scrollTargetVersion
            layoutVisibleRows()
        }

        private func visibleRowRange() -> Range<Int> {
            guard rowCount > 0,
                  let scrollView
            else {
                return 0..<0
            }

            let rect = scrollView.contentView.bounds
            let rowWidth = currentRowWidth()
            let lower = rowIndex(atY: rect.minY, rowWidth: rowWidth)
            let upper = rowIndex(atY: max(rect.minY, rect.maxY), rowWidth: rowWidth)
            let lowerBound = max(0, lower - overscanRows)
            let upperBound = min(rowCount, upper + overscanRows + 1)
            return lowerBound < upperBound ? lowerBound..<upperBound : 0..<0
        }

        private func rowIndex(atY y: CGFloat, rowWidth: CGFloat) -> Int {
            guard rowCount > 0 else { return 0 }
            let normalizedY = max(0, y - topInset)
            guard rowHeightForRow != nil else {
                let row = Int((normalizedY / rowHeight).rounded(.down))
                return min(max(0, row), rowCount - 1)
            }

            let offsets = rowOffsets(rowWidth: rowWidth)
            let insertionIndex = firstRowOffsetIndex(greaterThan: normalizedY, in: offsets)
            let row = insertionIndex - 1
            return min(max(0, row), rowCount - 1)
        }

        private func rowFrame(_ row: Int, width: CGFloat) -> CGRect {
            let rowWidth = max(0, width - leadingInset - trailingInset)
            return CGRect(
                x: leadingInset,
                y: topInset + rowTop(row, rowWidth: rowWidth),
                width: rowWidth,
                height: effectiveRowHeight(row, rowWidth: rowWidth)
            )
        }

        private func boundedScrollTargetRow() -> Int? {
            guard rowCount > 0, let scrollTargetRow else { return nil }
            return min(max(0, scrollTargetRow), rowCount - 1)
        }

        private func rowTop(_ row: Int, rowWidth: CGFloat) -> CGFloat {
            guard rowHeightForRow != nil else {
                return CGFloat(row) * rowHeight
            }
            let offsets = rowOffsets(rowWidth: rowWidth)
            guard offsets.indices.contains(row) else {
                return 0
            }
            return offsets[row]
        }

        private func effectiveRowHeight(_ row: Int, rowWidth: CGFloat) -> CGFloat {
            guard row >= 0, row < rowCount else {
                return rowHeight
            }
            return rawRowHeight(row, rowWidth: rowWidth)
        }

        private func rawRowHeight(_ row: Int, rowWidth: CGFloat) -> CGFloat {
            guard let rowHeightForRow else {
                return rowHeight
            }
            return max(1, rowHeightForRow(row, rowWidth))
        }

        private func documentHeight(rowWidth: CGFloat) -> CGFloat {
            guard rowHeightForRow != nil else {
                return topInset + CGFloat(rowCount) * rowHeight + bottomInset
            }
            return topInset + (rowOffsets(rowWidth: rowWidth).last ?? 0) + bottomInset
        }

        private func rowOffsets(rowWidth: CGFloat) -> [CGFloat] {
            let width = max(1, rowWidth)
            if rowOffsetCacheRowCount == rowCount,
               rowOffsetCacheRowsVersion == rowsVersion,
               abs(rowOffsetCacheWidth - width) < 0.5 {
                return rowOffsetCache
            }

            var offsets: [CGFloat] = []
            offsets.reserveCapacity(rowCount + 1)
            var nextOffset: CGFloat = 0
            for row in 0..<rowCount {
                offsets.append(nextOffset)
                nextOffset += rawRowHeight(row, rowWidth: width)
            }
            offsets.append(nextOffset)

            rowOffsetCache = offsets
            rowOffsetCacheRowCount = rowCount
            rowOffsetCacheRowsVersion = rowsVersion
            rowOffsetCacheWidth = width
            return offsets
        }

        private func invalidateRowGeometryCache() {
            rowOffsetCache = []
            rowOffsetCacheRowCount = -1
            rowOffsetCacheRowsVersion = -1
            rowOffsetCacheWidth = -1
        }

        private func firstRowOffsetIndex(greaterThan y: CGFloat, in offsets: [CGFloat]) -> Int {
            var lowerBound = 0
            var upperBound = offsets.count
            while lowerBound < upperBound {
                let middle = lowerBound + (upperBound - lowerBound) / 2
                if offsets[middle] > y {
                    upperBound = middle
                } else {
                    lowerBound = middle + 1
                }
            }
            return lowerBound
        }

        private func currentRowWidth() -> CGFloat {
            guard let scrollView else {
                return max(1, rowHeight)
            }
            let width = max(scrollView.contentSize.width, scrollView.bounds.width)
            return max(1, width - leadingInset - trailingInset)
        }

        private var topInset: CGFloat {
            contentInsets.top
        }

        private var bottomInset: CGFloat {
            contentInsets.bottom
        }

        private var leadingInset: CGFloat {
            contentInsets.leading
        }

        private var trailingInset: CGFloat {
            contentInsets.trailing
        }
    }
}

final class PlaybackSidebarVirtualDocumentView: NSView {
    weak var coordinator: PlaybackSidebarVirtualList.Coordinator?

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        coordinator?.layoutVisibleRows()
    }
}
