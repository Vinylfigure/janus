#!/usr/bin/env bash
# The work loop's consumption gate, made deterministic (janus#42): three views
# already agreed a `question:`-labeled issue was blocked on the operator, and
# the one actor that mattered — the loop's own prose-level judgment — consumed
# it anyway and built the unanswered branch. Label semantics live here, in one
# place, as an executable check; the skill text points at this file instead of
# restating the list.
#
# Usage: check-ready.sh [--body <file>] <label> [<label>...]
#   <label>...  every label on ONE candidate issue, verbatim
#   --body      optional: the issue body; when given, a "Done means" heading
#               (the Task form's rendered field) must be present
# Exit: 0 consumable · 1 not consumable (reason on stdout) · 64 usage
#
# Gating labels (Human Attention Protocol v1 — docs/ATTENTION.md):
#   question:     the answer is not known yet — building either branch is wrong
#   loop:hold     known work, intentionally paused
#   inbox:        a thought, not a spec — triage promotes it, the loop never consumes it
#   human-check:  machine work finished; the operator's verification is the next actor
set -uo pipefail

BODY_FILE=""
if [ "${1:-}" = "--body" ]; then
  BODY_FILE="${2:?usage: check-ready.sh [--body <file>] <label>...}"
  shift 2
fi
[ "$#" -ge 1 ] || { echo "usage: check-ready.sh [--body <file>] <label> [<label>...]" >&2; exit 64; }

has_task=0
for l in "$@"; do
  case "$l" in
    "task:") has_task=1 ;;
    "question:")    echo "not ready: carries question: — blocked on an operator decision"; exit 1 ;;
    "loop:hold")    echo "not ready: carries loop:hold — intentionally paused"; exit 1 ;;
    "inbox:")       echo "not ready: carries inbox: — a thought awaiting triage, not a spec"; exit 1 ;;
    "human-check:") echo "not ready: carries human-check: — waiting on the operator's verification"; exit 1 ;;
  esac
done
[ "$has_task" -eq 1 ] || { echo "not ready: not labeled task:"; exit 1; }

if [ -n "$BODY_FILE" ]; then
  [ -f "$BODY_FILE" ] || { echo "not ready: body file not found: $BODY_FILE"; exit 1; }
  grep -qiE '^#+[[:space:]]*Done means' "$BODY_FILE" \
    || { echo "not ready: body carries no 'Done means' heading — a task without a done-means is not ready"; exit 1; }
fi

echo "ready"
exit 0
