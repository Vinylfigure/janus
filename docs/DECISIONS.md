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
