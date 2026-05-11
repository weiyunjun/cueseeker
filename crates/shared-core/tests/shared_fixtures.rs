use std::fs;
use std::path::{Path, PathBuf};

use cueseeker_shared_core::subtitles::{SubtitleCueGroup, SubtitleFormat, ass, srt};
use cueseeker_shared_core::{
    LibraryFolderPresentation, LibraryVideo, PlaybackRequestError, PlaybackRequestInput,
    PlaybackSubtitleSource, PlaybackSubtitleSourceFormat, PlaybackSubtitleTimeWindow, ShioriStore,
    ShioriUpsert, SubtitleFileScanner, SubtitleIndexer, SubtitleSearchPage, VideoMatcher,
    library_presentation_snapshot, resolve_playback_request, search_projection, shiori_cue_lines,
};

#[test]
fn srt_parser_matches_shared_fixture() {
    let root = fixture_root();
    let contents = fs::read_to_string(root.join("subtitles/srt-baseline.srt")).unwrap();
    let expected = expected_rows(&root.join("subtitles/srt-baseline.expected.tsv"));

    let actual = cue_group_rows(&srt::parse_cue_groups(&contents));

    assert_eq!(actual, expected);
}

#[test]
fn ass_parser_matches_shared_fixture() {
    let root = fixture_root();
    let contents = fs::read_to_string(root.join("subtitles/ass-baseline.ass")).unwrap();
    let expected = expected_rows(&root.join("subtitles/ass-baseline.expected.tsv"));

    let actual = cue_group_rows(&ass::parse_cue_groups(&contents));

    assert_eq!(actual, expected);
}

#[test]
fn video_matching_matches_shared_fixture() {
    let root = fixture_root().join("video-matching");
    let cases = fs::read_to_string(root.join("cases.tsv")).unwrap();
    let matcher = VideoMatcher::default();

    for line in cases.lines() {
        if line.trim().is_empty() || line.starts_with('#') {
            continue;
        }

        let fields: Vec<&str> = line.splitn(2, '\t').collect();
        assert_eq!(fields.len(), 2, "invalid case row: {line}");

        let subtitle = root.join(fields[0]);
        let actual = matcher
            .matching_video(&subtitle)
            .map(|path| relative_path(&root, &path));
        let expected = if fields[1] == "NONE" {
            None
        } else {
            Some(fields[1].to_string())
        };

        assert_eq!(actual, expected, "case row: {line}");
    }
}

#[test]
fn subtitle_scanner_matches_shared_fixture() {
    let root = fixture_root();
    let scanning_root = root.join("scanning");
    let scanner = SubtitleFileScanner::default();
    let scan_root = scanning_root.join("library");

    assert_eq!(
        relative_paths(&scanning_root, scanner.scan_subtitle_files(&scan_root)),
        expected_rows(&root.join("scanning/expected-subtitles.txt"))
    );
    assert_eq!(
        relative_paths(&scanning_root, scanner.scan_srt_files(&scan_root)),
        expected_rows(&root.join("scanning/expected-srt.txt"))
    );
}

#[test]
fn subtitle_indexing_projection_matches_shared_fixture() {
    let root = fixture_root();
    let indexing_root = root.join("indexing");
    let projection = SubtitleIndexer::default().project_folder(&indexing_root.join("library"));

    assert_eq!(
        indexing_projection_rows(&indexing_root, &projection),
        expected_rows(&root.join("indexing/expected-projection.tsv"))
    );
}

#[test]
fn subtitle_search_matches_shared_fixture() {
    let root = fixture_root();
    let search_root = root.join("search");
    let projection = SubtitleIndexer::default().project_folder(&search_root.join("library"));
    let cases = search_cases(&search_root.join("cases.tsv"));

    assert_eq!(
        search_rows(&search_root, &projection, &cases),
        expected_rows(&search_root.join("expected-results.tsv"))
    );
}

