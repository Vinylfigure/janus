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

## DL-002 · 2026-08-21 · Human Attention Protocol v1: sparse labels, versioned by label, states derived

- Context: the operator runs ~9 parallel agent work streams and loses track
  of what needs their attention, especially on the phone. Research (janus#42,
  overlord#68, overlord#127, janus#31) established the missing layer is a
  formal human-attention protocol, and janus#42 proved the cost of an
  informal one: the work loop consumed a `question:`-labeled issue and built
  one branch of an unanswered decision. The question was how to make
  attention machine-readable without a second source of truth.
- Decided by: operator (Vinylfigure), via the overlord-ui architecture
  review, 2026-08-21.
- Decision: type (idea / task / question) is separate from state (inbox /
  ready / working / verifying / human_check / done / held / blocked). Labels
  stay sparse — `inbox:`, `task:`, `question:`, `human-check:`, `loop:hold` —
  and the protocol defines which combinations are legal. The protocol version
  is the `janus:v1` label, applied by every issue form (a hidden body comment
  cannot version form-created issues: GitHub Issue Forms display markdown
  elements but do not submit them into the body; a label is also structurally
  queryable). Stable body headings are the v1 API; task dependencies are an
  explicit `Blocked by` field, never prose references. Human action results
  are lifecycle events encoded as canonical comments
  (`<!-- janus:decision:v1 -->`, `<!-- janus:human-check:v1 -->`) plus label
  transitions. Readers of a future v2 must tolerate v1, and migration never
  silently alters an unresolved human decision. Full text: docs/ATTENTION.md.
- Supersedes: none.
