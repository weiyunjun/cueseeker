use crate::subtitle_indexer::SubtitleIndexingProjection;
use crate::subtitles::SubtitleFormat;

#[derive(Debug, Clone, PartialEq)]
pub struct SubtitleSearchResult {
    pub subtitle_path: String,
    pub subtitle_format: SubtitleFormat,
    pub video_path: String,
    pub video_name: String,
    pub start_milliseconds: i32,
    pub end_milliseconds: i32,
    pub content: String,
    pub cue_lines: Vec<String>,
    pub entry_id: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SubtitleSearchPage {
    pub results: Vec<SubtitleSearchResult>,
    pub total_count: usize,
}

#[derive(Debug, Clone)]
struct SearchQueryPlan {
    line_match_rule: LineMatchRule,
}

#[derive(Debug, Clone)]
enum LineMatchRule {
    LatinPrefix(String),
    OrderedLatinTokens(Vec<String>),
    CjkSubstring(String),
    ExplicitFts(String),
}

pub fn search_projection(
    projection: &SubtitleIndexingProjection,
    query: &str,
    limit: usize,
    offset: usize,
) -> SubtitleSearchPage {
    let Some(plan) = search_query_plan(query, limit) else {
        return SubtitleSearchPage {
            results: Vec::new(),
            total_count: 0,
        };
    };

    let mut results = Vec::new();
    let mut entry_id = 0;

    for file in &projection.indexed_files {
        let video_name = file
            .video_path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or_default()
            .to_string();

        for group in &file.cue_groups {
            let cue_lines: Vec<String> = group
                .cue_lines
                .iter()
                .map(|line| line.content.clone())
                .collect();
            let searchable_lines = if cue_lines.is_empty() {
                vec![group.search_content.clone()]
            } else {
                cue_lines.clone()
            };

            if searchable_lines
                .iter()
                .any(|line| line_matches(line, &plan.line_match_rule))
            {
                results.push(SubtitleSearchResult {
                    subtitle_path: file.subtitle_path.to_string_lossy().into_owned(),
                    subtitle_format: file.format,
                    video_path: file.video_path.to_string_lossy().into_owned(),
                    video_name: video_name.clone(),
                    start_milliseconds: group.start_milliseconds,
                    end_milliseconds: group.end_milliseconds,
                    content: group.search_content.clone(),
                    cue_lines,
                    entry_id,
                });
            }
            entry_id += 1;
        }
    }

    sorted_search_results(&mut results);
    let total_count = results.len();
    let page_results = results.into_iter().skip(offset).take(limit).collect();
    SubtitleSearchPage {
        results: page_results,
        total_count,
    }
}

fn search_query_plan(query: &str, limit: usize) -> Option<SearchQueryPlan> {
    let trimmed = query.trim();
    if trimmed.is_empty() || limit == 0 {
        return None;
    }

    let has_explicit_phrase =
        trimmed.len() >= 2 && trimmed.starts_with('"') && trimmed.ends_with('"');
    let has_fts_syntax =
        has_explicit_phrase || trimmed.contains('*') || contains_fts_operator(trimmed);
    let has_cjk = contains_cjk_search_character(trimmed);
    let query_tokens = if has_cjk {
        Vec::new()
    } else {
        tokenize_latin_tokens(trimmed)
    };

    if !has_fts_syntax && !has_cjk && query_tokens.is_empty() {
        return None;
    }

    let line_match_rule = if has_fts_syntax {
        LineMatchRule::ExplicitFts(trimmed.to_string())
    } else if has_cjk {
        LineMatchRule::CjkSubstring(trimmed.to_string())
    } else if query_tokens.len() > 1 {
        LineMatchRule::OrderedLatinTokens(query_tokens)
    } else {
        LineMatchRule::LatinPrefix(query_tokens[0].clone())
    };

    Some(SearchQueryPlan { line_match_rule })
}

fn line_matches(line: &str, rule: &LineMatchRule) -> bool {
    match rule {
        LineMatchRule::LatinPrefix(token) => tokenize_latin_tokens(line)
            .iter()
            .any(|line_token| line_token.starts_with(token)),
        LineMatchRule::OrderedLatinTokens(tokens) => matches_ordered_whole_tokens(line, tokens),
        LineMatchRule::CjkSubstring(query) => line.contains(query),
        LineMatchRule::ExplicitFts(query) => matches_explicit_fts_line_fallback(line, query),
    }
}

fn matches_explicit_fts_line_fallback(line: &str, query: &str) -> bool {
    let trimmed = query.trim();
    if trimmed.len() >= 2 && trimmed.starts_with('"') && trimmed.ends_with('"') {
        let phrase = &trimmed[1..trimmed.len() - 1];
        return line.to_lowercase().contains(&phrase.to_lowercase());
    }

    let operators = ["AND", "OR", "NOT", "NEAR"];
    let query_tokens: Vec<String> = tokenize_latin_tokens(trimmed)
        .into_iter()
        .filter(|token| !operators.contains(&token.to_uppercase().as_str()))
        .collect();

    if query_tokens.is_empty() {
        return false;
    }

    let line_tokens = tokenize_latin_tokens(line);
    if trimmed.to_uppercase().contains(" OR ") {
        return query_tokens.iter().any(|token| {
            line_tokens
                .iter()
                .any(|line_token| line_token == token || line_token.starts_with(token))
        });
    }

    query_tokens.iter().all(|token| {
        line_tokens
            .iter()
            .any(|line_token| line_token == token || line_token.starts_with(token))
    })
}

fn contains_fts_operator(text: &str) -> bool {
    let operators = ["AND", "OR", "NOT", "NEAR"];
    let mut current = String::new();

    for character in text.chars() {
        if is_ascii_word_character(character) {
            current.push(character);
        } else {
            if operators.contains(&current.as_str()) {
                return true;
            }
            current.clear();
        }
    }

    operators.contains(&current.as_str())
}

fn tokenize_latin_tokens(text: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let mut current = String::new();
    let mut contains_apostrophe = false;
    let mut chars = text.chars().peekable();

    while let Some(character) = chars.next() {
        if character.is_ascii_alphanumeric() {
            current.push(character.to_ascii_lowercase());
        } else if character == '\''
            && !current.is_empty()
            && !contains_apostrophe
            && chars
                .peek()
                .is_some_and(|next| next.is_ascii_alphanumeric())
        {
            current.push(character);
            contains_apostrophe = true;
        } else {
            flush_token(&mut tokens, &mut current);
            contains_apostrophe = false;
        }
    }

    flush_token(&mut tokens, &mut current);
    tokens
}

fn matches_ordered_whole_tokens(content: &str, query_tokens: &[String]) -> bool {
    if query_tokens.is_empty() {
        return false;
    }

    let content_tokens = tokenize_latin_tokens(content);
    if content_tokens.len() < query_tokens.len() {
        return false;
    }

    let mut query_index = 0;
    for token in content_tokens {
        if token == query_tokens[query_index] {
            query_index += 1;
            if query_index == query_tokens.len() {
                return true;
            }
        }
    }

    false
}

fn contains_cjk_search_character(text: &str) -> bool {
    text.chars().any(is_cjk_search_character)
}

fn is_cjk_search_character(character: char) -> bool {
    let value = character as u32;
    (0x3400..=0x4DBF).contains(&value)
        || (0x4E00..=0x9FFF).contains(&value)
        || (0xF900..=0xFAFF).contains(&value)
        || (0x3040..=0x309F).contains(&value)
        || (0x30A0..=0x30FF).contains(&value)
        || (0x31F0..=0x31FF).contains(&value)
        || (0xFF66..=0xFF9F).contains(&value)
}

fn is_ascii_word_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || character == '_'
}

fn flush_token(tokens: &mut Vec<String>, current: &mut String) {
    if !current.is_empty() {
        tokens.push(std::mem::take(current));
    }
}

fn sorted_search_results(results: &mut [SubtitleSearchResult]) {
    results.sort_by(|lhs, rhs| {
        lhs.subtitle_path
            .cmp(&rhs.subtitle_path)
            .then(lhs.start_milliseconds.cmp(&rhs.start_milliseconds))
            .then(lhs.end_milliseconds.cmp(&rhs.end_milliseconds))
            .then(lhs.entry_id.cmp(&rhs.entry_id))
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_cross_line_ordered_matches() {
        let tokens = vec!["alpha".to_string(), "beta".to_string()];

        assert!(matches_ordered_whole_tokens("alpha middle beta", &tokens));
        assert!(!matches_ordered_whole_tokens("beta alpha", &tokens));
    }
}
