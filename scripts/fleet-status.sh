#!/usr/bin/env bash
# Fleet-status engine, run by .github/workflows/fleet-status.yml on a
# schedule (and by hand). Four jobs:
#   1. ensure the label vocabulary exists (idempotent)
#   2. aging ladder: open `question:` issues and open claude/* PRs quiet
#      >3 days get `aging`, >7 days `overdue`; a reply from the repo owner
#      clears both (responsibility transferred back). NEVER closes anything.
#   3. branch-without-PR detector (L-047): a claude/* head >24h old with no
#      open PR is a red finding — "pushed" is not "delivered".
#   4. rewrite the ONE "Status dashboard" issue body in place (never append).
# Exits nonzero iff red findings exist, so the run itself becomes a visible
# failing check.
#
# --dry-run: gather and print the dashboard body, mutate nothing —
# test-hooks.sh smokes this with a stubbed gh on PATH.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

command -v gh >/dev/null 2>&1 || { echo "fleet-status: gh not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "fleet-status: jq not found" >&2; exit 1; }

# Every gather degrades to an empty result rather than crashing the whole
# dashboard — a partial dashboard beats no dashboard.
ghj() { gh "$@" 2>/dev/null || echo '[]'; }

OWNER="${GITHUB_REPOSITORY_OWNER:-}"
[ -n "$OWNER" ] || OWNER=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || true)
[ -n "$OWNER" ] || OWNER=unknown
REPO="${GITHUB_REPOSITORY:-}"
[ -n "$REPO" ] || REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)

NOW=$(date -u +%s)
iso_epoch() { date -u -d "$1" +%s 2>/dev/null || echo "$NOW"; }
age_days()  { echo $(( (NOW - $(iso_epoch "$1")) / 86400 )); }
age_hours() { echo $(( (NOW - $(iso_epoch "$1")) / 3600 )); }

# --- 1. label vocabulary (idempotent; --force updates color/description) ----
if [ "$DRY" -eq 0 ]; then
  gh label create "task:"     --force --color 1d76db --description "unit of ready work — carries a done-means"        >/dev/null 2>&1 || true
  gh label create "question:" --force --color d93f0b --description "blocked on an operator decision"                 >/dev/null 2>&1 || true
  gh label create "loop:hold" --force --color 5319e7 --description "the work loop must not take this"                >/dev/null 2>&1 || true
  gh label create "aging"     --force --color fbca04 --description ">3 days without a response"                      >/dev/null 2>&1 || true
  gh label create "overdue"   --force --color b60205 --description ">7 days without a response"                      >/dev/null 2>&1 || true
  gh label create "dashboard" --force --color 0e8a16 --description "the regenerated status dashboard issue"          >/dev/null 2>&1 || true
  gh label create "inbox:"    --force --color c5def5 --description "a thought, not a spec — triaged, never consumed" >/dev/null 2>&1 || true
  gh label create "human-check:" --force --color e99695 --description "operator's eyes required before merge"        >/dev/null 2>&1 || true
  gh label create "janus:v1"  --force --color 0052cc --description "Janus Human Attention Protocol v1 (docs/ATTENTION.md)" >/dev/null 2>&1 || true
fi

# --- gather ------------------------------------------------------------------
questions=$(ghj issue list --label "question:" --state open --limit 200 --json number,title,createdAt,updatedAt)
tasks=$(ghj issue list --label "task:" --state open --limit 200 --json number,createdAt,labels)
prs_full=$(ghj pr list --state open --limit 200 --json number,title,body,headRefName)
inboxes=$(ghj issue list --label "inbox:" --state open --limit 200 --json number,title,createdAt)
hchecks=$(ghj issue list --label "human-check:" --state open --limit 200 --json number,title,createdAt)
prs=$(ghj pr list --state open --limit 200 --json number,title,createdAt,updatedAt,headRefName)

# --- 2. aging ladder (issues + claude/* PRs; owner reply clears; never close)
apply_aging() { # kind(issue|pr) number updated_at
  local kind=$1 num=$2 updated=$3 days last
  days=$(age_days "$updated")
  last=$(gh "$kind" view "$num" --json comments 2>/dev/null \
    | jq -r '.comments[-1].author.login // ""' 2>/dev/null || true)
  if [ "$last" = "$OWNER" ]; then
    [ "$DRY" -eq 0 ] && gh "$kind" edit "$num" --remove-label aging --remove-label overdue >/dev/null 2>&1
    return 0
  fi
  if [ "$days" -gt 7 ]; then
    [ "$DRY" -eq 0 ] && gh "$kind" edit "$num" --add-label overdue --add-label aging >/dev/null 2>&1
  elif [ "$days" -gt 3 ]; then
    [ "$DRY" -eq 0 ] && gh "$kind" edit "$num" --add-label aging >/dev/null 2>&1
  fi
  return 0
}
while read -r num updated; do
  [ -n "$num" ] && apply_aging issue "$num" "$updated"
