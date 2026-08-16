#!/usr/bin/env bash
# Schema check for .github/loops.yaml — the declarative loop manifest.
# Reconciliation is detect-only: this script never creates or deletes an
# automation; it only refuses to let the declaration rot.
#
# Exit codes (Terraform plan's -detailed-exitcode style: distinct codes for
# distinct findings):
#   0  manifest exists and every loop entry is schema-complete
#   1  operational error: manifest missing or unreadable
#   2  schema violation, details on stderr
#
# Deliberately grep/awk only: the schema is ours, children run this before
# any stack is bootstrapped, and the hooks' dependency baseline (POSIX tools
# + bash) is the ceiling here too.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MANIFEST="${1:-$ROOT/.github/loops.yaml}"

if [ ! -r "$MANIFEST" ]; then
  echo "check-loops: manifest missing or unreadable: $MANIFEST" >&2
  exit 1
fi

errors=""
add_err() { errors="${errors}check-loops: schema: $1"$'\n'; }

grep -qE '^loops:[[:space:]]*$' "$MANIFEST" || add_err "no top-level 'loops:' key"

awk_errs=$(awk '
  function val(line,   v) {
    v = line
    sub(/^[[:space:]]*(- )?[A-Za-z_]+:[[:space:]]*/, "", v)
    if (v ~ /^"/) { sub(/^"/, "", v); sub(/".*$/, "", v) }
    else { sub(/[[:space:]]+#.*$/, "", v); sub(/[[:space:]]+$/, "", v) }
    return v
  }
  function id() { return (seen["name"] != "" ? "\047" seen["name"] "\047" : "#" n) }
  function flush(   c, parts) {
    if (!inloop) return
    if (seen["name"] == "")          print "loop entry #" n " has an empty name"
    if (!("schedule" in seen))       print "loop " id() " missing schedule"
    else { c = split(seen["schedule"], parts, /[[:space:]]+/)
           if (c != 5) print "loop " id() " schedule is not a 5-field cron: \047" seen["schedule"] "\047" }
    if (!("driver" in seen))         print "loop " id() " missing driver"
    else if (seen["driver"] !~ /^(routine|github-action|manual)$/)
      print "loop " id() " driver must be routine|github-action|manual, got \047" seen["driver"] "\047"
    if (!("enabled" in seen))        print "loop " id() " missing enabled"
    else if (seen["enabled"] !~ /^(true|false)$/)
      print "loop " id() " enabled must be true|false, got \047" seen["enabled"] "\047"
    if (!("owner" in seen) || seen["owner"] == "")
      print "loop " id() " missing owner"
    if (seen["driver"] == "routine" && (!("skill" in seen) || seen["skill"] == ""))
      print "loop " id() " has driver routine but no skill"
    if (seen["driver"] == "github-action" && (!("workflow" in seen) || seen["workflow"] == ""))
      print "loop " id() " has driver github-action but no workflow"
  }
  /^[[:space:]]*#/ { next }
  /^[[:space:]]*$/ { next }
  /^  - name:/ {
    flush(); inloop = 1; n++
    delete seen
    seen["name"] = val($0)
    if (seen["name"] != "") {
      names[seen["name"]]++
      if (names[seen["name"]] > 1) print "duplicate loop name \047" seen["name"] "\047"
    }
    next
  }
  /^  - / { flush(); inloop = 0; n++; print "loop entry #" n " must start with name:"; next }
  inloop && /^    [A-Za-z_]+:/ {
    key = $0; sub(/^[[:space:]]*/, "", key); sub(/:.*/, "", key)
    seen[key] = val($0)
    next
  }
  END { flush() }
' "$MANIFEST")
if [ -n "$awk_errs" ]; then
  while IFS= read -r e; do [ -n "$e" ] && add_err "$e"; done <<< "$awk_errs"
fi

# Cross-check: a declared github-action workflow file must exist next to the
# manifest — a manifest naming a ghost workflow is exactly the rot this
# check exists to catch.
WFDIR="$(dirname "$MANIFEST")/workflows"
while IFS= read -r wf; do
  [ -n "$wf" ] || continue
  [ -f "$WFDIR/$wf" ] || add_err "workflow '$wf' declared but $WFDIR/$wf does not exist"
done < <(awk '/^    workflow:/ { v = $2; gsub(/"/, "", v); print v }' "$MANIFEST")

if [ -n "$errors" ]; then
  printf '%s' "$errors" >&2
  exit 2
fi

n_loops=$(grep -cE '^  - name:' "$MANIFEST")
if [ "$n_loops" -eq 0 ]; then
  echo "check-loops: schema: manifest declares no loops" >&2
  exit 2
fi
echo "check-loops: ok — $n_loops loop(s) declared"
exit 0
