#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOCAL_VIDEO_PATH="/Users/weiyunjun/Documents/video/胜 者即是正义01.mkv"
LOCAL_SUBTITLE_PATH="/Users/weiyunjun/Documents/video/胜 者即是正义01.ass"

usage() {
  cat <<'USAGE'
Usage:
  scripts/playback_sync_local_diagnostics.sh [options]

Defaults:
  video: /Users/weiyunjun/Documents/video/胜 者即是正义01.mkv
  subtitle: /Users/weiyunjun/Documents/video/胜 者即是正义01.ass
  mode: legacy
  duration: 300
  backend baseline: enabled

Any option accepted by playback_sync_diagnostics.sh can be appended after the
defaults, for example:

  scripts/playback_sync_local_diagnostics.sh --mode both
  scripts/playback_sync_local_diagnostics.sh --duration 60
USAGE
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

exec "${ROOT_DIR}/scripts/playback_sync_diagnostics.sh" \
  --video "${LOCAL_VIDEO_PATH}" \
  --subtitle "${LOCAL_SUBTITLE_PATH}" \
  --mode legacy \
  --duration 300 \
  "$@"
