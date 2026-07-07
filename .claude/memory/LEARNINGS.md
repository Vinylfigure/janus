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
