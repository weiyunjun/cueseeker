import CueSeekerCore
import Foundation

enum ASSPlaybackFontIntentProvider {
    static func requestedFontNames(
        sourcePath: String?,
        renderCacheProvider: (any PlaybackSubtitleRenderCacheProviding)?
    ) throws -> [String]? {
        guard let sourcePath,
              let renderCacheProvider
        else {
            return nil
        }

        let subtitleFile = URL.fromMediaPath(sourcePath)
        guard try renderCacheProvider.hasCurrentASSFontReferenceManifest(forSubtitleFile: subtitleFile) else {
            return nil
        }

        var seenKeys = Set<String>()
        var fontNames: [String] = []
        for reference in try renderCacheProvider.assFontReferences(forSubtitleFile: subtitleFile) {
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
