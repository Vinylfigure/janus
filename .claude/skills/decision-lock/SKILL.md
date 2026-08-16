---
name: decision-lock
description: Freeze a resolved product or design decision as a dated, ID'd, owner-attributed record in docs/DECISIONS.md, so later plans cite the lock instead of re-litigating it.
when_to_use: Use when a discussion resolves a decision ("lock this", "that's the decision") or a plan touches a locked one.
argument-hint: [the decision to lock]
---

Convergently invented by two children (fillmore-v2's DL-N gating table,
DryDock's dated owner-approved amendments): a decision nobody wrote down
gets re-litigated — or silently drifted past — by the next session.

## Hold in mind

1. A lock records a decision made, not a proposal — no resolution, no lock.
2. Every lock names its owner and date; an unattributed decision cannot be honestly amended.
3. Locks are append-only: amend with a new entry citing the superseded ID, never by editing history.
4. A plan touching a locked decision cites the lock ID or files a `question:` issue — silent override is decision drift.

## Steps

1. Extract the final decision in one sentence; separate it from the options discussed.
2. Read `docs/DECISIONS.md` (create it with a two-line header on first use). An existing lock on the same question means this is an amendment — cite it.
3. Append: `## DL-NNN · YYYY-MM-DD · <decision, one sentence>` with `Context:` (one line), `Decided by:` (the owner), `Supersedes:` (ID or none).
4. Reconcile every canonical doc the decision changes in the same commit; grep for contradicting wording (L-007).

## Before finishing

Read the entry back: owner, date, supersedes present; canonical docs no
longer contradict it; the lock is one decision, not a bundle.
