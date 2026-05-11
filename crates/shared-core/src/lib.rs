pub mod library;
pub mod playback_intent;
pub mod shiori;
pub mod subtitle_indexer;
pub mod subtitle_scanner;
pub mod subtitle_search;
pub mod subtitles;
pub mod video_matching;

pub use library::{
    LibraryFolderPresentation, LibraryVideo, LibraryVideoPresentation,
    library_presentation_snapshot, library_videos,
};
pub use playback_intent::{
    PlaybackRequest, PlaybackRequestError, PlaybackRequestInput, PlaybackSubtitleSource,
    PlaybackSubtitleSourceFormat, PlaybackSubtitleTimeWindow, resolve_playback_request,
};
pub use shiori::{Shiori, ShioriStore, ShioriUpsert, shiori_cue_lines};
pub use subtitle_indexer::{
    IndexedSubtitleFile, SubtitleIndexer, SubtitleIndexingFailure, SubtitleIndexingProjection,
    SubtitleIndexingResult,
};
pub use subtitle_scanner::{SubtitleFileScanner, supported_subtitle_extensions};
pub use subtitle_search::{SubtitleSearchPage, SubtitleSearchResult, search_projection};
pub use subtitles::{SubtitleCueGroup, SubtitleCueLine, SubtitleEntry, SubtitleFormat, ass, srt};
pub use video_matching::{VideoMatcher, default_video_extensions};
