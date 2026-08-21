# Decisions

Append-only log of resolved product/design decisions. Amend by appending a
new entry that cites the superseded ID — never by editing history.

## DL-001 · 2026-08-16 · Janus grows its own child-ledger harvest pass for reverse heredity

- Context: Child→parent learning flow was manual (`docs/AUDIT-2026-08.md`
  §6.5). Question was whether the overlord survey's memory-health column is
  a sufficient reverse-heredity mechanism, or whether janus should grow its
  own harvest pass — e.g. `/recalibrate` reading child ledgers via the L-044
  cross-sibling evidence rule.
- Decided by: operator (Vinylfigure), via comment on issue #21.
- Decision: janus grows its own harvest pass — `/recalibrate` reads child
  ledgers, applying the L-044 cross-sibling evidence rule. The overlord
  survey's memory-health column stays as a downstream view, not the
  mechanism itself.
- Supersedes: none.

## DL-002 · 2026-08-21 · Human Attention Protocol v1: typed states, a deterministic gate, human verification first-class

- Context: #42 proved that prose-level label understanding is not a gate —
  `/work-loop` consumed a `question:`-labeled issue and built the unanswered
  branch. Separately, capture required a done-means up front (the Task form),
  which blocked frictionless idea capture, and "machine work done, operator
  eyes needed" had no state at all. An operator-supplied architecture review
  (2026-08-21) called for a formal human-attention protocol between janus
  repos and their consumers.
- Decided by: operator (Vinylfigure), via the multi-repo-task-visibility
  session's approved plan.
- Decision: docs/ATTENTION.md is the versioned protocol (v1). Type
  (idea/task/question) is separated from state; the label vocabulary gains
  `inbox:` (thought awaiting triage, no done-means) and `human-check:`
  (machine work done, operator verification before merge); the consumption
  gate is executable (`scripts/check-ready.sh`, fixtured) rather than prose;
  the Question form carries recommendation/consequence/reversibility; form
  headings are the machine-parse contract, so renaming one is a version bump.
  Structured JSON events are deferred to a future v2 (L-014).
- Supersedes: none.
