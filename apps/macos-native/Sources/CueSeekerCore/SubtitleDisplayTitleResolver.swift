import Foundation

public struct SubtitleAlias: Equatable, Sendable {
    public let folderPath: String
    public let folderTitle: String
    public let rank: Int
    public let total: Int
    public let paddedRank: String

    public var displayTitle: String {
        "\(folderTitle) - \(paddedRank)"
    }

    public var episodeLabel: String {
        "Episode \(paddedRank)"
    }
}

public enum SubtitleDisplayTitleResolver {
    public static func displayTitle(
        forSubtitlePath subtitlePath: String,
        fileManager: FileManager = .default
    ) -> String {
        guard let alias = alias(forSubtitlePath: subtitlePath, fileManager: fileManager) else {
            return URL(fileURLWithPath: subtitlePath).lastPathComponent
        }
        return alias.displayTitle
    }

    public static func alias(
        forSubtitlePath subtitlePath: String,
        fileManager: FileManager = .default
    ) -> SubtitleAlias? {
        let subtitleURL = URL(fileURLWithPath: subtitlePath)
        let parentURL = subtitleURL.deletingLastPathComponent()
        let parentTitle = parentURL.lastPathComponent
        let subtitleExtension = subtitleURL.pathExtension.lowercased()

        guard !parentTitle.isEmpty,
              SubtitleFileScanner.supportedSubtitleExtensions.contains(subtitleExtension)
        else {
            return nil
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
            return nil
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
            return nil
        }

        let total = sameExtensionSubtitleFiles.count
        let rank = rankIndex + 1
        let width = max(2, String(total).count)
        let paddedRank = String(format: "%0*d", width, rank)

        return SubtitleAlias(
            folderPath: parentURL.standardizedFileURL.path,
            folderTitle: parentTitle,
            rank: rank,
            total: total,
            paddedRank: paddedRank
        )
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
