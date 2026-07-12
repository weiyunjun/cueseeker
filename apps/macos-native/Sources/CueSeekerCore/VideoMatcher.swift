import Foundation

public struct VideoMatcher {
    public static let defaultVideoExtensions = ["mp4", "mkv", "webm", "avi", "mov"]

    private let fileManager: FileManager
    private let videoExtensions: [String]

    public init(
        fileManager: FileManager = .default,
        videoExtensions: [String] = Self.defaultVideoExtensions
    ) {
        self.fileManager = fileManager
        self.videoExtensions = videoExtensions.map { $0.lowercased() }
    }

    public func matchingVideo(for subtitleFile: URL) -> URL? {
        let directory = subtitleFile.deletingLastPathComponent()
        let subtitleBaseName = subtitleFile.deletingPathExtension().lastPathComponent

        for baseName in candidateBaseNames(for: subtitleBaseName) {
            for fileExtension in videoExtensions {
                let candidate = directory
                    .appendingPathComponent(baseName)
                    .appendingPathExtension(fileExtension)

                if fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }

    public func candidateBaseNames(for subtitleBaseName: String) -> [String] {
        var candidates = [subtitleBaseName]

        if let suffixSeparator = subtitleBaseName.lastIndex(of: "."),
           suffixSeparator != subtitleBaseName.startIndex {
            let stripped = String(subtitleBaseName[..<suffixSeparator])
            if !stripped.isEmpty {
                candidates.append(stripped)
            }
        }

        return candidates
    }
}
