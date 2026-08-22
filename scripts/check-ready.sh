#!/usr/bin/env bash
# The consumption gate, executable and in one place (janus#42, L-057).
#
# Two things this repo learned the hard way, both encoded here:
#
#   1. Prose is not a gate. Three views already agreed a `question:`-labeled
#      issue was blocked on the operator, and the loop's prose-level judgment
#      consumed it anyway and built the branch nobody had chosen (#42).
#   2. A state you define and never compute is not a gate either. ATTENTION.md
#      defines `working` — an open PR or delivery branch already references
#      the issue — and every implementation checked labels only, so a task
#      another actor had started looked identical to a fresh one. Two sessions
#      built this protocol nine seconds apart through that hole (L-057).
#
# `working` cannot be derived from labels, so it is an explicit input: the
# caller passes --working after asking GitHub. Making it an argument rather
# than an assumption is the point — a caller that has not checked has to say
# so by omission, and `fleet-status.sh` (which does check) is the reference
# implementation of the derivation.
#
# Usage: check-ready.sh [--body <file>] [--working] <label> [<label>...]
#   <label>...  every label on ONE candidate issue, verbatim
#   --body      optional: the issue body; a "Done means" heading must be present
#   --working   the caller found an open PR or delivery branch for this issue
# Exit: 0 consumable · 1 not consumable (reason on stdout) · 64 usage
#
# Gating labels (Human Attention Protocol v1 — docs/ATTENTION.md):
#   question:     the answer is not known yet — building either branch is wrong
#   loop:hold     known work, intentionally paused
#   inbox:        a thought, not a spec — triage promotes it, the loop never consumes it
#   human-check:  machine work finished; the operator's verification is the next actor
set -uo pipefail

BODY_FILE=""
WORKING=0
while true; do
  case "${1:-}" in
    --body)    BODY_FILE="${2:?usage: check-ready.sh [--body <file>] [--working] <label>...}"; shift 2 ;;
    --working) WORKING=1; shift ;;
    *)         break ;;
  esac
done
[ "$#" -ge 1 ] || { echo "usage: check-ready.sh [--body <file>] [--working] <label> [<label>...]" >&2; exit 64; }

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

if [ "$WORKING" -eq 1 ]; then
  echo "not ready: working — an open PR or delivery branch already references it"
  exit 1
fi

if [ -n "$BODY_FILE" ]; then
  [ -f "$BODY_FILE" ] || { echo "not ready: body file not found: $BODY_FILE"; exit 1; }
  grep -qiE '^#+[[:space:]]*Done means' "$BODY_FILE" \
    || { echo "not ready: body carries no 'Done means' heading — a task without a done-means is not ready"; exit 1; }
fi

echo "ready"
exit 0
