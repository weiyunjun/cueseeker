use std::path::{Path, PathBuf};

pub fn default_video_extensions() -> &'static [&'static str] {
    &["mp4", "mkv", "webm", "avi", "mov"]
}

#[derive(Debug, Clone)]
pub struct VideoMatcher {
    video_extensions: Vec<String>,
}

impl Default for VideoMatcher {
    fn default() -> Self {
        Self::new(default_video_extensions())
    }
}

impl VideoMatcher {
    pub fn new(video_extensions: &[&str]) -> Self {
        Self {
            video_extensions: video_extensions
                .iter()
                .map(|extension| extension.to_ascii_lowercase())
                .collect(),
        }
    }

    pub fn matching_video(&self, subtitle_file: &Path) -> Option<PathBuf> {
        let directory = subtitle_file.parent()?;
        let subtitle_base_name = subtitle_file.file_stem()?.to_str()?;

        for base_name in candidate_base_names(subtitle_base_name) {
            for extension in &self.video_extensions {
                let candidate = directory.join(format!("{base_name}.{extension}"));
                if candidate.exists() {
                    return Some(candidate);
                }
            }
        }

        None
    }

    pub fn candidate_base_names(&self, subtitle_base_name: &str) -> Vec<String> {
        candidate_base_names(subtitle_base_name)
    }
}

fn candidate_base_names(subtitle_base_name: &str) -> Vec<String> {
    let mut candidates = vec![subtitle_base_name.to_string()];

    if let Some(dot_index) = subtitle_base_name.rfind('.') {
        let suffix = &subtitle_base_name[dot_index + 1..];
        let stripped = &subtitle_base_name[..dot_index];
        if !stripped.is_empty() && is_simple_language_suffix(suffix) {
            candidates.push(stripped.to_string());
        }
    }

    candidates
}

fn is_simple_language_suffix(suffix: &str) -> bool {
    let mut parts = suffix.split('-');
    let Some(first) = parts.next() else {
        return false;
    };

    if !is_language_part(first) {
        return false;
    }

    match (parts.next(), parts.next()) {
        (None, None) => true,
        (Some(second), None) => is_language_part(second),
        _ => false,
    }
}

fn is_language_part(part: &str) -> bool {
    let length = part.len();
    (2..=5).contains(&length) && part.bytes().all(|byte| byte.is_ascii_alphabetic())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_simple_language_suffixes() {
        let matcher = VideoMatcher::default();

        assert_eq!(matcher.candidate_base_names("Movie"), ["Movie"]);
        assert_eq!(
            matcher.candidate_base_names("Movie.en"),
            ["Movie.en", "Movie"]
        );
        assert_eq!(
            matcher.candidate_base_names("Movie.zh-Hans"),
            ["Movie.zh-Hans", "Movie"]
        );
        assert_eq!(
            matcher.candidate_base_names("Movie.english"),
            ["Movie.english"]
        );
    }
}
