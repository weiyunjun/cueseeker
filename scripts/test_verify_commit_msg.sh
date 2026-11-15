#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify_commit_msg.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Create an isolated mock repo root with real requirement files for deterministic tests
MOCK_ROOT="$TMP_DIR/repo"
mkdir -p "$MOCK_ROOT/docs/human/requirements/archive"
mkdir -p "$MOCK_ROOT/docs/human/design/ui"
REQ_A="docs/human/requirements/20261115-Engineering-Conventional Commit Format And Strict Single-Line Requirement Hook.md"
REQ_B="docs/human/requirements/20261115-Feature-Sample Requirement.md"
printf "# Mock Requirement A\n" > "$MOCK_ROOT/$REQ_A"
printf "# Mock Requirement B\n" > "$MOCK_ROOT/$REQ_B"
printf "# Archived Requirement\n" > "$MOCK_ROOT/docs/human/requirements/archive/20260101-Old.md"
printf "# Design Doc\n" > "$MOCK_ROOT/docs/human/design/ui/UI Index.md"

pass_count=0
fail_count=0

run_test() {
    local desc="$1"
    local content="$2"
    local expected_exit="$3"

    local msg_file="$TMP_DIR/msg.txt"
    printf "%s\n" "$content" > "$msg_file"

    set +e
    CUESEEKER_REPO_ROOT="$MOCK_ROOT" "$VERIFY_SCRIPT" "$msg_file" > /dev/null 2>&1
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

# Valid cases
run_test "Valid feat commit" \
    "feat: add settings about page ($REQ_B)" \
    0

run_test "Valid docs commit for design sync citing only requirement" \
    "docs: sync settings about design spec ($REQ_B)" \
    0

run_test "Valid chore commit with hook requirement" \
    "chore: enforce strict single-line conventional commit hook ($REQ_A)" \
    0

run_test "Valid fix commit with git comment lines" \
    "fix: fallback debug icon on about page ($REQ_B)

# Please enter the commit message for your changes.
# Lines starting with '#' will be ignored." \
    0

# Invalid cases
run_test "Reject multi-line commit message with body" \
    "feat: add settings about page ($REQ_B)

Additional body paragraph is forbidden." \
    1

run_test "Reject legacy uppercase area prefix" \
    "Docs: update git workflow rules ($REQ_A)" \
    1

run_test "Reject scoped conventional commit prefix" \
    "feat(settings): add about page ($REQ_B)" \
    1

run_test "Reject unknown lowercase type prefix" \
    "update: adjust commit hook script ($REQ_A)" \
    1

run_test "Reject Chinese characters in summary" \
    "feat: 新增设置关于页面 ($REQ_B)" \
    1

run_test "Reject full-width punctuation" \
    "feat：add settings about page ($REQ_B)" \
    1

run_test "Reject single-word vague summary" \
    "fix: update ($REQ_B)" \
    1

run_test "Reject missing requirement path" \
    "feat: add settings about page" \
    1

run_test "Reject bare requirement path without parentheses" \
    "feat: add settings about page for $REQ_B" \
    1

run_test "Reject bare requirement path embedded inside summary" \
    "docs: add $REQ_B ($REQ_B)" \
    1

run_test "Reject leading or trailing spaces" \
    " feat: add settings about page ($REQ_B)" \
    1

run_test "Reject leading slash in requirement path" \
    "feat: add settings about page (/$REQ_B)" \
    1

run_test "Reject design document path in parentheses" \
    "docs: sync dialog scrim spec (docs/human/design/ui/UI Index.md)" \
    1

run_test "Reject comma-joined requirement and design paths" \
    "docs: sync dialog scrim spec ($REQ_B, docs/human/design/ui/UI Index.md)" \
    1

run_test "Reject multiple parenthesized requirement paths" \
    "docs: sync specs ($REQ_A) ($REQ_B)" \
    1

run_test "Reject archived subdirectory requirement path" \
    "docs: cite archived requirement (docs/human/requirements/archive/20260101-Old.md)" \
    1

run_test "Reject non-existent requirement file" \
    "feat: add settings about page (docs/human/requirements/20991231-Feature-Does Not Exist.md)" \
    1

run_test "Reject empty message" \
    "" \
    1

run_test "Reject comment-only message" \
    "# This is a comment
# Another comment line" \
    1

echo "=== Test Results: $pass_count passed, $fail_count failed ==="

if [ "$fail_count" -ne 0 ]; then
    exit 1
fi
exit 0
