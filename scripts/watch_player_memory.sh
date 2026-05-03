#!/usr/bin/env bash
set -euo pipefail

readonly INTERVAL_SECONDS=5
readonly APPS=("CueSeeker" "Movist Pro")
STATE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cueseeker-player-memory.XXXXXX")"

cleanup() {
  rm -rf "${STATE_DIR}"
}
trap cleanup EXIT

cpu_time_seconds() {
  local time_text="$1"

  awk -v value="${time_text}" '
    BEGIN {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      days = 0
      rest = value
      if (index(value, "-") > 0) {
        split(value, day_parts, "-")
        days = day_parts[1] + 0
        rest = day_parts[2]
      }
      count = split(rest, parts, ":")
      if (count == 2) {
        seconds = (parts[1] * 60) + parts[2]
      } else if (count == 3) {
        seconds = (parts[1] * 3600) + (parts[2] * 60) + parts[3]
      } else {
        seconds = rest + 0
      }
      printf "%.3f", (days * 86400) + seconds
    }
  '
}

cpu_percent_for_pid() {
  local pid="$1"
  local now_seconds="$2"
  local state_path="${STATE_DIR}/${pid}.state"
  local cpu_time_text cpu_seconds previous_cpu_seconds previous_wall_seconds cpu_percent

  cpu_time_text="$(ps -p "${pid}" -o time= 2>/dev/null || true)"
  if [[ -z "${cpu_time_text}" ]]; then
    printf "-"
    return
  fi

  cpu_seconds="$(cpu_time_seconds "${cpu_time_text}")"
  if [[ ! -f "${state_path}" ]]; then
    printf "%s %s\n" "${cpu_seconds}" "${now_seconds}" > "${state_path}"
    printf "-"
    return
  fi

  read -r previous_cpu_seconds previous_wall_seconds < "${state_path}" || true
  printf "%s %s\n" "${cpu_seconds}" "${now_seconds}" > "${state_path}"

  if [[ -z "${previous_cpu_seconds:-}" || -z "${previous_wall_seconds:-}" ]]; then
    printf "-"
    return
  fi

  cpu_percent="$(
    awk \
      -v current_cpu="${cpu_seconds}" \
      -v previous_cpu="${previous_cpu_seconds}" \
      -v current_wall="${now_seconds}" \
      -v previous_wall="${previous_wall_seconds}" '
      BEGIN {
        cpu_delta = current_cpu - previous_cpu
        wall_delta = current_wall - previous_wall
        if (cpu_delta < 0 || wall_delta <= 0) {
          print "-"
        } else {
          printf "%.1f", (cpu_delta / wall_delta) * 100
        }
      }
    '
  )"
  printf "%s" "${cpu_percent}"
}

printf "timestamp\tapp\tpid\tcpu_delta(%%)\treal(RSIZE)\tprivate(RPRVT)\n"

while true; do
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  now_seconds="$(date '+%s')"

  for app in "${APPS[@]}"; do
    pids="$(pgrep -x "${app}" || true)"

    if [[ -z "${pids}" ]]; then
      printf "%s\t%s\t-\t-\t-\t-\n" "${timestamp}" "${app}"
      continue
    fi

    while IFS= read -r pid; do
      [[ -n "${pid}" ]] || continue

      cpu="$(cpu_percent_for_pid "${pid}" "${now_seconds}")"
      line="$(
        top -r -l 1 -pid "${pid}" -stats pid,rsize,rprvt,command 2>/dev/null \
          | awk -v pid="${pid}" '$1 == pid { print; exit }' \
          || true
      )"

      if [[ -z "${line}" ]]; then
        printf "%s\t%s\t%s\t%s\t-\t-\n" "${timestamp}" "${app}" "${pid}" "${cpu}"
        continue
      fi

      read -r _ real private _ <<< "${line}"
      printf "%s\t%s\t%s\t%s\t%s\t%s\n" "${timestamp}" "${app}" "${pid}" "${cpu}" "${real}" "${private}"
    done <<< "${pids}"
  done

  sleep "${INTERVAL_SECONDS}"
done
