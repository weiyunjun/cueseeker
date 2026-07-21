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
    func install(_ contents: [CueContent]) -> Bool {
        var changedCueIDs: Set<Int64> = []
        for content in contents where contentByCueID[content.cueID] != content {
            contentByCueID[content.cueID] = content
            changedCueIDs.insert(content.cueID)
        }
        return publishChange(cueIDs: changedCueIDs)
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
