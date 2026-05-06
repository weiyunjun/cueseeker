import CNativePlayback
import CueSeekerCore
import Foundation

public struct PlaybackASSFontResourceIndexingResult: Equatable, Sendable {
    public var indexedManifests = 0
    public var readyWithFonts = 0
    public var readyWithoutFonts = 0
    public var failedManifests = 0
    public var skippedUnchangedManifests = 0
}

public struct PlaybackASSFontResourceIndexer {
    private static let conventionalFontDirectoryNames = [
        "Fonts",
        "fonts",
        "Font",
        "font",
        "FONTS",
        "FONT"
    ]
    private static let supportedFontExtensions: Set<String> = [
        "ttf",
        "otf",
        "ttc",
        "otc",
        "woff",
        "woff2"
    ]
    private static let attachmentContainerExtensions: Set<String> = [
        "mkv",
        "mka",
        "mks",
        "webm"
    ]
    private let cacheRoot: URL?
    private let fileManager: FileManager

    public init(cacheRoot: URL? = nil, fileManager: FileManager = .default) {
        self.cacheRoot = cacheRoot
        self.fileManager = fileManager
    }

    public func index(folder: URL, into database: SubtitleDatabase) throws -> PlaybackASSFontResourceIndexingResult {
        try database.migrate()

        var result = PlaybackASSFontResourceIndexingResult()
        let folderPathPrefixes = Self.folderPathPrefixes(for: folder)
        let files = try database.subtitleFiles().filter { metadata in
            metadata.subtitleFormat == .ass
                && metadata.videoPath != nil
                && folderPathPrefixes.contains { metadata.subtitlePath.hasPrefix($0) }
        }

        for metadata in files {
            guard let videoPath = metadata.videoPath else {
                continue
            }

            let subtitleFile = URL(fileURLWithPath: metadata.subtitlePath)
            let videoFile = URL(fileURLWithPath: videoPath)
            let signature = try resourceSignature(subtitleFile: subtitleFile, videoFile: videoFile)

            if let existing = try database.assFontResourceManifest(
                forSubtitleFile: subtitleFile,
                videoFile: videoFile
            ), existing.resourceSignature == signature, isUsableCachedManifest(existing) {
                result.skippedUnchangedManifests += 1
                continue
            }

            let manifest = prepareManifest(
                subtitleFile: subtitleFile,
                videoFile: videoFile,
                resourceSignature: signature
            )

            try database.upsertASSFontResourceManifest(
                subtitleFile: subtitleFile,
                videoFile: videoFile,
                status: manifest.status,
                fontsDirectory: manifest.fontsDirectory,
                resourceSignature: signature,
                errorMessage: manifest.errorMessage
            )

            result.indexedManifests += 1
            switch manifest.status {
            case .readyWithFonts:
                result.readyWithFonts += 1
            case .readyWithoutFonts:
                result.readyWithoutFonts += 1
            case .failed:
                result.failedManifests += 1
            }
        }

        return result
    }

    private func prepareManifest(
        subtitleFile: URL,
        videoFile: URL,
        resourceSignature: String
    ) -> PreparedFontManifest {
        do {
            let sourceDirectories = try fontSourceDirectories(subtitleFile: subtitleFile, videoFile: videoFile)
            let discoveredFontFiles = try sourceDirectories.flatMap { try fontFiles(in: $0) }
            let shouldInspectAttachments = Self.shouldInspectAttachments(in: videoFile)

            guard !discoveredFontFiles.isEmpty || shouldInspectAttachments else {
                return PreparedFontManifest(status: .readyWithoutFonts, fontsDirectory: nil, errorMessage: nil)
            }

            let targetDirectory = try preparedFontDirectory(for: resourceSignature)
            if fileManager.fileExists(atPath: targetDirectory.path) {
                try fileManager.removeItem(at: targetDirectory)
            }
            try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

            var materializedFontCount = 0
            for fontFile in discoveredFontFiles {
                try copyFontFile(fontFile, to: targetDirectory)
                materializedFontCount += 1
            }

            var extractionError: String?
            if shouldInspectAttachments {
                do {
                    let extractedCount = try SFXMediaFontAttachmentExtractor.extractFontAttachments(
                        fromMediaAtPath: videoFile.path,
                        toDirectory: targetDirectory.path
                    )
                    materializedFontCount += extractedCount.intValue
                } catch {
                    extractionError = error.localizedDescription
                }
            }

            if materializedFontCount > 0 {
                return PreparedFontManifest(
                    status: .readyWithFonts,
                    fontsDirectory: targetDirectory,
                    errorMessage: extractionError
                )
            }

            try? fileManager.removeItem(at: targetDirectory)
            if let extractionError {
                return PreparedFontManifest(status: .failed, fontsDirectory: nil, errorMessage: extractionError)
            }
            return PreparedFontManifest(status: .readyWithoutFonts, fontsDirectory: nil, errorMessage: nil)
        } catch {
            return PreparedFontManifest(status: .failed, fontsDirectory: nil, errorMessage: error.localizedDescription)
        }
    }

