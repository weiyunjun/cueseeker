use std::fs;
use std::path::{Path, PathBuf};

use crate::subtitle_scanner::SubtitleFileScanner;
use crate::subtitles::{SubtitleCueGroup, SubtitleFormat, ass, srt};
use crate::video_matching::VideoMatcher;

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct SubtitleIndexingResult {
    pub scanned_subtitle_files: usize,
    pub indexed_subtitle_files: usize,
    pub indexed_subtitle_entries: usize,
    pub skipped_unchanged_subtitle_files: usize,
    pub skipped_missing_video: usize,
    pub skipped_unreadable_subtitle: usize,
    pub failed_files: Vec<SubtitleIndexingFailure>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SubtitleIndexingFailure {
    pub path: PathBuf,
    pub reason: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct IndexedSubtitleFile {
    pub subtitle_path: PathBuf,
    pub video_path: PathBuf,
    pub format: SubtitleFormat,
    pub cue_groups: Vec<SubtitleCueGroup>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SubtitleIndexingProjection {
    pub result: SubtitleIndexingResult,
    pub indexed_files: Vec<IndexedSubtitleFile>,
}

#[derive(Debug, Clone, Default)]
pub struct SubtitleIndexer {
    scanner: SubtitleFileScanner,
    matcher: VideoMatcher,
}

impl SubtitleIndexer {
    pub fn new(scanner: SubtitleFileScanner, matcher: VideoMatcher) -> Self {
        Self { scanner, matcher }
    }

    pub fn project_folder(&self, folder: &Path) -> SubtitleIndexingProjection {
        let subtitle_files = self.scanner.scan_subtitle_files(folder);
        let mut result = SubtitleIndexingResult {
            scanned_subtitle_files: subtitle_files.len(),
            ..SubtitleIndexingResult::default()
        };
        let mut indexed_files = Vec::new();

        for subtitle_file in subtitle_files {
            let Some(video_file) = self.matcher.matching_video(&subtitle_file) else {
                result.skipped_missing_video += 1;
                continue;
            };

            let contents = match fs::read_to_string(&subtitle_file) {
                Ok(contents) => contents,
                Err(_) => {
                    result.skipped_unreadable_subtitle += 1;
                    result.failed_files.push(SubtitleIndexingFailure {
                        path: subtitle_file,
                        reason: "Subtitle file could not be read.".to_string(),
                    });
                    continue;
                }
            };

            let Some(format) = subtitle_format(&subtitle_file) else {
                continue;
            };

            let cue_groups = match format {
                SubtitleFormat::Srt => srt::parse_cue_groups(&contents),
                SubtitleFormat::Ass => ass::parse_cue_groups(&contents),
            };

            result.indexed_subtitle_files += 1;
            result.indexed_subtitle_entries += cue_groups.len();
            indexed_files.push(IndexedSubtitleFile {
                subtitle_path: subtitle_file,
                video_path: video_file,
                format,
                cue_groups,
            });
        }

        SubtitleIndexingProjection {
            result,
            indexed_files,
        }
    }
}

fn subtitle_format(path: &Path) -> Option<SubtitleFormat> {
    match path.extension()?.to_str()?.to_ascii_lowercase().as_str() {
        "srt" => Some(SubtitleFormat::Srt),
        "ass" => Some(SubtitleFormat::Ass),
        _ => None,
    }
}
