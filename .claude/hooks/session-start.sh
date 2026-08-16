#!/usr/bin/env bash
# SessionStart hook: inject at most 5 short lines of status into the new session.
# Workspace rule: hooks add concepts to always-on context, so keep it minimal.
set -euo pipefail

DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER="$DIR/.claude/memory/LEARNINGS.md"
CLAUDE_MD="$DIR/CLAUDE.md"
SIGNALS="$DIR/.claude/memory/.session-signals"

input=$(cat)
source=$(printf '%s' "$input" | { command -v jq >/dev/null 2>&1 && jq -r '.source // "startup"' || echo startup; })

lines=()

# Workspace rescue: compaction just disrupted the model's working set.
# This is the one start where an extra line is worth its budget.
if [ "$source" = "compact" ]; then
  pending=0
  [ -s "$SIGNALS" ] && pending=$(wc -l < "$SIGNALS" | tr -d ' ')
  lines+=("Context was just compacted — re-verbalize your working set: restate the current task's invariants and its 'done means' check before continuing. Learning signals pending: $pending.")
fi

if [ -f "$CLAUDE_MD" ] && grep -q "NOT BOOTSTRAPPED" "$CLAUDE_MD"; then
  lines+=("This scaffold is not bootstrapped: run /bootstrap to wire verification to a real stack.")
fi

# Heredity self-check: template identity plus a foreign origin means this copy
# skipped /replicate — nudges alone don't revive a dead-provisioned loop (L-039).
# The template's own checkouts (origin absent or named janus) stay silent.
if [ -f "$CLAUDE_MD" ] && head -1 "$CLAUDE_MD" | grep -q '^# Janus (template)'; then
  origin=$(git -C "$DIR" remote get-url origin 2>/dev/null || true)
  case "$origin" in
    ""|*/janus|*/janus.git) : ;;
    *) lines+=("Un-replicated template copy detected (Janus identity, foreign origin) — run /replicate retrofit before real work.") ;;
  esac
fi

# Leftover signals: a session that skipped the Stop nudge (or died) must not
# lose its lessons. The compact branch above already reports the count.
if [ "$source" != "compact" ] && [ -s "$SIGNALS" ]; then
  n=$(wc -l < "$SIGNALS" | tr -d ' ')
  lines+=("$n unprocessed learning signal(s) from a previous session — consider /reflect.")
fi

if [ -f "$LEDGER" ]; then
  # Count only real entries (below the marker), not the format spec above it.
  candidates=$(awk '/<!-- entries below this line -->/{in_entries=1; next} in_entries && /^- Status: candidate/{n++} END{print n+0}' "$LEDGER" 2>/dev/null || echo 0)
  ripe=$(awk '/<!-- entries below this line -->/{in_entries=1; next} !in_entries{next} /^## /{e=0} /^- Evidence: /{if($3+0 >= 2) e=1} /^- Status: candidate/{if(e)n++; e=0} END{print n+0}' "$LEDGER" 2>/dev/null || echo 0)
  if [ "${ripe:-0}" -gt 0 ]; then
    lines+=("Memory: ${candidates:-0} candidate learnings, $ripe with Evidence >= 2 — consider /evolve.")
  fi
fi

# Recalibration staleness: nudge only once bootstrapped — session zero has one job.
# The stamp holds epoch seconds in its CONTENT (mtimes don't survive clones).
STAMP="$DIR/.claude/memory/recalibrated-at"
if [ -f "$CLAUDE_MD" ] && ! grep -q "NOT BOOTSTRAPPED" "$CLAUDE_MD"; then
  stamp=""
  [ -f "$STAMP" ] && stamp=$(tr -cd '0-9' < "$STAMP")
  now=$(date +%s)
  if [ -z "$stamp" ] || [ "$((now - stamp))" -gt 2592000 ]; then
    lines+=("Recalibration is stale (never recorded or >30 days) — consider /recalibrate to re-verify encoded practices.")
  fi
fi

# Backlog visibility: one line of GitHub work state, only when gh can answer.
# Every failure path is silent — no gh, no jq, no GitHub remote, no auth, no
# network: a status line is never worth breaking session start over.
work_line() {
  command -v gh >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0
  case "$(git -C "$DIR" remote get-url origin 2>/dev/null)" in
    *github.com*) : ;;
    *) return 0 ;;
  esac
  local TMO="" t q qn prs oldest oe line
  command -v timeout >/dev/null 2>&1 && TMO="timeout 5"
  t=$( (cd "$DIR" && $TMO gh issue list --label 'task:' --state open --limit 100 --json number) 2>/dev/null | jq 'length' 2>/dev/null) || return 0
  q=$( (cd "$DIR" && $TMO gh issue list --label 'question:' --state open --limit 100 --json createdAt) 2>/dev/null) || return 0
  prs=$( (cd "$DIR" && $TMO gh pr list --state open --limit 100 --json number) 2>/dev/null | jq 'length' 2>/dev/null) || return 0
  qn=$(printf '%s' "$q" | jq 'length' 2>/dev/null) || return 0
  case "$t$qn$prs" in *[!0-9]*|"") return 0 ;; esac
  line="work: $t task:, $qn question:"
  if [ "$qn" -gt 0 ]; then
    oldest=$(printf '%s' "$q" | jq -r 'map(.createdAt) | sort | .[0] // empty' 2>/dev/null)
    if [ -n "$oldest" ]; then
      oe=$(date -u -d "$oldest" +%s 2>/dev/null || true)
      [ -n "$oe" ] && line="$line (oldest $(( ($(date +%s) - oe) / 86400 ))d)"
    fi
  fi
  lines+=("$line, $prs open PRs")
  return 0
}
work_line || true

# Build-plan continuation: a merged milestone is a trigger, not a stop —
# surface the next unticked task so sessions conduct instead of waiting (L-042).
PLAN="$DIR/docs/EXECUTION-PLAN.md"
if [ -f "$PLAN" ]; then
  next=$(grep -m1 -oE '^- \[ \] \*\*[A-Za-z0-9._-]+\*\*' "$PLAN" | sed -E 's/.*\*\*([A-Za-z0-9._-]+)\*\*.*/\1/')
  if [ -n "$next" ]; then
    lines+=("Build plan: next unblocked task is $next (docs/EXECUTION-PLAN.md) — continue it.")
  fi
fi

if [ "${#lines[@]}" -gt 0 ]; then
  context=$(printf '%s ' "${lines[@]}")
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg ctx "$context" \
      '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
  else
    printf '%s\n' "$context"
  fi
fi
exit 0
