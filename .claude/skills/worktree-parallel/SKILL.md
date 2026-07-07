---
name: worktree-parallel
description: Fan a task out into parallel Claude Code sessions, each in its own git worktree, then merge tracks after each verifies green. Use for independent workstreams - refactor + feature + bugfix concurrently.
disable-model-invocation: true
argument-hint: [task to parallelize]
---

Parallel sessions multiply throughput only when the tracks are genuinely
independent and each track closes its own verification loop before merging.
Worktrees share the repo's `.claude/` (it's in-tree), so every parallel
session gets the same skills, hooks, and memory for free.

## Hold in mind

1. Tracks must be independent: no two tracks editing the same files, or the merge eats the savings.
2. Each track verifies green in its own worktree before any merge.
3. Worktrees are disposable; branches carry the work. Clean up after merging.

## Steps

1. Split the task into independent tracks. For each, write one paragraph: scope, files it will touch, its "done means" check. If two tracks overlap on files, merge them into one track.
2. For each track: `scripts/new-worktree.sh create <slug>` — creates `../<repo>-wt-<slug>` on branch `wt/<slug>`.
3. Print a kickoff prompt for each track for the user to paste into a new `claude` session in that worktree. Include: the track's scope paragraph, its "done means" check, and the instruction to run `/verify-loop` before declaring done.
4. Merge protocol, once tracks report green:
   - In the main checkout, merge each `wt/<slug>` branch one at a time, running `scripts/verify.sh full` after each merge.
   - On conflict or post-merge red: fix in the main checkout before merging the next track.
5. Cleanup: `scripts/new-worktree.sh clean <slug>` for each merged track.

## Before finishing

List each track, its branch, and its verification evidence. Confirm
`verify.sh full` is green on the merged result and all worktrees are cleaned.
