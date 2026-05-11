use std::collections::HashMap;

use super::{SubtitleCueGroup, SubtitleCueLine, SubtitleFormat};

pub fn parse_cue_groups(contents: &str) -> Vec<SubtitleCueGroup> {
    Parser::new(contents).parse()
}

pub fn milliseconds(timecode: &str) -> Option<i32> {
    let trimmed = timecode.trim();
    let hour_parts: Vec<&str> = trimmed.split(':').collect();
    if hour_parts.len() != 3 {
        return None;
    }

    let hours: i32 = hour_parts[0].parse().ok()?;
    let minutes: i32 = hour_parts[1].parse().ok()?;
    if !(0..60).contains(&minutes) {
        return None;
    }

    let second_parts: Vec<&str> = hour_parts[2].split('.').collect();
    if second_parts.len() != 2 {
        return None;
    }

    let seconds: i32 = second_parts[0].parse().ok()?;
    let fraction: i32 = second_parts[1].parse().ok()?;
    if !(0..60).contains(&seconds) {
        return None;
    }

    let milliseconds = match second_parts[1].len() {
        1 => fraction * 100,
        2 => fraction * 10,
        3 => fraction,
        _ => return None,
    };

    if !(0..1000).contains(&milliseconds) {
        return None;
    }

    Some((((hours * 60) + minutes) * 60 + seconds) * 1000 + milliseconds)
}

