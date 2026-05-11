use super::{SubtitleCueGroup, SubtitleEntry};

pub fn parse(contents: &str) -> Vec<SubtitleEntry> {
    split_blocks(contents)
        .iter()
        .filter_map(|lines| parse_block(lines))
        .collect()
}

pub fn parse_cue_groups(contents: &str) -> Vec<SubtitleCueGroup> {
    parse(contents)
        .iter()
        .enumerate()
        .map(|(index, entry)| entry.cue_group(index))
        .collect()
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

    let second_parts: Vec<&str> = hour_parts[2].split([',', '.']).collect();
    if second_parts.len() != 2 {
        return None;
    }

    let seconds: i32 = second_parts[0].parse().ok()?;
    let milliseconds: i32 = second_parts[1].parse().ok()?;
    if !(0..60).contains(&seconds) || !(0..1000).contains(&milliseconds) {
        return None;
    }

    Some((((hours * 60) + minutes) * 60 + seconds) * 1000 + milliseconds)
}

fn parse_block(lines: &[String]) -> Option<SubtitleEntry> {
    if lines.is_empty() {
        return None;
    }

    let first_line = lines[0].trim();
    let sequence_number = first_line.parse::<i32>().ok();
    let time_line_index = if sequence_number.is_some() { 1 } else { 0 };
    let time_line = lines.get(time_line_index)?.trim();
    let range = time_line.find("-->")?;
    let start_timecode = time_line[..range].trim().to_string();
    let end_timecode = time_line[range + "-->".len()..].trim().to_string();

    let start_milliseconds = milliseconds(&start_timecode)?;
    let end_milliseconds = milliseconds(&end_timecode)?;
    if end_milliseconds < start_milliseconds {
        return None;
    }

    let text = lines
        .iter()
        .skip(time_line_index + 1)
        .map(|line| line.trim())
        .collect::<Vec<_>>()
        .join("\n")
        .trim()
        .to_string();

    if text.is_empty() {
        return None;
    }

    Some(SubtitleEntry {
        sequence_number,
        start_timecode,
        end_timecode,
        start_milliseconds,
        end_milliseconds,
        text,
    })
}

fn split_blocks(contents: &str) -> Vec<Vec<String>> {
    let normalized = contents
        .replace('\u{feff}', "")
        .replace("\r\n", "\n")
        .replace('\r', "\n");

    let mut blocks = Vec::new();
    let mut current_block = Vec::new();

    for line in normalized.split('\n') {
        if line.trim().is_empty() {
            if !current_block.is_empty() {
                blocks.push(current_block);
                current_block = Vec::new();
            }
        } else {
            current_block.push(line.to_string());
        }
    }

    if !current_block.is_empty() {
        blocks.push(current_block);
    }

    blocks
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_srt_milliseconds_like_macos() {
        assert_eq!(milliseconds("00:00:00,000"), Some(0));
        assert_eq!(milliseconds("00:00:01,001"), Some(1001));
        assert_eq!(milliseconds("01:02:03.456"), Some(3_723_456));
        assert_eq!(milliseconds("00:00:00,1000"), None);
    }
}
