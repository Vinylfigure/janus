#!/usr/bin/env bash
# Ledger aging nudge (L-017): surfaces Evidence-1 candidates stuck past a
# staleness threshold. /evolve's own nudge (session-start.sh's ripe count)
# only fires at Evidence >= 2, so an Evidence-1 entry has no review path at
# all once it stops accumulating recurrences — some sat unseen for 5+ weeks
# before this existed. Non-fatal by design: this is a nudge, not a schema
# check, so it always exits 0 and never blocks `verify.sh full` or CI.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LEDGER="${1:-$ROOT/.claude/memory/LEARNINGS.md}"
THRESHOLD_DAYS="${2:-30}"

[ -r "$LEDGER" ] || exit 0

now=$(date +%s)

# Only entries below the format-spec marker are real (L-002); id/date come
# from the "## L-NNN · YYYY-MM-DD · title" header, Evidence resets per entry
# so a non-candidate's count never leaks into the next one (same bug class
# session-start.sh's ripe-counter hit).
pairs=$(awk '
  /<!-- entries below this line -->/ { in_entries=1; next }
  !in_entries { next }
  /^## L-/ { id=$2; entry_date=$4; evidence=-1 }
  /^- Evidence: / { evidence = $3 + 0 }
  /^- Status: candidate/ { if (id != "" && evidence == 1) print id, entry_date; id="" }
' "$LEDGER")

[ -z "$pairs" ] && exit 0

stale=""
n=0
while IFS=' ' read -r id entry_date; do
  [ -n "$id" ] || continue
  epoch=$(date -u -d "$entry_date" +%s 2>/dev/null) || continue
  age=$(( (now - epoch) / 86400 ))
  [ "$age" -ge "$THRESHOLD_DAYS" ] || continue
  stale="${stale}  $id (${age}d)"$'\n'
  n=$((n + 1))
done <<< "$pairs"

if [ "$n" -gt 0 ]; then
  echo "check-ledger-aging: $n candidate(s) at Evidence 1 for >= ${THRESHOLD_DAYS}d with no review path — consider /evolve, or a /decision-lock accepting the decay:"
  printf '%s' "$stale"
fi
exit 0
