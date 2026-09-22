import Foundation

/// A subtitle has no Display Title of its own. Display Title belongs to the
/// video, which Index names when it publishes its core data, and a subtitle
/// takes the one of the video it matches, so a cue, an excerpt and its video
/// always read the same title and nothing looks at the disk to find it. See
/// `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing
/// Database Records.md` and `docs/human/requirements/20260923-Bug-Display
/// Title Computed When Index Publishes Core Data.md`.
public enum SubtitleDisplayTitleResolver {
    /// The Display Title of the subtitle whose id `subtitleFileID` names, as a
    /// SQL expression: its matched video's Display Title.
    static func matchedVideoDisplayTitleSQL(subtitleFileID: String) -> String {
        """
        COALESCE(
            (
                SELECT title_video.display_title
                FROM subtitle_video_matches title_match
                JOIN video_files title_video ON title_video.id = title_match.video_file_id
                WHERE title_match.subtitle_file_id = \(subtitleFileID)
                  AND title_match.is_active = 1
                LIMIT 1
            ),
            ''
        )
        """
    }

    /// Brings every subtitle's search title back in line with its video's
    /// Display Title, on upgrade.
    static func refreshSearchOrderDisplayTitles(on database: SQLiteDatabase) throws {
        let title = matchedVideoDisplayTitleSQL(
            subtitleFileID: "subtitle_search_order_rows.subtitle_file_id"
        )
        try database.execute(
            """
            UPDATE subtitle_search_order_rows
            SET display_title = \(title)
            WHERE display_title IS NOT \(title);
            """
        )
    }

    public static func compareDisplayTitles(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.localizedStandardCompare(rhs)
    }
}
