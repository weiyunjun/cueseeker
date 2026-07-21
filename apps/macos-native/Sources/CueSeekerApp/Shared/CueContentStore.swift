import Foundation
import CueSeekerCore

final class CueContentStore {
    private(set) var revision: UInt64 = 0
    private var contentByCueID: [Int64: CueContent] = [:]

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
        var changed = false
        for content in contents where contentByCueID[content.cueID] != content {
            contentByCueID[content.cueID] = content
            changed = true
        }
        if changed {
            revision &+= 1
        }
        return changed
    }

    @discardableResult
    func remove(cueIDs: Set<Int64>) -> Bool {
        guard !cueIDs.isEmpty else { return false }
        let oldCount = contentByCueID.count
        contentByCueID = contentByCueID.filter { !cueIDs.contains($0.key) }
        guard contentByCueID.count != oldCount else { return false }
        revision &+= 1
        return true
    }

    func removeAll() {
        guard !contentByCueID.isEmpty else { return }
        contentByCueID.removeAll(keepingCapacity: true)
        revision &+= 1
    }
}