#[test]
fn library_presentation_matches_shared_fixture() {
    let root = fixture_root();
    let library_root = root.join("library");
    let indexed_videos = library_indexed_videos(&library_root.join("indexed-videos.tsv"));
    let snapshot = library_presentation_snapshot(&indexed_videos);

    assert_eq!(
        library_presentation_rows(&snapshot),
        expected_rows(&library_root.join("expected-presentation.tsv"))
    );
}

#[test]
fn shiori_matches_shared_fixture() {
    let root = fixture_root().join("shiori");
    let mut store = ShioriStore::default();
    apply_shiori_operations(&mut store, &root.join("operations.tsv"));

    assert_eq!(
        shiori_rows(&store.records()),
        expected_rows(&root.join("expected-rows.tsv"))
    );
}

#[test]
fn playback_intent_matches_shared_fixture() {
    let root = fixture_root().join("playback-intent");

    assert_eq!(
        playback_rows(&root.join("cases.tsv")),
        expected_rows(&root.join("expected-rows.tsv"))
    );
}

#[test]
fn phase1_shared_contract_smoke_covers_all_domains() {
    let root = fixture_root();

    assert_eq!(
        cue_group_rows(&srt::parse_cue_groups(
            &fs::read_to_string(root.join("subtitles/srt-baseline.srt")).unwrap()
        )),
        expected_rows(&root.join("subtitles/srt-baseline.expected.tsv"))
    );
    assert_eq!(
        cue_group_rows(&ass::parse_cue_groups(
            &fs::read_to_string(root.join("subtitles/ass-baseline.ass")).unwrap()
        )),
        expected_rows(&root.join("subtitles/ass-baseline.expected.tsv"))
    );
    assert_eq!(
        indexing_projection_rows(
            &root.join("indexing"),
            &SubtitleIndexer::default().project_folder(&root.join("indexing/library"))
        ),
        expected_rows(&root.join("indexing/expected-projection.tsv"))
    );
    assert_eq!(
        search_rows(
            &root.join("search"),
            &SubtitleIndexer::default().project_folder(&root.join("search/library")),
            &search_cases(&root.join("search/cases.tsv"))
        ),
        expected_rows(&root.join("search/expected-results.tsv"))
    );

    let indexed_videos = library_indexed_videos(&root.join("library/indexed-videos.tsv"));
    assert_eq!(
        library_presentation_rows(&library_presentation_snapshot(&indexed_videos)),
        expected_rows(&root.join("library/expected-presentation.tsv"))
    );

    let mut store = ShioriStore::default();
    apply_shiori_operations(&mut store, &root.join("shiori/operations.tsv"));
    assert_eq!(
        shiori_rows(&store.records()),
        expected_rows(&root.join("shiori/expected-rows.tsv"))
    );
    assert_eq!(
        playback_rows(&root.join("playback-intent/cases.tsv")),
        expected_rows(&root.join("playback-intent/expected-rows.tsv"))
    );
}

fn fixture_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .join("fixtures/shared-core")
}

fn expected_rows(path: &Path) -> Vec<String> {
    fs::read_to_string(path)
        .unwrap()
        .lines()
        .filter(|line| {
            let trimmed = line.trim();
            !trimmed.is_empty() && !trimmed.starts_with('#')
        })
        .map(ToOwned::to_owned)
        .collect()
}

fn relative_paths(root: &Path, paths: Vec<PathBuf>) -> Vec<String> {
    paths.iter().map(|path| relative_path(root, path)).collect()
}

