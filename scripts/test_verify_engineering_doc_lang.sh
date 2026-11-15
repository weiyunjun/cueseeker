#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify_engineering_doc_lang.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

pass_count=0
fail_count=0

assert_exit() {
    local desc="$1"
    local expected_exit="$2"
    shift 2

    set +e
    "$@" > /dev/null 2>&1
    local actual_exit=$?
    set -e

    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "PASS: $desc"
        pass_count=$((pass_count + 1))
    else
        echo "FAIL: $desc (expected exit $expected_exit, got $actual_exit)"
        fail_count=$((fail_count + 1))
    fi
}

run_file_test() {
    local desc="$1"
    local content="$2"
    local expected_exit="$3"

    local doc_file="$TMP_DIR/sample.md"
    printf "%s\n" "$content" > "$doc_file"
    assert_exit "$desc" "$expected_exit" "$VERIFY_SCRIPT" "$doc_file"
}

echo "=== Running engineering documentation language verification tests ==="

# Valid direct-file cases
run_file_test "Allow pure English implementation record with macOS symbols and en/em dashes" \
    "# 2026-11-15 Sample Implementation Record

## Summary

- Updated shortcut handling for ⌘, and ⇧← — preserving CueSeeker's focus ring (pages 1–3)." \
    0

run_file_test "Allow non-English UI copy inside inline backticks and double/single ASCII quotes" \
    "# HDR Metadata Display

- Localized Dolby Vision as \`杜比视界\`, \"杜比視界\", and '杜比视界' alongside benchmark query \`大丈夫\`." \
    0

run_file_test "Allow non-English examples inside fenced code blocks" \
    "# Localization Fixture

\`\`\`text
zh-Hans: 全部文件夹
ja: 大丈夫
\`\`\`" \
    0

# Invalid direct-file cases
run_file_test "Reject Chinese heading in implementation record" \
    "# HDR 元数据索引工程实现记录

- Updated metadata probing." \
    1

run_file_test "Reject bare Chinese prose in bullet item" \
    "# Sample Record

- 对应需求单: \`docs/human/requirements/20261115-Feature-Sample.md\`" \
    1

run_file_test "Reject full-width punctuation in English prose" \
    "# Sample Record

- Related Requirement：\`docs/human/requirements/20261115-Feature-Sample.md\`" \
    1

run_file_test "Reject bare Chinese between English contraction apostrophes" \
    "# Sample Record

- CueSeeker's UI 全部文件夹 isn't allowed without backticks or quotes." \
    1

run_file_test "Reject Chinese curly quotes wrapping bare Chinese text" \
    "# Sample Record

- Localized badge as “杜比视界” without ASCII quotes or backticks." \
    1

# Git index / pre-commit staging scope tests
MOCK_REPO="$TMP_DIR/repo"
git init -q "$MOCK_REPO"
git -C "$MOCK_REPO" config user.name "Test User"
git -C "$MOCK_REPO" config user.email "test@example.com"
mkdir -p "$MOCK_REPO/docs/human/requirements" "$MOCK_REPO/docs/engineering/records" "$MOCK_REPO/Apps"

# Historical unstaged/unmodified Chinese record already in HEAD must not block unrelated commits
printf "# 历史中文实现记录\n\n- 旧内容保持不动。\n" \
    > "$MOCK_REPO/docs/engineering/records/2026-08-20-legacy-record.md"
printf "# Changelog\n\n## Unreleased\n" > "$MOCK_REPO/docs/changelog.md"
git -C "$MOCK_REPO" add .
git -C "$MOCK_REPO" commit -q -m "initial baseline"

# Install hook into mock repo and verify installation
(cd "$MOCK_REPO" && "$VERIFY_SCRIPT" --install > /dev/null)

# 1. Staged Chinese requirement under docs/human/ must pass while legacy record stays untouched
printf "# 版本\n\nmain\n\n# 需求描述\n\n1. 允许人类需求单使用中文。\n" \
    > "$MOCK_REPO/docs/human/requirements/20261115-Feature-Human Doc.md"
git -C "$MOCK_REPO" add "docs/human/requirements/20261115-Feature-Human Doc.md"
assert_exit "Ignore staged Chinese files under docs/human/ and untouched historical records" \
    0 env CUESEEKER_REPO_ROOT="$MOCK_REPO" "$VERIFY_SCRIPT"

# 2. Staged Chinese implementation record under docs/engineering/records/ must be blocked
printf "# 新建中文实现记录\n\n- 修改摘要。\n" \
    > "$MOCK_REPO/docs/engineering/records/20261115-bad-record.md"
git -C "$MOCK_REPO" add "docs/engineering/records/20261115-bad-record.md"
assert_exit "Block staged Chinese implementation record under docs/engineering/records/" \
    1 env CUESEEKER_REPO_ROOT="$MOCK_REPO" "$VERIFY_SCRIPT"
git -C "$MOCK_REPO" reset -q HEAD "docs/engineering/records/20261115-bad-record.md"
rm -f "$MOCK_REPO/docs/engineering/records/20261115-bad-record.md"

# 3. Staged bare Chinese in docs/changelog.md must be blocked
printf "\n- Added Excerpt (摘录 in Chinese).\n" >> "$MOCK_REPO/docs/changelog.md"
git -C "$MOCK_REPO" add "docs/changelog.md"
assert_exit "Block staged bare Chinese in docs/changelog.md" \
    1 env CUESEEKER_REPO_ROOT="$MOCK_REPO" "$VERIFY_SCRIPT"

# 4. Staged English record + backticked UI copy in docs/changelog.md must pass
printf "# Changelog\n\n## Unreleased\n\n- Added Excerpt (\`摘录\` in Chinese).\n" \
    > "$MOCK_REPO/docs/changelog.md"
printf "# 2026-11-15 Valid Record\n\n- Verified \`全部文件夹\` copy.\n" \
    > "$MOCK_REPO/docs/engineering/records/20261115-good-record.md"
git -C "$MOCK_REPO" add "docs/changelog.md" "docs/engineering/records/20261115-good-record.md"
assert_exit "Allow staged English record and backtick-wrapped UI copy in docs/changelog.md" \
    0 env CUESEEKER_REPO_ROOT="$MOCK_REPO" "$VERIFY_SCRIPT"

echo "=== Test Results: $pass_count passed, $fail_count failed ==="

if [ "$fail_count" -ne 0 ]; then
    exit 1
fi
exit 0
