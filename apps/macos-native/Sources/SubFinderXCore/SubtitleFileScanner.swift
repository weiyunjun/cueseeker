import Foundation

public struct SubtitleFileScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scanSRTFiles(in folder: URL) -> [URL] {
        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var subtitleFiles: [URL] = []

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) else {
                continue
            }

            if values.isSymbolicLink == true {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true,
                  fileURL.pathExtension.lowercased() == "srt"
            else {
                continue
            }

            subtitleFiles.append(fileURL)
        }

        return subtitleFiles.sorted { $0.path < $1.path }
    }
}
