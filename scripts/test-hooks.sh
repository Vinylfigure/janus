#!/usr/bin/env bash
# Fixture tests for the Janus hook plumbing. This is what `verify.sh full`
# runs for the template repo itself, and what CI runs on every PR.
#
# Behavioral tests run against a sandbox copy of the repo (CLAUDE_PROJECT_DIR
# points at a temp dir), so they never touch the real memory files.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FAILS=0

pass() { echo "  ok: $1"; }
fail() { echo "  FAIL: $1" >&2; FAILS=$((FAILS + 1)); }

command -v jq >/dev/null 2>&1 || { echo "test-hooks.sh requires jq" >&2; exit 1; }

echo "== static checks =="
for f in "$ROOT"/.claude/hooks/*.sh "$ROOT"/scripts/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "bash -n $(basename "$f")"; else fail "bash -n $(basename "$f")"; fi
done
if jq . "$ROOT/.claude/settings.json" >/dev/null 2>&1; then pass "settings.json is valid JSON"; else fail "settings.json is valid JSON"; fi

echo "== sandbox setup =="
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/.claude" "$SANDBOX/scripts"
cp -r "$ROOT/.claude/hooks" "$SANDBOX/.claude/hooks"
cp -r "$ROOT/.claude/memory" "$SANDBOX/.claude/memory"
cp "$ROOT/CLAUDE.md" "$SANDBOX/CLAUDE.md"
rm -f "$SANDBOX/.claude/memory/.session-signals" "$SANDBOX/.claude/memory/.nudged-"*
printf '#!/usr/bin/env bash\nexit 0\n' > "$SANDBOX/scripts/verify.sh"
chmod +x "$SANDBOX/scripts/verify.sh"
export CLAUDE_PROJECT_DIR="$SANDBOX"
SIGNALS="$SANDBOX/.claude/memory/.session-signals"
pass "sandbox at $SANDBOX"

echo "== prompt-signal.sh =="
echo '{"prompt":"please add a login page"}' | "$SANDBOX/.claude/hooks/prompt-signal.sh"
[ ! -f "$SIGNALS" ] && pass "normal prompt logs nothing" || fail "normal prompt logs nothing"
echo '{"prompt":"no, that is wrong, undo that"}' | "$SANDBOX/.claude/hooks/prompt-signal.sh"
grep -q '^correction:' "$SIGNALS" 2>/dev/null && pass "correction prompt logs a signal" || fail "correction prompt logs a signal"

echo "== stop-reflect-nudge.sh =="
out=$(echo '{"session_id":"t1"}' | "$SANDBOX/.claude/hooks/stop-reflect-nudge.sh")
echo "$out" | jq -e '.decision == "block"' >/dev/null 2>&1 && pass "signals present -> block" || fail "signals present -> block (got: $out)"
[ -f "$SANDBOX/.claude/memory/.nudged-t1" ] && pass "nudge marker created" || fail "nudge marker created"
out=$(echo '{"session_id":"t1"}' | "$SANDBOX/.claude/hooks/stop-reflect-nudge.sh")
[ -z "$out" ] && pass "second stop same session -> silent (loop guard)" || fail "second stop same session -> silent (got: $out)"
rm -f "$SIGNALS" "$SANDBOX/.claude/memory/.nudged-t1"
out=$(echo '{"session_id":"t2"}' | "$SANDBOX/.claude/hooks/stop-reflect-nudge.sh")
[ -z "$out" ] && [ ! -f "$SANDBOX/.claude/memory/.nudged-t2" ] && pass "clean session -> silent, no marker" || fail "clean session -> silent, no marker"

echo "== post-edit-verify.sh =="
echo '{"tool_input":{"file_path":"'"$SANDBOX"'/src/app.py"}}' | "$SANDBOX/.claude/hooks/post-edit-verify.sh"
[ $? -eq 0 ] && pass "passing verify -> exit 0" || fail "passing verify -> exit 0"
printf '#!/usr/bin/env bash\n[ "$1" = quick ] && { echo "lint error: undefined name"; exit 1; }\nexit 0\n' > "$SANDBOX/scripts/verify.sh"
err=$(echo '{"tool_input":{"file_path":"'"$SANDBOX"'/src/app.py"}}' | "$SANDBOX/.claude/hooks/post-edit-verify.sh" 2>&1 >/dev/null)
rc=$?
[ $rc -eq 2 ] && pass "failing verify -> exit 2" || fail "failing verify -> exit 2 (got $rc)"
echo "$err" | grep -q "lint error" && pass "failure output reaches stderr" || fail "failure output reaches stderr"
grep -q '^verify-fail:' "$SIGNALS" 2>/dev/null && pass "failure logs a signal" || fail "failure logs a signal"
echo '{"tool_input":{"file_path":"'"$SANDBOX"'/.claude/memory/LEARNINGS.md"}}' | "$SANDBOX/.claude/hooks/post-edit-verify.sh"
[ $? -eq 0 ] && pass "memory files exempt from the loop" || fail "memory files exempt from the loop"
rm -f "$SIGNALS"

echo "== session-start.sh =="
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "bootstrap" && pass "un-bootstrapped repo -> bootstrap nudge" || fail "un-bootstrapped repo -> bootstrap nudge (got: $out)"
echo "$out" | grep -q "consider /evolve" && fail "clean ledger -> no memory line" || pass "clean ledger -> no memory line"
printf '\n## L-900 · 2026-01-01 · Fixture entry\n- Trigger: fixture\n- Rule: fixture rule\n- Scope: project\n- Evidence: 2\n- Status: candidate\n' >> "$SANDBOX/.claude/memory/LEARNINGS.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "1 with Evidence >= 2" && pass "ripe learning counted (spec text not miscounted)" || fail "ripe learning counted (got: $out)"
out=$(echo '{"source":"compact"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -qi "compacted" && pass "compact source -> workspace-rescue line" || fail "compact source -> workspace-rescue line (got: $out)"

echo "== new-worktree.sh (skipped outside a git checkout) =="
if git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  SLUG="tests-$$"
  if "$ROOT/scripts/new-worktree.sh" create "$SLUG" >/dev/null 2>&1 \
     && "$ROOT/scripts/new-worktree.sh" clean "$SLUG" >/dev/null 2>&1 \
     && [ ! -d "$ROOT/../$(basename "$ROOT")-wt-$SLUG" ]; then
    pass "worktree create/clean cycle"
  else
    fail "worktree create/clean cycle"
    git -C "$ROOT" worktree remove --force "$ROOT/../$(basename "$ROOT")-wt-$SLUG" 2>/dev/null
    git -C "$ROOT" branch -D "wt/$SLUG" 2>/dev/null
  fi
else
  echo "  skip: not a git checkout with commits"
fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "ALL HOOK TESTS PASSED"
  exit 0
else
  echo "$FAILS TEST(S) FAILED" >&2
  exit 1
fi
