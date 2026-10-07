#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify_commit_msg.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

pass_count=0
fail_count=0

run_test() {
    local desc="$1"
    local content="$2"
    local expected_exit="$3"

    local msg_file="$TMP_DIR/msg.txt"
    printf "%s\n" "$content" > "$msg_file"

    set +e
    "$VERIFY_SCRIPT" "$msg_file" > /dev/null 2>&1
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

echo "=== Running commit message verification tests ==="

# 1. Standard valid single-line message
run_test "Standard valid single-line message" \
    "Docs: add commit message verification (docs/human/requirements/20261007-Engineering-Commit Message Validation Hook.md)" \
    0

# 2. Standard valid multi-line message (docs path in body)
run_test "Standard valid multi-line message" \
    "Search: eliminate disk logs and enforce test isolation

docs/human/requirements/20261003-Engineering-Eliminate Disk Logs And Enforce Clean Tests.md" \
    0

# 3. Valid multi-word Area
run_test "Valid multi-word Area" \
    "Search & Excerpt: remove deferred refresh (docs/human/requirements/test.md)" \
    0

# 4. Reject: missing docs/human/ path
run_test "Reject missing docs/human/ path" \
    "UI: reduce button height to 32px" \
    1

# 5. Reject: lowercase area
run_test "Reject lowercase area" \
    "docs: update requirement (docs/human/requirements/test.md)" \
    1

# 6. Reject: conventional commit format
run_test "Reject conventional commit format" \
    "feat(file): direct query and instant rendering (docs/human/requirements/test.md)" \
    1

# 7. Reject: no colon in subject
run_test "Reject subject without colon" \
    "Update requirement docs (docs/human/requirements/test.md)" \
    1

# 8. Reject: empty message
run_test "Reject empty message" \
    "" \
    1

# 9. Reject: comment-only message
run_test "Reject comment-only message" \
    "# This is a comment
# Another comment line" \
    1

echo "=== Test Results: $pass_count passed, $fail_count failed ==="

if [ "$fail_count" -ne 0 ]; then
    exit 1
fi
exit 0
