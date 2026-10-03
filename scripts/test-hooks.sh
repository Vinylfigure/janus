#!/usr/bin/env bash
# Fixture tests for the Janus scaffold plumbing: hook behavior plus
# name-level docs cross-references. This is what `verify.sh full` runs for
# the template repo itself, and what CI runs on every PR.
#
# Behavioral tests run against a sandbox copy of the repo (CLAUDE_PROJECT_DIR
# points at a temp dir), so they never touch the real memory files.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FAILS=0

pass() { echo "  ok: $1"; }
fail() { echo "  FAIL: $1" >&2; FAILS=$((FAILS + 1)); }

command -v jq >/dev/null 2>&1 || { echo "test-hooks.sh requires jq" >&2; exit 1; }

node --test "$ROOT/scripts/effect-policy.test.mjs" "$ROOT/scripts/effect-policy-read.test.mjs" "$ROOT/scripts/policy-approval.test.mjs" "$ROOT/scripts/weekly-learning.test.mjs" "$ROOT/scripts/codex-compat.test.mjs" || fail "policy, weekly learning and Codex compatibility tests"
python3 "$ROOT/scripts/test-auto-merge.py" || fail "offline merge-engine behavior"

echo "== static checks =="
for f in "$ROOT"/.claude/hooks/*.sh "$ROOT"/scripts/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "bash -n $(basename "$f")"; else fail "bash -n $(basename "$f")"; fi
done
if jq . "$ROOT/.claude/settings.json" >/dev/null 2>&1; then pass "settings.json is valid JSON"; else fail "settings.json is valid JSON"; fi
# Workflow/manifest YAML must at least parse. Skips (never fails) without
# python3+pyyaml — CI's ubuntu runner always has both, so rot cannot merge.
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
  for f in "$ROOT"/.github/workflows/*.yml "$ROOT"/.github/loops.yaml "$ROOT"/.github/ISSUE_TEMPLATE/*.yml; do
    [ -f "$f" ] || continue
    if python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$f" 2>/dev/null; then
      pass "yaml parses: $(basename "$f")"
    else
      fail "yaml parses: $(basename "$f")"
    fi
  done
else
  echo "  skip: python3+pyyaml unavailable — YAML parse checks skipped"
fi

echo "== frontmatter (skills + agents) =="
# The quick dispatcher's *) arm exits 0 for every .md, so nothing else in the
# repo would catch a malformed or misspelled frontmatter block. Field sets are
# claims about a moving target — /recalibrate re-verifies them against
# code.claude.com/docs/en/skills and the anthropics/skills spec.
SKILL_FIELDS=" name description when_to_use argument-hint arguments disable-model-invocation user-invocable allowed-tools disallowed-tools model effort context agent background hooks paths shell "
AGENT_FIELDS=" name description tools disallowedTools model permissionMode maxTurns skills mcpServers hooks memory background effort isolation color initialPrompt "
check_frontmatter() {
  local file=$1 allowed=$2 expect=$3 label=$4
  if [ "$(head -1 "$file")" != "---" ]; then fail "$label: no frontmatter opening ---"; return; fi
  local end; end=$(awk 'NR>1 && /^---[[:space:]]*$/{print NR; exit}' "$file")
  if [ -z "$end" ]; then fail "$label: unterminated frontmatter block"; return; fi
  # A stray `---` rule in the body would otherwise pose as the closer and turn
  # prose into "fields", so require the whole region to be frontmatter-shaped:
  # a key, an indented continuation, or a list item.
  local stray; stray=$(sed -n "2,$((end - 1))p" "$file" \
    | grep -vE '^[[:space:]]*$|^[[:space:]]|^-[[:space:]]|^[a-zA-Z][a-zA-Z0-9_-]*:' | head -1)
  if [ -n "$stray" ]; then fail "$label: unterminated frontmatter block (body text before closing ---: '${stray:0:40}')"; return; fi
  local bad=""
  while IFS= read -r key; do
    case "$allowed" in *" $key "*) ;; *) bad="$bad $key" ;; esac
  done < <(sed -n "2,$((end - 1))p" "$file" | grep -oE '^[a-zA-Z][a-zA-Z0-9_-]*:' | tr -d ':')
  if [ -n "$bad" ]; then fail "$label: unknown frontmatter field(s):$bad"; else pass "$label: frontmatter fields known"; fi
  local declared; declared=$(sed -n "2,$((end - 1))p" "$file" | sed -n 's/^name:[[:space:]]*//p' | tr -d '"'"'"' ')
  if [ -z "$declared" ] || [ "$declared" = "$expect" ]; then pass "$label: name matches path"; else fail "$label: name '$declared' != '$expect'"; fi
}
for d in "$ROOT"/.claude/skills/*/; do
  check_frontmatter "$d/SKILL.md" "$SKILL_FIELDS" "$(basename "$d")" "skill $(basename "$d")"
done
for d in "$ROOT"/.agents/skills/*/; do
  check_frontmatter "$d/SKILL.md" " name description " "$(basename "$d")" "Codex skill $(basename "$d")"