    private func isUsableCachedManifest(_ manifest: ASSFontResourceManifest) -> Bool {
        switch manifest.status {
        case .readyWithoutFonts:
            return true
        case .failed:
            return false
        case .readyWithFonts:
            guard let fontsDirectoryPath = manifest.fontsDirectoryPath else {
                return false
            }

            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: fontsDirectoryPath, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    private func fontSourceDirectories(subtitleFile: URL, videoFile: URL) throws -> [URL] {
        let parentDirectories = [
            subtitleFile.deletingLastPathComponent(),
            videoFile.deletingLastPathComponent()
        ]
            .map(\.standardizedFileURL)
            .uniquedByPath()
        var directories: [URL] = []

        for parentDirectory in parentDirectories {
            for name in Self.conventionalFontDirectoryNames {
                let candidate = parentDirectory.appendingPathComponent(name, isDirectory: true)
                if isDirectory(candidate) {
                    directories.append(candidate.standardizedFileURL)
                }
            }
        }

        return directories.uniquedByPath()
    }

    private func fontFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else {
                continue
            }

            if Self.supportedFontExtensions.contains(fileURL.pathExtension.lowercased()) {
                files.append(fileURL.standardizedFileURL)
            }
        }

        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func resourceSignature(subtitleFile: URL, videoFile: URL) throws -> String {
        var hasher = StableStringHasher()
        try hasher.addFileIdentity(subtitleFile, label: "subtitle", fileManager: fileManager)
        try hasher.addFileIdentity(videoFile, label: "video", fileManager: fileManager)

        let sourceDirectories = try fontSourceDirectories(subtitleFile: subtitleFile, videoFile: videoFile)
        for directory in sourceDirectories {
            hasher.add("font-directory:\(directory.path)")
        }
        for fontFile in try sourceDirectories.flatMap({ try fontFiles(in: $0) }) {
            try hasher.addFileIdentity(fontFile, label: "font", fileManager: fileManager)
        }
        hasher.add("extractor-version:1")

        return String(format: "%016llx", hasher.value)
    }

    private func preparedFontDirectory(for resourceSignature: String) throws -> URL {
        let root: URL
        if let cacheRoot {
            root = cacheRoot
        } else {
            guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                throw PlaybackASSFontResourceIndexerError(message: "Could not locate the user cache directory.")
            }
            root = cachesDirectory
                .appendingPathComponent("CueSeeker", isDirectory: true)
                .appendingPathComponent("ASSFontResources", isDirectory: true)
        }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(resourceSignature, isDirectory: true)
    }

    private func copyFontFile(_ fontFile: URL, to directory: URL) throws {
        let destination = uniqueDestinationURL(for: fontFile.lastPathComponent, in: directory)
        try fileManager.copyItem(at: fontFile, to: destination)
    }

    private func uniqueDestinationURL(for filename: String, in directory: URL) -> URL {
        let safeFilename = sanitizedFilename(filename)
        var candidate = directory.appendingPathComponent(safeFilename)
        guard fileManager.fileExists(atPath: candidate.path) else {
            return candidate
        }

        let baseName = (safeFilename as NSString).deletingPathExtension
        let pathExtension = (safeFilename as NSString).pathExtension
        var index = 2
        while true {
            let numberedName = pathExtension.isEmpty
                ? "\(baseName)-\(index)"
                : "\(baseName)-\(index).\(pathExtension)"
            candidate = directory.appendingPathComponent(numberedName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func sanitizedFilename(_ filename: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-()[] ")
        let sanitizedScalars = filename.unicodeScalars.map {
            allowedCharacters.contains($0) ? Character($0) : "_"
        }
        let sanitized = String(sanitizedScalars)
        return sanitized.isEmpty ? "font.ttf" : sanitized
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func shouldInspectAttachments(in videoFile: URL) -> Bool {
        attachmentContainerExtensions.contains(videoFile.pathExtension.lowercased())
    }

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        let folder = folder.standardizedFileURL
        let path = folder.path
        return [path.hasSuffix("/") ? path : path + "/"]
    }
}

private struct PreparedFontManifest {
    let status: ASSFontResourceStatus
    let fontsDirectory: URL?
    let errorMessage: String?
}

private struct PlaybackASSFontResourceIndexerError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private struct StableStringHasher {
    private(set) var value: UInt64 = 0xcbf29ce484222325

    mutating func add(_ string: String) {
        for byte in string.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x100000001b3
        }
    }

    mutating func addFileIdentity(_ url: URL, label: String, fileManager: FileManager) throws {
        add("\(label):\(url.standardizedFileURL.path)")

        guard fileManager.fileExists(atPath: url.path) else {
            add(":missing")
            return
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] {
            add(":size=\(size)")
        }
        if let modifiedAt = attributes[.modificationDate] as? Date {
            add(":mtime=\(modifiedAt.timeIntervalSince1970)")
        }
    }
}

private extension Array where Element == URL {
    func uniquedByPath() -> [URL] {
        var seen: Set<String> = []
        var urls: [URL] = []

        for url in self {
            let path = url.standardizedFileURL.path
            if seen.insert(path).inserted {
                urls.append(url)
            }
        }

        return urls
    }
}
