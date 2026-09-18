import Foundation

public enum VideoMatchingError: Error, Equatable, Sendable {
    case directoryEnumerationFailed(String)
    case metadataReadFailed(String)
}

public struct VideoMatcher {
    public static let defaultVideoExtensions = ["mkv", "mp4", "webm", "flv", "avi", "mov"]

    private struct VideoCandidate {
        let url: URL
        let nameAfterRemovingOneExtension: String
        let nameAfterRemovingTwoExtensions: String?
        let extensionPriority: Int
    }

    private let fileManager: FileManager
    private let videoExtensions: [String]

    public init(
        fileManager: FileManager = .default,
        videoExtensions: [String] = Self.defaultVideoExtensions
    ) {
        self.fileManager = fileManager
        self.videoExtensions = videoExtensions.map { $0.lowercased() }
    }

    public func matchingVideo(for subtitleFile: URL) throws -> URL? {
        let directory = subtitleFile.deletingLastPathComponent()
        return matchingVideo(
            for: subtitleFile,
            videoCandidates: try videos(in: directory)
        )
    }

    public func matchingVideos(
        for subtitleFiles: [URL]
    ) throws -> [URL: URL] {
        let filesByDirectory = Dictionary(
            grouping: subtitleFiles
        ) {
            $0.deletingLastPathComponent().standardizedFileURL.path
        }
        var matches: [URL: URL] = [:]
        for files in filesByDirectory.values {
            try Task.checkCancellation()
            guard let first = files.first else {
                continue
            }
            let candidates = try videos(
                in: first.deletingLastPathComponent()
            )
            for subtitleFile in files {
                if let video = matchingVideo(
                    for: subtitleFile,
                    videoCandidates: candidates
                ) {
                    matches[subtitleFile] = video
                }
            }
        }
        return matches
    }

    private func matchingVideo(
        for subtitleFile: URL,
        videoCandidates: [VideoCandidate]
    ) -> URL? {
        let subtitleBaseName = subtitleFile.deletingPathExtension().lastPathComponent
        let subtitleNames = candidateBaseNames(for: subtitleBaseName)
            .map(Self.normalizedName)
        guard let subtitleNameAfterRemovingOneExtension = subtitleNames.first else {
            return nil
        }

        if let match = preferredVideo(
            from: videoCandidates.filter {
                $0.nameAfterRemovingOneExtension == subtitleNameAfterRemovingOneExtension
            }
        ) {
            return match
        }

        if let match = preferredVideo(
            from: videoCandidates.filter {
                $0.nameAfterRemovingTwoExtensions == subtitleNameAfterRemovingOneExtension
            }
        ) {
            return match
        }

        guard subtitleNames.count == 2 else {
            return nil
        }
        let subtitleNameAfterRemovingTwoExtensions = subtitleNames[1]

        if let match = preferredVideo(
            from: videoCandidates.filter {
                $0.nameAfterRemovingOneExtension == subtitleNameAfterRemovingTwoExtensions
            }
        ) {
            return match
        }

        return preferredVideo(
            from: videoCandidates.filter {
                $0.nameAfterRemovingTwoExtensions == subtitleNameAfterRemovingTwoExtensions
            }
        )
    }

    /// Pairs subtitle file names with video file names by the same rules as
    /// `matchingVideos(for:)`, without touching the file system. Every name is
    /// a bare file name from one directory; the result maps each matched
    /// subtitle name to its video name.
    public func matchingVideoNames(
        subtitleFileNames: [String],
        among fileNames: [String]
    ) -> [String: String] {
        let directory = URL(fileURLWithPath: "/")
        let candidates = fileNames.compactMap {
            videoCandidate(fileName: $0, in: directory)
        }
        var matches: [String: String] = [:]
        for subtitleName in subtitleFileNames {
            if let video = matchingVideo(
                for: directory.appendingPathComponent(subtitleName),
                videoCandidates: candidates
            ) {
                matches[subtitleName] = video.lastPathComponent
            }
        }
        return matches
    }

    private func videos(in directory: URL) throws -> [VideoCandidate] {
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsSubdirectoryDescendants]
            )
        } catch {
            throw VideoMatchingError.directoryEnumerationFailed(directory.path)
        }

        return try contents.compactMap { url in
            guard let candidate = videoCandidate(
                fileName: url.lastPathComponent,
                in: directory
            ) else {
                return nil
            }
            let attributes: [FileAttributeKey: Any]
            do {
                attributes = try fileManager.attributesOfItem(
                    atPath: url.path
                )
            } catch {
                throw VideoMatchingError.metadataReadFailed(url.path)
            }
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                return nil
            }
            return candidate
        }
    }

    private func videoCandidate(fileName: String, in directory: URL) -> VideoCandidate? {
        let url = directory.appendingPathComponent(fileName)
        guard let extensionPriority = videoExtensions.firstIndex(
            of: url.pathExtension.lowercased()
        ) else {
            return nil
        }

        let baseNames = candidateBaseNames(
            for: url.deletingPathExtension().lastPathComponent
        ).map(Self.normalizedName)

        guard let nameAfterRemovingOneExtension = baseNames.first else {
            return nil
        }

        return VideoCandidate(
            url: url,
            nameAfterRemovingOneExtension: nameAfterRemovingOneExtension,
            nameAfterRemovingTwoExtensions: baseNames.count == 2 ? baseNames[1] : nil,
            extensionPriority: extensionPriority
        )
    }

    private func preferredVideo(from candidates: [VideoCandidate]) -> URL? {
        candidates.min { lhs, rhs in
            if lhs.extensionPriority != rhs.extensionPriority {
                return lhs.extensionPriority < rhs.extensionPriority
            }

            return Self.normalizedName(lhs.url.lastPathComponent)
                < Self.normalizedName(rhs.url.lastPathComponent)
        }?.url
    }

    private static func normalizedName(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
    }

    public func candidateBaseNames(for baseName: String) -> [String] {
        var candidates = [baseName]

        if let suffixSeparator = baseName.lastIndex(of: "."),
           suffixSeparator != baseName.startIndex {
            let stripped = String(baseName[..<suffixSeparator])
            if !stripped.isEmpty {
                candidates.append(stripped)
            }
        }

        return candidates
    }
}