fn cue_group_rows(groups: &[SubtitleCueGroup]) -> Vec<String> {
    let mut rows = Vec::new();

    for group in groups {
        rows.push(
            [
                "group".to_string(),
                group
                    .sequence_number
                    .map(|value| value.to_string())
                    .unwrap_or_default(),
                group.start_timecode.clone(),
                group.end_timecode.clone(),
                group.start_milliseconds.to_string(),
                group.end_milliseconds.to_string(),
                escape_text(&group.search_content),
            ]
            .join("\t"),
        );

        for line in &group.cue_lines {
            rows.push(
                [
                    "line".to_string(),
                    line.event_index.to_string(),
                    format_subtitle_format(line.source_format),
                    line.source_style.clone().unwrap_or_default(),
                    line.source_layer
                        .map(|value| value.to_string())
                        .unwrap_or_default(),
                    line.start_timecode.clone(),
                    line.end_timecode.clone(),
                    line.start_milliseconds.to_string(),
                    line.end_milliseconds.to_string(),
                    escape_text(&line.content),
                    format_optional_number(line.display_x),
                    format_optional_number(line.display_y),
                    line.display_order.to_string(),
                ]
                .join("\t"),
            );
        }
    }

    rows
}

fn indexing_projection_rows(
    root: &Path,
    projection: &cueseeker_shared_core::SubtitleIndexingProjection,
) -> Vec<String> {
    let mut rows = vec![
        [
            "summary".to_string(),
            projection.result.scanned_subtitle_files.to_string(),
            projection.result.indexed_subtitle_files.to_string(),
            projection.result.indexed_subtitle_entries.to_string(),
            projection.result.skipped_missing_video.to_string(),
            projection.result.skipped_unreadable_subtitle.to_string(),
            projection.result.failed_files.len().to_string(),
        ]
        .join("\t"),
    ];

    for file in &projection.indexed_files {
        rows.push(
            [
                "file".to_string(),
                relative_path(root, &file.subtitle_path),
                relative_path(root, &file.video_path),
                format_subtitle_format(file.format),
                file.cue_groups.len().to_string(),
            ]
            .join("\t"),
        );
        rows.extend(cue_group_rows(&file.cue_groups));
    }

    rows
}

fn search_cases(path: &Path) -> Vec<(String, String, usize, usize)> {
    fs::read_to_string(path)
        .unwrap()
        .lines()
        .filter(|line| {
            let trimmed = line.trim();
            !trimmed.is_empty() && !trimmed.starts_with('#')
        })
        .map(|line| {
            let fields: Vec<&str> = line.split('\t').collect();
            assert_eq!(fields.len(), 4, "invalid search case row: {line}");
            (
                fields[0].to_string(),
                if fields[1] == "<EMPTY>" {
                    String::new()
                } else {
                    fields[1].to_string()
                },
                fields[2].parse().unwrap(),
                fields[3].parse().unwrap(),
            )
        })
        .collect()
}

fn search_rows(
    root: &Path,
    projection: &cueseeker_shared_core::SubtitleIndexingProjection,
    cases: &[(String, String, usize, usize)],
) -> Vec<String> {
    let mut rows = Vec::new();

    for (name, query, limit, offset) in cases {
        let page = search_projection(projection, query, *limit, *offset);
        rows.extend(search_page_rows(root, name, &page));
    }

    rows
}

fn search_page_rows(root: &Path, case_name: &str, page: &SubtitleSearchPage) -> Vec<String> {
    let mut rows = vec![
        [
            "case".to_string(),
            case_name.to_string(),
            page.total_count.to_string(),
        ]
        .join("\t"),
    ];

    for result in &page.results {
        rows.push(
            [
                "result".to_string(),
                relative_path(root, Path::new(&result.subtitle_path)),
                relative_path(root, Path::new(&result.video_path)),
                format_subtitle_format(result.subtitle_format),
                result.start_milliseconds.to_string(),
                result.end_milliseconds.to_string(),
                escape_text(&result.content),
                escape_text(&result.cue_lines.join("\n")),
            ]
            .join("\t"),
        );
    }

    rows
}

fn library_indexed_videos(path: &Path) -> Vec<LibraryVideo> {
    fs::read_to_string(path)
        .unwrap()
        .lines()
        .filter(|line| {
            let trimmed = line.trim();
            !trimmed.is_empty() && !trimmed.starts_with('#')
        })
        .map(|line| {
            let fields: Vec<&str> = line.split('\t').collect();
            assert_eq!(fields.len(), 4, "invalid library row: {line}");
            let video_path = fields[1].to_string();
            LibraryVideo {
                video_name: Path::new(&video_path)
                    .file_name()
                    .unwrap()
                    .to_string_lossy()
                    .into_owned(),
                video_path,
                duration: if fields[3] == "NONE" {
                    None
                } else {
                    Some(fields[3].parse().unwrap())
                },
                subtitle_path: fields[0].to_string(),
                subtitle_format: parse_subtitle_format(fields[2]),
            }
        })
        .collect()
}

