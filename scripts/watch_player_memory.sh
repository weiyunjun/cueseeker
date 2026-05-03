#!/usr/bin/env bash
set -euo pipefail

readonly INTERVAL_SECONDS=5
readonly APPS=("CueSeeker" "Movist Pro")

printf "timestamp\tapp\tpid\treal(MEM)\tprivate(RPRVT)\n"

while true; do
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  for app in "${APPS[@]}"; do
    pids="$(pgrep -x "${app}" || true)"

    if [[ -z "${pids}" ]]; then
      printf "%s\t%s\t-\t-\t-\n" "${timestamp}" "${app}"
      continue
    fi

    while IFS= read -r pid; do
      [[ -n "${pid}" ]] || continue

      line="$(
        top -l 1 -pid "${pid}" -stats pid,mem,rprvt,command 2>/dev/null \
          | awk -v pid="${pid}" '$1 == pid { print; exit }' \
          || true
      )"

      if [[ -z "${line}" ]]; then
        printf "%s\t%s\t%s\t-\t-\n" "${timestamp}" "${app}" "${pid}"
        continue
      fi

      read -r _ real private _ <<< "${line}"
      printf "%s\t%s\t%s\t%s\t%s\n" "${timestamp}" "${app}" "${pid}" "${real}" "${private}"
    done <<< "${pids}"
  done

  sleep "${INTERVAL_SECONDS}"
done
