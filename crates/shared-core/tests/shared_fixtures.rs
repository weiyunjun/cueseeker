use std::fs;
use std::path::{Path, PathBuf};

use cueseeker_shared_core::subtitles::{SubtitleCueGroup, SubtitleFormat, ass, srt};
use cueseeker_shared_core::{
    SubtitleFileScanner, SubtitleIndexer, SubtitleSearchPage, VideoMatcher, search_projection,
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

fn format_subtitle_format(format: SubtitleFormat) -> String {
    match format {
        SubtitleFormat::Srt => "srt".to_string(),
        SubtitleFormat::Ass => "ass".to_string(),
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

fn relative_path(root: &Path, path: &Path) -> String {
    path.strip_prefix(root)
        .unwrap()
        .to_string_lossy()
        .replace('\\', "/")
}
