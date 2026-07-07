#!/usr/bin/env bash
# Stack-agnostic verification dispatcher. /bootstrap fills in the real commands.
#
# Usage:
#   scripts/verify.sh quick [file]   # fast per-file check (<10s): format/lint/typecheck
#   scripts/verify.sh full           # the whole truth: tests + build (+ graph refresh)
#
# Contract:
# - `quick` is wired to the PostToolUse hook: it must be FAST and exit nonzero
#   with useful output on failure (the agent sees stderr and iterates).
# - `full` is the closed loop for /verify-loop and the verifier agent: exit 0
#   means the project is genuinely healthy.
# - Until /bootstrap runs, both modes are silent no-ops so the template stays
#   quiet out of the box.
set -uo pipefail

MODE="${1:-full}"
FILE="${2:-}"

case "$MODE" in
  quick)
    # janus:bootstrap:quick:start
    # NOT BOOTSTRAPPED: no-op. /bootstrap replaces this block with real
    # per-file checks, e.g.:
    #   case "$FILE" in
    #     *.py) ruff check "$FILE" && ruff format --check "$FILE" ;;
    #     *.ts|*.tsx) npx eslint "$FILE" && npx tsc --noEmit ;;
    #   esac
    exit 0
    # janus:bootstrap:quick:end
    ;;
  full)
    # janus:bootstrap:full:start
    # NOT BOOTSTRAPPED: no-op. /bootstrap replaces this block with the real
    # suite, e.g.:
    #   ruff check . && pytest
    # If graphify is installed, keep the knowledge graph fresh too:
    #   command -v graphify >/dev/null 2>&1 && graphify . --quiet
    exit 0
    # janus:bootstrap:full:end
    ;;
  *)
    echo "usage: verify.sh quick [file] | full" >&2
    exit 64
    ;;
esac
