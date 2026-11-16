import Combine
import Foundation
import CueSeekerCore

struct CueContentStoreChange: Equatable {
    let revision: UInt64
    let cueIDs: Set<Int64>

    func merging(_ other: CueContentStoreChange) -> CueContentStoreChange {
        CueContentStoreChange(
            revision: max(revision, other.revision),
            cueIDs: cueIDs.union(other.cueIDs)
        )
    }
}

private final class EvictedCueContentStorageBox: @unchecked Sendable {
    private var storage: [Int64: CueContent]

    init(_ storage: consuming [Int64: CueContent]) {
        self.storage = storage
    }

    func release() {
        storage = [:]
    }
}

@MainActor
final class CueContentStore {
    private nonisolated static let asyncBackgroundReleaseThreshold = 1_000
    private nonisolated static let inPlaceRemovalThreshold = 1_000
    private nonisolated static let oversizedCapacityBackgroundThreshold = 4_096

    private(set) var revision: UInt64 = 0
    private var contentByCueID: [Int64: CueContent] = [:]
    let changes = PassthroughSubject<CueContentStoreChange, Never>()

    var count: Int {
        contentByCueID.count
    }

    var cachedCueIDs: [Int64] {
        Array(contentByCueID.keys)
    }

    func content(for cueID: Int64) -> CueContent? {
        contentByCueID[cueID]
    }

    func contents(for cueIDs: [Int64]) -> [CueContent]? {
        var contents: [CueContent] = []
        contents.reserveCapacity(cueIDs.count)
        for cueID in cueIDs {
            guard let content = contentByCueID[cueID] else {
                return nil
            }
            contents.append(content)
        }
        return contents
    }

    @discardableResult
    func install(_ contents: [CueContent], publishesChange: Bool = true) -> Bool {
        guard !contents.isEmpty else { return false }
        if contentByCueID.capacity < contentByCueID.count + contents.count {
            contentByCueID.reserveCapacity(contentByCueID.count + contents.count)
        }
        if !publishesChange {
            var didChange = false
            var didModifyExisting = false
            for content in contents {
                if let existing = contentByCueID[content.cueID] {
                    if existing != content {
                        contentByCueID[content.cueID] = content
                        didChange = true
                        didModifyExisting = true
                    }
                } else {
                    contentByCueID[content.cueID] = content
                    didChange = true
                }
            }
            if didModifyExisting {
                revision &+= 1
            }
            return didChange
        }
        var changedCueIDs: Set<Int64> = []
        changedCueIDs.reserveCapacity(contents.count)
        for content in contents where contentByCueID[content.cueID] != content {
            contentByCueID[content.cueID] = content
            changedCueIDs.insert(content.cueID)
        }
        return publishChange(cueIDs: changedCueIDs)
    }

    @discardableResult
    func installPrebuilt(
        _ prebuilt: [Int64: CueContent],
        publishesChange: Bool = false,
        reclaimingOutside extraRetainedCueIDs: Set<Int64>? = nil
    ) -> Bool {
        guard !prebuilt.isEmpty else {
            if let extraRetainedCueIDs {
                return reclaimUnused(retaining: extraRetainedCueIDs) > 0
            }
            return false
        }
        if publishesChange {
            let didInstall = install(Array(prebuilt.values), publishesChange: true)
            if let extraRetainedCueIDs {
                let removed = reclaimUnused(
                    retaining: extraRetainedCueIDs.union(prebuilt.keys)
                )
                return didInstall || removed > 0
            }
            return didInstall
        }
        if let extraRetainedCueIDs {
            return installPrebuiltReclaiming(
                prebuilt,
                extraRetainedCueIDs: extraRetainedCueIDs
            )
        }
        if contentByCueID.isEmpty {
            contentByCueID = prebuilt
            return true
        }
        if contentByCueID.count <= prebuilt.count {
            var merged = prebuilt
            var didModifyExisting = false
            for (cueID, existingContent) in contentByCueID {
                if let newContent = merged[cueID] {
                    if newContent != existingContent {
                        didModifyExisting = true
                    }
                } else {
                    merged[cueID] = existingContent
                }
            }
            let didChange = didModifyExisting || merged.count != contentByCueID.count
            contentByCueID = merged
            if didModifyExisting {
                revision &+= 1
            }
            return didChange
        }
        var didChange = false
        var didModifyExisting = false
        for (cueID, content) in prebuilt {
            if let existing = contentByCueID[cueID] {
                if existing != content {
                    contentByCueID[cueID] = content
                    didChange = true
                    didModifyExisting = true
                }
            } else {
                contentByCueID[cueID] = content
                didChange = true
            }
        }
        if didModifyExisting {
            revision &+= 1
        }
        return didChange
    }

