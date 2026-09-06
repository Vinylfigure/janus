#!/usr/bin/env bash
# The recorded-ask check (docs/ATTENTION.md, "The recorded ask").
#
# When a session parks work for the operator it records the ask as a fact, not
# as prose: a `janus:ask:v1` comment whose fields a surface reads without
# inference. This script is the gate the emitting skill runs BEFORE posting —
# an ask that names an identifier, a file, a permission key, or hedges is not
# posted at all, and the skill stops with the failing line.
#
# Usage: check-ask.sh <comment-body-file>
# Exit:  0 parses · 1 not a valid ask (reason on stdout) · 64 usage
#
# Deliberately grep/awk only, like every other gate here: children run it
# before any stack is bootstrapped, and the emitting skill's tool grant is a
# shell one-liner.
set -uo pipefail

BODY_FILE="${1:-}"
[ -n "$BODY_FILE" ] || { echo "usage: check-ask.sh <comment-body-file>"; exit 64; }
[ -f "$BODY_FILE" ] || { echo "not an ask: body file not found: $BODY_FILE"; exit 1; }

fail() { echo "not an ask: $1"; exit 1; }

# The vocabulary deny-list, applied to Ask / Because / If-nothing. Same intent
# as check-record.sh's jargon list: the operator reads these lines, so the
# machine's own nouns never appear in them. Each entry is <ERE>@@<reason>; the
# scanned text is padded with spaces, so a pattern never needs ^ or $.
DENY_PATTERNS=(
  '#[0-9]+@@names an issue or pull request number'
  '[A-Za-z0-9_-]+/[A-Za-z0-9_-]+\.[A-Za-z0-9]+@@names a file path'
  '\.(sh|mjs|ya?ml)[^A-Za-z0-9]@@names a script or config file'
  '(L-[0-9]|DL-|goal/[0-9])@@names a rule, decision, or goal id'
  '(contents|pull-requests|issues):@@names a permission key'
  '[^A-Za-z](may|might|probably|seems)[^A-Za-z]@@hedges (may / might / probably / seems)'
)

deny_scan() { # deny_scan <field-name> <text>
  local field="$1" text="$2" entry pattern reason
  case "$text" in
    "This PR"*|"This issue"*|"This change"*)
      fail "$field makes the artifact the subject (starts with This PR / This issue / This change): $text" ;;
  esac
  for entry in "${DENY_PATTERNS[@]}"; do
    pattern="${entry%%@@*}"
    reason="${entry##*@@}"
    if printf ' %s \n' "$text" | grep -qE "$pattern"; then
      fail "$field $reason: $text"
    fi
  done
}

# --- shape ---------------------------------------------------------------
first_line=$(grep -vE '^[[:space:]]*$' "$BODY_FILE" | head -1)
[ "$first_line" = '<!-- janus:ask:v1 -->' ] \
  || fail "first line is not the janus:ask:v1 marker (got: $first_line)"

field() { # field <name> — the single-line value of "<name>:"
  sed -nE "s/^[[:space:]]*$1:[[:space:]]*(.*)\$/\1/p" "$BODY_FILE" | head -1
}
present() { grep -qE "^[[:space:]]*$1:" "$BODY_FILE"; }

for required in Ask Because If-nothing Options Supersedes Source-revision; do
  present "$required" || fail "missing required field '$required:'"
done

# --- Ask -----------------------------------------------------------------
ask=$(field Ask)
[ -n "$ask" ] || fail "Ask is empty"
[ "${#ask}" -le 80 ] || fail "Ask is ${#ask} chars, must be <=80"
verb=${ask%% *}
case "$verb" in
  Approve|Answer|Do|Confirm|Close|Merge) ;;
  *) fail "Ask must open with the fixed verb set (Approve · Answer · Do this · Confirm it is done · Close or re-spec · Merge), got '$verb'" ;;
esac
deny_scan "Ask" "$ask"

# --- Because -------------------------------------------------------------
# The fact lines are the "- " bullets between "Because:" and the next field.
because=$(awk '
  /^[[:space:]]*Because:[[:space:]]*$/ { inb = 1; next }
  inb && /^[[:space:]]*[A-Za-z][A-Za-z-]*:/ { exit }
  inb && /^[[:space:]]*-[[:space:]]/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); print; next }
  inb && /^[[:space:]]*$/ { next }
' "$BODY_FILE")
n_because=$(printf '%s\n' "$because" | grep -c .)
{ [ "$n_because" -ge 1 ] && [ "$n_because" -le 3 ]; } \
  || fail "Because needs 1-3 fact lines, each starting '- ' (found $n_because)"
while IFS= read -r factline; do
  [ -n "$factline" ] || continue
  [ "${#factline}" -le 140 ] || fail "Because line is ${#factline} chars, must be <=140: $factline"
  deny_scan "Because" "$factline"
done <<< "$because"

# --- If-nothing ----------------------------------------------------------
ifnothing=$(field If-nothing)
[ -n "$ifnothing" ] || fail "If-nothing is empty"
[ "${#ifnothing}" -le 140 ] || fail "If-nothing is ${#ifnothing} chars, must be <=140"
deny_scan "If-nothing" "$ifnothing"

# --- Options -------------------------------------------------------------
options=$(field Options)
[ -n "$options" ] || fail "Options is empty"
n_options=0
IFS='|' read -r -a option_names <<< "$options"
for name in "${option_names[@]}"; do
  trimmed=$(printf '%s' "$name" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  [ -n "$trimmed" ] || fail "Options has an empty name: $options"
  [ "${#trimmed}" -le 30 ] || fail "Option name is ${#trimmed} chars, must be <=30: $trimmed"
  n_options=$((n_options + 1))
done
{ [ "$n_options" -ge 2 ] && [ "$n_options" -le 4 ]; } \
  || fail "Options needs 2-4 names separated by '|' (found $n_options)"

# --- Supersedes / Source-revision ----------------------------------------
[ -n "$(field Supersedes)" ] || fail "Supersedes is empty (use 'none' when this is the first ask)"
[ -n "$(field Source-revision)" ] || fail "Source-revision is empty"

echo "ask ok: $ask"
exit 0
