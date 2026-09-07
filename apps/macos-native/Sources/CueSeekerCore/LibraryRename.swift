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
    /// The disk and the database disagree about the files involved, or the
    /// folder is not indexed at all: a new Index has to run first.
    case filesChangedSinceIndex
    /// The new name is already taken, on disk or in the database.
    case destinationExists(name: String)
    /// With the new name the folder's videos and subtitles would pair
    /// differently.
    case pairingWouldChange(name: String)
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
    private struct NamePair: Hashable {
        let subtitle: String
        let video: String
    }

    private let database: IndexingDatabase

    public init(database: IndexingDatabase) {
        self.database = database
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
        let folderURL = URL(fileURLWithPath: folderPath)
        let newPath = (folderPath as NSString).deletingLastPathComponent + "/" + newName
        let newURL = URL(fileURLWithPath: newPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }

        let files = try database.renameFileRecords(underFolderPath: folderPath)
        guard !files.subtitles.isEmpty else {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }
        try requireUnchanged(files.subtitles + files.videos)

        // The whole subtree is paired again the way Index pairs it. Anything
        // the database does not know about, or knows differently, is drift.
        let scannedSubtitles: [URL]
        let diskMatches: [URL: URL]
        do {
            scannedSubtitles = try SubtitleFileScanner().scanSubtitleFilesSafely(in: folderURL)
            diskMatches = try VideoMatcher().matchingVideos(for: scannedSubtitles)
        } catch {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }
        let diskPairs = Set(diskMatches.map {
            NamePair(
                subtitle: Self.canonicalPath($0.key.path),
                video: Self.canonicalPath($0.value.path)
            )
        })
        let databasePairs = Set(
            try database.activeRenamePairs(underFolderPath: folderPath).map {
                NamePair(
                    subtitle: Self.canonicalPath($0.subtitlePath),
                    video: Self.canonicalPath($0.videoPath)
                )
            }
        )
        guard diskPairs == databasePairs else {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }

        try requireDestinationFree(newURL, sameObjectAs: folderURL, name: newName)
        guard try !database.hasRenameRows(atOrUnderPath: newPath) else {
            throw LibraryRenameConflict.destinationExists(name: newName)
        }

        let step = LibraryRenameStep(oldPath: folderPath, newPath: newPath)
        let oldFolderPaths = Set(files.subtitles.map {
            ($0.path as NSString).deletingLastPathComponent
        }).sorted()
        let newFolderPaths = oldFolderPaths.compactMap {
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
        guard let group = try database.renameFileGroup(videoPath: videoPath) else {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }
        let directory = URL(fileURLWithPath: (group.video.path as NSString).deletingLastPathComponent)
        let videoName = (group.video.path as NSString).lastPathComponent
        let subtitleNames = group.subtitles.map {
            URL(fileURLWithPath: $0.path).lastPathComponent
        }
        guard let baseName = LibraryFileGroupNaming.commonBaseName(
            videoName: videoName,
            subtitleNames: subtitleNames
        ) else {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }
        try requireUnchanged([group.video] + group.subtitles)

        let listing = try directoryFileNames(directory)
        let databasePairs = Set(
            try database.activeRenamePairs(inDirectory: directory.path).map {
                NamePair(
                    subtitle: URL(fileURLWithPath: $0.subtitlePath).lastPathComponent,
                    video: URL(fileURLWithPath: $0.videoPath).lastPathComponent
                )
            }
        )
        guard pairs(amongFileNames: listing) == databasePairs else {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }

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
            try requireDestinationFree(
                directory.appendingPathComponent(renamed),
                sameObjectAs: directory.appendingPathComponent(name),
                name: renamed
            )
        }

        let renamedListing = listing.map { renamedNames[$0] ?? $0 }
        let expectedPairs = Set(databasePairs.map {
            NamePair(
                subtitle: renamedNames[$0.subtitle] ?? $0.subtitle,
                video: renamedNames[$0.video] ?? $0.video
            )
        })
        guard pairs(amongFileNames: renamedListing) == expectedPairs else {
            throw LibraryRenameConflict.pairingWouldChange(name: newBaseName)
        }
        for name in groupNames {
            let renamed = renamedNames[name] ?? name
            guard try !database.hasRenameRows(
                atOrUnderPath: directory.path + "/" + renamed
            ) else {
                throw LibraryRenameConflict.destinationExists(name: renamed)
            }
        }

        let steps = groupNames.map { name in
            LibraryRenameStep(
                oldPath: directory.path + "/" + name,
                newPath: directory.path + "/" + (renamedNames[name] ?? name)
            )
        }
        return LibraryRenamePlan(
            request: request,
            steps: steps,
            affectedFolderPaths: [directory.path]
        )
    }

    private func requireUnchanged(_ records: [RenameFileRecord]) throws {
        for record in records {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: record.path),
                  attributes[.type] as? FileAttributeType == .typeRegular,
                  let fileSize = (attributes[.size] as? NSNumber)?.int64Value,
                  let modifiedAt = attributes[.modificationDate] as? Date,
                  record.fileSize == fileSize,
                  let storedModifiedAt = record.modifiedAt,
                  abs(storedModifiedAt - modifiedAt.timeIntervalSince1970) < 0.001
            else {
                throw LibraryRenameConflict.filesChangedSinceIndex
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

    /// The regular, visible files of one directory — what Index sees there.
    private func directoryFileNames(_ directory: URL) throws -> [String] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw LibraryRenameConflict.filesChangedSinceIndex
        }
        return contents.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true
            else {
                return nil
            }
            return url.lastPathComponent
        }
    }

    private func pairs(amongFileNames fileNames: [String]) -> Set<NamePair> {
        let subtitleNames = fileNames.filter {
            SubtitleFileScanner.supportedSubtitleExtensions.contains(
                URL(fileURLWithPath: $0).pathExtension.lowercased()
            )
        }
        let matches = VideoMatcher().matchingVideoNames(
            subtitleFileNames: subtitleNames,
            among: fileNames
        )
        return Set(matches.map { NamePair(subtitle: $0.key, video: $0.value) })
    }

    /// `/var/...` and `/private/var/...` name the same place, and the index
    /// stores both forms — roots as given, files as the enumerator reports
    /// them — so paths are compared in one form. The same rule as the
    /// indexing database's folder path variants.
    static func canonicalPath(_ path: String) -> String {
        path.hasPrefix("/private/var/") ? String(path.dropFirst("/private".count)) : path
    }

    /// `path` moved by the rename of `oldPath` to `newPath`, or nil when the
    /// rename does not touch it. The result keeps the form `path` had.
    static func rewrite(_ path: String, from oldPath: String, to newPath: String) -> String? {
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

    // MARK: - Execution

    /// Renames on disk, then updates the database. A disk failure renames back
    /// what was already done; a database failure renames everything back.
    public func perform(_ plan: LibraryRenamePlan) throws {
        var completed: [LibraryRenameStep] = []
        for step in plan.steps {
            do {
                try FileManager.default.moveItem(atPath: step.oldPath, toPath: step.newPath)
            } catch {
                restore(completed)
                throw LibraryRenameError.renameFailed(path: step.oldPath)
            }
            completed.append(step)
        }

        do {
            try database.applyRename(plan)
        } catch {
            restore(completed)
            throw LibraryRenameError.databaseUpdateFailed(String(describing: error))
        }
    }

    private func restore(_ steps: [LibraryRenameStep]) {
        for step in steps.reversed() {
            try? FileManager.default.moveItem(atPath: step.newPath, toPath: step.oldPath)
        }
    }
}