done < <(printf '%s' "$questions" | jq -r '.[] | "\(.number) \(.updatedAt)"' 2>/dev/null)
while read -r num updated; do
  [ -n "$num" ] && apply_aging pr "$num" "$updated"
done < <(printf '%s' "$prs" | jq -r '.[] | select(.headRefName | startswith("claude/")) | "\(.number) \(.updatedAt)"' 2>/dev/null)

# --- 3. red findings: branch-without-PR (L-047) + manifest schema ------------
reds=""
pr_heads=$(printf '%s' "$prs" | jq -r '.[].headRefName' 2>/dev/null)
if [ -n "$REPO" ]; then
  while read -r bname bsha; do
    [ -n "$bname" ] || continue
    printf '%s\n' "$pr_heads" | grep -qxF "$bname" && continue
    cdate=$(ghj api "repos/$REPO/commits/$bsha" | jq -r '.commit.committer.date // empty' 2>/dev/null)
    [ -n "$cdate" ] || continue
    h=$(age_hours "$cdate")
    if [ "$h" -gt 24 ]; then
      reds="${reds}- branch without PR (L-047): \`$bname\` — head ${h}h old, no open PR"$'\n'
    fi
  done < <(ghj api "repos/$REPO/branches?per_page=100" \
    | jq -r '.[] | select(.name | startswith("claude/")) | "\(.name) \(.commit.sha)"' 2>/dev/null)
fi
manifest_out=$("$ROOT/scripts/check-loops.sh" 2>&1) || \
  reds="${reds}- loop manifest failed its schema check: \`scripts/check-loops.sh\` said: ${manifest_out}"$'\n'

# --- 4. dashboard body (rewritten in place, never appended) ------------------
pr_rows=""
while read -r num; do
  [ -n "$num" ] || continue
  title=$(printf '%s' "$prs" | jq -r ".[] | select(.number == $num) | .title")
  created=$(printf '%s' "$prs" | jq -r ".[] | select(.number == $num) | .createdAt")
  checks_out=$(gh pr checks "$num" 2>/dev/null || true)
  if [ -z "$checks_out" ]; then
    checks="unknown"
  else
    nfail=$(printf '%s\n' "$checks_out" | awk -F'\t' '$2 == "fail"' | grep -c . || true)
    npend=$(printf '%s\n' "$checks_out" | awk -F'\t' '$2 == "pending"' | grep -c . || true)
    if [ "${nfail:-0}" -gt 0 ]; then checks="red ($nfail failing)"
    elif [ "${npend:-0}" -gt 0 ]; then checks="pending"
    else checks="green"; fi
  fi
  pr_rows="${pr_rows}| #$num | $title | $(age_days "$created")d | $checks |"$'\n'
done < <(printf '%s' "$prs" | jq -r '.[].number' 2>/dev/null)
[ -n "$pr_rows" ] || pr_rows="_none open_"$'\n'

q_rows=""
while read -r num created; do
  [ -n "$num" ] || continue
  title=$(printf '%s' "$questions" | jq -r ".[] | select(.number == $num) | .title")
  d=$(age_days "$created")
  mark=""; [ "$d" -gt 7 ] && mark=" **overdue**"
  q_rows="${q_rows}- #$num $title — open ${d}d$mark"$'\n'
done < <(printf '%s' "$questions" | jq -r '.[] | "\(.number) \(.createdAt)"' 2>/dev/null)
[ -n "$q_rows" ] || q_rows="_nothing blocked on the operator_"$'\n'

n_tasks=$(printf '%s' "$tasks" | jq 'length' 2>/dev/null || echo 0)
oldest_task="—"
if [ "${n_tasks:-0}" -gt 0 ]; then
  oldest_created=$(printf '%s' "$tasks" | jq -r 'map(.createdAt) | sort | .[0]')
  oldest_task="oldest $(age_days "$oldest_created")d"
fi

# The consumption gate (docs/ATTENTION.md). Two halves, and the second one
# is the one this repo learned the hard way:
#
#   labels  — a `task:` carrying any gating label is not consumable.
#   working — an issue an open PR or a live delivery branch ALREADY
#             references is not consumable either, however clean its labels
#             are. ATTENTION.md has always defined `working` as a state; it
#             was defined and then never computed, so a task another actor
#             had already started still read "ready" to every consumer. Two
#             sessions built this protocol nine seconds apart through that
#             hole (L-057).
#
# Derived from what GitHub already knows: closing keywords in an open PR's
# title/body, and the issue number embedded in a delivery branch name
# (`task/17-...`, `claude/42-...`).
working_nums=$(
  {
    printf '%s' "$prs_full" | jq -r '.[] | ((.body // "") + " " + (.title // ""))' 2>/dev/null \
      | grep -oiE '(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#[0-9]+' \
      | grep -oE '[0-9]+'
    printf '%s' "$prs_full" | jq -r '.[].headRefName' 2>/dev/null \
      | grep -oE '(^|/)[0-9]+-' | grep -oE '[0-9]+'
  } 2>/dev/null | sort -u
)
is_working() { [ -n "$working_nums" ] && printf '%s\n' "$working_nums" | grep -qxF "$1"; }