done
for f in "$ROOT"/.claude/agents/*.md; do
  check_frontmatter "$f" "$AGENT_FIELDS" "$(basename "$f" .md)" "agent $(basename "$f" .md)"
done

echo "== model tiers: gates are never cheapened =="
# docs/MODEL-TIERS.md's load-bearing rule, at the top of the enforcement ladder
# because prose asking nicely would not survive the next tidy-up. A gate judges
# whether OTHER work is correct, so it must inherit the session's model: pinning
# one can only cap a session the operator deliberately escalated (Fable 5 for a
# hard plan), and pinning a cheap one buys headroom by rubber-stamping.
gate_file() {
  case $1 in
    verifier) echo "$ROOT/.claude/agents/verifier.md" ;;
    *) echo "$ROOT/.claude/skills/$1/SKILL.md" ;;
  esac
}
for g in verify-loop plan-feature goal-review evolve dispatch verifier; do
  f=$(gate_file "$g")
  if [ ! -f "$f" ]; then pass "gate $g absent from this repo (skipped)"; continue; fi
  end=$(awk 'NR>1 && /^---[[:space:]]*$/{print NR; exit}' "$f")
  fm=$(sed -n "2,$((end - 1))p" "$f")
  if printf '%s\n' "$fm" | grep -qE '^model:'; then
    fail "gate $g pins a model — gates inherit the session model (docs/MODEL-TIERS.md)"
  else
    pass "gate $g inherits the session model"
  fi
  if printf '%s\n' "$fm" | grep -qE '^effort:[[:space:]]*xhigh[[:space:]]*$'; then
    pass "gate $g declares effort: xhigh"
  else
    fail "gate $g must declare 'effort: xhigh' (docs/MODEL-TIERS.md)"
  fi
done

echo "== docs consistency (name-level) =="
# Keeps docs/ honest about the tree: names, paths, and counts only — semantic
# accuracy stays on SELF-IMPROVEMENT.md rule 1 and /recalibrate.
if [ ! -f "$ROOT/docs/ARCHITECTURE.md" ]; then
  echo "  skip: no docs/ARCHITECTURE.md (docs pruned — checks opt out)"
else
  for d in "$ROOT"/.claude/skills/*/; do
    name=$(basename "$d")
    if grep -q -- "/$name" "$ROOT/docs/USAGE.md"; then pass "skill /$name in USAGE.md"; else fail "skill /$name missing from docs/USAGE.md — add a trigger-table row"; fi
  done
  for f in "$ROOT"/.claude/hooks/*.sh; do
    b=$(basename "$f")
    if grep -q "$b" "$ROOT/docs/ARCHITECTURE.md"; then pass "hook $b in ARCHITECTURE.md"; else fail "hook $b missing from docs/ARCHITECTURE.md hook table"; fi
  done
  for f in "$ROOT"/.claude/agents/*.md; do
    a=$(basename "$f" .md)
    if grep -q "$a" "$ROOT/docs/ARCHITECTURE.md"; then pass "agent $a in ARCHITECTURE.md"; else fail "agent $a missing from docs/ARCHITECTURE.md"; fi
  done
  for t in $(grep -ohE '[A-Za-z0-9_.-]+\.sh' "$ROOT"/docs/*.md | sort -u); do
    if [ -f "$ROOT/scripts/$t" ] || [ -f "$ROOT/.claude/hooks/$t" ]; then pass "docs script ref $t exists"; else fail "docs reference $t but no such file in scripts/ or .claude/hooks/"; fi
  done
  # recalibrated-at is deliberately absent from this list: it is written only
  # by a completed /recalibrate run (L-020), so its absence is a valid state.
  for p in .github/workflows/verify.yml .github/workflows/fleet-status.yml \
           .github/workflows/gate-integrity.yml .github/loops.yaml .github/CODEOWNERS \
           .github/ISSUE_TEMPLATE/task.yml .github/ISSUE_TEMPLATE/question.yml \
           .github/ISSUE_TEMPLATE/inbox.yml .github/ISSUE_TEMPLATE/config.yml \
           docs/ATTENTION.md scripts/deny-list.json scripts/card-grammar.json \
           scripts/vendor-grammar.sh \
           .claude/settings.json .claude/memory/LEARNINGS.md .claude/memory/sources-seen.md; do
    if [ -e "$ROOT/$p" ]; then pass "component-map path $p exists"; else fail "component-map path $p missing from tree"; fi
  done
  n=$(ls "$ROOT"/.claude/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')
  if grep -qE "hooks/ +$n shell hooks" "$ROOT/docs/ARCHITECTURE.md"; then pass "component-map hook count is $n"; else fail "component map hook count != $n (expected line matching 'hooks/ +$n shell hooks')"; fi
  n=$(ls -d "$ROOT"/.claude/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
  if grep -qE "skills/ +$n skills" "$ROOT/docs/ARCHITECTURE.md"; then pass "component-map skill count is $n"; else fail "component map skill count != $n (expected line matching 'skills/ +$n skills')"; fi
  n=$(ls "$ROOT"/.claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  if grep -qE "agents/ +$n subagents" "$ROOT/docs/ARCHITECTURE.md"; then pass "component-map agent count is $n"; else fail "component map agent count != $n (expected line matching 'agents/ +$n subagents')"; fi
fi

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
# Enriched signal: keyword and excerpt travel with the timestamp, so a later
# session can tell WHY it fired (a bare timestamp forced guessing — L-031).
line=$(grep '^correction:' "$SIGNALS" 2>/dev/null | tail -1)
printf '%s' "$line" | grep -qi ':no,:' && pass "correction signal carries matched keyword" || fail "correction signal carries matched keyword (got: $line)"
printf '%s' "$line" | grep -qi 'no, that is wrong' && pass "correction signal carries prompt excerpt" || fail "correction signal carries prompt excerpt (got: $line)"
# Author id rides as the LAST field, "-" when absent (L-031: a signal carries
# its cause AND its author).
rm -f "$SIGNALS"
echo '{"session_id":"sess-fixture","prompt":"no, undo that"}' | "$SANDBOX/.claude/hooks/prompt-signal.sh"
line=$(grep '^correction:' "$SIGNALS" 2>/dev/null | tail -1)
printf '%s' "$line" | grep -q 'sess-fixture' && pass "correction signal carries author session id" || fail "correction signal carries author session id (got: $line)"
rm -f "$SIGNALS"
echo '{"prompt":"no, undo that"}' | "$SANDBOX/.claude/hooks/prompt-signal.sh"
line=$(grep '^correction:' "$SIGNALS" 2>/dev/null | tail -1)
printf '%s' "$line" | grep -q -- ':-$' && pass "missing session id -> '-' placeholder" || fail "missing session id -> '-' placeholder (got: $line)"
rm -f "$SIGNALS"
long=$(printf 'wrong %.0s' $(seq 1 40))
echo "{\"prompt\":\"$long\"}" | "$SANDBOX/.claude/hooks/prompt-signal.sh"
line=$(grep '^correction:' "$SIGNALS" 2>/dev/null | tail -1)
[ -n "$line" ] && [ "${#line}" -le 130 ] && pass "excerpt truncated to a bounded line" || fail "excerpt truncated to a bounded line (len ${#line})"
[ "$(wc -l < "$SIGNALS")" -eq 1 ] && pass "multiline-safe: one signal = one line" || fail "multiline-safe: one signal = one line"

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
echo '{"session_id":"sess-fixture","tool_input":{"file_path":"'"$SANDBOX"'/src/app.py"}}' | "$SANDBOX/.claude/hooks/post-edit-verify.sh" 2>/dev/null
grep '^verify-fail:' "$SIGNALS" 2>/dev/null | tail -1 | grep -q 'sess-fixture' && pass "verify-fail signal carries author session id" || fail "verify-fail signal carries author session id"
echo '{"tool_input":{"file_path":"'"$SANDBOX"'/.claude/memory/LEARNINGS.md"}}' | "$SANDBOX/.claude/hooks/post-edit-verify.sh"
[ $? -eq 0 ] && pass "memory files exempt from the loop" || fail "memory files exempt from the loop"
rm -f "$SIGNALS"

echo "== verify.sh dispatcher (template contract) =="
# Runs the REAL repo dispatcher (the sandbox copy is a stub). Asserts only
# what survives /bootstrap: the *.sh/*.json arms, the usage exit, and the
# sentinel markers. Never runs `full` here (recursion) or the *) fallback
# (bootstrap replaces it).
mkdir -p "$SANDBOX/fixtures"
printf '#!/usr/bin/env bash\nexit 0\n' > "$SANDBOX/fixtures/good.sh"
printf '#!/usr/bin/env bash\nif true; then\n' > "$SANDBOX/fixtures/bad.sh"
printf '{ "unterminated":\n' > "$SANDBOX/fixtures/bad.json"
"$ROOT/scripts/verify.sh" quick "$SANDBOX/fixtures/good.sh" >/dev/null 2>&1 && pass "quick: valid .sh -> exit 0" || fail "quick: valid .sh -> exit 0"
"$ROOT/scripts/verify.sh" quick "$SANDBOX/fixtures/bad.sh" >/dev/null 2>&1 && fail "quick: broken .sh -> nonzero" || pass "quick: broken .sh -> nonzero"
"$ROOT/scripts/verify.sh" quick "$SANDBOX/fixtures/bad.json" >/dev/null 2>&1 && fail "quick: broken .json -> nonzero" || pass "quick: broken .json -> nonzero"
"$ROOT/scripts/verify.sh" bogus >/dev/null 2>&1
rc=$?
[ "$rc" -eq 64 ] && pass "unknown mode -> exit 64" || fail "unknown mode -> exit 64 (got $rc)"
for m in quick:start quick:end full:start full:end; do
  grep -q "janus:bootstrap:$m" "$ROOT/scripts/verify.sh" && pass "sentinel janus:bootstrap:$m present" || fail "sentinel janus:bootstrap:$m present"
done

echo "== check-loops.sh (loop manifest) =="
"$ROOT/scripts/check-loops.sh" >/dev/null 2>&1 && pass "repo manifest validates (exit 0)" || fail "repo manifest validates (exit 0)"
printf 'loops:\n  - name: broken\n    driver: routine\n' > "$SANDBOX/loops-broken.yaml"
"$ROOT/scripts/check-loops.sh" "$SANDBOX/loops-broken.yaml" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && pass "incomplete loop entry -> exit 2" || fail "incomplete loop entry -> exit 2 (got $rc)"
err=$("$ROOT/scripts/check-loops.sh" "$SANDBOX/loops-broken.yaml" 2>&1 >/dev/null)
echo "$err" | grep -q "missing schedule" && pass "schema violation names the missing key" || fail "schema violation names the missing key (got: $err)"
"$ROOT/scripts/check-loops.sh" "$SANDBOX/no-such-loops.yaml" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 1 ] && pass "missing manifest -> exit 1" || fail "missing manifest -> exit 1 (got $rc)"
printf 'loops:\n  - name: ghost\n    schedule: "17 1 * * *"\n    driver: github-action\n    workflow: no-such.yml\n    enabled: true\n    owner: fixture\n' > "$SANDBOX/loops-ghost.yaml"
"$ROOT/scripts/check-loops.sh" "$SANDBOX/loops-ghost.yaml" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && pass "ghost workflow reference -> exit 2" || fail "ghost workflow reference -> exit 2 (got $rc)"

echo "== check-ledger-aging.sh (Evidence-1 staleness nudge) =="
LFIX="$SANDBOX/ledger-aging.md"
stale_date=$(date -u -d '-40 days' +%Y-%m-%d 2>/dev/null)
fresh_date=$(date -u +%Y-%m-%d)
old_promoted_date=$(date -u -d '-90 days' +%Y-%m-%d 2>/dev/null)
if [ -z "$stale_date" ] || [ -z "$old_promoted_date" ]; then
  echo "  skip: date -d unavailable — check-ledger-aging.sh fixtures skipped"
else
  cat > "$LFIX" <<EOF
# fixture ledger

<!-- entries below this line -->

## L-100 · $stale_date · Stale Evidence-1 candidate
- Trigger: fixture
- Rule: fixture rule
- Scope: project
- Evidence: 1
- Status: candidate

## L-101 · $fresh_date · Fresh Evidence-1 candidate
- Trigger: fixture
- Rule: fixture rule
- Scope: project
- Evidence: 1
- Status: candidate

## L-102 · $old_promoted_date · Stale but already promoted
- Trigger: fixture
- Rule: fixture rule
- Scope: project
- Evidence: 1
- Status: promoted:CLAUDE.md (Evidence 1 — promoted on explicit user confirmation)

## L-103 · $old_promoted_date · Stale but ripe (Evidence 2, own review path already)
- Trigger: fixture
- Rule: fixture rule
- Scope: project
- Evidence: 2
- Status: candidate
EOF
  out=$("$ROOT/scripts/check-ledger-aging.sh" "$LFIX" 30)
  rc=$?
  [ "$rc" -eq 0 ] && pass "check-ledger-aging: always exits 0 (nudge, not a gate)" || fail "check-ledger-aging: always exits 0 (got $rc)"
  echo "$out" | grep -q "L-100" && pass "stale Evidence-1 candidate flagged" || fail "stale Evidence-1 candidate flagged (got: $out)"
  echo "$out" | grep -q "L-101" && fail "fresh candidate must not be flagged (got: $out)" || pass "fresh candidate must not be flagged"
  echo "$out" | grep -q "L-102" && fail "already-promoted entry must not be flagged (got: $out)" || pass "already-promoted entry must not be flagged"
  echo "$out" | grep -q "L-103" && fail "Evidence>=2 entry must not be flagged (ripe path covers it) (got: $out)" || pass "Evidence>=2 entry must not be flagged"
  echo "$out" | grep -q "^check-ledger-aging: 1 candidate" && pass "aging count is exactly 1" || fail "aging count is exactly 1 (got: $out)"
fi
out=$("$ROOT/scripts/check-ledger-aging.sh" "$SANDBOX/no-such-ledger.md" 2>&1)
rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass "missing ledger -> silent exit 0" || fail "missing ledger -> silent exit 0 (got rc=$rc, out=$out)"
out=$("$ROOT/scripts/check-ledger-aging.sh" "$ROOT/.claude/memory/LEARNINGS.md" 999999)
rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass "real ledger, huge threshold -> silent exit 0" || fail "real ledger, huge threshold -> silent exit 0 (got rc=$rc, out=$out)"
echo "== generate-agents-md.sh (AGENTS.md mirror, #22) =="
"$ROOT/scripts/generate-agents-md.sh" --check >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && pass "real AGENTS.md matches CLAUDE.md (exit 0)" || fail "real AGENTS.md matches CLAUDE.md (got $rc)"
AGENTSFIX="$SANDBOX/agents-fixture"
mkdir -p "$AGENTSFIX"
printf '# Fixture project\n\n- a fact\n' > "$AGENTSFIX/CLAUDE.src.md"
"$ROOT/scripts/generate-agents-md.sh" "$AGENTSFIX/CLAUDE.src.md" "$AGENTSFIX/AGENTS.out.md" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && pass "generation exits 0" || fail "generation exits 0 (got $rc)"
grep -q "a fact" "$AGENTSFIX/AGENTS.out.md" 2>/dev/null && pass "generated file carries source content" || fail "generated file carries source content"
grep -q "GENERATED FILE" "$AGENTSFIX/AGENTS.out.md" 2>/dev/null && pass "generated file carries a do-not-edit header" || fail "generated file carries a do-not-edit header"
"$ROOT/scripts/generate-agents-md.sh" --check "$AGENTSFIX/CLAUDE.src.md" "$AGENTSFIX/AGENTS.out.md" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && pass "--check: in-sync pair -> exit 0" || fail "--check: in-sync pair -> exit 0 (got $rc)"
printf '# Fixture project\n\n- a fact\n- hand-edited drift\n' > "$AGENTSFIX/AGENTS.out.md"
"$ROOT/scripts/generate-agents-md.sh" --check "$AGENTSFIX/CLAUDE.src.md" "$AGENTSFIX/AGENTS.out.md" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && pass "--check: drifted pair -> exit 2" || fail "--check: drifted pair -> exit 2 (got $rc)"
"$ROOT/scripts/generate-agents-md.sh" --check "$AGENTSFIX/no-such-src.md" "$AGENTSFIX/AGENTS.out.md" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 1 ] && pass "missing source -> exit 1" || fail "missing source -> exit 1 (got $rc)"
"$ROOT/scripts/generate-agents-md.sh" --check "$AGENTSFIX/CLAUDE.src.md" "$AGENTSFIX/no-such-out.md" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && pass "missing OUT under --check -> exit 2 (fails closed, not a silent pass)" || fail "missing OUT under --check -> exit 2 (got $rc)"

echo "== fleet-status.sh (stubbed gh, --dry-run) =="
# The dashboard engine must render every section from stub data and mutate
# nothing. The stub answers the exact gh shapes the script (and the
# session-start work line) asks for; everything else degrades to [].
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"
case "$args" in
  *"pr list"*) echo '[{"number":7,"title":"stub PR","createdAt":"2026-08-10T00:00:00Z","updatedAt":"2026-08-10T00:00:00Z","headRefName":"claude/stub-branch"}]' ;;
  *"issue list"*"task:"*) echo '[{"number":3,"createdAt":"2026-08-01T00:00:00Z"}]' ;;
  *"issue list"*"question:"*) echo '[{"number":4,"title":"stub question","createdAt":"2026-08-12T00:00:00Z","updatedAt":"2026-08-12T00:00:00Z"}]' ;;
  *"pr checks"*) printf 'test\tpass\t1m\thttps://example.invalid\n' ;;
  *"pr view"*|*"issue view"*) echo '{"comments":[]}' ;;
  *"repo view"*) echo 'stub' ;;
  *) echo '[]' ;;
esac
EOF
chmod +x "$SANDBOX/bin/gh"
out=$(PATH="$SANDBOX/bin:$PATH" "$ROOT/scripts/fleet-status.sh" --dry-run 2>/dev/null)
rc=$?
[ "$rc" -eq 0 ] && pass "dry-run with clean data -> exit 0" || fail "dry-run with clean data -> exit 0 (got $rc)"
for h in "## Open PRs" "## Blocked on operator" "## Awaiting your check" "## Backlog" "## Inbox" "## Loops" "## Red findings"; do
  echo "$out" | grep -qF "$h" && pass "dashboard section: $h" || fail "dashboard section: $h"
done
echo "$out" | grep -qF "declared, not armed" && pass "unarmed loops flagged" || fail "unarmed loops flagged"
echo "$out" | grep -qF "regenerated in place" && pass "footer states in-place regeneration" || fail "footer states in-place regeneration"

echo "== fleet-status.sh consumption gate (docs/ATTENTION.md) =="
# The #42 fixture: two otherwise-identical open task: issues, one also
# labeled question:. The gate must count exactly one consumable and name the
# question:-labeled one as gated — the work-loop skill's Gating labels list
# mirrors this line.
mkdir -p "$SANDBOX/gatebin"
cat > "$SANDBOX/gatebin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"
case "$args" in
  *"issue list"*"task:"*) echo '[{"number":3,"createdAt":"2026-08-01T00:00:00Z","labels":[{"name":"task:"}]},{"number":9,"createdAt":"2026-08-01T00:00:00Z","labels":[{"name":"task:"},{"name":"question:"}]}]' ;;
  *"issue list"*"inbox:"*) echo '[{"number":11,"title":"stub thought","createdAt":"2026-08-19T00:00:00Z"}]' ;;
  *"issue list"*"human-check:"*) echo '[{"number":12,"title":"stub check","createdAt":"2026-08-19T00:00:00Z"}]' ;;
  *"issue list"*"question:"*) echo '[]' ;;
  *"pr list"*) echo '[]' ;;
  *"pr view"*|*"issue view"*) echo '{"comments":[]}' ;;
  *"repo view"*) echo 'stub' ;;
  *) echo '[]' ;;
esac
EOF
chmod +x "$SANDBOX/gatebin/gh"
out=$(PATH="$SANDBOX/gatebin:$PATH" "$ROOT/scripts/fleet-status.sh" --dry-run 2>/dev/null)
echo "$out" | grep -qF "Consumable now: 1" && pass "gate: question:-labeled task is not consumable, unlabeled twin is" || fail "gate: question:-labeled task is not consumable, unlabeled twin is (got: $(echo "$out" | grep 'Consumable now' || echo 'no gate line'))"
echo "$out" | grep -qF "gated: #9" && pass "gate: the gated issue is named with its labels" || fail "gate: the gated issue is named with its labels"
echo "$out" | grep -qF "#11 stub thought" && pass "inbox section lists captured thoughts" || fail "inbox section lists captured thoughts"
echo "$out" | grep -qF "#12 stub check" && pass "awaiting-your-check section lists human-check: issues" || fail "awaiting-your-check section lists human-check: issues"

echo "== fleet-status.sh working state (the gate's second half) =="
# ATTENTION.md defines `working` as "an open PR or claude/* branch references
# the issue" and the gate never computed it, so a task another actor had
# already started still read consumable (L-057). Same two task: issues as
# above, both unlabeled this time; an open PR closes one of them.
mkdir -p "$SANDBOX/workbin"
cat > "$SANDBOX/workbin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"
case "$args" in
  *"issue list"*"task:"*) echo '[{"number":3,"createdAt":"2026-08-01T00:00:00Z","labels":[{"name":"task:"}]},{"number":9,"createdAt":"2026-08-01T00:00:00Z","labels":[{"name":"task:"}]}]' ;;
  *"pr list"*"body"*)     echo '[{"number":50,"title":"deliver the thing","body":"Closes #3\n","headRefName":"claude/deliver-thing"}]' ;;
  *"pr list"*)            echo '[{"number":50,"title":"deliver the thing","createdAt":"2026-08-20T00:00:00Z","updatedAt":"2026-08-20T00:00:00Z","headRefName":"claude/deliver-thing"}]' ;;
  *"pr checks"*)          printf 'test\tpass\t1m\thttps://example.invalid\n' ;;
  *"pr view"*|*"issue view"*) echo '{"comments":[]}' ;;
  *"repo view"*)          echo 'stub' ;;
  *)                      echo '[]' ;;
esac
EOF
chmod +x "$SANDBOX/workbin/gh"
out=$(PATH="$SANDBOX/workbin:$PATH" "$ROOT/scripts/fleet-status.sh" --dry-run 2>/dev/null)
echo "$out" | grep -qF "Consumable now: 1" && pass "gate: an issue an open PR already closes is not consumable" || fail "gate: an issue an open PR already closes is not consumable (got: $(echo "$out" | grep 'Consumable now' || echo 'no gate line'))"
echo "$out" | grep -qF "gated: #3 — working" && pass "gate: the working issue is named with its reason" || fail "gate: the working issue is named with its reason"
echo "$out" | grep -qF "gated: #9" && fail "gate: an unreferenced twin must stay consumable" || pass "gate: an unreferenced twin must stay consumable"

echo "== check-ready.sh (the gate, executable) =="
# Label semantics asserted here so weakening one is a visible, gate-blocked
# act — and `working` asserted alongside them, because the state that was
# defined-but-never-computed is the one that actually cost this repo (L-057).
CR="$ROOT/scripts/check-ready.sh"
"$CR" "task:" >/dev/null 2>&1 && pass "check-ready: bare task: -> ready (exit 0)" || fail "check-ready: bare task: -> ready (exit 0)"
"$CR" "task:" "question:" >/dev/null 2>&1 && fail "check-ready: task:+question: -> blocked" || pass "check-ready: task:+question: -> blocked"
"$CR" "task:" "loop:hold" >/dev/null 2>&1 && fail "check-ready: task:+loop:hold -> blocked" || pass "check-ready: task:+loop:hold -> blocked"
"$CR" "task:" "inbox:" >/dev/null 2>&1 && fail "check-ready: task:+inbox: -> blocked" || pass "check-ready: task:+inbox: -> blocked"
"$CR" "task:" "human-check:" >/dev/null 2>&1 && fail "check-ready: task:+human-check: -> blocked" || pass "check-ready: task:+human-check: -> blocked"
"$CR" "intent:" >/dev/null 2>&1 && fail "check-ready: bare intent: -> blocked" || pass "check-ready: bare intent: -> blocked"
"$CR" "task:" "intent:" >/dev/null 2>&1 && fail "check-ready: task:+intent: -> blocked" || pass "check-ready: task:+intent: -> blocked"
"$CR" "enhancement" >/dev/null 2>&1 && fail "check-ready: not labeled task: -> blocked" || pass "check-ready: not labeled task: -> blocked"
"$CR" --working "task:" >/dev/null 2>&1 && fail "check-ready: --working -> blocked even with clean labels" || pass "check-ready: --working -> blocked even with clean labels"
out=$("$CR" --working "task:" 2>/dev/null)
echo "$out" | grep -q "already references it" && pass "check-ready: working block names its reason" || fail "check-ready: working block names its reason"
"$CR" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ] && pass "check-ready: no labels -> usage exit 64" || fail "check-ready: no labels -> usage exit 64 (got $rc)"
CRB="$SANDBOX/cr-body.md"
printf '### Done means\n\nverify.sh exits 0\n' > "$CRB"
"$CR" --body "$CRB" "task:" >/dev/null 2>&1 && pass "check-ready: body with Done means -> ready" || fail "check-ready: body with Done means -> ready"
printf 'no done means heading here\n' > "$CRB"
"$CR" --body "$CRB" "task:" >/dev/null 2>&1 && fail "check-ready: body without Done means -> blocked" || pass "check-ready: body without Done means -> blocked"
"$CR" --body "$SANDBOX/no-such-body.md" "task:" >/dev/null 2>&1 && fail "check-ready: missing body file -> blocked (fails closed)" || pass "check-ready: missing body file -> blocked (fails closed)"

echo "== check-record.sh (In plain words at filing, self-test on fixtures) =="
# This is verify.sh full's only exercise of check-record.sh: a self-test
# against fixture bodies here, never a scan of live issues.
CRR="$ROOT/scripts/check-record.sh"
CRRB="$SANDBOX/record-body.md"
printf '### In plain words\nThe app opens in under two seconds and switching views is instant.\n\n### Done means\nverify.sh full exits 0\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && pass "check-record: compliant task body -> exit 0" || fail "check-record: compliant task body -> exit 0"
printf '### Done means\nverify.sh full exits 0\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: task body without In plain words -> exit 1" || pass "check-record: task body without In plain words -> exit 1"
printf '### In plain words\nThe fixture reconciles against the canonical schema per protocol v1.\n\n### Done means\nx\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: In plain words matching the jargon deny-list -> exit 1" || pass "check-record: In plain words matching the jargon deny-list -> exit 1"
printf '### In plain words\nRun `scripts/verify.sh` to confirm it works.\n\n### Done means\nx\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: In plain words with backticks -> exit 1" || pass "check-record: In plain words with backticks -> exit 1"
# ONE cap for every record's plain line 1 (scripts/card-grammar.json): 80
# characters, 12 words, one sentence. The old rule joined the whole section
# and capped the join at 160, which let a 150-character first line — the line
# a card actually shows — straight through.
EIGHTY="Risky changes wait for your approval and everything safer merges itself quietly."
EIGHTYONE="x${EIGHTY}"   # 81 chars, still 12 words and one sentence
printf '### In plain words\n%s\n\n### Done means\nx\n' "$EIGHTY" > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && pass "check-record: an 80-char, 12-word plain line -> exit 0" || fail "check-record: an 80-char, 12-word plain line -> exit 0"
printf '### In plain words\n%s\n\n### Done means\nx\n' "$EIGHTYONE" > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: an 81-char plain line -> exit 1" || pass "check-record: an 81-char plain line -> exit 1"
# The older, weaker bound is KEPT, not replaced: a line over 160 must still be
# refused, and an assertion that stops being made is an assertion nobody
# notices going missing (this repo's own machinery gate reads a rename as a
# removal, and it is right to).
LONG="$(printf 'x%.0s' $(seq 1 161))"
printf '### In plain words\n%s\n\n### Done means\nx\n' "$LONG" > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: In plain words over 160 chars -> exit 1" || pass "check-record: In plain words over 160 chars -> exit 1"
printf '### In plain words\none two three four five six seven eight nine ten eleven twelve thirteen\n\n### Done means\nx\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: a 13-word plain line -> exit 1" || pass "check-record: a 13-word plain line -> exit 1"
printf '### In plain words\nThe app opens fast. Switching views is instant.\n\n### Done means\nx\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: a two-sentence plain line -> exit 1" || pass "check-record: a two-sentence plain line -> exit 1"
# A blocker is a dependency, never an ancestor: a task whose Blocked by names
# its own Parent goal / Parent intent would wait on a record that closes only
# after the task itself (overlord-ui#187/#188/#201 sat "Blocked" a week).
printf '### In plain words\nSchedules read in words on the settings screen.\n\n### Parent goal\ngoal/283\n\n### Blocked by\nVinylfigure/overlord#283 — built in a worktree from the operator'"'"'s session.\n\n### Done means\nx\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: Blocked by naming the task's own Parent goal -> exit 1" || pass "check-record: Blocked by naming the task's own Parent goal -> exit 1"
printf '### In plain words\nSchedules read in words on the settings screen.\n\n### Parent intent\nVinylfigure/overlord#262\n\n### Blocked by\nhttps://github.com/Vinylfigure/overlord/issues/262\n\n### Done means\nx\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: Blocked by naming the task's own Parent intent by URL -> exit 1" || pass "check-record: Blocked by naming the task's own Parent intent by URL -> exit 1"
printf '### In plain words\nSchedules read in words on the settings screen.\n\n### Parent goal\ngoal/283\n\n### Blocked by\nNothing.\n\n### Done means\nx\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && pass "check-record: Blocked by of Nothing. under a parent -> exit 0" || fail "check-record: Blocked by of Nothing. under a parent -> exit 0"
printf '### In plain words\nSchedules read in words on the settings screen.\n\n### Parent goal\ngoal/283\n\n### Blocked by\n#12, Vinylfigure/overlord#328\n\n### Done means\nx\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && pass "check-record: Blocked by naming other records under a parent -> exit 0" || fail "check-record: Blocked by naming other records under a parent -> exit 0"
printf '### In plain words\nShould low-stakes questions answer themselves after three days\n\n### Decision\nx\n\n### Options\nYes, auto-answer\nNo, always wait\n\n### Recommended choice\nYes, auto-answer\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: a question whose plain line has no question mark -> exit 1" || pass "check-record: a question whose plain line has no question mark -> exit 1"
# The cap is the FILE's, not the script's.
jq '.caps.headlineChars = 10' "$ROOT/scripts/card-grammar.json" > "$SANDBOX/record-grammar.json"
printf '### In plain words\nThe app opens in under two seconds.\n\n### Done means\nx\n' > "$CRRB"
CARD_GRAMMAR="$SANDBOX/record-grammar.json" "$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: a cap lowered in card-grammar.json is enforced" || pass "check-record: a cap lowered in card-grammar.json is enforced"
CARD_GRAMMAR="$SANDBOX/no-such-card-grammar.json" "$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: a missing card grammar -> exit 1 (fails closed)" || pass "check-record: a missing card grammar -> exit 1 (fails closed)"
printf '### In plain words\nShould low-stakes questions answer themselves after three days?\n\n### Decision\nx\n\n### Options\nYes, auto-answer\nNo, always wait\n\n### Recommended choice\nYes, auto-answer\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && pass "check-record: compliant question body -> exit 0" || fail "check-record: compliant question body -> exit 0"
printf '### In plain words\nShould low-stakes questions answer themselves after three days?\n\n### Decision\nx\n\n### Recommended choice\nYes, auto-answer\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: question without Options -> exit 1" || pass "check-record: question without Options -> exit 1"
"$CRR" "$SANDBOX/no-such-record.md" >/dev/null 2>&1 && fail "check-record: missing body file -> exit 1 (fails closed)" || pass "check-record: missing body file -> exit 1 (fails closed)"
# One heading form is EMITTED (`### In plain words`); the older bold form is
# still READ, because records filed under it cannot be rewritten.
printf '**In plain words:** The app opens in under two seconds.\n\n**Done means:** it works\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && pass "check-record: a legacy bold In plain words line is still read" || fail "check-record: a legacy bold In plain words line is still read"
printf '**In plain words:** The record reconciles against the canonical schema.\n' > "$CRRB"
"$CRR" "$CRRB" >/dev/null 2>&1 && fail "check-record: a legacy bold line still faces the jargon deny-list -> exit 1" || pass "check-record: a legacy bold line still faces the jargon deny-list -> exit 1"
if grep -rn -- '\*\*In plain words' "$ROOT/docs" "$ROOT/.claude/skills" "$ROOT/.github" >/dev/null 2>&1; then
  fail "one heading form: the bold '**In plain words:**' spelling is still emitted somewhere"
else
  pass "one heading form: nothing in docs/, skills/ or .github/ emits the bold In plain words spelling"
fi

# Render the actual producer template's Human check placeholder into a task.
# It is a drafting aid, not a delivered review request.
python3 - "$ROOT/.github/ISSUE_TEMPLATE/task.yml" "$CRRB" <<'PYREVIEW'
import sys
text = open(sys.argv[1]).read().split("id: human-check", 1)[1]
lines = text.split("placeholder: |", 1)[1].split("    validations:", 1)[0].splitlines()
raw = "\n".join(line[8:] if line.startswith("        ") else line for line in lines).strip()
open(sys.argv[2], "w").write("### In plain words\nReview whether saved lessons belong in every project.\n\n### Human check\n" + raw + "\n")
PYREVIEW
"$CRR" "$CRRB" --ready-for-review >/dev/null 2>&1 && fail "review readiness: producer placeholder is not a delivery" || pass "review readiness: producer placeholder is not a delivery"
python3 - "$CRRB" <<'PYREVIEW'
import sys
p=sys.argv[1]; text=open(p).read().replace("https://...", "https://github.com/o/app/pull/9").replace("the deployed preview / the phone / the rendered artifact", "Delivered changes").replace("what to do, in one or two steps", "Open the change and review each lesson classification.").replace("what the operator must observe for this to pass", "Each project-specific lesson stays in its own project.")
open(p, "w").write(text)
PYREVIEW
"$CRR" "$CRRB" --ready-for-review >/dev/null 2>&1 && pass "review readiness: producer headings and concrete artifact parse" || fail "review readiness: producer headings and concrete artifact parse"
python3 - "$CRRB" <<'PYREVIEW'
import sys
p=sys.argv[1]; text=open(p).read().split("#### Pass")[0]+"#### Pass\n_No response_\n"
open(p,"w").write(text)
PYREVIEW
"$CRR" "$CRRB" --ready-for-review >/dev/null 2>&1 && fail "review readiness: missing pass criteria fails" || pass "review readiness: missing pass criteria fails"
printf '### In plain words\nReview the delivered change.\n### Human check\nSurface: Preview\nInstruction: Open and refresh the page.\nURL: https://github.com/o/app/pull/9\nPass: The saved value remains.\n' > "$CRRB"
"$CRR" "$CRRB" --ready-for-review >/dev/null 2>&1 && pass "review readiness: legacy colon fields remain accepted" || fail "review readiness: legacy colon fields remain accepted"
printf '### In plain words\nReview the delivered change.\n### Human check\n#### Surface\nDelivered change\n#### Instruction\nOpen and refresh the page.\n#### URL\nhttps://github.com/o/app/pull/9\n#### Pass criteria\nThe saved value remains.\n' > "$CRRB"
"$CRR" "$CRRB" --ready-for-review >/dev/null 2>&1 && pass "review readiness: the older Pass criteria heading remains readable" || fail "review readiness: the older Pass criteria heading remains readable"
printf '### In plain words\nCreate the connection.\n### Done means\nThe connection works.\n' > "$CRRB"
"$CRR" "$CRRB" --ready-for-review >/dev/null 2>&1 && fail "review readiness: ordinary work is not a delivered review" || pass "review readiness: ordinary work is not a delivered review"

python3 "$ROOT/scripts/test-human-response.py" && pass "human responses: typed writing requests cannot become review or worker work" || fail "human responses: typed request contract"
python3 "$ROOT/scripts/test-review-request.py" && pass "review producer: source-bound delivery transitions" || fail "review producer: source-bound delivery transitions"

echo "== check-ask.sh (the recorded ask, self-test on fixtures) =="
# The ask a session posts when it parks work for the operator (docs/ATTENTION.md,
# "The recorded ask"). Shipped fixtures cover the wording rules; the generated
# bodies below cover the shape rules.
CA="$ROOT/scripts/check-ask.sh"
CAF="$ROOT/scripts/fixtures"
"$CA" "$CAF/ask-pass.md" >/dev/null 2>&1 && pass "check-ask: a well-formed ask -> exit 0" || fail "check-ask: a well-formed ask -> exit 0"
"$CA" "$CAF/ask-fail-names-a-script.md" >/dev/null 2>&1 && fail "check-ask: an ask naming a script -> exit 1" || pass "check-ask: an ask naming a script -> exit 1"
"$CA" "$CAF/ask-fail-hedges.md" >/dev/null 2>&1 && fail "check-ask: an ask that hedges -> exit 1" || pass "check-ask: an ask that hedges -> exit 1"
"$CA" "$CAF/ask-fail-subject-is-the-artifact.md" >/dev/null 2>&1 && fail "check-ask: an ask whose subject is the artifact -> exit 1" || pass "check-ask: an ask whose subject is the artifact -> exit 1"
CAB="$SANDBOX/ask-body.md"
ask_body() { # ask_body <Ask> <Because line> <If-nothing> <Options>
  printf '<!-- janus:ask:v1 -->\nAsk: %s\nBecause:\n- %s\nIf-nothing: %s\nOptions: %s\nSupersedes: none\nSource-revision: 6d7c507\n' "$1" "$2" "$3" "$4" > "$CAB"
}
ask_body "Approve the wider access" "The sweep cannot reach two projects without it." "The queue keeps showing finished work." "Widen it | Leave it"
"$CA" "$CAB" >/dev/null 2>&1 && pass "check-ask: a minimal one-fact ask -> exit 0" || fail "check-ask: a minimal one-fact ask -> exit 0"
ask_body "Please look at this when you get a chance" "A fact." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: a verb outside the fixed set -> exit 1" || pass "check-ask: a verb outside the fixed set -> exit 1"
ask_body "Approve $(printf 'x%.0s' $(seq 1 90))" "A fact." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: an Ask over 80 chars -> exit 1" || pass "check-ask: an Ask over 80 chars -> exit 1"
ask_body "Approve the wider access" "$(printf 'x%.0s' $(seq 1 121))" "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: a Because line over 120 chars -> exit 1" || pass "check-ask: a Because line over 120 chars -> exit 1"
ask_body "Approve the wider access" "$(printf 'x%.0s' $(seq 1 120))" "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && pass "check-ask: a Because line at exactly 120 chars -> exit 0" || fail "check-ask: a Because line at exactly 120 chars -> exit 0"
# The older, weaker bound is KEPT, not replaced — see check-record above.
ask_body "Approve the wider access" "$(printf 'x%.0s' $(seq 1 141))" "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: a Because line over 140 chars -> exit 1" || pass "check-ask: a Because line over 140 chars -> exit 1"
ask_body "Approve the wider access" "A fact." "$(printf 'x%.0s' $(seq 1 121))" "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: an If-nothing over 120 chars -> exit 1" || pass "check-ask: an If-nothing over 120 chars -> exit 1"
# The caps are the FILE's, not the script's: swap the file, the rule changes.
jq '.caps.becauseChars = 12' "$ROOT/scripts/card-grammar.json" > "$SANDBOX/card-grammar.json"
ask_body "Approve the wider access" "A fact that runs past twelve characters." "Nothing moves." "Yes | No"
CARD_GRAMMAR="$SANDBOX/card-grammar.json" "$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: a cap lowered in card-grammar.json is enforced" || pass "check-ask: a cap lowered in card-grammar.json is enforced"
CARD_GRAMMAR="$SANDBOX/no-such-card-grammar.json" "$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: a missing card grammar -> exit 1 (fails closed)" || pass "check-ask: a missing card grammar -> exit 1 (fails closed)"
ask_body "Approve the wider access" "A fact." "Nothing moves." "Only one"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: fewer than 2 Options -> exit 1" || pass "check-ask: fewer than 2 Options -> exit 1"
ask_body "Approve the wider access" "A fact." "Nothing moves." "A | B | C | D | E"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: more than 4 Options -> exit 1" || pass "check-ask: more than 4 Options -> exit 1"
printf '<!-- janus:ask:v1 -->\nAsk: Approve the wider access\nBecause:\n- One.\n- Two.\n- Three.\n- Four.\nIf-nothing: Nothing moves.\nOptions: Yes | No\nSupersedes: none\nSource-revision: 6d7c507\n' > "$CAB"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: more than 3 Because lines -> exit 1" || pass "check-ask: more than 3 Because lines -> exit 1"
printf '<!-- janus:ask:v1 -->\nAsk: Approve the wider access\nBecause:\n- One.\nIf-nothing: Nothing moves.\nOptions: Yes | No\nSupersedes: none\n' > "$CAB"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: a missing required field -> exit 1" || pass "check-ask: a missing required field -> exit 1"
printf 'Ask: Approve the wider access\nBecause:\n- One.\nIf-nothing: Nothing moves.\nOptions: Yes | No\nSupersedes: none\nSource-revision: 6d7c507\n' > "$CAB"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: no janus:ask:v1 marker -> exit 1" || pass "check-ask: no janus:ask:v1 marker -> exit 1"
ask_body "Merge the change once the queue is clear" "The fix is proved by run 42." "The queue stays wrong." "Merge it | Send it back"
"$CA" "$CAB" >/dev/null 2>&1 && pass "check-ask: a plain fact naming no identifier -> exit 0" || fail "check-ask: a plain fact naming no identifier -> exit 0"
ask_body "Merge the change once the queue is clear" "The proof is in #249." "The queue stays wrong." "Merge it | Send it back"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: an ask naming an issue number -> exit 1" || pass "check-ask: an ask naming an issue number -> exit 1"
ask_body "Merge the change once the queue is clear" "The grant is missing pull-requests: write." "The queue stays wrong." "Merge it | Send it back"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: an ask naming a permission key -> exit 1" || pass "check-ask: an ask naming a permission key -> exit 1"
"$CA" "$SANDBOX/no-such-ask.md" >/dev/null 2>&1 && fail "check-ask: missing body file -> exit 1 (fails closed)" || pass "check-ask: missing body file -> exit 1 (fails closed)"
"$CA" >/dev/null 2>&1; [ $? -eq 64 ] && pass "check-ask: no argument -> exit 64 (usage)" || fail "check-ask: no argument -> exit 64 (usage)"

# The fixed set is six PHRASES. Matching the first token only would let a legal
# opening word carry an arbitrary tail — the free prose the marker replaces.
ask_body "Close it immediately without review" "A plain fact." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: 'Close' with a tail that is not 'or re-spec' -> exit 1" || pass "check-ask: 'Close' with a tail that is not 'or re-spec' -> exit 1"
ask_body "Confirm the sky is blue" "A plain fact." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: 'Confirm' with a tail that is not 'it is done' -> exit 1" || pass "check-ask: 'Confirm' with a tail that is not 'it is done' -> exit 1"
ask_body "Do the needful before Friday" "A plain fact." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: 'Do' with a tail that is not 'this' -> exit 1" || pass "check-ask: 'Do' with a tail that is not 'this' -> exit 1"
ask_body "Merged without review" "A plain fact." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: 'Merge' without a word boundary (Merged) -> exit 1" || pass "check-ask: 'Merge' without a word boundary (Merged) -> exit 1"
ask_body "Mergers are not the ask here" "A plain fact." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: 'Merge' without a word boundary (Mergers) -> exit 1" || pass "check-ask: 'Merge' without a word boundary (Mergers) -> exit 1"
for phrase in "Close or re-spec the change" "Confirm it is done on your phone" "Do this before Friday" "Merge it" "Merge" "Approve the wider access" "Answer the pricing question"; do
  ask_body "$phrase" "A plain fact." "Nothing moves." "Yes | No"
  "$CA" "$CAB" >/dev/null 2>&1 || fail "check-ask: the fixed phrase '$phrase' is accepted"
done
pass "check-ask: every phrase in the fixed verb set is accepted"

echo "== card-grammar.json (the fleet's ONE file of caps) =="
# One cap for every record's plain line 1, set here and nowhere else: this
# repo's check-record.sh and check-ask.sh read it, overlord's check-goal and
# check-intent read their vendored copy, and overlord-ui's renderer imports
# it. A number typed in four places is four numbers eventually (L-007), so
# these assertions prove the file is the number AND that the prose in
# docs/ATTENTION.md states the same numbers the file does.
CG="$ROOT/scripts/card-grammar.json"
jq . "$CG" >/dev/null 2>&1 && pass "card-grammar.json is valid JSON" || fail "card-grammar.json is valid JSON"
[ "$(jq -r '.version' "$CG" 2>/dev/null)" = "1" ] && pass "card-grammar.json declares version 1" || fail "card-grammar.json declares version 1"
for key in headlineChars headlineWords lineChars lineWords askChars becauseChars ifNothingChars optionChars becauseLines; do
  v=$(jq -r ".caps.$key // empty" "$CG" 2>/dev/null)
  case "$v" in
    ''|*[!0-9]*) fail "card-grammar.json caps.$key is missing or not a number (got '$v')" ;;
    *) pass "card-grammar.json caps.$key = $v" ;;
  esac
done
[ "$(jq -r '.caps.options | length' "$CG" 2>/dev/null)" = "2" ] && pass "card-grammar.json caps.options is a [min, max] pair" || fail "card-grammar.json caps.options is a [min, max] pair"
[ "$(jq -r '.verbs | length' "$CG" 2>/dev/null)" = "6" ] && pass "card-grammar.json names the six fixed verbs" || fail "card-grammar.json names the six fixed verbs"
# The checkers enforce the FILE's numbers, not their own: read the cap the
# script would use and compare it to the JSON.
for pair in "headlineChars:80" "askChars:80" "becauseChars:120" "ifNothingChars:120" "optionChars:30" "headlineWords:12"; do
  key=${pair%%:*}; want=${pair##*:}
  got=$(jq -r ".caps.$key" "$CG" 2>/dev/null)
  [ "$got" = "$want" ] && pass "card-grammar.json caps.$key is the agreed $want" || fail "card-grammar.json caps.$key is $got, the fleet agreed $want"
done
# Doc-vs-JSON: every character/word cap ATTENTION.md states must BE a cap in
# the file. This is the guard that catches prose left saying 160 (or 140)
# after the number moved.
GRAMMAR_NUMBERS=$(jq -r '[.caps | to_entries[] | .value] | flatten | .[] | tostring' "$CG" 2>/dev/null | sort -u)
stale=""
for n in $(grep -ohE '≤ ?[0-9]+ (chars|characters|words)|[0-9]+ (characters|words) or fewer' "$ROOT/docs/ATTENTION.md" | grep -oE '[0-9]+' | sort -u); do
  printf '%s\n' "$GRAMMAR_NUMBERS" | grep -qx "$n" || stale="$stale $n"
done
[ -z "$stale" ] && pass "every character/word cap docs/ATTENTION.md states is a cap in card-grammar.json" || fail "docs/ATTENTION.md states cap(s)$stale that card-grammar.json does not carry — the prose and the file disagree"
for n in $(jq -r '.caps.headlineChars, .caps.headlineWords' "$CG"); do
  grep -q "$n " "$ROOT/docs/ATTENTION.md" && pass "docs/ATTENTION.md states the headline cap $n" || fail "docs/ATTENTION.md never states the headline cap $n"
done

echo "== vendor-grammar.sh (the named vendoring mechanism) =="
# Copying by hand is how three copies of one list drifted apart. This is that
# copy, done the same way every time, and the pin it writes is what overlord
# and overlord-ui fail their builds on.
VG="$ROOT/scripts/vendor-grammar.sh"
[ -x "$VG" ] && pass "vendor-grammar.sh is executable" || fail "vendor-grammar.sh is executable"
"$VG" >/dev/null 2>&1; [ $? -eq 64 ] && pass "vendor-grammar.sh: no argument -> exit 64 (usage)" || fail "vendor-grammar.sh: no argument -> exit 64 (usage)"
"$VG" "$SANDBOX/no-such-consumer" >/dev/null 2>&1; [ $? -eq 64 ] && pass "vendor-grammar.sh: a consumer path that does not exist -> exit 64" || fail "vendor-grammar.sh: a consumer path that does not exist -> exit 64"
VGC="$SANDBOX/vendor-consumer"
mkdir -p "$VGC"
if "$VG" "$VGC" >/dev/null 2>&1; then
  pass "vendor-grammar.sh vendors into a fresh checkout"
else
  fail "vendor-grammar.sh vendors into a fresh checkout"
fi
VGS="$VGC/scripts/vendored-from-janus.sums"
if [ ! -f "$VGS" ]; then
  fail "vendor-grammar.sh wrote no scripts/vendored-from-janus.sums"
else
  vg_n=0; vg_bad=""
  while read -r want path; do
    case "$want" in \#*|"") continue ;; esac
    vg_n=$((vg_n + 1))
    src="$ROOT/${path#scripts/}"; src="$ROOT/scripts/${path#scripts/}"
    if [ ! -f "$VGC/$path" ]; then vg_bad="$vg_bad $path(absent)"; continue; fi
    got=$(if command -v sha256sum >/dev/null 2>&1; then sha256sum "$VGC/$path"; else shasum -a 256 "$VGC/$path"; fi | cut -d' ' -f1)
    here=$(if command -v sha256sum >/dev/null 2>&1; then sha256sum "$src"; else shasum -a 256 "$src"; fi | cut -d' ' -f1)
    { [ "$got" = "$want" ] && [ "$got" = "$here" ]; } || vg_bad="$vg_bad $path"
  done < "$VGS"
  [ "$vg_n" -ge 8 ] && pass "vendor-grammar.sh pins $vg_n files (grammar, deny-list, both gates, four ask fixtures)" || fail "vendor-grammar.sh pinned only $vg_n files — expected at least 8"
  [ -z "$vg_bad" ] && pass "every vendored file matches janus byte for byte and its written pin" || fail "vendored copies disagree with janus or with the pin:$vg_bad"
fi
# The vendored gates RUN in the consumer, reading the consumer's own grammar.
"$VGC/scripts/check-ask.sh" "$VGC/scripts/fixtures/ask-pass.md" >/dev/null 2>&1 && pass "the vendored check-ask.sh runs in the consumer checkout" || fail "the vendored check-ask.sh runs in the consumer checkout"
printf '### In plain words\nThe app opens in under two seconds.\n\n### Done means\nx\n' > "$SANDBOX/vendored-record.md"
"$VGC/scripts/check-record.sh" "$SANDBOX/vendored-record.md" >/dev/null 2>&1 && pass "the vendored check-record.sh runs in the consumer checkout" || fail "the vendored check-record.sh runs in the consumer checkout"

echo "== deny-list.json (the fleet's one vocabulary list) =="
# janus owns this file; overlord and overlord-ui vendor it by content and test
# equality against it (docs/ATTENTION.md). These assertions prove check-ask.sh
# reads the FILE rather than a copy of the words baked into the script.
DL="$ROOT/scripts/deny-list.json"
jq . "$DL" >/dev/null 2>&1 && pass "deny-list.json is valid JSON" || fail "deny-list.json is valid JSON"
for key in identifiers machine_words hedges artifact_subjects; do
  n=$(jq -r --arg k "$key" '.[$k] | length' "$DL" 2>/dev/null)
  [ "${n:-0}" -gt 0 ] && pass "deny-list.json carries a non-empty $key list ($n)" || fail "deny-list.json $key is missing or empty"
done
[ "$(jq -r '.version' "$DL" 2>/dev/null)" = "1" ] && pass "deny-list.json declares version 1" || fail "deny-list.json declares version 1"
# Every word in the file is actually enforced — the file IS the list.
missed=""
while IFS= read -r w; do
  ask_body "Approve the wider access" "The queue $w was left behind." "Nothing moves." "Yes | No"
  "$CA" "$CAB" >/dev/null 2>&1 && missed="$missed $w"
done < <(jq -r '.machine_words[], .hedges[]' "$DL")
[ -z "$missed" ] && pass "check-ask: every machine word and hedge in deny-list.json is rejected" || fail "check-ask: deny-list words not enforced:$missed"
missed=""
while IFS= read -r sub; do
  ask_body "Approve the wider access" "$sub was filed twice." "Nothing moves." "Yes | No"
  "$CA" "$CAB" >/dev/null 2>&1 && missed="$missed [$sub]"
done < <(jq -r '.artifact_subjects[]' "$DL")
[ -z "$missed" ] && pass "check-ask: every artifact subject in deny-list.json is rejected" || fail "check-ask: deny-list subjects not enforced:$missed"
# The two words the operator named: the ask must not speak about its own machinery.
ask_body "Approve the wider access" "The fixture proved the queue was wrong." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: an ask saying 'fixture' -> exit 1" || pass "check-ask: an ask saying 'fixture' -> exit 1"
ask_body "Approve the wider access" "The marker was never written to the record." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: an ask saying 'marker' -> exit 1" || pass "check-ask: an ask saying 'marker' -> exit 1"
ask_body "Approve the wider access" "The result is Likely correct." "Nothing moves." "Yes | No"
"$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: a hedge in any casing -> exit 1" || pass "check-ask: a hedge in any casing -> exit 1"
# Swapping the file swaps the rules: proof that nothing is baked into the script.
jq '.machine_words = ["banana"] | .hedges = ["banana"] | .identifiers = ["ZZZZ-no-such-pattern"] | .artifact_subjects = ["Banana"]' "$DL" > "$SANDBOX/deny-list.json"
ask_body "Approve the wider access" "The banana was left behind." "Nothing moves." "Yes | No"
CHECK_ASK_DENY_LIST="$SANDBOX/deny-list.json" "$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: a word added to the deny-list file is enforced" || pass "check-ask: a word added to the deny-list file is enforced"
ask_body "Approve the wider access" "The proof is in #249." "Nothing moves." "Yes | No"
CHECK_ASK_DENY_LIST="$SANDBOX/deny-list.json" "$CA" "$CAB" >/dev/null 2>&1 && pass "check-ask: a pattern removed from the deny-list file stops being enforced" || fail "check-ask: a pattern removed from the deny-list file stops being enforced"
ask_body "Approve the wider access" "A plain fact." "Nothing moves." "Yes | No"
CHECK_ASK_DENY_LIST="$SANDBOX/no-such-deny-list.json" "$CA" "$CAB" >/dev/null 2>&1 && fail "check-ask: a missing deny-list -> exit 1 (fails closed)" || pass "check-ask: a missing deny-list -> exit 1 (fails closed)"

echo "== harvest-ledgers.sh (reverse heredity, janus#38) =="
HV="$ROOT/scripts/harvest-ledgers.sh"
mkdir -p "$SANDBOX/harvest"
cat > "$SANDBOX/harvest/own.md" <<'EOF'
## L-001 · 2026-07-01 · Shared rule both repos hold

- Trigger: something
- Rule: shared.
- Scope: portable
- Evidence: 2
- Status: candidate
EOF
cat > "$SANDBOX/harvest/child.md" <<'EOF'
## L-050 · 2026-08-20 · Shared rule both repos hold

- Trigger: child copy
- Rule: shared.
- Scope: portable
- Evidence: 3
- Status: candidate

## L-051 · 2026-08-21 · Child-only portable lesson the template lacks

- Trigger: child incident
- Rule: harvest me.
- Scope: portable
- Evidence: 2
- Status: candidate

## L-052 · 2026-08-21 · Project-scoped child lesson

- Trigger: child-local
- Rule: never harvested.
- Scope: project
- Evidence: 1
- Status: candidate

## L-053 · 2026-08-22 · Retired portable lesson

- Trigger: gone
- Rule: dead.
- Scope: portable
- Evidence: 2
- Status: retired (merged elsewhere)
EOF
hv_out=$("$HV" "$SANDBOX/harvest/own.md" "$SANDBOX/harvest/child.md"); hv_rc=$?
[ "$hv_rc" -eq 0 ] && pass "harvest: exits 0 (survey, not a gate)" || fail "harvest: exits 0 (got $hv_rc)"
echo "$hv_out" | grep -q "L-051" && pass "harvest: child-only portable entry surfaces" || fail "harvest: child-only portable entry surfaces (got: $hv_out)"
echo "$hv_out" | grep -q "L-050" && fail "harvest: shared-title entry must not surface (got: $hv_out)" || pass "harvest: shared-title entry not surfaced"
echo "$hv_out" | grep -q "L-052" && fail "harvest: project-scoped entry must not surface (got: $hv_out)" || pass "harvest: project-scoped entry not surfaced"
echo "$hv_out" | grep -q "L-053" && fail "harvest: retired entry must not surface (got: $hv_out)" || pass "harvest: retired entry not surfaced"
n=$(printf '%s\n' "$hv_out" | grep -c "L-051")
[ "$n" -eq 1 ] && pass "harvest: exactly one candidate line" || fail "harvest: exactly one candidate line (got $n)"
"$HV" "$SANDBOX/harvest/own.md" "$SANDBOX/harvest/missing.md" 2>/dev/null >/dev/null && pass "harvest: missing child ledger skipped, still exit 0" || fail "harvest: missing child ledger skipped, still exit 0"

echo "== ledger and decision ids are unique (append-only union-merge guard) =="
# .gitattributes union-merges these files so parallel branches stop
# conflicting on them; the trade is that two branches can both land an entry
# under the same id. That must fail loudly here rather than merge silently.
dupe_ids() { grep -oE "^## $2[A-Za-z0-9-]+" "$1" 2>/dev/null | sort | uniq -d; }
d=$(dupe_ids "$ROOT/docs/DECISIONS.md" "DL-")
[ -z "$d" ] && pass "docs/DECISIONS.md has no duplicate lock id" || fail "docs/DECISIONS.md has duplicate lock id(s): $d"
learning_dupes() {
  awk '/<!-- entries below this line -->/{entries=1; next} entries && /^## L-[A-Za-z0-9-]+[[:space:]]/{print $2}' "$1" | sort | uniq -d
}
d=$(learning_dupes "$ROOT/.claude/memory/LEARNINGS.md")
[ -z "$d" ] && pass "LEARNINGS.md has no duplicate learning id" || fail "LEARNINGS.md has duplicate learning id(s): $d"
# Red-first proof the check can actually fail: a fixture file with a known dupe.
printf '## DL-2026-01-01-a · x\n## DL-2026-01-01-a · y\n' > "$SANDBOX/dupe-fixture.md"
d=$(dupe_ids "$SANDBOX/dupe-fixture.md" "DL-")
[ -n "$d" ] && pass "duplicate-id check detects a planted duplicate" || fail "duplicate-id check detects a planted duplicate"
printf '## L-20261001-first-lesson · format example\n<!-- entries below this line -->\n## L-20261001-first-lesson · real\n## L-20261001-second-lesson · distinct\n' > "$SANDBOX/learning-ids.md"
d=$(learning_dupes "$SANDBOX/learning-ids.md")
[ -z "$d" ] && pass "learning ids: distinct same-day slugs pass; format examples are ignored" || fail "learning ids: date was truncated or example counted ($d)"
printf '## L-20261001-second-lesson · duplicate\n' >> "$SANDBOX/learning-ids.md"
d=$(learning_dupes "$SANDBOX/learning-ids.md")
[ "$d" = 'L-20261001-second-lesson' ] && pass "learning ids: duplicate dated slug is detected in full" || fail "learning ids: missed full dated duplicate ($d)"
printf '<!-- entries below this line -->\n## L-001 · a\n## L-001 · b\n' > "$SANDBOX/learning-ids.md"
d=$(learning_dupes "$SANDBOX/learning-ids.md")
[ "$d" = 'L-001' ] && pass "learning ids: duplicate legacy id is still detected" || fail "learning ids: legacy duplicate missed ($d)"

echo "== session-start.sh: work line (backlog visibility) =="
# Renders only when gh + jq + a github.com origin all hold; every failure
# path is silent. A gh that errors covers the no-gh guard behaviorally —
# absence itself cannot be fixtured (PATH always carries the stub's dir).
WORKD="$SANDBOX/workline"
git init -q -b main "$WORKD" 2>/dev/null || git init -q "$WORKD"
git -C "$WORKD" remote add origin https://github.com/example/child.git
mkdir -p "$WORKD/.claude/memory"
printf '# Sandbox project\n\n- App stack: wired (fixture)\n' > "$WORKD/CLAUDE.md"
date +%s > "$WORKD/.claude/memory/recalibrated-at"
out=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$WORKD" PATH="$SANDBOX/bin:$PATH" "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "work: 1 task:, 1 question:" && pass "gh available -> work line renders counts" || fail "gh available -> work line renders counts (got: $out)"
echo "$out" | grep -q "1 open PRs" && pass "work line carries open-PR count" || fail "work line carries open-PR count (got: $out)"
mkdir -p "$SANDBOX/badbin"
printf '#!/usr/bin/env bash\nexit 1\n' > "$SANDBOX/badbin/gh"
chmod +x "$SANDBOX/badbin/gh"
out=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$WORKD" PATH="$SANDBOX/badbin:$PATH" "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "work:" && fail "failing gh -> silent (got: $out)" || pass "failing gh -> silent"
rm -rf "$WORKD"

echo "== session-start.sh =="
# Seed controlled CLAUDE.md state (L-009): these fixtures must pass in bootstrapped
# children too, so never depend on the live repo's facts block.
printf '# Sandbox project\n\n- App stack: NOT BOOTSTRAPPED — run /bootstrap.\n' > "$SANDBOX/CLAUDE.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "bootstrap" && pass "un-bootstrapped repo -> bootstrap nudge" || fail "un-bootstrapped repo -> bootstrap nudge (got: $out)"
# Leftover signals: a session that died or skipped the Stop nudge must not lose its lessons.
printf 'correction:2026-01-01T00:00:00Z\nverify-fail:/tmp/x\n' > "$SIGNALS"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "unprocessed learning signal" && pass "leftover signals -> reflect nudge" || fail "leftover signals -> reflect nudge (got: $out)"
out=$(echo '{"source":"compact"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "unprocessed learning signal" && fail "compact -> no duplicate signals line (got: $out)" || pass "compact -> no duplicate signals line"
echo "$out" | grep -q "Learning signals pending: 2" && pass "compact line reports pending count" || fail "compact line reports pending count (got: $out)"
rm -f "$SIGNALS"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "unprocessed" && fail "no signals -> silent (got: $out)" || pass "no signals -> silent"
# Decouple ledger fixtures from the shipped ledger's real entries: truncate the
# sandbox copy to header + marker so the fixtures below control what exists.
awk '{print} /<!-- entries below this line -->/{exit}' "$SANDBOX/.claude/memory/LEARNINGS.md" > "$SANDBOX/.claude/memory/LEARNINGS.md.tmp" \
  && mv "$SANDBOX/.claude/memory/LEARNINGS.md.tmp" "$SANDBOX/.claude/memory/LEARNINGS.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "consider /evolve" && fail "clean ledger -> no memory line" || pass "clean ledger -> no memory line"
printf '\n## L-900 · 2026-01-01 · Fixture entry\n- Trigger: fixture\n- Rule: fixture rule\n- Scope: project\n- Evidence: 2\n- Status: candidate\n' >> "$SANDBOX/.claude/memory/LEARNINGS.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "1 with Evidence >= 2" && pass "ripe learning counted (spec text not miscounted)" || fail "ripe learning counted (got: $out)"
# Regression: multi-digit Evidence must count as ripe (numeric >=, not a [2-9] first-digit match).
awk '{print} /<!-- entries below this line -->/{exit}' "$SANDBOX/.claude/memory/LEARNINGS.md" > "$SANDBOX/.claude/memory/LEARNINGS.md.tmp" \
  && mv "$SANDBOX/.claude/memory/LEARNINGS.md.tmp" "$SANDBOX/.claude/memory/LEARNINGS.md"
printf '\n## L-901 · 2026-01-01 · Double-digit evidence fixture\n- Trigger: fixture\n- Rule: fixture rule\n- Scope: project\n- Evidence: 10\n- Status: candidate\n' >> "$SANDBOX/.claude/memory/LEARNINGS.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "1 candidate learnings, 1 with Evidence >= 2" && pass "Evidence: 10 counts as ripe" || fail "Evidence: 10 counts as ripe (got: $out)"
# Regression: a non-candidate entry's Evidence must not leak into the next entry
# (replicated children start with high-Evidence 'inherited' entries).
awk '{print} /<!-- entries below this line -->/{exit}' "$SANDBOX/.claude/memory/LEARNINGS.md" > "$SANDBOX/.claude/memory/LEARNINGS.md.tmp" \
  && mv "$SANDBOX/.claude/memory/LEARNINGS.md.tmp" "$SANDBOX/.claude/memory/LEARNINGS.md"
printf '\n## L-902 · 2026-01-01 · Inherited high-evidence fixture\n- Trigger: fixture\n- Rule: fixture rule\n- Scope: portable\n- Evidence: 3\n- Status: inherited\n\n## L-903 · 2026-01-01 · Fresh candidate fixture\n- Trigger: fixture\n- Rule: fixture rule\n- Scope: project\n- Evidence: 1\n- Status: candidate\n' >> "$SANDBOX/.claude/memory/LEARNINGS.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "consider /evolve" && fail "non-candidate Evidence must not leak to next entry (got: $out)" || pass "non-candidate Evidence must not leak to next entry"
out=$(echo '{"source":"compact"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -qi "compacted" && pass "compact source -> workspace-rescue line" || fail "compact source -> workspace-rescue line (got: $out)"

echo "== session-start.sh: build-plan continuation =="
mkdir -p "$SANDBOX/docs"
printf -- '- [x] **T-DONE** — finished\n- [ ] **T-NEXT** — first open task\n- [ ] **T-LATER** — second open task\n' > "$SANDBOX/docs/EXECUTION-PLAN.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "next unblocked task is T-NEXT" && pass "plan present -> first unticked task surfaced" || fail "plan present -> first unticked task surfaced (got: $out)"
printf -- '- [x] **T-DONE** — finished\n- [x] **T-NEXT** — also finished\n' > "$SANDBOX/docs/EXECUTION-PLAN.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "Build plan" && fail "all boxes ticked -> silent (got: $out)" || pass "all boxes ticked -> silent"
rm -f "$SANDBOX/docs/EXECUTION-PLAN.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "Build plan" && fail "no plan file -> silent (got: $out)" || pass "no plan file -> silent"

echo "== session-start.sh: recalibration staleness =="
STAMPF="$SANDBOX/.claude/memory/recalibrated-at"
# Bootstrapped sandbox: overwrite via printf (sed -i diverges BSD/GNU), restore via cp below.
printf '# Sandbox project\n\n- App stack: wired (fixture)\n' > "$SANDBOX/CLAUDE.md"
rm -f "$STAMPF"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "recalibrate" && pass "bootstrapped + no stamp -> stale nudge" || fail "bootstrapped + no stamp -> stale nudge (got: $out)"
date +%s > "$STAMPF"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "recalibrate" && fail "fresh stamp -> silent (got: $out)" || pass "fresh stamp -> silent"
echo 1750000000 > "$STAMPF"   # 2025-06-15: fixed past epoch, always >30d old — fixture never rots
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "recalibrate" && pass "old stamp -> stale nudge" || fail "old stamp -> stale nudge (got: $out)"
printf 'not-a-number\n' > "$STAMPF"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "recalibrate" && pass "garbage stamp -> treated stale, no crash" || fail "garbage stamp -> treated stale (got: $out)"
printf '# Sandbox project\n\n- App stack: NOT BOOTSTRAPPED — run /bootstrap.\n' > "$SANDBOX/CLAUDE.md"
rm -f "$STAMPF"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "recalibrate" && fail "un-bootstrapped -> staleness gated off (got: $out)" || pass "un-bootstrapped -> staleness gated off"

echo "== session-start.sh: heredity self-check =="
# Template identity + foreign origin = un-replicated copy (L-039). The
# template's own checkouts (no remote, or a remote named janus) stay silent.
printf '# Janus (template)\n\n- App stack: NOT BOOTSTRAPPED — run /bootstrap.\n' > "$SANDBOX/CLAUDE.md"
out=$(echo '{"source":"startup"}' | "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "retrofit" && fail "non-git dir -> no heredity nudge (got: $out)" || pass "non-git dir -> no heredity nudge"
HER="$SANDBOX/heredity"
git init -q -b main "$HER" 2>/dev/null || git init -q "$HER"
git -C "$HER" config user.email t@t
git -C "$HER" config user.name t
mkdir -p "$HER/.claude/memory" "$HER/.claude/hooks"
printf '# Janus (template)\n\n- App stack: NOT BOOTSTRAPPED — run /bootstrap.\n' > "$HER/CLAUDE.md"
git -C "$HER" remote add origin https://github.com/example/some-child.git
out=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$HER" "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "retrofit" && pass "template identity + foreign origin -> retrofit nudge" || fail "template identity + foreign origin -> retrofit nudge (got: $out)"
git -C "$HER" remote set-url origin https://github.com/example/janus.git
out=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$HER" "$SANDBOX/.claude/hooks/session-start.sh")
echo "$out" | grep -q "retrofit" && fail "template's own origin -> silent (got: $out)" || pass "template's own origin -> silent"

echo "== check-machinery-gate.sh (seatbelt rule engine) =="
MG="$SANDBOX/machinery-gate"
mkdir -p "$MG/scripts" "$MG/.github/workflows"
git init -q -b main "$MG" 2>/dev/null || git init -q "$MG"
git -C "$MG" config user.email t@t
git -C "$MG" config user.name t
cp "$ROOT/scripts/check-machinery-gate.sh" "$MG/scripts/check-machinery-gate.sh"
cp "$ROOT/scripts/effect-policy.mjs" "$ROOT/scripts/effect-policy-cli.mjs" "$ROOT/scripts/effect-policy-read.mjs" "$ROOT/scripts/policy-approval.mjs" "$MG/scripts/"
printf 'pass "alpha holds"\nfail "alpha holds"\npass "beta holds"\nfail "beta holds"\n' > "$MG/scripts/test-hooks.sh"
printf 'name: ci\n' > "$MG/.github/workflows/ci.yml"
printf 'echo hi\n' > "$MG/scripts/helper.sh"
printf 'a doc\n' > "$MG/README.md"
git -C "$MG" add -A >/dev/null && git -C "$MG" commit -qm base
BASE_SHA=$(git -C "$MG" rev-parse HEAD)

mg_run() { ( cd "$MG" && ./scripts/check-machinery-gate.sh "$BASE_SHA" 2>&1 ); }
mg_reset() { git -C "$MG" checkout -q . && git -C "$MG" clean -qfd; }

# 1. untouched machinery -> clean
printf 'a doc, edited\n' > "$MG/README.md"
git -C "$MG" add -A >/dev/null && git -C "$MG" commit -qm docs-only
out=$(mg_run); rc=$?
[ "$rc" -eq 0 ] && pass "machinery gate: no machinery touched -> exit 0" || fail "machinery gate: no machinery touched -> exit 0 (rc=$rc, out=$out)"

# 2. additive fixture change -> allowed (the case the old any-touch rule failed)
printf 'pass "alpha holds"\nfail "alpha holds"\npass "beta holds"\nfail "beta holds"\npass "gamma holds"\nfail "gamma holds"\n' > "$MG/scripts/test-hooks.sh"
git -C "$MG" add -A >/dev/null && git -C "$MG" commit -qm additive
out=$(mg_run); rc=$?
[ "$rc" -eq 1 ] && pass "machinery gate: executable assertion additions require effect review" || fail "machinery gate: executable assertion additions must hold (rc=$rc, out=$out)"
echo "$out" | grep -q "unclassified-machinery-change" && pass "machinery gate: unclassified effect is named in the output" || fail "machinery gate: unclassified effect is named in the output (got: $out)"

# 3. assertion removed -> blocked
printf 'pass "alpha holds"\nfail "alpha holds"\n' > "$MG/scripts/test-hooks.sh"
git -C "$MG" add -A >/dev/null && git -C "$MG" commit -qm weaken
out=$(mg_run); rc=$?
[ "$rc" -eq 1 ] && pass "machinery gate: assertion removed -> exit 1" || fail "machinery gate: assertion removed -> exit 1 (rc=$rc, out=$out)"
echo "$out" | grep -q 'unclassified-machinery-change' && pass "machinery gate: names the unclassified executable effect" || fail "machinery gate: names the unclassified executable effect (got: $out)"

# 4. workflow modified -> blocked even with no assertion loss
git -C "$MG" reset -q --hard "$BASE_SHA"
printf 'name: ci\non: push\n' > "$MG/.github/workflows/ci.yml"
git -C "$MG" add -A >/dev/null && git -C "$MG" commit -qm workflow
out=$(mg_run); rc=$?
[ "$rc" -eq 1 ] && pass "machinery gate: workflow modified -> exit 1" || fail "machinery gate: workflow modified -> exit 1 (rc=$rc, out=$out)"

# 5. fixture script deleted outright -> blocked
git -C "$MG" reset -q --hard "$BASE_SHA"
git -C "$MG" rm -q "scripts/helper.sh" && git -C "$MG" commit -qm delete-helper
out=$(mg_run); rc=$?
[ "$rc" -eq 1 ] && pass "machinery gate: fixture script deleted -> exit 1" || fail "machinery gate: fixture script deleted -> exit 1 (rc=$rc, out=$out)"
git -C "$MG" reset -q --hard "$BASE_SHA"

echo "== question.yml v1 protocol (additive v1.1 fields, docs/ATTENTION.md) =="
Q="$ROOT/.github/ISSUE_TEMPLATE/question.yml"
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
  echo "  skip: python3+pyyaml unavailable — question.yml field-order checks skipped"
else
  Q_LABELS=$(python3 - "$Q" <<'PYEOF'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
for field in doc["body"]:
    label = field.get("attributes", {}).get("label")
    if label:
        print(label)
PYEOF
)
  if [ -z "$Q_LABELS" ]; then
    fail "question.yml parses as YAML with a body of labeled fields"
  else
    pass "question.yml parses as YAML with a body of labeled fields"
  fi
  EXPECTED_V1=$'Decision\nRecommended choice\nWhy\nIf you do nothing\nReversible?\nNeeded by\nBlocks'
  EXPECTED_FULL=$'In plain words\nOptions\nDecision\nRecommended choice\nWhy\nIf you do nothing\nReversible?\nNeeded by\nBlocks\nParent goal\nGates signal\nKind'
  if [ "$Q_LABELS" = "$EXPECTED_FULL" ]; then
    pass "question.yml labels, in order: In plain words, Options, then the 7 v1 headings, then Parent goal, Gates signal, Kind"
  else
    fail "question.yml label order != In plain words + Options + v1 + Parent goal/Gates signal/Kind (got: $(echo "$Q_LABELS" | tr '\n' '|'))"
  fi
  Q_SECOND=$(echo "$Q_LABELS" | sed -n 2p)
  if [ "$Q_SECOND" = "Options" ]; then
    pass "question.yml renders Options second, before Decision (the card's buttons are the second thing filed)"
  else
    fail "question.yml second label != Options (got: $Q_SECOND)"
  fi
  # `In plain words` and `Options` are v1.1 additions — the original 7 must
  # still appear, unrenamed, in their original relative order. They are no
  # longer required to be first: the two lines a card needs (headline and
  # buttons) are filed ahead of them, and parsers key on heading text.
  V1_SUBSEQ=$(printf '%s\n' "$Q_LABELS" | grep -xF -f <(printf '%s\n' "$EXPECTED_V1"))
  if [ "$V1_SUBSEQ" = "$EXPECTED_V1" ]; then
    pass "question.yml still carries the 7 v1 headings, unrenamed, in original relative order"
  else
    fail "question.yml v1 headings missing or reordered (got: $(echo "$V1_SUBSEQ" | tr '\n' '|'))"
  fi
  Q_FIRST=$(echo "$Q_LABELS" | head -1)
  if [ "$Q_FIRST" = "In plain words" ]; then
    pass "question.yml renders In plain words first"
  else
    fail "question.yml first label != In plain words (got: $Q_FIRST)"
  fi

  # A sample v1 body carrying only the seven original headings (no v1.1
  # fields at all) must still read as valid v1 — the new fields are
  # additive, not required, and their absence must not break an old body.
  V1_ONLY_BODY=$'### Decision\nShould X or Y own Z?\n\n### Recommended choice\nX, because reasons.\n\n### Why\nBecause reasons.\n\n### If you do nothing\nZ stays unowned.\n\n### Reversible?\nyes\n\n### Needed by\n2026-09-01\n\n### Blocks\n#45'
  v1_body_ok=1
  while IFS= read -r heading; do
    case "$V1_ONLY_BODY" in
      *"### $heading"*) ;;
      *) v1_body_ok=0 ;;
    esac
  done <<< "$EXPECTED_V1"
  if [ "$v1_body_ok" -eq 1 ]; then
    pass "a v1 body without the 3 new headings still contains all 7 required headings"
  else
    fail "a v1 body without the 3 new headings is missing one of the 7 required headings"
  fi

  for tf in task.yml inbox.yml; do
    T_FIRST=$(python3 - "$ROOT/.github/ISSUE_TEMPLATE/$tf" <<'PYEOF'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
labels = [f.get("attributes", {}).get("label") for f in doc["body"] if f.get("attributes", {}).get("label")]
print(labels[0] if labels else "")
PYEOF
)
    if [ "$T_FIRST" = "In plain words" ]; then
      pass "$tf renders In plain words first"
    else
      fail "$tf first label != In plain words (got: $T_FIRST)"
    fi
  done

  # task.yml's v1.1 additions: an optional Parent goal (the Goal graph join)
  # and the `#### Pass` spelling in the Human check placeholder.
  T_LABELS=$(python3 - "$ROOT/.github/ISSUE_TEMPLATE/task.yml" <<'PYEOF'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
for field in doc["body"]:
    label = field.get("attributes", {}).get("label")
    if label:
        print(label)
PYEOF
)
  if printf '%s\n' "$T_LABELS" | grep -qx "Parent goal"; then
    pass "task.yml carries the optional Parent goal field"
  else
    fail "task.yml is missing the Parent goal field (got: $(echo "$T_LABELS" | tr '\n' '|'))"
  fi
  if grep -qE '^[[:space:]]*#### Pass[[:space:]]*$' "$ROOT/.github/ISSUE_TEMPLATE/task.yml"; then
    pass "task.yml Human check placeholder uses the #### Pass heading"
  else
    fail "task.yml Human check placeholder does not use '#### Pass'"
  fi
fi

echo "== ready-drafts.sh (stubbed gh: a green, unheld, quiet draft is marked ready; everything else holds) =="
# The ready step reads its allowlist from an engine's config block, so the
# fixture ships its own block — the assertions must not drift with this repo's
# real ELIGIBLE_PREFIXES. Every gh shape the script asks for has a case; the
# mutating verbs record a count so idempotence and --dry-run are provable.
RD="$SANDBOX/ready-drafts"; mkdir -p "$RD/bin"
cat > "$RD/engine.sh" <<'EOF'
# janus:merge-config:start
MERGE_METHOD="merge"
ELIGIBLE_PREFIXES="task/ claude/"
FORBIDDEN_PREFIXES="intent/ heartbeat/"
# janus:merge-config:end
EOF
cat > "$RD/bin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"
pr() { printf '{"number":%s,"headRefName":"%s","baseRefName":"%s","isDraft":%s,"labels":[%s],"mergeable":"%s","headRefOid":"%s","reviews":[],"reviewDecision":""}' "$@"; }
case "$args" in
  *"repo view --json defaultBranchRef"*) echo '{"defaultBranchRef":{"name":"main"}}' ;;
  *"pr list --state open"*)
    if [ -n "${RD_LIST_FAILS:-}" ]; then echo "stub: list refused" >&2; exit 1; fi
    printf '[%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s]\n' \
      "$(pr 600 task/fix-y main true '' MERGEABLE old600)" \
      "$(pr 601 codex/x main true '' MERGEABLE old601)" \
      "$(pr 602 task/stacked task/fix-y true '' MERGEABLE old602)" \
      "$(pr 603 task/held main true '' MERGEABLE old603)" \
      "$(pr 604 task/young main true '' MERGEABLE young604)" \
      "$(pr 605 task/red main true '' MERGEABLE old605)" \
      "$(pr 606 task/blind main true '' MERGEABLE old606)" \
      "$(pr 607 task/asked main true '{"name":"question:"}' MERGEABLE old607)" \
      "$(pr 608 task/conflict main true '' CONFLICTING old608)" \
      "$(pr 609 intent/phase main true '' MERGEABLE old609)" \
      "$(pr 610 task/shipped main false '' MERGEABLE old610)" \
      "$(pr 611 task/acted main true '' MERGEABLE old611)" ;;
  *"issues/603/comments"*) echo '[{"body":"<!-- janus:ask:v1 -->\nAsk: Merge or send it back"}]' ;;
  *"issues/611/comments"*) echo '[{"body":"<!-- janus:ready-drafts:v1 -->\nAction: marked-ready\nHead: old611"}]' ;;
  *"issues/"*"/comments"*) echo '[]' ;;
  *"commits/young604"*) printf '{"commit":{"committer":{"date":"%s"}}}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" ;;
  *"commits/"*) echo '{"commit":{"committer":{"date":"2020-01-01T00:00:00Z"}}}' ;;
  *"pr checks 605"*) printf 'ci\tfail\t1m\thttps://example.invalid\n' ;;
  *"pr checks 606"*) : ;;
  *"pr checks"*) printf 'ci\tpass\t1m\thttps://example.invalid\n' ;;
  *"pr ready"*) if [ -n "${RD_MUST_NOT_WRITE:-}" ]; then echo "MUST NOT BE CALLED: $args" >&2; exit 1; fi; echo "$args" >> "$RD_LOG"; exit 0 ;;
  *"pr comment"*) if [ -n "${RD_MUST_NOT_WRITE:-}" ]; then echo "MUST NOT BE CALLED: $args" >&2; exit 1; fi; echo "$args" >> "$RD_LOG"; exit 0 ;;
  *) echo "stub: unexpected gh $args" >&2; exit 1 ;;
esac
EOF
chmod +x "$RD/bin/gh"
: > "$RD/log"
out=$(GITHUB_REPOSITORY=example/rd READY_DRAFTS_ENGINE="$RD/engine.sh" RD_LOG="$RD/log" PATH="$RD/bin:$PATH" bash "$ROOT/scripts/ready-drafts.sh"); rc=$?
[ "$rc" -eq 0 ] && pass "ready-drafts: complete pass exits 0" || fail "ready-drafts: complete pass exits 0 (got $rc: $out)"
echo "$out" | grep -qF "$(printf '600\tready\tmarked ready for review (head old600)')" && pass "ready-drafts: green, quiet, unheld eligible draft is marked ready" || fail "ready-drafts: green draft marked ready (got: $out)"
grep -q "^pr ready 600$" "$RD/log" && pass "ready-drafts: gh pr ready was called for the flipped PR" || fail "ready-drafts: gh pr ready called (log: $(cat "$RD/log"))"
grep -q "^pr comment 600 --body <!-- janus:ready-drafts:v1 -->" "$RD/log" && pass "ready-drafts: the flip leaves a lifecycle comment carrying the marker" || fail "ready-drafts: lifecycle comment posted (log: $(cat "$RD/log"))"
[ "$(grep -c '^pr ready' "$RD/log")" -eq 1 ] && pass "ready-drafts: exactly one PR was flipped" || fail "ready-drafts: exactly one PR flipped (log: $(cat "$RD/log"))"
echo "$out" | grep -qF "$(printf '601\tskip\tunknown head prefix (codex/x)')" && pass "ready-drafts: a prefix outside the engine's allowlist is never touched" || fail "ready-drafts: unknown prefix skipped (got: $out)"
echo "$out" | grep -qF "$(printf '602\tskip\tbase is task/fix-y, not main')" && pass "ready-drafts: a stacked PR (base != default branch) is skipped" || fail "ready-drafts: stacked PR skipped (got: $out)"
echo "$out" | grep -qF "$(printf '603\tskip\tdraft is held by a recorded ask (janus:ask:v1)')" && pass "ready-drafts: a draft carrying a recorded ask stays the operator's" || fail "ready-drafts: recorded ask holds (got: $out)"
echo "$out" | grep -qE "$(printf '604\tskip\thead is 0h old, younger than the 2h quiet window')" && pass "ready-drafts: a head inside the quiet window is left alone" || fail "ready-drafts: quiet window holds (got: $out)"
echo "$out" | grep -qF "$(printf '605\tskip\tchecks not all green (1 failing: ci)')" && pass "ready-drafts: a red check holds" || fail "ready-drafts: red check holds (got: $out)"
echo "$out" | grep -qF "$(printf '606\tskip\tchecks not all green (no checks visible to this token')" && pass "ready-drafts: unreadable checks hold — unknown is not permission" || fail "ready-drafts: unreadable checks hold (got: $out)"
echo "$out" | grep -qF "$(printf '607\tskip\tPR carries gating label question:')" && pass "ready-drafts: a gating label holds" || fail "ready-drafts: gating label holds (got: $out)"
echo "$out" | grep -qF "$(printf '608\tskip\tbranch conflicting with main')" && pass "ready-drafts: a conflicting branch holds" || fail "ready-drafts: conflicting holds (got: $out)"
echo "$out" | grep -qF "$(printf '609\tskip\tIntent/heartbeat-tier head prefix (intent/phase)')" && pass "ready-drafts: a forbidden prefix holds" || fail "ready-drafts: forbidden prefix holds (got: $out)"
echo "$out" | grep -qF "$(printf '610\tskip\tnot a draft')" && pass "ready-drafts: a non-draft is reported, not touched" || fail "ready-drafts: non-draft reported (got: $out)"
echo "$out" | grep -qF "$(printf '611\tskip\talready marked ready for head old611')" && pass "ready-drafts: once per head SHA — an acted head is a no-op" || fail "ready-drafts: idempotent per head (got: $out)"
: > "$RD/log"
out=$(GITHUB_REPOSITORY=example/rd READY_DRAFTS_ENGINE="$RD/engine.sh" RD_LOG="$RD/log" RD_MUST_NOT_WRITE=1 PATH="$RD/bin:$PATH" bash "$ROOT/scripts/ready-drafts.sh" --dry-run); rc=$?
[ "$rc" -eq 0 ] && echo "$out" | grep -qF "$(printf '600\tready\twould mark ready for review (head old600)')" && pass "ready-drafts: --dry-run previews the flip" || fail "ready-drafts: --dry-run previews the flip (rc $rc, got: $out)"
[ ! -s "$RD/log" ] && pass "ready-drafts: --dry-run calls neither pr ready nor pr comment" || fail "ready-drafts: --dry-run mutated (log: $(cat "$RD/log"))"
out=$(GITHUB_REPOSITORY=example/rd READY_DRAFTS_ENGINE="$RD/engine.sh" RD_LOG="$RD/log" RD_LIST_FAILS=1 PATH="$RD/bin:$PATH" bash "$ROOT/scripts/ready-drafts.sh"); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -qF "HOLD: could not list open PRs" && pass "ready-drafts: an unreadable PR list is a red run, never 'nothing to do'" || fail "ready-drafts: unreadable PR list -> exit 1 with reason (rc $rc, got: $out)"
out=$(GITHUB_REPOSITORY=example/rd READY_DRAFTS_ENGINE="$RD/no-such-engine.sh" PATH="$RD/bin:$PATH" bash "$ROOT/scripts/ready-drafts.sh" 2>&1); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -qF "nothing to be eligible for" && pass "ready-drafts: no engine, no allowlist, no flip" || fail "ready-drafts: missing engine refuses (rc $rc, got: $out)"
grep -q 'ready-drafts.sh' "$ROOT/.github/workflows/auto-merge.yml" && pass "auto-merge.yml runs the ready step" || fail "auto-merge.yml must run scripts/ready-drafts.sh before the engine"
awk '/ready-drafts.sh/{r=NR} /run: \.\/scripts\/auto-merge.sh$/{m=NR} END{exit !(r && m && r < m)}' "$ROOT/.github/workflows/auto-merge.yml" && pass "auto-merge.yml runs the ready step BEFORE the merge pass" || fail "auto-merge.yml: the ready step must precede the armed merge pass"

echo
if [ "$FAILS" -eq 0 ]; then
  echo "ALL SCAFFOLD TESTS PASSED"
  exit 0
else
  echo "$FAILS TEST(S) FAILED" >&2
  exit 1
fi
