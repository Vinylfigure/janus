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
# shell one-liner. That includes reading the deny-list — no jq, no python.
set -uo pipefail

BODY_FILE="${1:-}"
[ -n "$BODY_FILE" ] || { echo "usage: check-ask.sh <comment-body-file>"; exit 64; }
[ -f "$BODY_FILE" ] || { echo "not an ask: body file not found: $BODY_FILE"; exit 1; }

fail() { echo "not an ask: $1"; exit 1; }

# --- the deny-list -------------------------------------------------------
# `scripts/deny-list.json` is the fleet's ONE vocabulary list, and this repo is
# where it lives: overlord and overlord-ui vendor the file by content and test
# equality against it (docs/ATTENTION.md). Three lists drifting apart is the
# failure this replaces, so nothing below hard-codes a word — the file is the
# list. It is applied to Ask / Because / If-nothing: the operator reads those
# three lines, so the machine's own nouns never appear in them.
DENY_FILE="${CHECK_ASK_DENY_LIST:-$(dirname "$0")/deny-list.json}"
[ -f "$DENY_FILE" ] || { echo "not an ask: deny-list not found: $DENY_FILE"; exit 1; }

# Flat JSON arrays of strings, one element per line — the shape this repo
# writes and the fixture suite pins against jq. Unescapes \\ and \" and
# nothing else, because nothing else appears in the list.
json_array() { # json_array <key> <file>
  awk -v key="$1" '
    !ing && $0 ~ ("\"" key "\"[ \t]*:[ \t]*\\[") { ing = 1; next }
    ing && /^[ \t]*\]/ { exit }
    ing {
      line = $0
      first = index(line, "\"")
      if (first == 0) next
      line = substr(line, first + 1)
      last = 0
      for (i = length(line); i > 0; i--) if (substr(line, i, 1) == "\"") { last = i; break }
      if (last == 0) next
      value = substr(line, 1, last - 1)
      gsub(/\\"/, "\"", value)
      gsub(/\\\\/, "\\", value)
      print value
    }' "$2"
}

read_list() { # read_list <array-name> <key> — bash 3.2 ships no mapfile
  local line
  eval "$1=()"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    eval "$1+=(\"\$line\")"
  done < <(json_array "$2" "$DENY_FILE")
}

read_list DENY_IDENTIFIERS identifiers
read_list DENY_MACHINE_WORDS machine_words
read_list DENY_HEDGES hedges
read_list DENY_ARTIFACT_SUBJECTS artifact_subjects
{ [ "${#DENY_IDENTIFIERS[@]}" -gt 0 ] && [ "${#DENY_MACHINE_WORDS[@]}" -gt 0 ] \
  && [ "${#DENY_HEDGES[@]}" -gt 0 ] && [ "${#DENY_ARTIFACT_SUBJECTS[@]}" -gt 0 ]; } \
  || { echo "not an ask: deny-list is missing a category: $DENY_FILE"; exit 1; }

# Word lists become one alternation each, matched case-insensitively against
# space-padded text, so neither pattern needs ^ or $ and both are
# word-boundaried by construction.
join_alternation() { local IFS='|'; printf '%s' "$*"; }
MACHINE_WORDS_RE="[^A-Za-z0-9]($(join_alternation "${DENY_MACHINE_WORDS[@]}"))[^A-Za-z0-9]"
HEDGES_RE="[^A-Za-z0-9]($(join_alternation "${DENY_HEDGES[@]}"))[^A-Za-z0-9]"

deny_scan() { # deny_scan <field-name> <text>
  local field="$1" text="$2" pattern subject padded
  padded=$(printf ' %s ' "$text")
  for subject in "${DENY_ARTIFACT_SUBJECTS[@]}"; do
    case "$text" in
      "$subject"*) fail "$field makes the artifact the subject (opens with \"$subject\"): $text" ;;
    esac
  done
  for pattern in "${DENY_IDENTIFIERS[@]}"; do
    if printf '%s\n' "$padded" | grep -qE "$pattern"; then
      fail "$field names an identifier the operator does not use (matched /$pattern/): $text"
    fi
  done
  if printf '%s\n' "$padded" | grep -qiE "$MACHINE_WORDS_RE"; then
    fail "$field uses a machine word from the deny-list: $text"
  fi
  if printf '%s\n' "$padded" | grep -qiE "$HEDGES_RE"; then
    fail "$field hedges — a fact stated is a fact checked: $text"
  fi
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
# The fixed set is six PHRASES, not six first words. Matching only the first
# token let "Close it immediately without review" and "Confirm the sky is blue"
# through — a legal opening word with an arbitrary tail, which is exactly the
# free prose the marker exists to end. The multi-word verbs must appear
# verbatim; the single-word ones may carry the rest of the sentence.
case "$ask" in
  "Approve "*|"Answer "*|"Do this"*|"Confirm it is done"*|"Close or re-spec"*|"Merge"*) ;;
  *) fail "Ask must open with a phrase from the fixed verb set (Approve … · Answer … · Do this … · Confirm it is done … · Close or re-spec … · Merge …), got: $ask" ;;
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
