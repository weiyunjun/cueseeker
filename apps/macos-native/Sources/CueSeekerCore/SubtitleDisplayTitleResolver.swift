import Foundation

public enum SubtitleDisplayTitleResolver {
    public static func displayTitle(
        forSubtitlePath subtitlePath: String,
        fileManager: FileManager = .default
    ) -> String {
        let subtitleURL = URL(fileURLWithPath: subtitlePath)
        let fallbackTitle = subtitleURL.lastPathComponent
        let parentURL = subtitleURL.deletingLastPathComponent()
        let parentTitle = parentURL.lastPathComponent
        let subtitleExtension = subtitleURL.pathExtension.lowercased()

        guard !parentTitle.isEmpty,
              SubtitleFileScanner.supportedSubtitleExtensions.contains(subtitleExtension)
        else {
            return fallbackTitle
        }

        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .isSymbolicLinkKey
        ]

        let siblings: [URL]
        do {
            siblings = try fileManager.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
        } catch {
            return fallbackTitle
        }

        let sameExtensionSubtitleFiles = siblings.filter { sibling in
            guard sibling.pathExtension.lowercased() == subtitleExtension,
                  let values = try? sibling.resourceValues(forKeys: Set(resourceKeys)),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true
            else {
                return false
            }

            return true
        }
        .sorted(by: finderLikeFilenameSort)

        guard let rankIndex = sameExtensionSubtitleFiles.firstIndex(where: {
            $0.standardizedFileURL.path == subtitleURL.standardizedFileURL.path
        }) else {
            return fallbackTitle
        }

        let rank = rankIndex + 1
        let width = max(2, String(sameExtensionSubtitleFiles.count).count)
        let sequence = String(format: "%0*d", width, rank)
        return "\(parentTitle) - \(sequence)"
    }

    public static func compareDisplayTitles(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.localizedStandardCompare(rhs)
    }

    private static func finderLikeFilenameSort(_ lhs: URL, _ rhs: URL) -> Bool {
        let filenameComparison = lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent)
        if filenameComparison != .orderedSame {
            return filenameComparison == .orderedAscending
        }

        return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
    }
}
