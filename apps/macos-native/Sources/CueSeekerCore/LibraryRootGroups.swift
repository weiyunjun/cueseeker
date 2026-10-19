import Foundation

/// How the root folders the reader added stand to each other.
///
/// Folders form a tree, so two roots are either unrelated or one holds the
/// other. Roots that hold each other form a group, and the outermost one
/// speaks for it: it is what gets indexed, what owns the indexed files, and
/// what the Edit tree shows. A group stands where its earliest-added root
/// stands in the list.
public enum LibraryRootGroups {
    /// The outermost root of every group, in group order.
    public static func representatives(of roots: [URL]) -> [URL] {
        var representatives: [URL] = []
        for root in roots {
            let representative = coveringRoot(of: root, in: roots) ?? root
            if !representatives.contains(representative) {
                representatives.append(representative)
            }
        }
        return representatives
    }

    /// The outermost of `roots` that is `folder` or holds it.
    public static func coveringRoot(of folder: URL, in roots: [URL]) -> URL? {
        roots
            .filter { holds($0, folder) }
            .min { $0.mediaPath.count < $1.mediaPath.count }
    }

    /// The groups of `roots` that sit inside `folder` without being it, as
    /// their outermost roots.
    public static func representatives(inside folder: URL, of roots: [URL]) -> [URL] {
        representatives(of: roots).filter {
            holds(folder, $0) && !holds($0, folder)
        }
    }

    /// Whether `folder` is `other` or one of its ancestors. Compared by whole
    /// path components, so `/Media/A` does not hold `/Media/AB`.
    public static func holds(_ folder: URL, _ other: URL) -> Bool {
        guard folder.isWebDAVURL == other.isWebDAVURL,
              folder.isSMBURL == other.isSMBURL else {
            return false
        }
        let folderPath = folder.mediaPath
        let otherPath = other.mediaPath
        if folderPath == otherPath {
            return true
        }
        let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        return otherPath.hasPrefix(prefix)
    }
}
