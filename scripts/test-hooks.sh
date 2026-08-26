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
           docs/ATTENTION.md \
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

echo "== ledger and decision ids are unique (append-only union-merge guard) =="
# .gitattributes union-merges these files so parallel branches stop
# conflicting on them; the trade is that two branches can both land an entry
# under the same id. That must fail loudly here rather than merge silently.
dupe_ids() { grep -oE "^## $2[A-Za-z0-9-]+" "$1" 2>/dev/null | sort | uniq -d; }
d=$(dupe_ids "$ROOT/docs/DECISIONS.md" "DL-")
[ -z "$d" ] && pass "docs/DECISIONS.md has no duplicate lock id" || fail "docs/DECISIONS.md has duplicate lock id(s): $d"
d=$(grep -oE '^## L-[0-9]+' "$ROOT/.claude/memory/LEARNINGS.md" 2>/dev/null | sort | uniq -d)
[ -z "$d" ] && pass "LEARNINGS.md has no duplicate learning id" || fail "LEARNINGS.md has duplicate learning id(s): $d"
# Red-first proof the check can actually fail: a fixture file with a known dupe.
printf '## DL-2026-01-01-a · x\n## DL-2026-01-01-a · y\n' > "$SANDBOX/dupe-fixture.md"
d=$(dupe_ids "$SANDBOX/dupe-fixture.md" "DL-")
[ -n "$d" ] && pass "duplicate-id check detects a planted duplicate" || fail "duplicate-id check detects a planted duplicate"

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
[ "$rc" -eq 0 ] && pass "machinery gate: assertion added -> exit 0" || fail "machinery gate: assertion added -> exit 0 (rc=$rc, out=$out)"
echo "$out" | grep -q "additive change, allowed" && pass "machinery gate: additive change is named in the output" || fail "machinery gate: additive change is named in the output (got: $out)"

# 3. assertion removed -> blocked
printf 'pass "alpha holds"\nfail "alpha holds"\n' > "$MG/scripts/test-hooks.sh"
git -C "$MG" add -A >/dev/null && git -C "$MG" commit -qm weaken
out=$(mg_run); rc=$?
[ "$rc" -eq 1 ] && pass "machinery gate: assertion removed -> exit 1" || fail "machinery gate: assertion removed -> exit 1 (rc=$rc, out=$out)"
echo "$out" | grep -q 'assertion removed.*beta holds' && pass "machinery gate: names the removed assertion" || fail "machinery gate: names the removed assertion (got: $out)"

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
  EXPECTED_FULL=$'Decision\nRecommended choice\nWhy\nIf you do nothing\nReversible?\nNeeded by\nBlocks\nParent goal\nGates signal\nKind'
  if [ "$Q_LABELS" = "$EXPECTED_FULL" ]; then
    pass "question.yml labels, in order: the 7 v1 headings then Parent goal, Gates signal, Kind"
  else
    fail "question.yml label order != 7 v1 headings followed by Parent goal, Gates signal, Kind (got: $(echo "$Q_LABELS" | tr '\n' '|'))"
  fi
  Q_LABELS_HEAD7=$(echo "$Q_LABELS" | head -7)
  if [ "$Q_LABELS_HEAD7" = "$EXPECTED_V1" ]; then
    pass "question.yml first 7 labels start with the v1 machine interface, unrenamed"
  else
    fail "question.yml first 7 labels != v1 machine interface (got: $(echo "$Q_LABELS_HEAD7" | tr '\n' '|'))"
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
fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "ALL SCAFFOLD TESTS PASSED"
  exit 0
else
  echo "$FAILS TEST(S) FAILED" >&2
  exit 1
fi
