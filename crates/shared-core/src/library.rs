use std::cmp::Ordering;
use std::collections::HashMap;
use std::path::Path;

use crate::subtitles::SubtitleFormat;

#[derive(Debug, Clone, PartialEq)]
pub struct LibraryVideo {
    pub video_path: String,
    pub video_name: String,
    pub duration: Option<f64>,
    pub subtitle_path: String,
    pub subtitle_format: SubtitleFormat,
}

#[derive(Debug, Clone, PartialEq)]
pub struct LibraryVideoPresentation {
    pub video_path: String,
    pub video_name: String,
    pub duration: Option<f64>,
    pub subtitle_path: String,
    pub subtitle_format: SubtitleFormat,
    pub display_title: String,
    pub file_extension: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct LibraryFolderPresentation {
    pub folder_path: String,
    pub folder_title: String,
    pub videos: Vec<LibraryVideoPresentation>,
}

pub fn library_videos(indexed_videos: &[LibraryVideo]) -> Vec<LibraryVideo> {
    let mut videos_by_path: HashMap<&str, LibraryVideo> = HashMap::new();

    for video in indexed_videos {
        if let Some(existing) = videos_by_path.get_mut(video.video_path.as_str()) {
            if natural_cmp(&video.subtitle_path, &existing.subtitle_path).is_lt() {
                *existing = video.clone();
            }
        } else {
            videos_by_path.insert(video.video_path.as_str(), video.clone());
        }
    }

    let mut videos: Vec<LibraryVideo> = videos_by_path.into_values().collect();
    videos.sort_by(compare_library_videos);
    videos
}

pub fn library_presentation_snapshot(
    indexed_videos: &[LibraryVideo],
) -> Vec<LibraryFolderPresentation> {
    let videos = library_videos(indexed_videos);
    let mut videos_by_folder_path: HashMap<String, Vec<LibraryVideo>> = HashMap::new();

    for video in videos {
        let folder_path = parent_path(&video.video_path);
        videos_by_folder_path
            .entry(folder_path)
            .or_default()
            .push(video);
    }

    let mut folder_paths: Vec<String> = videos_by_folder_path.keys().cloned().collect();
    folder_paths.sort_by(|lhs, rhs| {
        natural_cmp(&path_last_component(lhs), &path_last_component(rhs))
            .then_with(|| natural_cmp(lhs, rhs))
    });

    folder_paths
        .into_iter()
        .enumerate()
        .map(|(_folder_order, folder_path)| {
            let folder_title = path_last_component(&folder_path);
            let mut videos = videos_by_folder_path
                .remove(&folder_path)
                .unwrap_or_default();
            videos.sort_by(compare_library_videos);
            let rank_width = 2.max(videos.len().to_string().len());

            let videos = videos
                .into_iter()
                .enumerate()
                .map(|(video_order, video)| {
                    let sequence = format!("{:0width$}", video_order + 1, width = rank_width);
                    LibraryVideoPresentation {
                        file_extension: path_extension(&video.video_path).to_ascii_lowercase(),
                        display_title: format!("{folder_title} - {sequence}"),
                        video_path: video.video_path,
                        video_name: video.video_name,
                        duration: video.duration,
                        subtitle_path: video.subtitle_path,
                        subtitle_format: video.subtitle_format,
                    }
                })
                .collect();

            LibraryFolderPresentation {
                folder_path,
                folder_title,
                videos,
            }
        })
        .collect()
}

fn compare_library_videos(lhs: &LibraryVideo, rhs: &LibraryVideo) -> Ordering {
    natural_cmp(
        &path_last_component(&parent_path(&lhs.video_path)),
        &path_last_component(&parent_path(&rhs.video_path)),
    )
    .then_with(|| natural_cmp(&lhs.video_name, &rhs.video_name))
    .then_with(|| natural_cmp(&lhs.video_path, &rhs.video_path))
}

fn parent_path(path: &str) -> String {
    Path::new(path)
        .parent()
        .map(|parent| parent.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn path_last_component(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn path_extension(path: &str) -> String {
    Path::new(path)
        .extension()
        .map(|extension| extension.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn natural_cmp(lhs: &str, rhs: &str) -> Ordering {
    let mut lhs_chars = lhs.chars().peekable();
    let mut rhs_chars = rhs.chars().peekable();

    loop {
        match (lhs_chars.peek(), rhs_chars.peek()) {
            (None, None) => return Ordering::Equal,
            (None, Some(_)) => return Ordering::Less,
            (Some(_), None) => return Ordering::Greater,
            (Some(lhs_char), Some(rhs_char))
                if lhs_char.is_ascii_digit() && rhs_char.is_ascii_digit() =>
            {
                let lhs_number = take_digit_run(&mut lhs_chars);
                let rhs_number = take_digit_run(&mut rhs_chars);
                let ordering = compare_digit_runs(&lhs_number, &rhs_number);
                if !ordering.is_eq() {
                    return ordering;
                }
            }
            (Some(_), Some(_)) => {
                let lhs_char = lhs_chars.next().expect("peeked char must exist");
                let rhs_char = rhs_chars.next().expect("peeked char must exist");
                let ordering = lhs_char
                    .to_ascii_lowercase()
                    .cmp(&rhs_char.to_ascii_lowercase())
                    .then_with(|| lhs_char.cmp(&rhs_char));
                if !ordering.is_eq() {
                    return ordering;
                }
            }
        }
    }
}

fn take_digit_run<I>(chars: &mut std::iter::Peekable<I>) -> String
where
    I: Iterator<Item = char>,
{
    let mut digits = String::new();
    while chars
        .peek()
        .is_some_and(|character| character.is_ascii_digit())
    {
        digits.push(chars.next().expect("peeked digit must exist"));
    }
    digits
}

fn compare_digit_runs(lhs: &str, rhs: &str) -> Ordering {
    let lhs_trimmed = lhs.trim_start_matches('0');
    let rhs_trimmed = rhs.trim_start_matches('0');
    let lhs_effective = if lhs_trimmed.is_empty() {
        "0"
    } else {
        lhs_trimmed
    };
    let rhs_effective = if rhs_trimmed.is_empty() {
        "0"
    } else {
        rhs_trimmed
    };

    lhs_effective
        .len()
        .cmp(&rhs_effective.len())
        .then_with(|| lhs_effective.cmp(rhs_effective))
        .then_with(|| lhs.len().cmp(&rhs.len()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compares_embedded_numbers_naturally() {
        assert!(natural_cmp("Episode 2.mkv", "Episode 11.mkv").is_lt());
        assert!(natural_cmp("Show 2", "Show 11").is_lt());
    }
}
