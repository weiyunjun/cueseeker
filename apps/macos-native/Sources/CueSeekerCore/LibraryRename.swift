import Foundation

/// One in-App rename. Paths are absolute; the rename changes paths only and
/// keeps every LibraryID, VideoID, SubtitleID and CueID.
public enum LibraryRenameRequest: Equatable, Sendable {
    /// Renames the directory at `path` to `newName` inside its parent.
    case folder(path: String, newName: String)
    /// Renames the video at `videoPath` together with every subtitle paired
    /// with it, replacing the base name they share with `newBaseName`.
    case fileGroup(videoPath: String, newBaseName: String)

    /// Whether the rename would move the file at `videoPath`.
    public func involves(videoPath: String) -> Bool {
        switch self {
        case .folder(let path, _):
            return videoPath == path || videoPath.hasPrefix(path + "/")
        case .fileGroup(let ownVideoPath, _):
            return videoPath == ownVideoPath
        }
    }
}

public enum LibraryRenameNameError: Equatable, Sendable {
    case empty
    case unchanged
    case invalid
}

/// The name rules the rename dialog applies before a task is queued.
public enum LibraryRenameNameValidator {
    private static let reservedCharacters = Set("\\/:*?\"<>|".unicodeScalars)
    private static let reservedDeviceNames: Set<String> = {
        var names: Set<String> = ["CON", "PRN", "AUX", "NUL"]
        for number in 1...9 {
            names.insert("COM\(number)")
            names.insert("LPT\(number)")
        }
        return names
    }()

    public static func validate(
        _ newName: String,
        currentName: String
    ) -> LibraryRenameNameError? {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .empty
        }
        guard newName.precomposedStringWithCanonicalMapping
            != currentName.precomposedStringWithCanonicalMapping
        else {
            return .unchanged
        }
        guard !newName.hasPrefix("."),
              !newName.hasSuffix("."),
              !newName.hasSuffix(" ")
        else {
            return .invalid
        }
        guard !newName.unicodeScalars.contains(where: {
            reservedCharacters.contains($0) || $0.value < 0x20 || $0.value == 0x7F
        }) else {
            return .invalid
        }
        let stem = newName.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? newName
        guard !reservedDeviceNames.contains(stem.uppercased()) else {
            return .invalid
        }
        return nil
    }
}

/// The name a video and its subtitles share once each file's last one or two
/// extensions are removed — the part `Rename Files` replaces.
public enum LibraryFileGroupNaming {
    public static func commonBaseName(
        videoName: String,
        subtitleNames: [String]
    ) -> String? {
        let normalizedVideoName = videoName.precomposedStringWithCanonicalMapping
        let normalizedSubtitleNames = subtitleNames.map(\.precomposedStringWithCanonicalMapping)
        let videoStem = (normalizedVideoName as NSString).deletingPathExtension
        for candidate in VideoMatcher().candidateBaseNames(for: videoStem) {
            let isShared = normalizedSubtitleNames.allSatisfy {
                tail(of: $0, after: candidate) != nil
            }
            if isShared {
                return candidate
            }
        }
        return nil
    }

    /// `fileName` with `baseName` replaced by `newBaseName`; nil when the
    /// name is not the base name followed by one or two extensions.
    public static func renamedFileName(
        _ fileName: String,
        baseName: String,
        newBaseName: String
    ) -> String? {
        tail(
            of: fileName.precomposedStringWithCanonicalMapping,
            after: baseName.precomposedStringWithCanonicalMapping
        ).map { newBaseName + "." + $0 }
    }

    /// What follows `baseName` and its dot when `fileName` is that base name
    /// plus one or two non-empty dot-separated components.
    private static func tail(of fileName: String, after baseName: String) -> String? {
        let prefix = baseName + "."
        guard fileName.hasPrefix(prefix) else {
            return nil
        }
        let tail = String(fileName.dropFirst(prefix.count))
        let components = tail.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(components.count),
              components.allSatisfy({ !$0.isEmpty })
        else {
            return nil
        }
        return tail
    }
}

