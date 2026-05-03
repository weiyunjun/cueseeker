#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/apps/macos-native"

VIDEO_PATH=""
SUBTITLE_PATH=""
DURATION_SECONDS="300"
START_SECONDS="0"
MODE="both"
SAMPLE_INTERVAL_SECONDS="1"
DRIFT_THRESHOLD_SECONDS="0.75"
STALL_THRESHOLD_SECONDS="2"
RUN_BACKEND_BASELINE="1"
VERBOSE="0"

usage() {
  cat <<'USAGE'
Usage:
  scripts/playback_sync_diagnostics.sh --video path --subtitle path [options]

Options:
  --mode native|legacy|both       Subtitle renderer mode to test. Default: both
  --duration seconds              Playback duration per app-mode run. Default: 300
  --start seconds                 Start timestamp. Default: 0
  --sample-interval seconds       App probe sampling interval. Default: 1
  --drift-threshold seconds       App media-clock drift threshold. Default: 0.75
  --stall-threshold seconds       Consecutive flat media-time threshold. Default: 2
  --skip-backend-baseline         Skip the NativePlaybackProbe audio/video baseline
  --verbose                       Print every app-probe sample
  -h, --help                      Show this help

The backend baseline uses NativePlaybackProbe and reports audio-clock/video
lateness. The app-mode runs use PlaybackSyncProbe and exercise the real
PlaybackPlayer with native or legacy ASS overlay attached.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --video)
      VIDEO_PATH="${2:-}"
      shift 2
      ;;
    --subtitle)
      SUBTITLE_PATH="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --duration)
      DURATION_SECONDS="${2:-}"
      shift 2
      ;;
    --start)
      START_SECONDS="${2:-}"
      shift 2
      ;;
    --sample-interval)
      SAMPLE_INTERVAL_SECONDS="${2:-}"
      shift 2
      ;;
    --drift-threshold)
      DRIFT_THRESHOLD_SECONDS="${2:-}"
      shift 2
      ;;
    --stall-threshold)
      STALL_THRESHOLD_SECONDS="${2:-}"
      shift 2
      ;;
    --skip-backend-baseline)
      RUN_BACKEND_BASELINE="0"
      shift
      ;;
    --verbose)
      VERBOSE="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${VIDEO_PATH}" || -z "${SUBTITLE_PATH}" ]]; then
  echo "Both --video and --subtitle are required." >&2
  usage >&2
  exit 2
fi

if [[ "${MODE}" != "native" && "${MODE}" != "legacy" && "${MODE}" != "both" ]]; then
  echo "--mode must be native, legacy, or both." >&2
  exit 2
fi

if [[ ! -f "${VIDEO_PATH}" ]]; then
  echo "Video file does not exist: ${VIDEO_PATH}" >&2
  exit 2
fi

if [[ ! -f "${SUBTITLE_PATH}" ]]; then
  echo "Subtitle file does not exist: ${SUBTITLE_PATH}" >&2
  exit 2
fi

LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cueseeker-sync.XXXXXX")"
echo "CueSeeker playback sync diagnostics"
echo "  video: ${VIDEO_PATH}"
echo "  subtitle: ${SUBTITLE_PATH}"
echo "  duration: ${DURATION_SECONDS}s"
echo "  logs: ${LOG_DIR}"

(
  cd "${APP_DIR}"
  swift build --product NativePlaybackProbe --product PlaybackSyncProbe
)

BIN_DIR="$(cd "${APP_DIR}" && swift build --show-bin-path)"
NATIVE_PLAYBACK_PROBE="${BIN_DIR}/NativePlaybackProbe"
PLAYBACK_SYNC_PROBE="${BIN_DIR}/PlaybackSyncProbe"

if [[ "${RUN_BACKEND_BASELINE}" == "1" ]]; then
  echo
  echo "== Backend audio/video baseline =="
  "${NATIVE_PLAYBACK_PROBE}" \
    --display \
    --quiet \
    --seek "${START_SECONDS}" \
    --run-duration "${DURATION_SECONDS}" \
    --memory-sample-interval "10" \
    "${VIDEO_PATH}" | tee "${LOG_DIR}/backend-av.log"
fi

declare -a MODES
if [[ "${MODE}" == "both" ]]; then
  MODES=(native legacy)
else
  MODES=("${MODE}")
fi

for renderer_mode in "${MODES[@]}"; do
  echo
  echo "== App playback sync: ${renderer_mode} =="
  args=(
    --mode "${renderer_mode}"
    --video "${VIDEO_PATH}"
    --subtitle "${SUBTITLE_PATH}"
    --duration "${DURATION_SECONDS}"
    --start "${START_SECONDS}"
    --sample-interval "${SAMPLE_INTERVAL_SECONDS}"
    --drift-threshold "${DRIFT_THRESHOLD_SECONDS}"
    --stall-threshold "${STALL_THRESHOLD_SECONDS}"
  )
  if [[ "${VERBOSE}" == "1" ]]; then
    args+=(--verbose)
  fi

  "${PLAYBACK_SYNC_PROBE}" "${args[@]}" | tee "${LOG_DIR}/app-${renderer_mode}.log"
done

echo
echo "Diagnostics complete. Logs are in ${LOG_DIR}"
