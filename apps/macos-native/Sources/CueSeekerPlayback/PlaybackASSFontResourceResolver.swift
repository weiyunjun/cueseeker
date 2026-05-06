import CNativePlayback
import Foundation

enum PlaybackASSFontResourceResolver {
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
    private static let readyMarkerFilename = ".cue-seeker-font-cache-ready"

    static func prepareFontDirectory(
        for source: PlaybackSubtitleSource,
        cacheRoot: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL? {
        let sourceDirectories = try fontSourceDirectories(for: source, fileManager: fileManager)
        let fontFiles = try sourceDirectories.flatMap {
            try fontFileURLs(in: $0, fileManager: fileManager)
        }
        let shouldInspectMatchedVideo = source.matchedVideoURL.map {
            fileManager.fileExists(atPath: $0.path)
        } ?? false

        guard !fontFiles.isEmpty || shouldInspectMatchedVideo else {
            return nil
        }

        let root = try cacheRoot ?? defaultCacheRoot(fileManager: fileManager)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let cacheKey = try cacheKey(
            for: source,
            fontSourceDirectories: sourceDirectories,
            fontFiles: fontFiles,
            fileManager: fileManager
        )
        let targetDirectory = root.appendingPathComponent(cacheKey, isDirectory: true)
        let readyMarker = targetDirectory.appendingPathComponent(readyMarkerFilename)

        if fileManager.fileExists(atPath: readyMarker.path) {
            return containsFontFiles(in: targetDirectory, fileManager: fileManager) ? targetDirectory : nil
        }

        if fileManager.fileExists(atPath: targetDirectory.path) {
            try fileManager.removeItem(at: targetDirectory)
        }
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        var materializedFontCount = 0
        for fontFile in fontFiles {
            try copyFontFile(fontFile, to: targetDirectory, fileManager: fileManager)
            materializedFontCount += 1
        }

        if shouldInspectMatchedVideo, let matchedVideoURL = source.matchedVideoURL {
            do {
                let extractedCount = try SFXMediaFontAttachmentExtractor.extractFontAttachments(
                    fromMediaAtPath: matchedVideoURL.path,
                    toDirectory: targetDirectory.path
                )
                materializedFontCount += extractedCount.intValue
            } catch {
                print("Failed to extract media font attachments: \(error)")
            }
        }

        guard materializedFontCount > 0 || containsFontFiles(in: targetDirectory, fileManager: fileManager) else {
            try? fileManager.removeItem(at: targetDirectory)
            return nil
        }

        try Data().write(to: readyMarker)
        return targetDirectory
    }

    private static func defaultCacheRoot(fileManager: FileManager) throws -> URL {
        guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw PlaybackASSFontResourceResolverError(message: "Could not locate the user cache directory.")
        }

        return cachesDirectory
            .appendingPathComponent("CueSeeker", isDirectory: true)
            .appendingPathComponent("ASSFontResources", isDirectory: true)
    }

    private static func fontSourceDirectories(
        for source: PlaybackSubtitleSource,
        fileManager: FileManager
    ) throws -> [URL] {
        var directories: [URL] = []

        if let fontResourceDirectoryURL = source.fontResourceDirectoryURL,
           isDirectory(fontResourceDirectoryURL, fileManager: fileManager) {
            directories.append(fontResourceDirectoryURL.standardizedFileURL)
        }

        let parentDirectories = [
            source.url.deletingLastPathComponent(),
            source.matchedVideoURL?.deletingLastPathComponent()
        ]
            .compactMap { $0?.standardizedFileURL }
            .uniquedByPath()

        for parentDirectory in parentDirectories {
            for name in conventionalFontDirectoryNames {
                let candidate = parentDirectory.appendingPathComponent(name, isDirectory: true)
                if isDirectory(candidate, fileManager: fileManager) {
                    directories.append(candidate.standardizedFileURL)
                }
            }
        }

        return directories.uniquedByPath()
    }

    private static func fontFileURLs(in directory: URL, fileManager: FileManager) throws -> [URL] {
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

            if supportedFontExtensions.contains(fileURL.pathExtension.lowercased()) {
                files.append(fileURL.standardizedFileURL)
            }
        }

        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private static func copyFontFile(_ fontFile: URL, to directory: URL, fileManager: FileManager) throws {
        let destination = uniqueDestinationURL(
            for: fontFile.lastPathComponent,
            in: directory,
            fileManager: fileManager
        )
        try fileManager.copyItem(at: fontFile, to: destination)
    }

    private static func uniqueDestinationURL(
        for filename: String,
        in directory: URL,
        fileManager: FileManager
    ) -> URL {
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

    private static func sanitizedFilename(_ filename: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-()[] ")
        let sanitizedScalars = filename.unicodeScalars.map {
            allowedCharacters.contains($0) ? Character($0) : "_"
        }
        let sanitized = String(sanitizedScalars)
        return sanitized.isEmpty ? "font.ttf" : sanitized
    }

    private static func containsFontFiles(in directory: URL, fileManager: FileManager) -> Bool {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        for case let fileURL as URL in enumerator {
            guard supportedFontExtensions.contains(fileURL.pathExtension.lowercased()) else {
                continue
            }

            let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues?.isRegularFile == true {
                return true
            }
        }

        return false
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func cacheKey(
        for source: PlaybackSubtitleSource,
        fontSourceDirectories: [URL],
        fontFiles: [URL],
        fileManager: FileManager
    ) throws -> String {
        var hasher = StableStringHasher()
        try hasher.addFileIdentity(source.url, label: "subtitle", fileManager: fileManager)
        if let matchedVideoURL = source.matchedVideoURL {
            try hasher.addFileIdentity(matchedVideoURL, label: "video", fileManager: fileManager)
        }
        for directory in fontSourceDirectories {
            hasher.add("font-directory:\(directory.path)")
        }
        for fontFile in fontFiles {
            try hasher.addFileIdentity(fontFile, label: "font", fileManager: fileManager)
        }

        return String(format: "%016llx", hasher.value)
    }
}

private struct PlaybackASSFontResourceResolverError: LocalizedError {
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
