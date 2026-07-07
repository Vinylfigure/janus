#!/usr/bin/env bash
# Git worktree helper for parallel Claude Code sessions.
#
# Usage:
#   scripts/new-worktree.sh create <slug>   # ../<repo>-wt-<slug> on branch wt/<slug>
#   scripts/new-worktree.sh list
#   scripts/new-worktree.sh clean <slug>    # remove worktree + delete branch if merged
set -euo pipefail

CMD="${1:-list}"
SLUG="${2:-}"

ROOT=$(git rev-parse --show-toplevel)
REPO=$(basename "$ROOT")

case "$CMD" in
  create)
    [ -n "$SLUG" ] || { echo "usage: new-worktree.sh create <slug>" >&2; exit 64; }
    DEST="$ROOT/../$REPO-wt-$SLUG"
    git -C "$ROOT" worktree add -b "wt/$SLUG" "$DEST"
    echo "Worktree ready: $DEST (branch wt/$SLUG)"
    echo "Start a session there with:  cd $DEST && claude"
    ;;
  list)
    git -C "$ROOT" worktree list
    ;;
  clean)
    [ -n "$SLUG" ] || { echo "usage: new-worktree.sh clean <slug>" >&2; exit 64; }
    DEST="$ROOT/../$REPO-wt-$SLUG"
    git -C "$ROOT" worktree remove "$DEST"
    git -C "$ROOT" branch -d "wt/$SLUG" || {
      echo "Branch wt/$SLUG is not fully merged; delete manually with: git branch -D wt/$SLUG" >&2
    }
    ;;
  *)
    echo "usage: new-worktree.sh create <slug> | list | clean <slug>" >&2
    exit 64
    ;;
esac
