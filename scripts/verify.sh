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
    # Template plumbing checks. /bootstrap replaces this block with the
    # project's real per-file checks (budget: <10s), e.g.:
    #   *.py) ruff check "$FILE" && ruff format --check "$FILE" ;;
    #   *.ts|*.tsx) npx eslint "$FILE" && npx tsc --noEmit ;;
    # Keep the *.sh/*.json arms — hook scripts exist in every child.
    case "$FILE" in
      *.sh) bash -n "$FILE" ;;
      *.json) command -v jq >/dev/null 2>&1 && jq . "$FILE" >/dev/null ;;
      *) exit 0 ;;
    esac
    # janus:bootstrap:quick:end
    ;;
  full)
    # janus:bootstrap:full:start
    # Template plumbing suite. /bootstrap replaces this block with the
    # project's real suite (lint all, typecheck, tests, build), e.g.:
    #   ruff check . && pytest
    "$(dirname "$0")/test-hooks.sh"
    # janus:bootstrap:full:end
    ;;
  *)
    echo "usage: verify.sh quick [file] | full" >&2
    exit 64
    ;;
esac
