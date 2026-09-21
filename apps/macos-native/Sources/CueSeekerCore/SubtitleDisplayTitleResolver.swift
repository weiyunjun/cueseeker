import Foundation

/// A subtitle has no Display Title of its own. Display Title belongs to the
/// video, which Index names once in the Library rows, and a subtitle takes the
/// one of the video it matches, so a cue, an excerpt and its video always read
/// the same title and nothing looks at the disk to find it. See
/// `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing
/// Database Records.md`.
public enum SubtitleDisplayTitleResolver {
    /// The Display Title of the subtitle whose id `subtitleFileID` names, as a
    /// SQL expression: its matched video's Library title, or the video's name
    /// while that video's Library row is still being built.
    static func matchedVideoDisplayTitleSQL(subtitleFileID: String) -> String {
        """
        COALESCE(
            (
                SELECT lvr.display_title
                FROM subtitle_video_matches title_match
                JOIN video_files title_video ON title_video.id = title_match.video_file_id
                JOIN library_video_rows lvr ON lvr.video_path = title_video.path
                WHERE title_match.subtitle_file_id = \(subtitleFileID)
                  AND title_match.is_active = 1
                LIMIT 1
            ),
            (
                SELECT title_video.video_name
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
    /// Library title, after the Library rows were rebuilt or on upgrade.
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