/// Why the conflict check refused a rename. Nothing was changed.
public enum LibraryRenameConflict: Error, Equatable, Sendable {
    /// The folder or one of the paired files to rename does not exist on disk,
    /// or the target is not in the index.
    case filesChangedSinceIndex
    /// The new name is already taken in the same directory, on disk or in the database.
    case destinationExists(name: String)
}

/// Why the execution stage failed. Whatever had been renamed on disk was
/// renamed back.
public enum LibraryRenameError: Error, Equatable, Sendable {
    case renameFailed(path: String)
    case databaseUpdateFailed(String)
}

public struct LibraryRenameStep: Equatable, Sendable {
    public let oldPath: String
    public let newPath: String

    public init(oldPath: String, newPath: String) {
        self.oldPath = oldPath
        self.newPath = newPath
    }
}

/// A rename the conflict check accepted: what moves on disk, in order, and
/// which indexed directories have derived rows to rebuild afterwards, at
/// their old and their new paths.
public struct LibraryRenamePlan: Equatable, Sendable {
    public let request: LibraryRenameRequest
    public let steps: [LibraryRenameStep]
    public let affectedFolderPaths: [String]

    public init(
        request: LibraryRenameRequest,
        steps: [LibraryRenameStep],
        affectedFolderPaths: [String]
    ) {
        self.request = request
        self.steps = steps
        self.affectedFolderPaths = affectedFolderPaths
    }
}

/// Runs the two stages of a rename task against one database: the read-only
/// conflict check, then the disk renames and the database update that either
/// both happen or neither does.
public struct LibraryRenamer: Sendable {
    private let database: IndexingDatabase
    private let webdavClient: WebDAVClient
    private let webdavConfigurationStore: WebDAVConfigurationStore
    private let webdavSubtitleCache: WebDAVSubtitleCache

    public init(
        database: IndexingDatabase,
        webdavClient: WebDAVClient = .shared,
        webdavConfigurationStore: WebDAVConfigurationStore = .shared,
        webdavSubtitleCache: WebDAVSubtitleCache = .shared
    ) {
        self.database = database
        self.webdavClient = webdavClient
        self.webdavConfigurationStore = webdavConfigurationStore
        self.webdavSubtitleCache = webdavSubtitleCache
    }

    // MARK: - Conflict check

    public func checkConflicts(_ request: LibraryRenameRequest) throws -> LibraryRenamePlan {
        switch request {
        case .folder(let path, let newName):
            return try checkFolderRename(path: path, newName: newName, request: request)
        case .fileGroup(let videoPath, let newBaseName):
            return try checkFileGroupRename(
                videoPath: videoPath,
                newBaseName: newBaseName,
                request: request
            )
        }
    }

    private func checkFolderRename(
        path: String,
        newName: String,
        request: LibraryRenameRequest
    ) throws -> LibraryRenamePlan {
        let folderPath = path
        let newPath = Self.replacingLastPathComponent(of: folderPath, with: newName)
        if folderPath.isWebDAVPath {
            guard (try? webdavClient.directoryExists(at: folderPath)) == true else {
                throw LibraryRenameConflict.filesChangedSinceIndex
            }
        } else {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                throw LibraryRenameConflict.filesChangedSinceIndex
            }
        }

        let oldFolderPaths = try database.indexedSubtitleFolderPaths(underFolderPath: folderPath)
        guard !oldFolderPaths.isEmpty else {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }

        if folderPath.isWebDAVPath {
            try requireWebDAVDestinationFree(newPath: newPath, oldPath: folderPath, name: newName)
        } else {
            let folderURL = URL(fileURLWithPath: folderPath)
            let newURL = URL(fileURLWithPath: newPath)
            try requireDestinationFree(newURL, sameObjectAs: folderURL, name: newName)
        }
        if Self.canonicalPath(folderPath) != Self.canonicalPath(newPath) {
            guard try !database.hasRenameRows(atOrUnderPath: newPath) else {
                throw LibraryRenameConflict.destinationExists(name: newName)
            }
        }

