#[derive(Debug, Clone, PartialEq)]
pub enum PlaybackSubtitleSourceFormat {
    Ass,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlaybackSubtitleTimeWindow {
    pub start_milliseconds: i32,
    pub end_milliseconds: i32,
}

impl PlaybackSubtitleTimeWindow {
    pub fn new(start_milliseconds: i32, end_milliseconds: i32) -> Self {
        let start_milliseconds = start_milliseconds.max(0);
        Self {
            start_milliseconds,
            end_milliseconds: end_milliseconds.max(start_milliseconds),
        }
    }

    pub fn overlaps(&self, start_milliseconds: i32, end_milliseconds: i32) -> bool {
        let cue_start_milliseconds = start_milliseconds.max(0);
        let cue_end_milliseconds = end_milliseconds.max(cue_start_milliseconds);

        if cue_start_milliseconds == cue_end_milliseconds {
            return cue_start_milliseconds >= self.start_milliseconds
                && cue_start_milliseconds <= self.end_milliseconds;
        }

        cue_start_milliseconds < self.end_milliseconds
            && cue_end_milliseconds > self.start_milliseconds
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlaybackSubtitleSource {
    pub url: String,
    pub format: PlaybackSubtitleSourceFormat,
    pub matched_video_url: Option<String>,
    pub font_resource_directory_url: Option<String>,
    pub preparation_time_window: Option<PlaybackSubtitleTimeWindow>,
    pub render_cache_database_url: Option<String>,
}

impl PlaybackSubtitleSource {
    fn filling_matched_video_url(self, fallback_video_url: &str) -> Self {
        if self.matched_video_url.is_some() {
            return self;
        }

        Self {
            matched_video_url: Some(fallback_video_url.to_string()),
            ..self
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlaybackRequestInput {
    pub video_url: String,
    pub is_file_url: bool,
    pub video_exists: bool,
    pub start_milliseconds: i32,
    pub subtitle_source: Option<PlaybackSubtitleSource>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlaybackRequest {
    pub video_url: String,
    pub start_milliseconds: i32,
    pub subtitle_source: Option<PlaybackSubtitleSource>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum PlaybackRequestError {
    InvalidVideoUrl(String),
    MissingVideoFile(String),
}

pub fn resolve_playback_request(
    input: PlaybackRequestInput,
) -> Result<PlaybackRequest, PlaybackRequestError> {
    if !input.is_file_url {
        return Err(PlaybackRequestError::InvalidVideoUrl(input.video_url));
    }

    if !input.video_exists {
        return Err(PlaybackRequestError::MissingVideoFile(input.video_url));
    }

    Ok(PlaybackRequest {
        video_url: input.video_url.clone(),
        start_milliseconds: input.start_milliseconds.max(0),
        subtitle_source: input
            .subtitle_source
            .map(|source| source.filling_matched_video_url(&input.video_url)),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn time_window_clamps_start_and_end() {
        let window = PlaybackSubtitleTimeWindow::new(-500, -250);

        assert_eq!(window.start_milliseconds, 0);
        assert_eq!(window.end_milliseconds, 0);
    }

    #[test]
    fn time_window_detects_overlap_like_macos() {
        let window = PlaybackSubtitleTimeWindow::new(2_000, 5_000);

        assert!(!window.overlaps(1_000, 2_000));
        assert!(window.overlaps(1_500, 2_500));
        assert!(window.overlaps(5_000, 5_000));
        assert!(!window.overlaps(5_001, 6_000));
    }
}
