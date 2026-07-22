import CueSeekerCore
import Foundation

enum ASSPlaybackFontIntentProvider {
    static func requestedFontNames(
        sourcePath: String?,
        renderCacheDatabaseURL: URL?
    ) throws -> [String]? {
        guard let sourcePath,
              let renderCacheDatabaseURL
        else {
            return nil
        }

        let subtitleFile = URL(fileURLWithPath: sourcePath)
        let database = try PlaybackSubtitleDatabase(path: renderCacheDatabaseURL)
        guard try database.hasCurrentASSFontReferenceManifest(forSubtitleFile: subtitleFile) else {
            return nil
        }

        var seenKeys = Set<String>()
        var fontNames: [String] = []
        for reference in try database.assFontReferences(forSubtitleFile: subtitleFile) {
            let key = reference.fontName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(
                    options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                    locale: Locale(identifier: "en_US_POSIX")
                )
            guard !key.isEmpty, !seenKeys.contains(key) else {
                continue
            }

            seenKeys.insert(key)
            fontNames.append(reference.fontName)
        }

        return fontNames
    }
}