    @discardableResult
    func reclaimUnused(retaining retainedCueIDs: Set<Int64>) -> Int {
        guard !contentByCueID.isEmpty else {
            return 0
        }
        let previousCount = contentByCueID.count
        let previousCapacity = contentByCueID.capacity

        if retainedCueIDs.isEmpty {
            let box = Self.swapOutStorage(&contentByCueID, replacement: [:])
            Self.releaseEvictedStorage(
                box,
                removedCount: previousCount,
                previousCapacity: previousCapacity
            )
            return previousCount
        }

        if retainedCueIDs.count < previousCount {
            var compacted: [Int64: CueContent] = [:]
            compacted.reserveCapacity(retainedCueIDs.count)
            for cueID in retainedCueIDs {
                if let content = contentByCueID[cueID] {
                    compacted[cueID] = content
                }
            }
            let keptCount = compacted.count
            let removedCount = previousCount - keptCount
            guard removedCount > 0 || Self.shouldCompactCapacity(previousCapacity, keptCount: keptCount) else {
                return 0
            }
            let replacement = keptCount == 0 ? [:] : consume compacted
            let box = Self.swapOutStorage(&contentByCueID, replacement: replacement)
            Self.releaseEvictedStorage(
                box,
                removedCount: removedCount,
                previousCapacity: previousCapacity
            )
            return removedCount
        }

        var keptCount = 0
        var hasStaleKeys = false
        for cueID in contentByCueID.keys {
            if retainedCueIDs.contains(cueID) {
                keptCount += 1
            } else {
                hasStaleKeys = true
            }
        }
        let removedCount = previousCount - keptCount
        guard hasStaleKeys || Self.shouldCompactCapacity(previousCapacity, keptCount: keptCount) else {
            return 0
        }
        if keptCount == 0 {
            let box = Self.swapOutStorage(&contentByCueID, replacement: [:])
            Self.releaseEvictedStorage(
                box,
                removedCount: previousCount,
                previousCapacity: previousCapacity
            )
            return previousCount
        }
        if removedCount < Self.inPlaceRemovalThreshold && !Self.shouldCompactCapacity(previousCapacity, keptCount: keptCount) {
            let staleKeys = contentByCueID.keys.filter { !retainedCueIDs.contains($0) }
            for cueID in staleKeys {
                contentByCueID.removeValue(forKey: cueID)
            }
            return removedCount
        }
        var compacted: [Int64: CueContent] = [:]
        compacted.reserveCapacity(keptCount)
        for (cueID, content) in contentByCueID where retainedCueIDs.contains(cueID) {
            compacted[cueID] = content
        }
        let box = Self.swapOutStorage(&contentByCueID, replacement: consume compacted)
        Self.releaseEvictedStorage(
            box,
            removedCount: removedCount,
            previousCapacity: previousCapacity
        )
        return removedCount
    }

