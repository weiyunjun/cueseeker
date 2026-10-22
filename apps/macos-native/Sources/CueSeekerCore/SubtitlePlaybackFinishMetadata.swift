import Foundation

extension IndexingDatabase {
    private struct PlaybackFinishCueGroup {
        let startMilliseconds: Int
        let endMilliseconds: Int
        let styles: Set<String>

        func overlapMilliseconds(with other: PlaybackFinishCueGroup) -> Int {
            min(endMilliseconds, other.endMilliseconds) - max(startMilliseconds, other.startMilliseconds)
        }
    }

    private struct PlaybackFinishCueGroupKey: Hashable {
        let startMilliseconds: Int
        let endMilliseconds: Int
    }

    static func playbackFinishMetadata(
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup]
    ) -> SubtitlePlaybackFinishMetadata {
        var stylesByTimeRange: [PlaybackFinishCueGroupKey: Set<String>] = [:]
        for group in cueGroups {
            let key = PlaybackFinishCueGroupKey(
                startMilliseconds: group.startMilliseconds,
                endMilliseconds: group.endMilliseconds
            )
            stylesByTimeRange[key, default: []].formUnion(
                group.cueLines.compactMap { line in
                    let style = line.sourceStyle?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return style?.isEmpty == true ? nil : style
                }
            )
        }

        let groupedCues = stylesByTimeRange.map { key, styles in
            PlaybackFinishCueGroup(
                startMilliseconds: key.startMilliseconds,
                endMilliseconds: key.endMilliseconds,
                styles: styles
            )
        }

        let lastSubtitleEndMilliseconds = groupedCues.map(\.endMilliseconds).max()
        guard format.usesASSSemantics else {
            return SubtitlePlaybackFinishMetadata(
                primaryStyles: [],
                primaryStyleLastEndMilliseconds: nil,
                lastSubtitleEndMilliseconds: lastSubtitleEndMilliseconds
            )
        }

        var styleCounts: [String: Int] = [:]
        for (index, group) in groupedCues.enumerated() {
            let hasOverlap = groupedCues.indices.contains { otherIndex in
                guard otherIndex != index else {
                    return false
                }

                return group.overlapMilliseconds(with: groupedCues[otherIndex]) >= 1
            }

            guard !hasOverlap else {
                continue
            }

            for style in group.styles {
                styleCounts[style, default: 0] += 1
            }
        }

        guard let primaryStyleCount = styleCounts.values.max(),
              primaryStyleCount > 0
        else {
            return SubtitlePlaybackFinishMetadata(
                primaryStyles: [],
                primaryStyleLastEndMilliseconds: nil,
                lastSubtitleEndMilliseconds: lastSubtitleEndMilliseconds
            )
        }

        let primaryStyles = styleCounts
            .filter { $0.value == primaryStyleCount }
            .map(\.key)
            .sorted()
        let primaryStyleSet = Set(primaryStyles)
        let primaryStyleLastEndMilliseconds = groupedCues
            .filter { !$0.styles.isDisjoint(with: primaryStyleSet) }
            .map(\.endMilliseconds)
            .max()

        return SubtitlePlaybackFinishMetadata(
            primaryStyles: primaryStyles,
            primaryStyleLastEndMilliseconds: primaryStyleLastEndMilliseconds,
            lastSubtitleEndMilliseconds: lastSubtitleEndMilliseconds
        )
    }

    static func encodePrimaryStyles(_ primaryStyles: [String]) throws -> String {
        let data = try JSONEncoder().encode(primaryStyles)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SQLiteDatabaseError.stepFailed("Primary style metadata could not be encoded.")
        }
        return json
    }
}
