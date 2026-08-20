#!/usr/bin/env bash
# Regenerates AGENTS.md from CLAUDE.md — the operator's "go" decision on
# issue #22 (L-046 watch-don't-buy resolved): CLAUDE.md stays canonical,
# AGENTS.md mirrors it so surfaces reading the agents.md convention instead
# of CLAUDE.md see the same content.
#
# Usage: generate-agents-md.sh [--check] [SRC] [OUT]
#   (no --check)  writes OUT from SRC (default: regenerates the real AGENTS.md)
#   --check       renders SRC into a temp file and diffs against OUT instead
#                 of writing — this is verify.sh full's drift gate
#
# Exit codes (check-loops.sh's -detailed-exitcode style):
#   0  written, or --check found no drift
#   1  operational error: SRC missing or unreadable
#   2  --check found drift
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CHECK=0
if [ "${1:-}" = "--check" ]; then
  CHECK=1
  shift
fi
SRC="${1:-$ROOT/CLAUDE.md}"
OUT="${2:-$ROOT/AGENTS.md}"

if [ ! -r "$SRC" ]; then
  echo "generate-agents-md: source missing or unreadable: $SRC" >&2
  exit 1
fi

render() {
  printf '<!-- GENERATED FILE — mirrors CLAUDE.md for the agents.md convention.\n     Do not hand-edit; regenerate with scripts/generate-agents-md.sh.\n     verify.sh full fails the build if this drifts from CLAUDE.md (#22). -->\n\n'
  cat "$SRC"
}

if [ "$CHECK" -eq 1 ]; then
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  render > "$tmp"
  if diff -q "$tmp" "$OUT" >/dev/null 2>&1; then
    echo "generate-agents-md: AGENTS.md matches CLAUDE.md"
    exit 0
  fi
  echo "generate-agents-md: AGENTS.md has drifted from CLAUDE.md — regenerate with scripts/generate-agents-md.sh" >&2
  diff -u "$OUT" "$tmp" >&2 || true
  exit 2
fi

render > "$OUT"
echo "generate-agents-md: wrote $OUT"
