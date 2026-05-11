use std::fs;
use std::path::{Path, PathBuf};

pub fn supported_subtitle_extensions() -> &'static [&'static str] {
    &["srt", "ass"]
}

#[derive(Debug, Clone)]
pub struct SubtitleFileScanner {
    supported_extensions: Vec<String>,
}

impl Default for SubtitleFileScanner {
    fn default() -> Self {
        Self::new(supported_subtitle_extensions())
    }
}

impl SubtitleFileScanner {
    pub fn new(supported_extensions: &[&str]) -> Self {
        Self {
            supported_extensions: supported_extensions
                .iter()
                .map(|extension| extension.to_ascii_lowercase())
                .collect(),
        }
    }

    pub fn scan_srt_files(&self, folder: &Path) -> Vec<PathBuf> {
        self.scan_subtitle_files(folder)
            .into_iter()
            .filter(|path| extension_equals(path, "srt"))
            .collect()
    }

    pub fn scan_subtitle_files(&self, folder: &Path) -> Vec<PathBuf> {
        let mut subtitle_files = Vec::new();
        self.scan_folder(folder, &mut subtitle_files);
        subtitle_files.sort_by(|lhs, rhs| path_sort_key(lhs).cmp(&path_sort_key(rhs)));
        subtitle_files
    }

    fn scan_folder(&self, folder: &Path, subtitle_files: &mut Vec<PathBuf>) {
        let Ok(entries) = fs::read_dir(folder) else {
            return;
        };

        for entry in entries.flatten() {
            let path = entry.path();
            if is_hidden_path_component(&path) {
                continue;
            }

            let Ok(file_type) = entry.file_type() else {
                continue;
            };

            if file_type.is_symlink() {
                continue;
            }

            if file_type.is_dir() {
                self.scan_folder(&path, subtitle_files);
            } else if file_type.is_file() && self.is_supported_subtitle(&path) {
                subtitle_files.push(path);
            }
        }
    }

    fn is_supported_subtitle(&self, path: &Path) -> bool {
        let Some(extension) = path.extension().and_then(|extension| extension.to_str()) else {
            return false;
        };
        let lowercased = extension.to_ascii_lowercase();
        self.supported_extensions
            .iter()
            .any(|supported| supported == &lowercased)
    }
}

fn extension_equals(path: &Path, expected: &str) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .map(|extension| extension.eq_ignore_ascii_case(expected))
        .unwrap_or(false)
}

fn is_hidden_path_component(path: &Path) -> bool {
    path.file_name()
        .and_then(|name| name.to_str())
        .map(|name| name.starts_with('.'))
        .unwrap_or(false)
}

fn path_sort_key(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn returns_empty_for_missing_folder() {
        let scanner = SubtitleFileScanner::default();
        let missing = std::env::temp_dir().join(unique_name("missing"));

        assert!(scanner.scan_subtitle_files(&missing).is_empty());
    }

    #[test]
    fn skips_symlink_directories() {
        let root = std::env::temp_dir().join(unique_name("scanner"));
        let real = root.join("Real");
        let linked = root.join("Linked");
        fs::create_dir_all(&real).unwrap();
        fs::write(real.join("LinkedOnly.srt"), "subtitle").unwrap();

        #[cfg(unix)]
        std::os::unix::fs::symlink(&real, &linked).unwrap();

        let scanner = SubtitleFileScanner::default();
        let results = scanner.scan_subtitle_files(&root);

        #[cfg(unix)]
        assert_eq!(results, vec![real.join("LinkedOnly.srt")]);

        let _ = fs::remove_dir_all(root);
    }

    fn unique_name(prefix: &str) -> String {
        let millis = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis();
        format!("CueSeeker-{prefix}-{millis}")
    }
}