n_consumable=0
gated_rows=""
while read -r num labels; do
  [ -n "$num" ] || continue
  reason=""
  case " $labels " in
    *" question: "*|*" loop:hold "*|*" inbox: "*|*" human-check: "*)
      reason="labels: $labels" ;;
  esac
  if [ -z "$reason" ] && is_working "$num"; then
    reason="working — an open PR or delivery branch already references it"
  fi
  if [ -n "$reason" ]; then
    gated_rows="${gated_rows}- gated: #$num — $reason"$'\n'
  else
    n_consumable=$(( n_consumable + 1 ))
  fi
done < <(printf '%s' "$tasks" | jq -r '.[] | "\(.number) \([.labels[]?.name] | join(" "))"' 2>/dev/null)

inbox_rows=""
n_inbox=$(printf '%s' "$inboxes" | jq 'length' 2>/dev/null || echo 0)
while read -r num created; do
  [ -n "$num" ] || continue
  title=$(printf '%s' "$inboxes" | jq -r ".[] | select(.number == $num) | .title")
  inbox_rows="${inbox_rows}- #$num $title — captured $(age_days "$created")d ago"$'\n'
done < <(printf '%s' "$inboxes" | jq -r '.[] | "\(.number) \(.createdAt)"' 2>/dev/null)
[ -n "$inbox_rows" ] || inbox_rows="_inbox empty_"$'\n'

hc_rows=""
while read -r num created; do
  [ -n "$num" ] || continue
  title=$(printf '%s' "$hchecks" | jq -r ".[] | select(.number == $num) | .title")
  hc_rows="${hc_rows}- #$num $title — waiting $(age_days "$created")d for your eyes"$'\n'
done < <(printf '%s' "$hchecks" | jq -r '.[] | "\(.number) \(.createdAt)"' 2>/dev/null)
[ -n "$hc_rows" ] || hc_rows="_nothing awaiting your check_"$'\n'

loop_rows=$(awk '
  function emit() {
    if (name == "") return
    state = (enabled == "true") ? "armed" : "**declared, not armed**"
    print "| " name " | `" sched "` | " drv " | " state " |"
  }
  /^  - name:/ { emit(); name=$3; sched=""; drv=""; enabled="" }
  /^    schedule:/ { sched=$0; sub(/^    schedule:[[:space:]]*"/, "", sched); sub(/".*$/, "", sched) }
  /^    driver:/ { drv=$2 }
  /^    enabled:/ { enabled=$2 }
  END { emit() }
' "$ROOT/.github/loops.yaml" 2>/dev/null)
[ -n "$loop_rows" ] || loop_rows="| _no manifest_ | | | |"

[ -n "$reds" ] || reds_body="_none_"
[ -n "$reds" ] && reds_body="$reds"

BODY="## Open PRs

| PR | title | age | checks |
|---|---|---|---|
$pr_rows
## Blocked on operator

$q_rows
## Awaiting your check

$hc_rows
## Backlog

${n_tasks:-0} open \`task:\` issue(s) ($oldest_task).
Consumable now: ${n_consumable} — the gate excludes \`question:\`/\`loop:hold\`/\`inbox:\`/\`human-check:\` (docs/ATTENTION.md).
$gated_rows

## Inbox

${n_inbox:-0} captured thought(s) — informational, never urgent; the work loop's idle arm triages.

$inbox_rows
## Loops

Declared in \`.github/loops.yaml\` (detect-only — this table reports, it never arms):

| loop | schedule | driver | state |
|---|---|---|---|
$loop_rows

## Red findings

$reds_body

---
_Last updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ") — this body is regenerated in place on every run; checkboxes and comments here are the operator's control surface._

🤖 Generated with [Claude Code](https://claude.com/claude-code)"

if [ "$DRY" -eq 1 ]; then
  printf '%s\n' "$BODY"
else
  num=$(ghj issue list --label dashboard --state open --limit 1 --json number | jq -r '.[0].number // empty' 2>/dev/null)
  if [ -n "$num" ]; then
    printf '%s' "$BODY" | gh issue edit "$num" --body-file - >/dev/null
  else
    printf '%s' "$BODY" | gh issue create --title "Status dashboard" --label dashboard --body-file - >/dev/null
  fi
fi

if [ -n "$reds" ]; then
  { echo "fleet-status: RED findings:"; printf '%s' "$reds"; } >&2
  exit 1
fi
echo "fleet-status: ok"
exit 0