    private func installPrebuiltReclaiming(
        _ prebuilt: [Int64: CueContent],
        extraRetainedCueIDs: Set<Int64>
    ) -> Bool {
        if contentByCueID.isEmpty {
            contentByCueID = prebuilt
            return true
        }
        let previousCount = contentByCueID.count
        let previousCapacity = contentByCueID.capacity
        var merged = prebuilt
        var didModifyExisting = false
        var evictedCount = 0

        if previousCount <= prebuilt.count + extraRetainedCueIDs.count {
            for (cueID, existingContent) in contentByCueID {
                if let newContent = merged[cueID] {
                    if newContent != existingContent {
                        didModifyExisting = true
                    }
                } else if extraRetainedCueIDs.contains(cueID) {
                    merged[cueID] = existingContent
                } else {
                    evictedCount += 1
                }
            }
        } else {
            var keptFromOld = 0
            for (cueID, newContent) in prebuilt {
                if let existingContent = contentByCueID[cueID] {
                    keptFromOld += 1
                    if newContent != existingContent {
                        didModifyExisting = true
                    }
                }
            }
            for cueID in extraRetainedCueIDs where merged[cueID] == nil {
                if let existingContent = contentByCueID[cueID] {
                    keptFromOld += 1
                    merged[cueID] = existingContent
                }
            }
            evictedCount = max(0, previousCount - keptFromOld)
        }

        let nextCount = merged.count
        let box = Self.swapOutStorage(&contentByCueID, replacement: consume merged)
        if didModifyExisting {
            revision &+= 1
        }
        Self.releaseEvictedStorage(
            box,
            removedCount: evictedCount,
            previousCapacity: previousCapacity
        )
        return didModifyExisting || nextCount != previousCount || evictedCount > 0
    }

    private nonisolated static func shouldCompactCapacity(
        _ capacity: Int,
        keptCount: Int
    ) -> Bool {
        capacity > max(64, keptCount * 4)
    }

    private nonisolated static func swapOutStorage(
        _ current: inout [Int64: CueContent],
        replacement: consuming [Int64: CueContent]
    ) -> EvictedCueContentStorageBox {
        var evicted: [Int64: CueContent] = [:]
        swap(&evicted, &current)
        current = replacement
        return EvictedCueContentStorageBox(consume evicted)
    }

    private nonisolated static func releaseEvictedStorage(
        _ box: EvictedCueContentStorageBox,
        removedCount: Int,
        previousCapacity: Int
    ) {
        let shouldOffload = removedCount >= asyncBackgroundReleaseThreshold
            || previousCapacity >= oversizedCapacityBackgroundThreshold
        guard shouldOffload else {
            box.release()
            return
        }
        DispatchQueue.global(qos: .utility).async {
            box.release()
            AppMemoryPressureRelief.relieveAfterLargeResultRelease(
                estimatedReleasedRows: removedCount
            )
        }
    }

    @discardableResult
    func remove(cueIDs: Set<Int64>) -> Bool {
        guard !cueIDs.isEmpty else { return false }
        let removedCueIDs = Set(contentByCueID.keys.filter(cueIDs.contains))
        for cueID in removedCueIDs {
            contentByCueID.removeValue(forKey: cueID)
        }
        return publishChange(cueIDs: removedCueIDs)
    }

    @discardableResult
    func remove(where shouldRemove: (CueContent) -> Bool) -> Bool {
        let removedCueIDs = Set(contentByCueID.compactMap { cueID, content in
            shouldRemove(content) ? cueID : nil
        })
        for cueID in removedCueIDs {
            contentByCueID.removeValue(forKey: cueID)
        }
        return publishChange(cueIDs: removedCueIDs)
    }

    func removeAll() {
        guard !contentByCueID.isEmpty else { return }
        let removedCueIDs = Set(contentByCueID.keys)
        contentByCueID.removeAll(keepingCapacity: true)
        _ = publishChange(cueIDs: removedCueIDs)
    }

    @discardableResult
    private func publishChange(cueIDs: Set<Int64>) -> Bool {
        guard !cueIDs.isEmpty else { return false }
        revision &+= 1
        changes.send(CueContentStoreChange(revision: revision, cueIDs: cueIDs))
        return true
    }
}
