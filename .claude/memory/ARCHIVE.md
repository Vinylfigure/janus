# Learnings archive (resolved history)

Memory's disk. Entries land here when `/evolve` resolves them — promoted,
retired, merged, or expired — moved from `LEARNINGS.md` so the active ledger
stays a bounded working set (≤25). Nothing is ever deleted: history stays
queryable via the knowledge graph or a targeted grep, but this file is never
loaded wholesale into context.

Format: identical to the entry format spec at the top of `LEARNINGS.md`.
IDs are sequential across both files — writers take the highest L-NNN found
in either file, plus 1. If an archived lesson recurs, do not edit it here:
write a fresh active entry in `LEARNINGS.md` citing the archived id — a
resolution that stopped working is itself evidence.

---

<!-- entries below this line -->

## L-005 · 2026-07-06 · Treat aggregator claims and fetch summaries as leads, never evidence
- Trigger: an aggregator site mixed verified practices with unverifiable feature claims — only primary-source-corroborated claims were encoded (janus refinement session); the withheld /goal claim was later confirmed by the official loops post (round-3 research); merged with L-011: a fetch-summary of the workspace paper attributed claims the paper never makes, caught by demanding verbatim quotes
- Rule: treat aggregator claims and fetch summaries as leads, never evidence — confirm any specific claim verbatim against a primary source before adopting or citing it
- Scope: portable
- Evidence: 3
- Status: promoted:CLAUDE.md

## L-011 · 2026-07-06 · Verify a source's specific claims as verbatim quotes before citing them
- Trigger: a first fetch-summary of the transformer-circuits workspace paper attributed capacity limits and RAG recommendations to it that the paper never makes; a re-fetch demanding verbatim quotes caught the embellishment (janus round-3 session)
- Rule: before citing a source for a specific claim, re-verify the claim as a verbatim quote from the source itself — summarization layers embellish; kin to L-005, a summary is a lead, not evidence
- Scope: portable
- Evidence: 1
- Status: retired (merged into L-005)
