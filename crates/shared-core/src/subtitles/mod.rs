pub mod ass;
pub mod srt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SubtitleFormat {
    Srt,
    Ass,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SubtitleEntry {
    pub sequence_number: Option<i32>,
    pub start_timecode: String,
    pub end_timecode: String,
    pub start_milliseconds: i32,
    pub end_milliseconds: i32,
    pub text: String,
}

impl SubtitleEntry {
    pub fn cue_group(&self, event_index: usize) -> SubtitleCueGroup {
        let line = SubtitleCueLine {
            event_index,
            source_format: SubtitleFormat::Srt,
            source_style: None,
            source_layer: None,
            start_timecode: self.start_timecode.clone(),
            end_timecode: self.end_timecode.clone(),
            start_milliseconds: self.start_milliseconds,
            end_milliseconds: self.end_milliseconds,
            content: self.text.clone(),
            display_x: None,
            display_y: None,
            display_order: 0,
        };

        SubtitleCueGroup {
            sequence_number: self.sequence_number,
            start_timecode: self.start_timecode.clone(),
            end_timecode: self.end_timecode.clone(),
            start_milliseconds: self.start_milliseconds,
            end_milliseconds: self.end_milliseconds,
            search_content: self.text.clone(),
            cue_lines: vec![line],
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct SubtitleCueGroup {
    pub sequence_number: Option<i32>,
    pub start_timecode: String,
    pub end_timecode: String,
    pub start_milliseconds: i32,
    pub end_milliseconds: i32,
    pub search_content: String,
    pub cue_lines: Vec<SubtitleCueLine>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SubtitleCueLine {
    pub event_index: usize,
    pub source_format: SubtitleFormat,
    pub source_style: Option<String>,
    pub source_layer: Option<i32>,
    pub start_timecode: String,
    pub end_timecode: String,
    pub start_milliseconds: i32,
    pub end_milliseconds: i32,
    pub content: String,
    pub display_x: Option<f64>,
    pub display_y: Option<f64>,
    pub display_order: usize,
}
