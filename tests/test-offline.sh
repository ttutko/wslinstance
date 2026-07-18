#!/usr/bin/env bash
# =============================================================================
# test-offline.sh — verify every preinstalled tool works WITHOUT network.
#
# Usage:
#   wsl-selftest                 # inside the imported WSL instance
#   ./tests/test-offline.sh      # from the repo (points at local list)
#
# In the build pipeline this is run inside `docker run --network none ...` so a
# pass proves the image is genuinely self-contained.
# =============================================================================
set -uo pipefail

LIST="${1:-/usr/local/share/wsl/expected-tools.txt}"
[ -f "$LIST" ] || LIST="$(dirname "$0")/expected-tools.txt"

if [ ! -f "$LIST" ]; then
  echo "test-offline: cannot find expected-tools.txt ($LIST)" >&2
  exit 2
fi

if [ -t 1 ]; then
  GRN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'; B=$'\033[1m'; R=$'\033[0m'
else
  GRN=""; RED=""; DIM=""; B=""; R=""
fi

pass=0; fail=0; failed_labels=""

printf '%s\n' "${B}Offline tool verification${R}"

# Best-effort network-isolation notice (not a hard requirement to run).
if command -v curl >/dev/null 2>&1; then
  if curl -sS --max-time 2 https://github.com >/dev/null 2>&1; then
    printf '%s\n' "${DIM}NOTE: network appears reachable — run under 'docker run --network none' or on the airgapped host for a true offline test.${R}"
  else
    printf '%s\n' "${DIM}Network unreachable (good — this is a real offline test).${R}"
  fi
fi
echo

while IFS=$'\t' read -r label cmd; do
  # skip comments / blanks
  case "${label:-}" in ''|\#*) continue;; esac
  [ -z "${cmd:-}" ] && continue
  if bash -c "$cmd" >/dev/null 2>&1; then
    printf '  %sPASS%s  %s\n' "$GRN" "$R" "$label"
    pass=$((pass+1))
  else
    printf '  %sFAIL%s  %s   %s(%s)%s\n' "$RED" "$R" "$label" "$DIM" "$cmd" "$R"
    fail=$((fail+1))
    failed_labels="$failed_labels $label"
  fi
done < "$LIST"

echo
printf '%s\n' "${B}Result: ${GRN}${pass} passed${R}, ${RED}${fail} failed${R}"
if [ "$fail" -ne 0 ]; then
  printf '%s\n' "${RED}Failed:${R}${failed_labels}"
  exit 1
fi
printf '%s\n' "${GRN}All tools verified offline.${R}"
