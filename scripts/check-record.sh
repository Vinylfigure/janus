#!/usr/bin/env bash
# In-plain-words filing check (protocol addition, docs/ATTENTION.md). A
# question:/task: body must open with a human-readable "### In plain words"
# line: the operator's control surface renders it as the card headline, so a
# record filed without one shows muted, "not yet in plain words". A question
# additionally needs "### Options" (2-4 named answers) so its buttons are
# real choices, not the literal "Accept the recommendation".
#
# Usage: check-record.sh <body-file>
# Exit: 0 compliant · 1 not compliant (reason on stdout) · 64 usage
#
# Kind is inferred, never a second argument: a body carrying a
# "### Recommended choice" heading (the question.yml field) is a question
# and must also carry Options; any other body is checked for the plain line
# only.
set -uo pipefail

BODY_FILE="${1:?usage: check-record.sh <body-file>}"
[ -f "$BODY_FILE" ] || { echo "not compliant: body file not found: $BODY_FILE"; exit 1; }

# section <heading> <file> — lines under the first ### heading matching <heading>
section() {
  awk -v h="$1" '
    /^#+[ \t]*/ { line=$0; sub(/^#+[ \t]*/,"",line)
      if (found) exit
      if (tolower(line) == tolower(h)) { found=1; next }
      next }
    found { print }' "$2"
}

DENY='fixtures?|reconcil[a-z]*|canonical|machine-decidable|decidable|protocol v[0-9]|schema|drift(ed)?|marker|orphan|sha256|\<P[0-9][a-z]?\>|\<R[0-9]+\>|\<L-?[0-9]{3,}\>|DL-|goal/[0-9]+|Drone'

plain=$(section "In plain words" "$BODY_FILE" | sed '/^[[:space:]]*$/d' | tr '\n' ' ' | sed -E 's/ +/ /g; s/^ //; s/ $//')
[ -n "$plain" ] || { echo "not compliant: missing '### In plain words' line"; exit 1; }
[ "${#plain}" -le 160 ] || { echo "not compliant: In plain words is ${#plain} chars, must be <=160"; exit 1; }
case "$plain" in *'`'*) echo "not compliant: In plain words contains backticks"; exit 1 ;; esac
echo "$plain" | grep -qiE "$DENY" && { echo "not compliant: In plain words uses protocol/jargon wording: $plain"; exit 1; }

if grep -qE '^#+[[:space:]]*Recommended choice' "$BODY_FILE"; then
  opts=$(section "Options" "$BODY_FILE" | sed '/^[[:space:]]*$/d')
  n=$(printf '%s\n' "$opts" | grep -c .)
  { [ -n "$opts" ] && [ "$n" -ge 2 ] && [ "$n" -le 4 ]; } \
    || { echo "not compliant: question needs '### Options' with 2-4 named answers (found $n)"; exit 1; }
fi

echo "compliant"
exit 0
