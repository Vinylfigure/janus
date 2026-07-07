#!/usr/bin/env bash
# SessionStart hook: inject at most 2 lines of status into the new session.
# Workspace rule: hooks add concepts to always-on context, so keep it minimal.
set -euo pipefail

DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER="$DIR/.claude/memory/LEARNINGS.md"
CLAUDE_MD="$DIR/CLAUDE.md"

lines=()

if [ -f "$CLAUDE_MD" ] && grep -q "NOT BOOTSTRAPPED" "$CLAUDE_MD"; then
  lines+=("This scaffold is not bootstrapped: run /bootstrap to wire verification to a real stack.")
fi

if [ -f "$LEDGER" ]; then
  # Count only real entries (below the marker), not the format spec above it.
  candidates=$(awk '/<!-- entries below this line -->/{in_entries=1; next} in_entries && /^- Status: candidate/{n++} END{print n+0}' "$LEDGER" 2>/dev/null || echo 0)
  ripe=$(awk '/<!-- entries below this line -->/{in_entries=1; next} !in_entries{next} /^- Evidence: [2-9]/{e=1} /^- Status: candidate/{if(e)n++; e=0} END{print n+0}' "$LEDGER" 2>/dev/null || echo 0)
  if [ "${ripe:-0}" -gt 0 ]; then
    lines+=("Memory: ${candidates:-0} candidate learnings, $ripe with Evidence >= 2 — consider /evolve.")
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
