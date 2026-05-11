use crate::subtitles::SubtitleFormat;

#[derive(Debug, Clone, PartialEq)]
pub struct Shiori {
    pub id: i64,
    pub subtitle_path: String,
    pub subtitle_format: SubtitleFormat,
    pub video_path: String,
    pub video_name: String,
    pub start_milliseconds: i32,
    pub end_milliseconds: i32,
    pub content: String,
    pub is_valid: bool,
    pub created_at: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ShioriUpsert {
    pub subtitle_path: String,
    pub subtitle_format: SubtitleFormat,
    pub video_path: String,
    pub video_name: String,
    pub start_milliseconds: i32,
    pub end_milliseconds: i32,
    pub content: String,
    pub created_at: String,
}

#[derive(Debug, Default)]
pub struct ShioriStore {
    records: Vec<Shiori>,
    next_id: i64,
}

impl ShioriStore {
    pub fn upsert(&mut self, upsert: ShioriUpsert) -> Shiori {
        let start_milliseconds = upsert.start_milliseconds.max(0);
        let end_milliseconds = upsert.end_milliseconds.max(upsert.start_milliseconds);
        self.next_id += 1;

        if let Some(existing) = self.records.iter_mut().find(|record| {
            record.subtitle_path == upsert.subtitle_path
                && record.start_milliseconds == start_milliseconds
                && record.end_milliseconds == end_milliseconds
        }) {
            existing.subtitle_format = upsert.subtitle_format;
            existing.video_path = upsert.video_path;
            existing.video_name = upsert.video_name;
            existing.content = upsert.content;
            existing.is_valid = true;
            return existing.clone();
        }

        let record = Shiori {
            id: self.next_id,
            subtitle_path: upsert.subtitle_path,
            subtitle_format: upsert.subtitle_format,
            video_path: upsert.video_path,
            video_name: upsert.video_name,
            start_milliseconds,
            end_milliseconds,
            content: upsert.content,
            is_valid: true,
            created_at: upsert.created_at,
        };
        self.records.push(record.clone());
        record
    }

    pub fn remove(
        &mut self,
        subtitle_path: &str,
        start_milliseconds: i32,
        end_milliseconds: i32,
    ) -> bool {
        let start_milliseconds = start_milliseconds.max(0);
        let end_milliseconds = end_milliseconds.max(start_milliseconds);
        let initial_len = self.records.len();
        self.records.retain(|record| {
            !(record.subtitle_path == subtitle_path
                && record.start_milliseconds == start_milliseconds
                && record.end_milliseconds == end_milliseconds)
        });
        self.records.len() != initial_len
    }

    pub fn records(&self) -> Vec<Shiori> {
        let mut records = self.records.clone();
        records.sort_by(|lhs, rhs| {
            lhs.subtitle_path
                .cmp(&rhs.subtitle_path)
                .then(lhs.start_milliseconds.cmp(&rhs.start_milliseconds))
                .then(lhs.end_milliseconds.cmp(&rhs.end_milliseconds))
                .then(lhs.id.cmp(&rhs.id))
        });
        records
    }
}

pub fn shiori_cue_lines(content: &str) -> Vec<String> {
    content
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(ToOwned::to_owned)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn duplicate_upsert_preserves_created_at_and_updates_metadata() {
        let mut store = ShioriStore::default();
        let original = store.upsert(ShioriUpsert {
            subtitle_path: "/A.srt".to_string(),
            subtitle_format: SubtitleFormat::Srt,
            video_path: "/A.mkv".to_string(),
            video_name: "A.mkv".to_string(),
            start_milliseconds: 1_000,
            end_milliseconds: 2_000,
            content: "original".to_string(),
            created_at: "2023-01-01T00:00:00Z".to_string(),
        });
        let duplicate = store.upsert(ShioriUpsert {
            subtitle_path: "/A.srt".to_string(),
            subtitle_format: SubtitleFormat::Srt,
            video_path: "/A-remux.mkv".to_string(),
            video_name: "A-remux.mkv".to_string(),
            start_milliseconds: 1_000,
            end_milliseconds: 2_000,
            content: "updated".to_string(),
            created_at: "2024-01-01T00:00:00Z".to_string(),
        });

        assert_eq!(original.id, duplicate.id);
        assert_eq!(duplicate.created_at, "2023-01-01T00:00:00Z");
        assert_eq!(duplicate.video_path, "/A-remux.mkv");
        assert_eq!(store.records().len(), 1);
    }
}
