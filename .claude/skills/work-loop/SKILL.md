---
name: work-loop
description: One iteration of the continuous work loop - consume exactly one ready task: issue and deliver it by PR, or, when the backlog is empty, evaluate the repo and file at most two new task: proposals. A Routine, /loop, or goal loop drives repetition.
when_to_use: Use when a scheduled firing (or the user) says to work the backlog, or to run one loop iteration by hand.
---

The consumer half of the work loop: descope capture fills the `task:` backlog
(L-043); this skill drains it. The platform owns the looping — Routines,
`/loop`, goal loops (L-015); this skill encodes one iteration's discipline.
State lives on disk (issues, ledger, git), never in the loop's memory: each
firing starts fresh and can only learn what it can read.

## Hold in mind

1. One task per firing. The schedule is the loop counter; a firing that tries to drain the queue trades fresh context for compounding drift.
2. The worker never grades its own homework: no verifier judgment, no ship. A loop with no verifier produces wrong answers faster.
3. Delivery is a PR, never the default branch — the human gate is the merge, not a pre-approval.
4. Never execute a proposal in the firing that created it: generation and execution live in separate iterations, and the gap between firings is the operator's veto window (closing the issue is the veto).
5. Untouchable: a `task:` labeled `loop:hold`, or one blocked on an unanswered `question:`. The kill switch is pausing the routine.

## Steps

1. Ready sweep: list open `task:` issues. Ready = carries a done-means, is within this environment's tool grant, and is not blocked on a `question:` or `loop:hold`. Take the oldest ready task unless one is explicitly marked priority.
2. Consume (exactly one): run the normal delivery path — `/plan-feature` for non-trivial work (its own rule lets simple tasks skip ceremony) → implement → `/verify-loop` → the `verifier` agent's judgment → `/ship` as a PR whose body says `Closes #N`. Descoped remainders follow the descope gate: new `task:` issues with `discovered-from:` refs.
3. Idle generation (only when NO task is ready): evaluate the repo against its stated purpose and objectives, the ledger's candidates and efficacy notes, and recent merged PRs; where the environment allows, add a bounded research pass on the repo's domain. File at most 2 proposal `task:` issues, each with a done-means and `discovered-from: work-loop idle evaluation`. Then stop — the next firing executes.
4. Nothing ready and nothing worth proposing: say so in one line and exit. An empty firing is a healthy signal, not a failure.

## Before finishing

State which arm ran (consumed #N with the PR URL / proposed #N,#M / empty),
the verifier's verdict when work shipped, and any remainder filed. A firing
must end in exactly one of those three states — never in silently-started
work.
