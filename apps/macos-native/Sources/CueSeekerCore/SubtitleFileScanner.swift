import Foundation

public enum SubtitleFileScanningError: Error, Equatable, Sendable {
    case rootIsNotReadableDirectory(String)
    case enumerationFailed(String)
    case metadataReadFailed(String)
}

public struct SubtitleFileScanner {
    public static let supportedSubtitleExtensions: Set<String> = ["srt", "ass", "vtt"]

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scanSRTFiles(in folder: URL) -> [URL] {
        scanSubtitleFiles(in: folder).filter { $0.pathExtension.lowercased() == "srt" }
    }

    public func scanSubtitleFiles(in folder: URL) -> [URL] {
        (try? scanSubtitleFilesSafely(in: folder)) ?? []
    }

    public func validateReadableDirectory(_ folder: URL) throws {
        let standardizedFolder = folder.standardizedFileURL
        guard let values = try? standardizedFolder.resourceValues(forKeys: [.isDirectoryKey]),
              values.isDirectory == true,
              fileManager.isReadableFile(atPath: standardizedFolder.path)
        else {
            throw SubtitleFileScanningError.rootIsNotReadableDirectory(
                standardizedFolder.path
            )
        }
    }

    public func scanSubtitleFilesSafely(in folder: URL) throws -> [URL] {
        try validateReadableDirectory(folder)
        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey
        ]

        var enumerationError: SubtitleFileScanningError?
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: { url, _ in
                enumerationError = .enumerationFailed(url.path)
                return false
            }
        ) else {
            throw SubtitleFileScanningError.enumerationFailed(folder.path)
        }

        var subtitleFiles: [URL] = []

        for case let fileURL as URL in enumerator {
            // A removed Index task stops between files. Returning what was
            // found so far would read as a complete scan and drop the rest.
            try Task.checkCancellation()
            let values: URLResourceValues
            do {
                values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            } catch {
                throw SubtitleFileScanningError.metadataReadFailed(fileURL.path)
            }

            if values.isSymbolicLink == true {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true,
                  Self.supportedSubtitleExtensions.contains(fileURL.pathExtension.lowercased())
            else {
                continue
            }

            subtitleFiles.append(fileURL)
        }

        if let enumerationError {
            throw enumerationError
        }

        return subtitleFiles.sorted { $0.path < $1.path }
    }
}