fn library_presentation_rows(snapshot: &[LibraryFolderPresentation]) -> Vec<String> {
    let mut rows = Vec::new();

    for folder in snapshot {
        rows.push(
            [
                "folder".to_string(),
                folder.folder_path.clone(),
                folder.folder_title.clone(),
            ]
            .join("\t"),
        );

        for video in &folder.videos {
            rows.push(
                [
                    "video".to_string(),
                    folder.folder_path.clone(),
                    folder.folder_title.clone(),
                    video.video_path.clone(),
                    video.video_name.clone(),
                    format_optional_number(video.duration),
                    video.subtitle_path.clone(),
                    format_subtitle_format(video.subtitle_format),
                    video.display_title.clone(),
                    video.file_extension.clone(),
                ]
                .join("\t"),
            );
        }
    }

    rows
}

fn apply_shiori_operations(store: &mut ShioriStore, path: &Path) {
    for line in expected_rows(path) {
        let fields: Vec<&str> = line.split('\t').collect();
        assert_eq!(fields.len(), 9, "invalid Shiori operation row: {line}");

        match fields[0] {
            "upsert" => {
                store.upsert(ShioriUpsert {
                    subtitle_path: fields[1].to_string(),
                    subtitle_format: parse_subtitle_format(fields[2]),
                    start_milliseconds: fields[3].parse().unwrap(),
                    end_milliseconds: fields[4].parse().unwrap(),
                    video_path: fields[5].to_string(),
                    video_name: fields[6].to_string(),
                    content: unescape_text(fields[7]),
                    created_at: fields[8].to_string(),
                });
            }
            "remove" => {
                store.remove(
                    fields[1],
                    fields[3].parse().unwrap(),
                    fields[4].parse().unwrap(),
                );
            }
            _ => panic!("unknown Shiori operation: {}", fields[0]),
        }
    }
}

fn shiori_rows(records: &[cueseeker_shared_core::Shiori]) -> Vec<String> {
    records
        .iter()
        .map(|record| {
            [
                "shiori".to_string(),
                record.id.to_string(),
                record.subtitle_path.clone(),
                format_subtitle_format(record.subtitle_format),
                record.video_path.clone(),
                record.video_name.clone(),
                record.start_milliseconds.to_string(),
                record.end_milliseconds.to_string(),
                escape_text(&record.content),
                record.is_valid.to_string(),
                record.created_at.clone(),
                shiori_cue_lines(&record.content).join("|"),
            ]
            .join("\t")
        })
        .collect()
}

