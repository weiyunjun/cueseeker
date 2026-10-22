import Foundation

extension SearchDatabase {
    public func searchNavigationSnapshot(
        _ query: String,
        under folders: [URL]? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        anchor: SearchNavigationAnchor,
        radius: Int = 1
    ) throws -> SearchNavigationSnapshot {
        let countPage = try searchPage(
            query,
            limit: 1,
            offset: 0,
            under: folders,
            languageFilter: languageFilter
        )
        let page = if countPage.totalCount <= countPage.results.count {
            countPage
        } else {
            try searchPage(
                query,
                limit: countPage.totalCount,
                offset: 0,
                under: folders,
                languageFilter: languageFilter
            )
        }
        let results = page.results
        let currentIndex = Self.searchNavigationIndex(
            in: results,
            anchor: anchor
        )
        let boundedRadius = max(1, radius)
        let neighborhood: [SubtitleSearchResult]
        if let currentIndex {
            let lowerBound = max(0, currentIndex - boundedRadius)
            let upperBound = min(results.count, currentIndex + boundedRadius + 1)
            neighborhood = Array(results[lowerBound..<upperBound])
        } else {
            neighborhood = Array(results.prefix((boundedRadius * 2) + 1))
        }

        let previous = currentIndex.flatMap { index in
            index > 0 ? results[index - 1] : nil
        }
        let current = currentIndex.map { results[$0] }
        let next = currentIndex.flatMap { index in
            index + 1 < results.count ? results[index + 1] : nil
        }

        return SearchNavigationSnapshot(
            totalCount: page.totalCount,
            currentIndex: currentIndex,
            neighborhood: neighborhood,
            previous: previous,
            current: current,
            next: next
        )
    }

    private static func searchNavigationIndex(
        in results: [SubtitleSearchResult],
        anchor: SearchNavigationAnchor
    ) -> Int? {
        if let videoPath = anchor.videoPath,
           let subtitlePath = anchor.subtitlePath {
            let normalizedVideoPath = URL.fromMediaPath(videoPath).mediaPath
            let normalizedSubtitlePath = URL.fromMediaPath(subtitlePath).mediaPath
            var timeMatchedIndex: Int?

            for (index, result) in results.enumerated() {
                let resultVideoPath = URL.fromMediaPath(result.videoPath).mediaPath
                let resultSubtitlePath = URL.fromMediaPath(result.subtitlePath).mediaPath
                guard resultVideoPath == normalizedVideoPath,
                      resultSubtitlePath == normalizedSubtitlePath,
                      result.startMilliseconds <= anchor.currentMilliseconds
                else {
                    continue
                }

                timeMatchedIndex = index
            }

            if let timeMatchedIndex {
                return timeMatchedIndex
            }
        }

        if let selectedEntryID = anchor.selectedEntryID,
           let selectedIndex = results.firstIndex(where: { $0.entryID == selectedEntryID }) {
            return selectedIndex
        }

        return nil
    }

    private static func searchNavigationIndex(
        in cueIDs: [Int64],
        anchor: SearchNavigationAnchor
    ) -> Int? {
        if let selectedEntryID = anchor.selectedEntryID,
           let selectedSearchRank = anchor.selectedSearchRank,
           cueIDs.indices.contains(selectedSearchRank),
           cueIDs[selectedSearchRank] == selectedEntryID {
            return selectedSearchRank
        }

        if anchor.selectedEntryID == nil,
           let selectedSearchRank = anchor.selectedSearchRank,
           cueIDs.indices.contains(selectedSearchRank) {
            return selectedSearchRank
        }

        if let selectedEntryID = anchor.selectedEntryID,
           let selectedIndex = cueIDs.firstIndex(of: selectedEntryID) {
            return selectedIndex
        }

        return nil
    }

    private static func searchNavigationIndex(
        of cueID: Int64,
        in cueIDs: [Int64],
        preferredSearchRank: Int?
    ) -> Int? {
        if let preferredSearchRank,
           cueIDs.indices.contains(preferredSearchRank),
           cueIDs[preferredSearchRank] == cueID {
            return preferredSearchRank
        }

        if let preferredSearchRank,
           cueIDs.indices.contains(preferredSearchRank) {
            var lowerIndex = preferredSearchRank - 1
            var upperIndex = preferredSearchRank + 1
            while lowerIndex >= 0 || upperIndex < cueIDs.count {
                if upperIndex < cueIDs.count {
                    if cueIDs[upperIndex] == cueID {
                        return upperIndex
                    }
                    upperIndex += 1
                }

                if lowerIndex >= 0 {
                    if cueIDs[lowerIndex] == cueID {
                        return lowerIndex
                    }
                    lowerIndex -= 1
                }
            }
        }

        return cueIDs.firstIndex(of: cueID)
    }
}
