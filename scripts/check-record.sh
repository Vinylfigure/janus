#!/usr/bin/env bash
# In-plain-words filing check (protocol addition, docs/ATTENTION.md). A
# question:/task: body must open with a human-readable "### In plain words"
# line: the operator's control surface renders it as the card headline, so a
# record filed without one shows muted, "not yet in plain words". A question
# additionally needs "### Options" (2-4 named answers) so its buttons are
# real choices, not the literal "Accept the recommendation".
#
# Usage: check-record.sh <body-file> [--ready-for-review]
# Exit: 0 compliant · 1 not compliant (reason on stdout) · 64 usage
#
# Kind is inferred, never a second argument: a body carrying a
# "### Recommended choice" heading (the question.yml field) is a question
# and must also carry Options; any other body is checked for the plain line
# only.
#
# The caps are NOT typed here. `scripts/card-grammar.json` is the fleet's one
# file of them, and this check reads it: one cap for every record's plain
# line 1 — 80 characters, 12 words, one sentence — shared with check-ask.sh,
# with overlord's check-goal/check-intent, and with overlord-ui's renderer.
# A number typed in four places is four numbers eventually (L-007), so the
# number lives in the file and every consumer vendors the file by content.
set -uo pipefail

BODY_FILE="${1:?usage: check-record.sh <body-file> [--ready-for-review]}"
MODE="${2:-filing}"
case "$MODE" in filing|--ready-for-review) ;; *) echo "unknown check mode: $MODE"; exit 64 ;; esac
[ -f "$BODY_FILE" ] || { echo "not compliant: body file not found: $BODY_FILE"; exit 1; }

# Declared writing actions stay human-owned; never infer their target from a parent.
response_kind=$(python3 "$(dirname "$0")/human-response.py" "$BODY_FILE" ${MODE/filing/}) || { echo "$response_kind"; exit 1; }

# section <heading> <file> — lines under the first ### heading matching
# <heading>. The heading form (`### In plain words`) is the only form this
# repo's templates and skills EMIT. The bold form (`**In plain words:** …`,
# with the sentence on the same line) is still READ, because records filed
# before the two forms were reconciled carry it and a body already on the
# record cannot be rewritten. A bold section ends at the next heading of
# either form; a `###` section ends at the next `###`, exactly as before.
section() {
  awk -v h="$1" '
    function norm(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); sub(/:$/, "", s); return tolower(s) }
    /^#+[ \t]*/ {
      line = $0; sub(/^#+[ \t]*/, "", line)
      if (found) exit
      if (norm(line) == norm(h)) { found = 1 }
      next }
    /^[ \t]*\*\*[^*]+\*\*/ {
      if (found && bold) exit
      if (!found) {
        label = $0; sub(/^[ \t]*\*\*/, "", label); sub(/\*\*.*$/, "", label)
        if (norm(label) == norm(h)) {
          found = 1; bold = 1
          rest = $0; sub(/^[ \t]*\*\*[^*]+\*\*[ \t]*/, "", rest)
          if (rest != "") print rest
        }
        next
      } }
    found { print }' "$2"
}

DENY='fixtures?|reconcil[a-z]*|canonical|machine-decidable|decidable|protocol v[0-9]|schema|drift(ed)?|marker|orphan|sha256|\<P[0-9][a-z]?\>|\<R[0-9]+\>|\<L-?[0-9]{3,}\>|DL-|goal/[0-9]+|Drone'

# --- the caps, read from the one file --------------------------------------
# Grep/awk only, like every other gate here: a child runs this before any
# stack is bootstrapped, so no jq and no python for the caps.
GRAMMAR_FILE="${CARD_GRAMMAR:-$(dirname "$0")/card-grammar.json}"
[ -f "$GRAMMAR_FILE" ] || { echo "not compliant: card grammar not found: $GRAMMAR_FILE"; exit 1; }

json_number() { # json_number <key> <file> — the integer value of "<key>": N
  awk -v key="$1" '
    match($0, "\"" key "\"[ \t]*:[ \t]*-?[0-9]+") {
      piece = substr($0, RSTART, RLENGTH)
      sub(/^[^:]*:[ \t]*/, "", piece)
      print piece
      exit
    }' "$2"
}

HEADLINE_CHARS=$(json_number headlineChars "$GRAMMAR_FILE")
HEADLINE_WORDS=$(json_number headlineWords "$GRAMMAR_FILE")
if [ "$response_kind" = write-outcome ]; then
  HEADLINE_CHARS=$(json_number requestHeadlineChars "$GRAMMAR_FILE")
  HEADLINE_WORDS=$(json_number requestHeadlineWords "$GRAMMAR_FILE")
fi
for cap_name in HEADLINE_CHARS HEADLINE_WORDS; do
  eval "cap_value=\$$cap_name"
  case "$cap_value" in
    ''|*[!0-9]*) echo "not compliant: card grammar has no usable $cap_name: $GRAMMAR_FILE"; exit 1 ;;
  esac
done