fn playback_rows(path: &Path) -> Vec<String> {
    expected_rows(path)
        .into_iter()
        .map(|line| {
            let fields: Vec<&str> = line.split('\t').collect();
            assert_eq!(fields.len(), 13, "invalid playback case row: {line}");
            let case_name = fields[0];
            let input = PlaybackRequestInput {
                video_url: fields[2].to_string(),
                is_file_url: fields[1] == "file",
                video_exists: fields[3] == "true",
                start_milliseconds: fields[4].parse().unwrap(),
                subtitle_source: playback_subtitle_source(&fields),
            };

            match resolve_playback_request(input) {
                Ok(request) => {
                    let subtitle_source = request.subtitle_source;
                    [
                        case_name.to_string(),
                        "ok".to_string(),
                        request.start_milliseconds.to_string(),
                        playback_subtitle_format(&subtitle_source),
                        subtitle_source
                            .as_ref()
                            .and_then(|source| source.matched_video_url.clone())
                            .unwrap_or_else(|| "NONE".to_string()),
                        subtitle_source
                            .as_ref()
                            .and_then(|source| source.font_resource_directory_url.clone())
                            .unwrap_or_else(|| "NONE".to_string()),
                        subtitle_source
                            .as_ref()
                            .and_then(|source| source.preparation_time_window.as_ref())
                            .map(|window| window.start_milliseconds.to_string())
                            .unwrap_or_else(|| "NONE".to_string()),
                        subtitle_source
                            .as_ref()
                            .and_then(|source| source.preparation_time_window.as_ref())
                            .map(|window| window.end_milliseconds.to_string())
                            .unwrap_or_else(|| "NONE".to_string()),
                        subtitle_source
                            .as_ref()
                            .and_then(|source| source.render_cache_database_url.clone())
                            .unwrap_or_else(|| "NONE".to_string()),
                    ]
                    .join("\t")
                }
                Err(PlaybackRequestError::MissingVideoFile(_)) => {
                    [case_name.to_string(), "missingVideoFile".to_string()].join("\t")
                }
                Err(PlaybackRequestError::InvalidVideoUrl(_)) => {
                    [case_name.to_string(), "invalidVideoURL".to_string()].join("\t")
                }
            }
        })
        .collect()
}

fn playback_subtitle_source(fields: &[&str]) -> Option<PlaybackSubtitleSource> {
    if fields[5] == "none" {
        return None;
    }

    Some(PlaybackSubtitleSource {
        url: fields[6].to_string(),
        format: PlaybackSubtitleSourceFormat::Ass,
        matched_video_url: optional_fixture_string(fields[7]),
        font_resource_directory_url: optional_fixture_string(fields[8]),
        preparation_time_window: if fields[9] == "NONE" {
            None
        } else {
            Some(PlaybackSubtitleTimeWindow::new(
                fields[9].parse().unwrap(),
                fields[10].parse().unwrap(),
            ))
        },
        render_cache_database_url: optional_fixture_string(fields[11]),
    })
}

fn playback_subtitle_format(source: &Option<PlaybackSubtitleSource>) -> String {
    match source {
        Some(PlaybackSubtitleSource {
            format: PlaybackSubtitleSourceFormat::Ass,
            ..
        }) => "ass".to_string(),
        None => "none".to_string(),
    }
}

fn optional_fixture_string(value: &str) -> Option<String> {
    if value == "NONE" {
        None
    } else {
        Some(value.to_string())
    }
}

fn format_subtitle_format(format: SubtitleFormat) -> String {
    match format {
        SubtitleFormat::Srt => "srt".to_string(),
        SubtitleFormat::Ass => "ass".to_string(),
    }
}

fn parse_subtitle_format(format: &str) -> SubtitleFormat {
    match format {
        "srt" => SubtitleFormat::Srt,
        "ass" => SubtitleFormat::Ass,
        _ => panic!("unknown subtitle format: {format}"),
    }
}

fn format_optional_number(value: Option<f64>) -> String {
    let Some(value) = value else {
        return String::new();
    };

    if (value.fract()).abs() < f64::EPSILON {
        format!("{}", value as i64)
    } else {
        value.to_string()
    }
}

fn escape_text(text: &str) -> String {
    text.replace('\\', "\\\\")
        .replace('\n', "\\n")
        .replace('\t', "\\t")
}

fn unescape_text(text: &str) -> String {
    let mut result = String::new();
    let mut chars = text.chars().peekable();

    while let Some(character) = chars.next() {
        if character == '\\' {
            match chars.next() {
                Some('n') => result.push('\n'),
                Some('t') => result.push('\t'),
                Some('\\') => result.push('\\'),
                Some(other) => {
                    result.push('\\');
                    result.push(other);
                }
                None => result.push('\\'),
            }
        } else {
            result.push(character);
        }
    }

    result
}

fn relative_path(root: &Path, path: &Path) -> String {
    path.strip_prefix(root)
        .unwrap()
        .to_string_lossy()
        .replace('\\', "/")
}