pub fn clean_text(text: &str) -> String {
    let mut cleaned = String::new();
    let mut is_inside_override = false;

    for character in text.chars() {
        if character == '{' {
            is_inside_override = true;
        } else if character == '}' {
            is_inside_override = false;
        } else if !is_inside_override {
            cleaned.push(character);
        }
    }

    cleaned
        .replace("\\N", "\n")
        .replace("\\n", "\n")
        .trim()
        .to_string()
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Section {
    ScriptInfo,
    Styles,
    Events,
    Unknown,
}

#[derive(Debug, Clone)]
struct AssStyle {
    alignment: Option<i32>,
    margin_l: Option<f64>,
    margin_r: Option<f64>,
    margin_v: Option<f64>,
}

#[derive(Debug, Clone)]
struct ParsedCueLine {
    event_index: usize,
    source_style: Option<String>,
    source_layer: Option<i32>,
    start_timecode: String,
    end_timecode: String,
    start_milliseconds: i32,
    end_milliseconds: i32,
    content: String,
    display_x: Option<f64>,
    display_y: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct CueGroupKey {
    start_timecode: String,
    end_timecode: String,
    start_milliseconds: i32,
    end_milliseconds: i32,
}

struct Parser<'a> {
    contents: &'a str,
    section: Section,
    play_res_x: Option<f64>,
    play_res_y: Option<f64>,
    style_format: Vec<String>,
    styles: HashMap<String, AssStyle>,
    event_format: Vec<String>,
    parsed_lines: Vec<ParsedCueLine>,
}

impl<'a> Parser<'a> {
    fn new(contents: &'a str) -> Self {
        Self {
            contents,
            section: Section::Unknown,
            play_res_x: None,
            play_res_y: None,
            style_format: Vec::new(),
            styles: HashMap::new(),
            event_format: Vec::new(),
            parsed_lines: Vec::new(),
        }
    }

    fn parse(mut self) -> Vec<SubtitleCueGroup> {
        let normalized = self
            .contents
            .replace('\u{feff}', "")
            .replace("\r\n", "\n")
            .replace('\r', "\n");

        for raw_line in normalized.split('\n') {
            self.parse_line(raw_line);
        }

        self.grouped_cue_lines()
    }

    fn parse_line(&mut self, raw_line: &str) {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with(';') {
            return;
        }

        if line.starts_with('[') && line.ends_with(']') {
            self.section = match line.to_ascii_lowercase().as_str() {
                "[script info]" => Section::ScriptInfo,
                "[v4+ styles]" => Section::Styles,
                "[events]" => Section::Events,
                _ => Section::Unknown,
            };
            return;
        }

        match self.section {
            Section::ScriptInfo => self.parse_script_info(line),
            Section::Styles => self.parse_style_line(line),
            Section::Events => self.parse_event_line(line),
            Section::Unknown => {}
        }
    }

    fn parse_script_info(&mut self, line: &str) {
        let Some(separator) = line.find(':') else {
            return;
        };

        let key = line[..separator].trim().to_ascii_lowercase();
        let value = line[separator + 1..].trim();

        if key == "playresx" {
            self.play_res_x = value.parse().ok();
        } else if key == "playresy" {
            self.play_res_y = value.parse().ok();
        }
    }

    fn parse_style_line(&mut self, line: &str) {
        let lowercased = line.to_ascii_lowercase();
        if lowercased.starts_with("format:") {
            self.style_format = parse_format(&line["format:".len()..]);
            return;
        }

        if !lowercased.starts_with("style:") || self.style_format.is_empty() {
            return;
        }

        let fields = split_fields(&line["style:".len()..], self.style_format.len());
        if fields.len() != self.style_format.len() {
            return;
        }

        let Some(name) = value("name", &fields, &self.style_format) else {
            return;
        };
        if name.is_empty() {
            return;
        }

        self.styles.insert(
            name.to_string(),
            AssStyle {
                alignment: value("alignment", &fields, &self.style_format).and_then(parse_i32),
                margin_l: value("marginl", &fields, &self.style_format).and_then(parse_f64),
                margin_r: value("marginr", &fields, &self.style_format).and_then(parse_f64),
                margin_v: value("marginv", &fields, &self.style_format).and_then(parse_f64),
            },
        );
    }

    fn parse_event_line(&mut self, line: &str) {
        let lowercased = line.to_ascii_lowercase();
        if lowercased.starts_with("format:") {
            self.event_format = parse_format(&line["format:".len()..]);
            return;
        }

        if !lowercased.starts_with("dialogue:") || self.event_format.is_empty() {
            return;
        }

        let event_index = self.parsed_lines.len();
        let fields = split_fields(&line["dialogue:".len()..], self.event_format.len());
        if fields.len() != self.event_format.len() {
            return;
        }

        let Some(start_timecode) = value("start", &fields, &self.event_format) else {
            return;
        };
        let Some(end_timecode) = value("end", &fields, &self.event_format) else {
            return;
        };
        let Some(start_milliseconds) = milliseconds(start_timecode) else {
            return;
        };
        let Some(end_milliseconds) = milliseconds(end_timecode) else {
            return;
        };
        if end_milliseconds < start_milliseconds {
            return;
        }
        let Some(raw_text) = value("text", &fields, &self.event_format) else {
            return;
        };

        let content = clean_text(raw_text);
        if content.is_empty() {
            return;
        }

        let source_style = value("style", &fields, &self.event_format)
            .filter(|style| !style.is_empty())
            .map(ToOwned::to_owned);
        let source_layer = value("layer", &fields, &self.event_format).and_then(parse_i32);
        let (display_x, display_y) = self.layout_projection(
            raw_text,
            source_style.as_deref(),
            value("marginl", &fields, &self.event_format).and_then(parse_f64),
            value("marginr", &fields, &self.event_format).and_then(parse_f64),
            value("marginv", &fields, &self.event_format).and_then(parse_f64),
        );

        self.parsed_lines.push(ParsedCueLine {
            event_index,
            source_style,
            source_layer,
            start_timecode: start_timecode.trim().to_string(),
            end_timecode: end_timecode.trim().to_string(),
            start_milliseconds,
            end_milliseconds,
            content,
            display_x,
            display_y,
        });
    }

    fn layout_projection(
        &self,
        raw_text: &str,
        style_name: Option<&str>,
        event_margin_l: Option<f64>,
        event_margin_r: Option<f64>,
        event_margin_v: Option<f64>,
    ) -> (Option<f64>, Option<f64>) {
        if let Some((x, y)) = inline_position(raw_text) {
            return (Some(x), Some(y));
        }

        let style = style_name.and_then(|name| self.styles.get(name));
        let alignment =
            inline_alignment(raw_text).or_else(|| style.and_then(|style| style.alignment));
        let Some(alignment) = alignment else {
            return (None, None);
        };
        let Some(play_res_y) = self.play_res_y else {
            return (None, None);
        };

        let margin_l = positive(event_margin_l)
            .or_else(|| style.and_then(|style| style.margin_l))
            .unwrap_or(0.0);
        let margin_r = positive(event_margin_r)
            .or_else(|| style.and_then(|style| style.margin_r))
            .unwrap_or(0.0);
        let margin_v = positive(event_margin_v)
            .or_else(|| style.and_then(|style| style.margin_v))
            .unwrap_or(0.0);

        let y = match alignment {
            7..=9 => margin_v,
            4..=6 => play_res_y / 2.0,
            _ => play_res_y - margin_v,
        };

        let x = self.play_res_x.map(|play_res_x| match alignment {
            1 | 4 | 7 => margin_l,
            3 | 6 | 9 => play_res_x - margin_r,
            _ => play_res_x / 2.0,
        });

        (x, Some(y))
    }

    fn grouped_cue_lines(&self) -> Vec<SubtitleCueGroup> {
        let mut groups: Vec<(CueGroupKey, Vec<ParsedCueLine>)> = Vec::new();

        for line in &self.parsed_lines {
            let key = CueGroupKey {
                start_timecode: line.start_timecode.clone(),
                end_timecode: line.end_timecode.clone(),
                start_milliseconds: line.start_milliseconds,
                end_milliseconds: line.end_milliseconds,
            };

            if let Some((_, lines)) = groups
                .iter_mut()
                .find(|(existing_key, _)| *existing_key == key)
            {
                lines.push(line.clone());
            } else {
                groups.push((key, vec![line.clone()]));
            }
        }

        let mut cue_groups: Vec<SubtitleCueGroup> = groups
            .into_iter()
            .map(|(key, lines)| {
                let cue_lines: Vec<SubtitleCueLine> = sorted_cue_lines(lines)
                    .into_iter()
                    .enumerate()
                    .map(|(display_order, line)| SubtitleCueLine {
                        event_index: line.event_index,
                        source_format: SubtitleFormat::Ass,
                        source_style: line.source_style,
                        source_layer: line.source_layer,
                        start_timecode: line.start_timecode,
                        end_timecode: line.end_timecode,
                        start_milliseconds: line.start_milliseconds,
                        end_milliseconds: line.end_milliseconds,
                        content: line.content,
                        display_x: line.display_x,
                        display_y: line.display_y,
                        display_order,
                    })
                    .collect();

                SubtitleCueGroup {
                    sequence_number: None,
                    start_timecode: key.start_timecode,
                    end_timecode: key.end_timecode,
                    start_milliseconds: key.start_milliseconds,
                    end_milliseconds: key.end_milliseconds,
                    search_content: cue_lines
                        .iter()
                        .map(|line| line.content.as_str())
                        .collect::<Vec<_>>()
                        .join("\n"),
                    cue_lines,
                }
            })
            .collect();

        cue_groups.sort_by(|lhs, rhs| {
            lhs.start_milliseconds
                .cmp(&rhs.start_milliseconds)
                .then(lhs.end_milliseconds.cmp(&rhs.end_milliseconds))
                .then(
                    lhs.cue_lines
                        .first()
                        .map(|line| line.event_index)
                        .unwrap_or(0)
                        .cmp(
                            &rhs.cue_lines
                                .first()
                                .map(|line| line.event_index)
                                .unwrap_or(0),
                        ),
                )
        });
        cue_groups
    }
}

fn sorted_cue_lines(mut lines: Vec<ParsedCueLine>) -> Vec<ParsedCueLine> {
    lines.sort_by(|lhs, rhs| {
        compare_optional_number(lhs.display_y, rhs.display_y)
            .then(compare_optional_number(lhs.display_x, rhs.display_x))
            .then(lhs.event_index.cmp(&rhs.event_index))
    });
    lines
}

fn compare_optional_number(lhs: Option<f64>, rhs: Option<f64>) -> std::cmp::Ordering {
    match (lhs, rhs) {
        (Some(lhs), Some(rhs)) => lhs.partial_cmp(&rhs).unwrap_or(std::cmp::Ordering::Equal),
        (Some(_), None) => std::cmp::Ordering::Less,
        (None, Some(_)) => std::cmp::Ordering::Greater,
        (None, None) => std::cmp::Ordering::Equal,
    }
}

fn inline_alignment(text: &str) -> Option<i32> {
    text.match_indices("\\an").find_map(|(index, _)| {
        text[index + "\\an".len()..]
            .chars()
            .next()
            .and_then(|character| character.to_digit(10))
            .filter(|value| (1..=9).contains(value))
            .map(|value| value as i32)
    })
}

fn inline_position(text: &str) -> Option<(f64, f64)> {
    parse_position_function(text, "\\pos(", false)
        .or_else(|| parse_position_function(text, "\\move(", true))
}

fn parse_position_function(
    text: &str,
    marker: &str,
    allow_more_fields: bool,
) -> Option<(f64, f64)> {
    let start = text.find(marker)? + marker.len();
    let rest = &text[start..];
    let end = rest.find(')')?;
    let body = &rest[..end];
    let fields: Vec<&str> = body.split(',').map(str::trim).collect();

    if (!allow_more_fields && fields.len() != 2) || fields.len() < 2 {
        return None;
    }

    Some((fields[0].parse().ok()?, fields[1].parse().ok()?))
}

fn parse_format(text: &str) -> Vec<String> {
    text.split(',')
        .map(|field| field.trim().to_ascii_lowercase())
        .collect()
}

fn split_fields(text: &str, expected_count: usize) -> Vec<String> {
    if expected_count <= 1 {
        return vec![text.trim().to_string()];
    }

    text.splitn(expected_count, ',')
        .map(|field| field.trim().to_string())
        .collect()
}

fn value<'a>(name: &str, fields: &'a [String], format: &[String]) -> Option<&'a str> {
    let index = format.iter().position(|field| field == name)?;
    fields.get(index).map(String::as_str)
}

fn positive(value: Option<f64>) -> Option<f64> {
    value.filter(|value| *value > 0.0)
}

fn parse_i32(text: &str) -> Option<i32> {
    text.parse().ok()
}

fn parse_f64(text: &str) -> Option<f64> {
    text.parse().ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_ass_milliseconds_like_macos() {
        assert_eq!(milliseconds("0:00:00.00"), Some(0));
        assert_eq!(milliseconds("1:02:03.45"), Some(3_723_450));
        assert_eq!(milliseconds("0:00:06.5"), Some(6_500));
        assert_eq!(milliseconds("0:00:08.0000"), None);
    }
}