        let step = LibraryRenameStep(oldPath: folderPath, newPath: newPath)
        let newFolderPaths = step.oldPath == step.newPath
            ? []
            : oldFolderPaths.compactMap {
                Self.rewrite($0, from: step.oldPath, to: step.newPath)
            }
        return LibraryRenamePlan(
            request: request,
            steps: [step],
            affectedFolderPaths: oldFolderPaths + newFolderPaths
        )
    }

    private func checkFileGroupRename(
        videoPath: String,
        newBaseName: String,
        request: LibraryRenameRequest
    ) throws -> LibraryRenamePlan {
        guard let group = try database.renameFileGroup(videoPath: videoPath),
              !group.subtitles.isEmpty
        else {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }
        let directoryPath = Self.parentPath(of: group.video.path)
        let videoName = Self.lastPathComponent(of: group.video.path)
        let subtitleNames = group.subtitles.map {
            Self.lastPathComponent(of: $0.path)
        }
        guard let baseName = LibraryFileGroupNaming.commonBaseName(
            videoName: videoName,
            subtitleNames: subtitleNames
        ) else {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }
        try requireExistingFiles([group.video] + group.subtitles)

        let groupNames = [videoName] + subtitleNames
        var renamedNames: [String: String] = [:]
        for name in groupNames {
            guard let renamed = LibraryFileGroupNaming.renamedFileName(
                name,
                baseName: baseName,
                newBaseName: newBaseName
            ) else {
                throw LibraryRenameConflict.filesChangedSinceIndex
            }
            renamedNames[name] = renamed
        }
        for name in groupNames {
            let renamed = renamedNames[name] ?? name
            let oldFilePath = directoryPath + "/" + name
            let newFilePath = directoryPath + "/" + renamed
            if directoryPath.isWebDAVPath {
                try requireWebDAVDestinationFree(
                    newPath: newFilePath,
                    oldPath: oldFilePath,
                    name: renamed
                )
            } else {
                let directory = URL(fileURLWithPath: directoryPath)
                try requireDestinationFree(
                    directory.appendingPathComponent(renamed),
                    sameObjectAs: directory.appendingPathComponent(name),
                    name: renamed
                )
            }
            if Self.canonicalPath(oldFilePath) != Self.canonicalPath(newFilePath) {
                guard try !database.hasRenameRows(
                    atOrUnderPath: newFilePath
                ) else {
                    throw LibraryRenameConflict.destinationExists(name: renamed)
                }
            }
        }

        let steps = groupNames.map { name in
            LibraryRenameStep(
                oldPath: directoryPath + "/" + name,
                newPath: directoryPath + "/" + (renamedNames[name] ?? name)
            )
        }
        return LibraryRenamePlan(
            request: request,
            steps: steps,
            affectedFolderPaths: [directoryPath]
        )
    }

    private func requireExistingFiles(_ records: [RenameFileRecord]) throws {
        for record in records {
            if record.path.isWebDAVPath {
                guard (try? webdavClient.fileExists(at: record.path)) == true else {
                    throw LibraryRenameConflict.filesChangedSinceIndex
                }
            } else {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: record.path, isDirectory: &isDirectory),
                      !isDirectory.boolValue
                else {
                    throw LibraryRenameConflict.filesChangedSinceIndex
                }
            }
        }
    }

    /// A destination that exists is a conflict unless it is the source itself,
    /// which is what a volume that ignores case or Unicode normalization
    /// answers for a name that differs only in those.
    private func requireDestinationFree(
        _ destination: URL,
        sameObjectAs source: URL,
        name: String
    ) throws {
        guard FileManager.default.fileExists(atPath: destination.path) else {
            return
        }
        let identity = try? destination.resourceValues(forKeys: [.fileResourceIdentifierKey])
            .fileResourceIdentifier
        let sourceIdentity = try? source.resourceValues(forKeys: [.fileResourceIdentifierKey])
            .fileResourceIdentifier
        guard let identity, let sourceIdentity, identity.isEqual(sourceIdentity) else {
            throw LibraryRenameConflict.destinationExists(name: name)
        }
    }

    private func requireWebDAVDestinationFree(
        newPath: String,
        oldPath: String,
        name: String
    ) throws {
        let normalizedNewName = name.precomposedStringWithCanonicalMapping
        let normalizedOldName = Self.lastPathComponent(of: oldPath).precomposedStringWithCanonicalMapping
        if normalizedNewName == normalizedOldName {
            return
        }
        if let siblings = try? webdavClient.listDirectoryItemsInParent(of: oldPath) {
            let collidesInListing = siblings.keys.contains { existing in
                let normalizedExisting = existing.precomposedStringWithCanonicalMapping
                return normalizedExisting == normalizedNewName && normalizedExisting != normalizedOldName
            }
            if collidesInListing {
                throw LibraryRenameConflict.destinationExists(name: name)
            }
        }
        if normalizedNewName.caseInsensitiveCompare(normalizedOldName) != .orderedSame {
            let existsWithoutSlash = (try? webdavClient.resourceExists(
                at: newPath,
                peerPathInSameDirectory: oldPath,
                addsTrailingSlash: false
            )) == true
            let existsWithSlash = (try? webdavClient.resourceExists(
                at: newPath,
                peerPathInSameDirectory: oldPath,
                addsTrailingSlash: true
            )) == true
            if existsWithoutSlash || existsWithSlash {
                throw LibraryRenameConflict.destinationExists(name: name)
            }
        }
    }

    public static func lastPathComponent(of path: String) -> String {
        if path.isWebDAVPath {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let schemeRange = trimmed.range(of: "://") else {
                return (path as NSString).lastPathComponent
            }
            let afterScheme = trimmed[schemeRange.upperBound...]
            guard let firstSlash = afterScheme.firstIndex(of: "/") else {
                return String(afterScheme)
            }
            var pathPart = String(afterScheme[firstSlash...])
            while pathPart.count > 1 && pathPart.hasSuffix("/") {
                pathPart.removeLast()
            }
            if pathPart == "/" {
                return String(afterScheme[..<firstSlash])
            }
            return pathPart.split(separator: "/").last.map(String.init) ?? pathPart
        }
        return (path as NSString).lastPathComponent
    }

    public static func parentPath(of path: String) -> String {
        if path.isWebDAVPath {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let schemeRange = trimmed.range(of: "://") else {
                return (path as NSString).deletingLastPathComponent
            }
            let schemeAndSlashes = trimmed[..<schemeRange.upperBound]
            let afterScheme = trimmed[schemeRange.upperBound...]
            guard let firstSlash = afterScheme.firstIndex(of: "/") else {
                return trimmed
            }
            let authority = afterScheme[..<firstSlash]
            var pathPart = String(afterScheme[firstSlash...])
            while pathPart.count > 1 && pathPart.hasSuffix("/") {
                pathPart.removeLast()
            }
            guard let lastSlash = pathPart.lastIndex(of: "/"), lastSlash > pathPart.startIndex else {
                return String(schemeAndSlashes) + String(authority)
            }
            return String(schemeAndSlashes) + String(authority) + String(pathPart[..<lastSlash])
        }
        return (path as NSString).deletingLastPathComponent
    }

    public static func replacingLastPathComponent(of path: String, with newName: String) -> String {
        let parent = parentPath(of: path)
        if parent == "/" {
            return "/" + newName
        }
        return parent + "/" + newName
    }

    /// `/var/...` and `/private/var/...` name the same place, and the index
    /// stores both forms — roots as given, files as the enumerator reports
    /// them — so paths are compared in one form. The same rule as the
    /// indexing database's folder path variants.
    static func canonicalPath(_ path: String) -> String {
        if path.isWebDAVPath {
            return URL.fromMediaPath(path).mediaPath
        }
        return path.hasPrefix("/private/var/") ? String(path.dropFirst("/private".count)) : path
    }

    /// `path` moved by the rename of `oldPath` to `newPath`, or nil when the
    /// rename does not touch it. The result keeps the form `path` had.
    public static func rewrite(_ path: String, from oldPath: String, to newPath: String) -> String? {
        let comparablePath = canonicalPath(path)
        let comparableOldPath = canonicalPath(oldPath)
        let remainder: Substring
        if comparablePath == comparableOldPath {
            remainder = ""
        } else if comparablePath.hasPrefix(comparableOldPath + "/") {
            remainder = comparablePath.dropFirst(comparableOldPath.count)
        } else {
            return nil
        }
        let canonicalNewPath = Self.canonicalPath(newPath)
        let replacement = path.hasPrefix("/private/var/") && canonicalNewPath.hasPrefix("/var/")
            ? "/private" + canonicalNewPath
            : canonicalNewPath
        return replacement + remainder
    }

    /// `path` rewritten by the first rename step that matches it, or `path`
    /// unchanged when no step touches it.
    public static func rewrittenPath(_ path: String, steps: [LibraryRenameStep]) -> String {
        for step in steps {
            if let rewritten = rewrite(path, from: step.oldPath, to: step.newPath) {
                return rewritten
            }
        }
        return path
    }

    // MARK: - Execution

    /// Renames on disk or WebDAV, then updates the database. A disk/WebDAV failure
    /// renames back what was already done; a database failure renames everything back.
    public func perform(_ plan: LibraryRenamePlan) throws {
        let isDirectoryRename: Bool
        switch plan.request {
        case .folder:
            isDirectoryRename = true
        case .fileGroup:
            isDirectoryRename = false
        }

        var completed: [LibraryRenameStep] = []
        for step in plan.steps {
            if step.oldPath != step.newPath {
                do {
                    if step.oldPath.isWebDAVPath {
                        try webdavClient.moveItem(
                            fromPath: step.oldPath,
                            toPath: step.newPath,
                            isDirectory: isDirectoryRename
                        )
                    } else {
                        try FileManager.default.moveItem(atPath: step.oldPath, toPath: step.newPath)
                    }
                } catch {
                    restore(completed, isDirectory: isDirectoryRename)
                    throw LibraryRenameError.renameFailed(path: step.oldPath)
                }
            }
            completed.append(step)
        }

        let movedSubtitles: [(oldPath: String, newPath: String)]
        do {
            movedSubtitles = try database.applyRename(plan)
        } catch {
            restore(completed, isDirectory: isDirectoryRename)
            throw LibraryRenameError.databaseUpdateFailed(String(describing: error))
        }

        for subtitleMove in movedSubtitles where subtitleMove.oldPath.isWebDAVPath {
            webdavSubtitleCache.moveCachedSubtitle(
                from: URL.fromMediaPath(subtitleMove.oldPath),
                to: URL.fromMediaPath(subtitleMove.newPath)
            )
        }

        if case .folder = plan.request {
            for step in plan.steps where step.oldPath.isWebDAVPath {
                webdavConfigurationStore.rewriteFolderPathPrefix(
                    from: step.oldPath,
                    to: step.newPath
                )
            }
        }

        if plan.steps.contains(where: { $0.oldPath.isWebDAVPath }) {
            webdavClient.clearResolvedPlayableCache()
        }
    }

    private func restore(_ steps: [LibraryRenameStep], isDirectory: Bool) {
        for step in steps.reversed() where step.oldPath != step.newPath {
            if step.newPath.isWebDAVPath {
                try? webdavClient.moveItem(
                    fromPath: step.newPath,
                    toPath: step.oldPath,
                    isDirectory: isDirectory
                )
            } else {
                try? FileManager.default.moveItem(atPath: step.newPath, toPath: step.oldPath)
            }
        }
    }
}
