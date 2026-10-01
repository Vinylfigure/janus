#!/usr/bin/env bash
# Reverse heredity, mechanical half (janus#38, DL-001, L-044): read child-repo
# ledgers and surface portable entries this template's own ledger does not
# hold, as harvest candidates for /recalibrate to judge. The script only
# *finds*; the skill decides what becomes a candidate entry, with the child
# repo + entry id cited in the Trigger so cross-sibling evidence counts per
# L-044 without conflating it with this repo's own observations.
#
# Usage:
#   harvest-ledgers.sh <own-ledger> <child-ledger> [<child-ledger>...]
#
# A <child-ledger> argument is a path to a child repo's
# .claude/memory/LEARNINGS.md (a checkout, a worktree, a fetched copy —
# acquisition is the caller's job; this script never touches the network).
#
# Output: one line per harvest candidate —
#   <child-file>\t<entry-id>\t<title>\t<evidence>
# An entry is a candidate when its Scope is portable AND its title (the text
# after "<learning-id> · date · ") appears nowhere in the own ledger. Retired entries
# are skipped. Exit 0 always: this is a survey, not a gate.
set -uo pipefail

OWN="${1:-}"
[ -n "$OWN" ] && [ -f "$OWN" ] || { echo "usage: harvest-ledgers.sh <own-ledger> <child-ledger>..." >&2; exit 64; }
shift

for child in "$@"; do
  [ -f "$child" ] || { echo "harvest: no ledger at $child (skipped)" >&2; continue; }
  awk -v own="$OWN" -v src="$child" '
    BEGIN {
      while ((getline line < own) > 0)
        if (line ~ /^## L-/) own_titles[entry_title(line)] = 1
      close(own)
    }
    /^## L-/ {
      emit(); id = $2; title = entry_title($0)
      portable = 0; retired = 0; evidence = ""
      next
    }
    /^- Scope: portable/ { portable = 1 }
    /^- Status: retired/ { retired = 1 }
    /^- Evidence: /      { evidence = $3 }
    END { emit() }
    function entry_title(line) {
      sub(/^## L-[A-Za-z0-9-]+ · [0-9-]+ · /, "", line)
      return line
    }
    function emit() {
      if (id != "" && portable && !retired && !(title in own_titles))
        printf "%s\t%s\t%s\t%s\n", src, id, title, evidence
      id = ""
    }
  ' FS=' ' "$child"
done
exit 0