# Line 1 is the headline; the caps apply to IT, never to the section joined
# into one string. The old join capped a two-line section at 160 characters
# and let a 150-character first line through — the very line a card clips.
plain_body=$(section "In plain words" "$BODY_FILE" | sed '/^[[:space:]]*$/d')
plain=$(printf '%s\n' "$plain_body" | head -1 | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
plain_all=$(printf '%s\n' "$plain_body" | tr '\n' ' ' | sed -E 's/ +/ /g; s/^ //; s/ $//')
[ -n "$plain" ] || { echo "not compliant: missing '### In plain words' line"; exit 1; }
[ "${#plain}" -le "$HEADLINE_CHARS" ] || { echo "not compliant: In plain words line 1 is ${#plain} chars, must be <=$HEADLINE_CHARS"; exit 1; }
plain_words=$(printf '%s\n' "$plain" | wc -w | tr -d ' ')
[ "$plain_words" -le "$HEADLINE_WORDS" ] || { echo "not compliant: In plain words line 1 is $plain_words words, must be <=$HEADLINE_WORDS"; exit 1; }
# One sentence: at most one terminator, and it ends the line. Two sentences
# on line 1 means the card shows half a thought and drops the rest.
terminators=$(printf '%s' "$plain" | tr -cd '.?!' | wc -c | tr -d ' ')
last_char=$(printf '%s' "$plain" | tail -c 1)
if [ "$terminators" -gt 1 ]; then
  echo "not compliant: In plain words line 1 is more than one sentence: $plain"; exit 1
fi
if [ "$terminators" -eq 1 ]; then
  case "$last_char" in
    .|\?|\!) ;;
    *) echo "not compliant: In plain words line 1 is more than one sentence: $plain"; exit 1 ;;
  esac
fi
case "$plain_all" in *'`'*) echo "not compliant: In plain words contains backticks"; exit 1 ;; esac
echo "$plain_all" | grep -qiE "$DENY" && { echo "not compliant: In plain words uses protocol/jargon wording: $plain_all"; exit 1; }

if grep -qE '^#+[[:space:]]*Recommended choice' "$BODY_FILE"; then
  # A question's plain line is the question itself, asked: it ends in a
  # question mark, so a surface renders it as a question rather than as a
  # statement the operator is asked to agree with.
  [ "$last_char" = '?' ] \
    || { echo "not compliant: a question's In plain words line must end with '?': $plain"; exit 1; }
  opts=$(section "Options" "$BODY_FILE" | sed '/^[[:space:]]*$/d')
  n=$(printf '%s\n' "$opts" | grep -c .)
  { [ -n "$opts" ] && [ "$n" -ge 2 ] && [ "$n" -le 4 ]; } \
    || { echo "not compliant: question needs '### Options' with 2-4 named answers (found $n)"; exit 1; }
fi

# Readiness is a delivery check, not a claim inferred from a label. Prospective
# task instructions may be drafted before an artifact exists; applying the
# human-check label requires the artifact, review steps and observable criteria.
if [ "$MODE" = --ready-for-review ]; then
  python3 - "$BODY_FILE" <<'PYREADY'
import re, sys
from urllib.parse import urlparse
body = open(sys.argv[1]).read().replace("\r\n", "\n")
match = re.search(r"^### Human check[ \t]*\n(.*?)(?=^#{1,3}[ \t]|\Z)", body, re.M | re.S)
if not match:
    print("not ready for review: missing Human check section"); sys.exit(1)
raw = match[1]
# `headings` is a list because a sub-heading may have more than one accepted
# spelling: the producer template now emits `#### Pass`, and `#### Pass
# criteria` (every body written before that) stays readable forever.
def field(headings, legacy):
    for heading in headings:
        match = re.search(r"^#### " + re.escape(heading) + r"[ \t]*\n(.*?)(?=^#{1,4}[ \t]|\Z)", raw, re.M | re.S)
        if match and match[1].strip(): return match[1].strip()
    match = re.search(r"^" + legacy + r":[ \t]*(.+)$", raw, re.M | re.I)
    return match[1].strip() if match else ""
values = {name: field(headings, legacy) for name, headings, legacy in [("Surface", ["Surface"], "Surface"), ("Instruction", ["Instruction"], "Instruction"), ("URL", ["URL"], "URL"), ("Pass", ["Pass", "Pass criteria"], "Pass")]}
placeholders={"what to do, in one or two steps", "what the operator must observe for this to pass", "the deployed preview / the phone / the rendered artifact"}
for name, value in values.items():
    if not value or value == "_No response_" or value in placeholders or re.match(r"^(?:TBD|TODO|https?://\.\.\.)$", value, re.I):
        print("not ready for review: missing " + name); sys.exit(1)
url = urlparse(values["URL"])
if url.scheme not in ("https", "http") or not url.hostname or url.username or url.password or re.search(r"\s|[<>]", values["URL"]) or url.hostname in ("example.com", "example.test") or url.hostname.endswith(".invalid"):
    print("not ready for review: URL must identify the delivered artifact"); sys.exit(1)
# This validates the request, not the remote artifact's existence or contents.
print("review request fields complete; verify the artifact and automated checks before labeling")
PYREADY
  [ $? -eq 0 ] || exit 1
fi

echo "compliant"
exit 0
