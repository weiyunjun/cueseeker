#!/bin/bash
set -euo pipefail
export LC_ALL=C

# Self-installation mode
if [ "${1:-}" = "--install" ]; then
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    HOOK_DIR="$(git rev-parse --git-path hooks 2>/dev/null || echo "$ROOT/.git/hooks")"
    mkdir -p "$HOOK_DIR"
    HOOK_FILE="$HOOK_DIR/commit-msg"
    cat << 'EOF' > "$HOOK_FILE"
#!/bin/bash
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "$ROOT/scripts/verify_commit_msg.sh" ]; then
    exec "$ROOT/scripts/verify_commit_msg.sh" "$1"
fi
exit 0
EOF
    chmod +x "$HOOK_FILE"
    echo "Installed commit-msg hook to $HOOK_FILE"
    exit 0
fi

COMMIT_FILE="${1:-}"
ROOT="${CUESEEKER_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

if [ -z "$COMMIT_FILE" ] || [ ! -f "$COMMIT_FILE" ]; then
    echo "error: commit message file not provided or does not exist." >&2
    exit 1
fi

fail() {
    local reason="$1"
    local current="${2:-}"
    echo "================================================================================" >&2
    echo "Commit Message Verification Failed:" >&2
    echo "  Reason: $reason" >&2
    if [ -n "$current" ]; then
        echo "  Current: '$current'" >&2
    fi
    echo "" >&2
    echo "Required single-line format (pure English ASCII):" >&2
    echo "  <type>: <concise summary> (docs/human/requirements/<requirement>.md)" >&2
    echo "" >&2
    echo "Allowed <type> prefixes (lowercase only, no '(scope)'):" >&2
    echo "  feat | fix | docs | refactor | perf | style | test | build | ci | chore | revert" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  feat: add settings about page (docs/human/requirements/20261115-Feature-Example.md)" >&2
    echo "================================================================================" >&2
    exit 1
}

# Collect all non-comment, non-blank lines
NON_EMPTY_LINES=()
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        \#*) continue ;;
    esac
    trimmed="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -n "$trimmed" ]; then
        NON_EMPTY_LINES+=("$line")
    fi
done < "$COMMIT_FILE"

if [ "${#NON_EMPTY_LINES[@]}" -eq 0 ]; then
    fail "Commit message is empty."
fi

if [ "${#NON_EMPTY_LINES[@]}" -gt 1 ]; then
    fail "Multi-line commit messages are forbidden; commit message must be a single line." "${NON_EMPTY_LINES[0]}"
fi

SUBJECT="${NON_EMPTY_LINES[0]}"

# 1. Pure English printable ASCII check (rejects CJK, full-width punctuation, tabs, CR)
if printf '%s' "$SUBJECT" | grep -q '[^ -~]'; then
    fail "Commit message must use pure English printable ASCII characters only (no Chinese, full-width punctuation, or tabs)." "$SUBJECT"
fi

case "$SUBJECT" in
    " "*|*" ")
        fail "Commit message must not have leading or trailing spaces." "$SUBJECT"
        ;;
esac

# 2. Reject scoped Conventional Commits such as feat(ui):
SCOPED_RE='^[A-Za-z]+\([^)]*\):'
if [[ "$SUBJECT" =~ $SCOPED_RE ]]; then
    fail "Scoped prefixes such as '<type>(<scope>):' are forbidden; use '<type>: <summary> (...)'." "$SUBJECT"
fi

# 3. Validate lowercase <type>: prefix whitelist
PREFIX_RE='^(feat|fix|docs|refactor|perf|style|test|build|ci|chore|revert): (.+)$'
if ! [[ "$SUBJECT" =~ $PREFIX_RE ]]; then
    fail "Subject must start with an allowed lowercase '<type>: ' prefix." "$SUBJECT"
fi
REST="${BASH_REMATCH[2]}"

# 4. Validate single trailing requirement path in parentheses (no leading '/', no subdirectories, no extra paths)
TRAIL_RE='^(.+) \(docs/human/requirements/([A-Za-z0-9][^/(),]*\.md)\)$'
if ! [[ "$REST" =~ $TRAIL_RE ]]; then
    fail "Subject must end with a single requirement path in parentheses: '(docs/human/requirements/<requirement>.md)'." "$SUBJECT"
fi
SUMMARY="${BASH_REMATCH[1]}"
REQ_FILENAME="${BASH_REMATCH[2]}"

# 5. Validate concise multi-word English summary without embedded paths
WORDS_RE='^[^ ]+( [^ ]+)+$'
LETTERS_RE='[A-Za-z]{2,}'
if ! [[ "$SUMMARY" =~ $WORDS_RE ]] || ! [[ "$SUMMARY" =~ $LETTERS_RE ]]; then
    fail "Summary must be a concise multi-word English description separated by single spaces (single-word vague summaries such as 'update' or 'changes' are forbidden)." "$SUBJECT"
fi

if [[ "$SUMMARY" == *"docs/human/"* ]] || [[ "$SUMMARY" == *"requirements/"* ]]; then
    fail "Do not include 'docs/human/' or 'requirements/' paths in the summary; attach a single requirement path in trailing parentheses only." "$SUBJECT"
fi

# 6. Verify that the referenced requirement document exists in the repository
REQ_REL_PATH="docs/human/requirements/$REQ_FILENAME"
if [ ! -f "$ROOT/$REQ_REL_PATH" ]; then
    fail "Referenced requirement file does not exist in repository: '$REQ_REL_PATH'." "$SUBJECT"
fi

exit 0
