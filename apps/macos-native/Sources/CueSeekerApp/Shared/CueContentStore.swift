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

@MainActor
final class CueContentStore {
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
        publishesChange: Bool = false
    ) -> Bool {
        guard !prebuilt.isEmpty else { return false }
        if publishesChange {
            return install(Array(prebuilt.values), publishesChange: true)
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
