pub mod subtitle_indexer;
pub mod subtitle_scanner;
pub mod subtitles;
pub mod video_matching;

pub use subtitle_indexer::{
    IndexedSubtitleFile, SubtitleIndexer, SubtitleIndexingFailure, SubtitleIndexingProjection,
    SubtitleIndexingResult,
};
pub use subtitle_scanner::{SubtitleFileScanner, supported_subtitle_extensions};
pub use subtitles::{SubtitleCueGroup, SubtitleCueLine, SubtitleEntry, SubtitleFormat, ass, srt};
pub use video_matching::{VideoMatcher, default_video_extensions};
