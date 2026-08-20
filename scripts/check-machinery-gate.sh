#!/usr/bin/env bash
# The seatbelt's rule engine, lifted out of .github/workflows/gate-integrity.yml
# so it can carry fixtures like every other gate in this repo.
#
# Without the `machinery-change` label, a PR is blocked when it:
#   1. modifies anything under .github/workflows/ — the CI definition itself,
#      where any edit is a deliberate act by definition;
#   2. REMOVES an existing assertion from scripts/test-hooks.sh — the actual
#      threat the seatbelt was written for (an agent quietly weakening its own
#      fixture suite). A purely additive change passes, which is the normal
#      case: adding a skill, hook, agent, or script requires adding assertions
#      to this file, and the old any-touch rule failed every one of them;
#   3. deletes a scripts/*.sh or .claude/hooks/*.sh fixture or hook outright.
#
# Usage: check-machinery-gate.sh <base-ref>   (run inside the work tree)
# Exit:  0 clean · 1 blocked
set -uo pipefail

BASE="${1:?usage: check-machinery-gate.sh <base-ref>}"
FIXTURE="scripts/test-hooks.sh"
bad=0

# The assertion's message is its identity: `pass "X"` and `fail "X"` are the
# two arms of one check, so dedup on the message and compare the sets.
assertions() { grep -oE '(^|[^[:alnum:]_])(pass|fail) "[^"]*"' | sed -E 's/.*(pass|fail) //' | sort -u; }

while IFS=$'\t' read -r status path newpath; do
  [ -n "$status" ] || continue
  target="${newpath:-$path}"

  case "$target" in
    .github/workflows/*)
      echo "::error file=$target::workflow modified without the machinery-change label"
      bad=1 ;;
  esac

  if [ "$target" = "$FIXTURE" ] && [ "${status:0:1}" != "D" ]; then
    before=$(git show "$BASE:$FIXTURE" 2>/dev/null | assertions)
    after=$(assertions < "$FIXTURE")
    removed=$(comm -23 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))
    if [ -n "$removed" ]; then
      while IFS= read -r a; do
        [ -n "$a" ] && echo "::error file=$FIXTURE::assertion removed without the machinery-change label: $a"
      done <<< "$removed"
      bad=1
    else
      echo "$FIXTURE modified, no assertion removed — additive change, allowed"
    fi
  fi

  if [ "${status:0:1}" = "D" ]; then
    case "$path" in
      scripts/*.sh|.claude/hooks/*.sh)
        echo "::error::fixture/hook script deleted without the machinery-change label: $path"
        bad=1 ;;
    esac
  fi
done < <(git diff --name-status -M "$BASE...HEAD")

[ "$bad" -eq 0 ] && echo "machinery gate: clean"
exit "$bad"
