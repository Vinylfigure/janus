---
name: evolve
description: Promote stable learnings (Evidence >= 2) from LEARNINGS.md into CLAUDE.md rules or new skills, retire contradicted rules, and enforce the CLAUDE.md concept budget. Run when /reflect or the session-start status suggests it.
disable-model-invocation: true
---

The garbage collector and promoter of Janus's memory. `/reflect` writes raw
lessons; this skill decides what graduates into always-loaded context.

## Hold in mind

1. CLAUDE.md is the model's always-on workspace: hard cap 20 concepts total, 12 in the learned-rules block. Over budget = something must merge or retire first.
2. Rule-shaped lessons (one imperative sentence) go to CLAUDE.md; procedure-shaped lessons (multi-step) become skills — procedures load on demand, rules must not.
3. The ledger is lineage history: entries are marked, never deleted.
4. Promotion needs Evidence >= 2 or explicit user confirmation — one occurrence is an anecdote.

## Steps

1. Launch the `memory-curator` agent. It reads `LEARNINGS.md`, `CLAUDE.md`, and existing skills, then returns a proposal: promotions (with target), merges, retirements, and contradictions. It does not edit anything.
2. Review the proposal yourself against the Hold-in-mind rules. Reject anything that lacks evidence or would blow the budget without a compensating retirement.
3. Apply promotions:
   - **Rule-shaped** → add one bullet inside the `<!-- janus:rules:start -->` / `<!-- janus:rules:end -->` sentinels in CLAUDE.md, suffixed with its ledger id, e.g. `- Never mock the database in integration tests. (L-007)`
   - **Procedure-shaped** → create or update a skill via `/add-skill`, then note the skill in the ledger entry.
   - **Stack-specific while this repo is still the template** → leave as candidate; children promote it after `/replicate`.
4. Apply retirements: rules contradicted by newer, better-evidenced entries get removed from CLAUDE.md and their ledger entry marked `Status: retired` with a one-line reason.
5. Update ledger statuses: `promoted:CLAUDE.md` or `promoted:skill/<name>`.
6. Count concepts in CLAUDE.md (bullets across all sections) and the rules block (bullets inside sentinels).

## Before finishing

Print: concepts total (assert <= 20), rules-block count (assert <= 12), number
promoted / merged / retired this run. If either assertion fails, fix it now by
merging or retiring — do not finish over budget.
