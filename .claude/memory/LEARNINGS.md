# Learnings ledger

Append-mostly, git-tracked. Written by `/reflect`, curated by `/evolve`,
inherited across projects by `/replicate`. Entries are never deleted — promoted
and retired entries stay as lineage history.

## Entry format

```
## L-NNN · YYYY-MM-DD · <imperative rule title, one concept>
- Trigger: <the concrete event that taught this — session, failure, correction>
- Rule: <imperative, testable, one concept — a rule, not a story>
- Scope: project | portable      # portable = true in any repo, inherited by /replicate
- Evidence: 1                    # incremented by /reflect on recurrence
- Status: candidate              # candidate | promoted:CLAUDE.md | promoted:skill/<name> | inherited | retired
```

Rules for writers (`/reflect`):
- One entry = one concept. If the lesson needs two sentences of rule, it is two entries.
- Before appending, grep for an equivalent entry; if found, increment its Evidence instead.
- IDs are sequential; find the highest existing L-NNN and add 1.

Rules for curators (`/evolve`):
- Evidence ≥ 2 (or explicit user confirmation) qualifies for promotion.
- Rule-shaped → CLAUDE.md `janus:rules` block. Procedure-shaped → a skill via /add-skill.
- Mark promoted entries `Status: promoted:<target>`; never delete them.

---

<!-- entries below this line -->

## L-001 · 2026-07-07 · Fixture-test every hook with sample JSON before committing
- Trigger: session-start.sh shipped a counting bug that only surfaced when tested against a seeded fixture ledger (janus build session)
- Rule: before committing a hook script, pipe fixture JSON through it and assert exit code and output for the pass, fail, and repeat cases
- Scope: portable
- Evidence: 1
- Status: candidate

## L-002 · 2026-07-07 · Scope pattern-counts below the content marker in self-documenting files
- Trigger: grep counted the format-spec example at the top of LEARNINGS.md as a real entry, inflating the session-start summary (janus build session)
- Rule: when a file embeds its own format spec, count or match entries only below its entries-start marker
- Scope: portable
- Evidence: 1
- Status: candidate

## L-003 · 2026-07-07 · Inject post-compaction context via SessionStart source=compact, not PreCompact
- Trigger: compaction workspace-rescue was first designed as a PreCompact hook; PreCompact output cannot reliably reach the post-compaction context window (janus hardening session)
- Rule: to restore context after compaction, hook SessionStart and branch on source == "compact"
- Scope: portable
- Evidence: 1
- Status: candidate
