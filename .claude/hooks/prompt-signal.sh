#!/usr/bin/env bash
# UserPromptSubmit hook: silent correction detector.
# If the user's prompt looks like a correction, log a signal for the Stop-hook
# nudge. Never blocks, never emits output — a false positive costs nothing now
# and at most one gentle /reflect nudge later.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SIGNALS="$DIR/.claude/memory/.session-signals"

prompt=$(jq -r '.prompt // empty' 2>/dev/null) || exit 0
[ -n "$prompt" ] || exit 0

if printf '%s' "$prompt" | grep -qiE "(^|[^a-z])(no,|wrong|not what i|don'?t do|stop doing|you should have|that'?s incorrect|undo that)([^a-z]|$)"; then
  mkdir -p "$(dirname "$SIGNALS")"
  printf 'correction:%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$SIGNALS"
fi
exit 0
