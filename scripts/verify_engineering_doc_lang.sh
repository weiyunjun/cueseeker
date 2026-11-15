#!/bin/bash
set -euo pipefail

# Self-installation mode for .git/hooks/pre-commit
if [ "${1:-}" = "--install" ]; then
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    HOOK_DIR="$(git rev-parse --git-path hooks 2>/dev/null || echo "$ROOT/.git/hooks")"
    mkdir -p "$HOOK_DIR"
    HOOK_FILE="$HOOK_DIR/pre-commit"
    cat << 'EOF' > "$HOOK_FILE"
#!/bin/bash
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "$ROOT/scripts/verify_engineering_doc_lang.sh" ]; then
    exec "$ROOT/scripts/verify_engineering_doc_lang.sh"
fi
exit 0
EOF
    chmod +x "$HOOK_FILE"
    echo "Installed pre-commit hook to $HOOK_FILE"
    exit 0
fi

ROOT="${CUESEEKER_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

exec python3 - "$ROOT" "$@" << 'PYEOF'
import os
import re
import subprocess
import sys

FENCE_OPEN_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})")
INLINE_CODE_RE = re.compile(r"(`+)(?:(?!\1).)+?\1")
DOUBLE_QUOTE_RE = re.compile(r'"[^"\n]*"')
SINGLE_QUOTE_RE = re.compile(r"(?<![A-Za-z0-9])'[^'\n]+'(?![A-Za-z0-9])")

FORBIDDEN_CJK_OR_FULLWIDTH_RE = re.compile(
    r"[\u2e80-\u2eff"
    r"\u3000-\u303f"
    r"\u3040-\u30ff"
    r"\u31c0-\u31ef"
    r"\u3400-\u4dbf"
    r"\u4e00-\u9fff"
    r"\uac00-\ud7af"
    r"\uf900-\ufaff"
    r"\ufe30-\ufe4f"
    r"\uff01-\uff60"
    r"\uffe0-\uffe6"
    r"\U00020000-\U0002ebef]"
)


def is_target_engineering_doc(rel_path: str) -> bool:
    return rel_path == "docs/changelog.md" or (
        rel_path.startswith("docs/engineering/") and rel_path.endswith(".md")
    )


def find_violations(text: str):
    violations = []
    in_fence = None
    for line_no, raw_line in enumerate(text.splitlines(), 1):
        fence_match = FENCE_OPEN_RE.match(raw_line)
        if fence_match:
            marker = fence_match.group(1)
            if in_fence is None:
                in_fence = (marker[0], len(marker))
                continue
            if (
                marker[0] == in_fence[0]
                and len(marker) >= in_fence[1]
                and raw_line[fence_match.end() :].strip() == ""
            ):
                in_fence = None
                continue
        if in_fence is not None:
            continue

        stripped = INLINE_CODE_RE.sub("", raw_line)
        stripped = DOUBLE_QUOTE_RE.sub("", stripped)
        stripped = SINGLE_QUOTE_RE.sub("", stripped)

        match = FORBIDDEN_CJK_OR_FULLWIDTH_RE.search(stripped)
        if match:
            violations.append((line_no, match.group(0), raw_line.strip()))
    return violations


def load_targets(repo_root: str, cli_files):
    targets = []
    if cli_files:
        for file_arg in cli_files:
            if not os.path.isfile(file_arg):
                sys.stderr.write(
                    f"error: documentation file does not exist: '{file_arg}'\n"
                )
                sys.exit(1)
            with open(file_arg, "r", encoding="utf-8") as fh:
                targets.append((file_arg, fh.read()))
        return targets

    proc = subprocess.run(
        ["git", "-C", repo_root, "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR"],
         capture_output=True,
        check=True,
    )
    staged_paths = [
        p.decode("utf-8") for p in proc.stdout.split(b"\0") if p
    ]
    for rel_path in staged_paths:
        if not is_target_engineering_doc(rel_path):
            continue
        blob = subprocess.run(
            ["git", "-C", repo_root, "show", f":{rel_path}"],
            capture_output=True,
            check=True,
        )
        targets.append((rel_path, blob.stdout.decode("utf-8")))
    return targets


def main():
    repo_root = sys.argv[1]
    cli_files = sys.argv[2:]
    targets = load_targets(repo_root, cli_files)

    all_failures = []
    for display_path, content in targets:
        file_violations = find_violations(content)
        if file_violations:
            all_failures.append((display_path, file_violations))

    if not all_failures:
        sys.exit(0)

    sys.stderr.write("=" * 80 + "\n")
    sys.stderr.write("Engineering Documentation Language Verification Failed:\n")
    sys.stderr.write(
        "  AI-maintained files under 'docs/engineering/' and 'docs/changelog.md'\n"
        "  must be written in English. Wrap literal non-English UI strings,\n"
        "  external titles, or query examples in backticks (`...`), ASCII quotes\n"
        "  (\"...\"), or fenced code blocks.\n\n"
    )
    for display_path, file_violations in all_failures:
        for line_no, bad_char, excerpt in file_violations[:10]:
            sys.stderr.write(
                f"  {display_path}:{line_no}: unexpected '{bad_char}' in: {excerpt}\n"
            )
        remaining = len(file_violations) - 10
        if remaining > 0:
            sys.stderr.write(
                f"  {display_path}: ... and {remaining} more line(s)\n"
            )
    sys.stderr.write("=" * 80 + "\n")
    sys.exit(1)


if __name__ == "__main__":
    main()
PYEOF
