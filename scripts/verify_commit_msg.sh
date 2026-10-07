#!/bin/bash
set -euo pipefail

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

if [ -z "$COMMIT_FILE" ] || [ ! -f "$COMMIT_FILE" ]; then
    echo "error: commit message file not provided or does not exist." >&2
    exit 1
fi

# Extract the subject (first non-comment, non-empty line)
SUBJECT=""
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        \#*) continue ;;
    esac
    trimmed="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -n "$trimmed" ]; then
        SUBJECT="$line"
        break
    fi
done < "$COMMIT_FILE"

if [ -z "$SUBJECT" ]; then
    echo "error: commit message is empty." >&2
    exit 1
fi

# 1. Subject format validation: must match ^[A-Z][a-zA-Z0-9 &]*: .+
if ! [[ "$SUBJECT" =~ ^[A-Z][a-zA-Z0-9\ \&]*:\ .+ ]]; then
    echo "================================================================================" >&2
    echo "Commit Message Verification Failed (Subject Format):" >&2
    echo "  Current subject: '$SUBJECT'" >&2
    echo "" >&2
    echo "Rule:" >&2
    echo "  Subject must follow '<Area>: <concise summary>' with Area starting with uppercase." >&2
    echo "  Conventional Commits (e.g. 'feat:') or lowercase prefixes (e.g. 'docs:') are forbidden." >&2
    echo "  Example: Docs: add new feature (docs/human/requirements/...)" >&2
    echo "================================================================================" >&2
    exit 1
fi

# 2. Traceability validation: must contain docs/human/ in non-comment lines
HAS_DOCS_HUMAN=false
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        \#*) continue ;;
    esac
    if [[ "$line" =~ docs/human/ ]]; then
        HAS_DOCS_HUMAN=true
        break
    fi
done < "$COMMIT_FILE"

if [ "$HAS_DOCS_HUMAN" != "true" ]; then
    echo "================================================================================" >&2
    echo "Commit Message Verification Failed (Missing Requirement Traceability):" >&2
    echo "  Commit message must cite a relevant document under 'docs/human/'." >&2
    echo "" >&2
    echo "Expected format:" >&2
    echo "  <Area>: <concise summary> (docs/human/requirements/<requirement-doc>.md)" >&2
    echo "  or include docs/human/<path> in the commit body." >&2
    echo "================================================================================" >&2
    exit 1
fi

exit 0
