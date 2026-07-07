---
name: evolve
description: Promote stable learnings (Evidence >= 2) from LEARNINGS.md into CLAUDE.md rules or new skills, retire contradicted rules, archive resolved entries, and enforce the concept budget. Use between tasks when the session-start status reports ripe learnings - never mid-implementation. Confirms with the user before editing CLAUDE.md.
---

The garbage collector and promoter of Janus's memory. `/reflect` writes raw
lessons; this skill decides what graduates into always-loaded context and
moves resolved history out of the active working set.

## Hold in mind

1. CLAUDE.md is the model's always-on workspace: hard cap 20 concepts total, 12 in the learned-rules block. Over budget = something must merge or retire first.
2. Rule-shaped lessons (one imperative sentence) go to CLAUDE.md; procedure-shaped lessons (multi-step) become skills — procedures load on demand, rules must not.
3. The ledger is lineage history: entries are marked, never deleted — resolved entries *move* to `ARCHIVE.md` so the active ledger stays ≤25.
4. Promotion needs Evidence >= 2 or explicit user confirmation — one occurrence is an anecdote.
5. Editing CLAUDE.md is gated: interactive → get the user's explicit yes first; headless (no user present) → apply on a branch and open a PR — the review is the confirmation. Ledger-only changes need no gate.

## Steps

1. Launch the `memory-curator` agent. It reads `LEARNINGS.md`, `CLAUDE.md`, and existing skills (grepping `ARCHIVE.md` only for specific priors), then returns a proposal: promotions (with target), merges, retirements, archivals, and contradictions. It does not edit anything.
2. Review the proposal yourself against the Hold-in-mind rules. Reject anything that lacks evidence or would blow the budget without a compensating retirement.
3. Gate: if the accepted proposal touches CLAUDE.md, present it in one screen and wait for the user's yes. In a headless run, skip the question — but land every convention change via a branch and PR, never directly on the default branch.
4. Apply promotions:
   - **Rule-shaped** → add one bullet inside the `<!-- janus:rules:start -->` / `<!-- janus:rules:end -->` sentinels in CLAUDE.md, suffixed with its ledger id, e.g. `- Never mock the database in integration tests. (L-007)`
   - **Procedure-shaped** → create or update a skill via `/add-skill`, then note the skill in the ledger entry.
   - **Stack-specific while this repo is still the template** → leave as candidate; children promote it after `/replicate`.
5. Apply retirements: rules contradicted by newer, better-evidenced entries get removed from CLAUDE.md and their ledger entry marked `Status: retired` with a one-line reason. Entries merged into another become `retired` with reason "merged into L-NNN". This authority extends to skills: an obsolete skill (or one blocking the 15-skill cap) gets a retirement proposal — deleting it still needs the user's yes.
6. Update ledger statuses: `promoted:CLAUDE.md` or `promoted:skill/<name>`.
7. Archive: move every `promoted:*` and `retired` entry — full text — from `LEARNINGS.md` to `ARCHIVE.md`, below its entries marker. Then, if the active count still exceeds 25, expire stale candidates: `Evidence: 1` entries untouched for 60+ days become `Status: retired` (reason: "expired unproven — resurrect by citing this id") and move too. If *still* over, have memory-curator propose merges rather than dropping anything.
8. Count concepts in CLAUDE.md (bullets across all sections), the rules block (bullets inside sentinels), and active ledger entries (below the marker in LEARNINGS.md).

## Before finishing

Print: concepts total (assert <= 20), rules-block count (assert <= 12), active
ledger count (assert <= 25), and the number promoted / merged / retired /
archived this run. If any assertion fails, fix it now by merging, retiring, or
archiving — do not finish over budget.
