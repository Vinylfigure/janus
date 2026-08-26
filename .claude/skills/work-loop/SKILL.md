---
name: work-loop
description: One iteration of the continuous work loop - consume exactly one consumable task: issue and deliver it by PR, or, when the backlog is empty, triage the inbox and evaluate the repo, filing at most two new task: proposals. A Routine, /loop, or goal loop drives repetition.
when_to_use: Use when a scheduled firing (or the user) says to work the backlog, or to run one loop iteration by hand.
model: claude-sonnet-5
effort: high
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
5. Untouchable: any issue the Gating labels list (Steps 1) excludes — held, questioned, unspecced, or awaiting the operator's check. The kill switch is pausing the routine.
6. **Headless permission boundary.** An unattended firing cannot write `.claude/hooks/**`, `.github/workflows/**`, or `.claude/settings.json`: the platform gates those paths as sensitive regardless of what `allowed_tools` grants, and there is nobody to answer the prompt, so the firing hangs instead of failing. The first armed firing proved it — three hours at `requires_action` on an Edit to `session-start.sh` (#26).

## Steps

1. Ready sweep: consult the Status dashboard issue and the open PRs first — an unmerged `claude/` PR from a prior firing outranks starting new work when its checks are red. Then list open `task:` issues and apply the gate below. Take the oldest consumable task unless one is explicitly marked priority.

   **The gate — the one list.** Consumable = labeled `task:` AND carries a done-means AND is within this environment's tool grant AND carries **none** of `question:` / `loop:hold` / `inbox:` / `human-check:` / `intent:` AND every issue named in its `### Blocked by` field is closed or resolved AND the issue is not already `working` — no open PR and no live delivery branch references it. The last clause is not optional politeness: a task someone else has already started looks identical to a fresh one until you compute it, and two sessions shipped contradictory implementations of this very protocol nine seconds apart by skipping it (L-057). Any failing condition makes the issue untouchable this firing. `question:` is not `loop:hold`: hold means "not now"; question means the answer is not known yet, and building either branch of an unanswered decision is wrong regardless of timing (#42). This list is the protocol's consumption gate (`docs/ATTENTION.md`); `fleet-status.sh` renders it as the Backlog's "Consumable now" line, and the fixture suite asserts a `question:`-labeled issue never counts.
1b. Permission preflight, before committing to the task rather than after: judge its done-means against hold-in-mind 6. If delivery requires writing a sensitive path, do not start it — comment on the issue naming the exact path and that it is operator-only in a headless firing, then evaluate the next ready task. If every ready task is operator-only, say so in one line and exit. A prompt that appears anyway is a stop-and-report, never a wait.
2. Consume (exactly one): run the normal delivery path — `/plan-feature` for non-trivial work (its own rule lets simple tasks skip ceremony) → implement → `/verify-loop` → the `verifier` agent's judgment → `/ship` as a PR whose body says `Closes #N`. Descoped remainders follow the descope gate: new `task:` issues with `discovered-from:` refs.
3. Idle generation (only when NO task is consumable): triage first — promote at most 2 open `inbox:` issues into `task:` proposals with a drafted done-means (or into a `question:` with the v1 headings when a product decision is needed), each commenting its provenance on the inbox issue and closing it; an inbox item is a thought, not a spec, so drafting the done-means is the triage work. Then, up to 2 proposals total this firing, evaluate the repo against its stated purpose and objectives, the ledger's candidates and efficacy notes, and recent merged PRs; where the environment allows, add a bounded research pass on the repo's domain. Every proposal carries a done-means and a `discovered-from:` ref (`work-loop inbox triage of #N` or `work-loop idle evaluation`). Then stop — the next firing executes (hold-in-mind 4).
4. Nothing ready and nothing worth proposing: say so in one line and exit. An empty firing is a healthy signal, not a failure.

## Before finishing

State which arm ran (consumed #N with the PR URL / proposed #N,#M / empty /
blocked-operator-only with the path that blocked it),
the verifier's verdict when work shipped, and any remainder filed. A firing
must end in exactly one of those four states — never in silently-started
work.
