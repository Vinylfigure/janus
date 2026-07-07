---
name: evolve
description: Promote stable learnings (Evidence >= 2) from LEARNINGS.md into CLAUDE.md rules or new skills, retire contradicted rules, and enforce the concept budget. Use between tasks when the session-start status reports ripe learnings - never mid-implementation. Confirms with the user before editing CLAUDE.md.
---

The garbage collector and promoter of Janus's memory. `/reflect` writes raw
lessons; this skill decides what graduates into always-loaded context.

## Hold in mind

1. CLAUDE.md is the model's always-on workspace: hard cap 20 concepts total, 12 in the learned-rules block. Over budget = something must merge or retire first.
2. Routing: rule-shaped + global → CLAUDE.md; rule-shaped + path-local → `.claude/rules/<topic>.md` with `paths:` frontmatter (loads only when matching files are touched, spends no CLAUDE.md budget); procedure-shaped → a skill. Procedures and path-local rules load on demand; global rules must not grow past the cap.
3. The ledger is lineage history: entries are marked, never deleted.
4. Promotion needs Evidence >= 2 or explicit user confirmation — one occurrence is an anecdote.
5. Editing CLAUDE.md is gated: interactive → get the user's explicit yes first; headless (no user present) → apply on a branch and open a PR — the review is the confirmation. Ledger-only changes need no gate.

## Steps

1. Launch the `memory-curator` agent. It reads `LEARNINGS.md`, `CLAUDE.md`, and existing skills, then returns a proposal: promotions (with target), merges, retirements, and contradictions. It does not edit anything.
2. Review the proposal yourself against the Hold-in-mind rules. Reject anything that lacks evidence or would blow the budget without a compensating retirement.
3. Gate: if the accepted proposal touches CLAUDE.md, present it in one screen and wait for the user's yes. In a headless run, skip the question — but land every convention change via a branch and PR, never directly on the default branch.
4. Apply promotions:
   - **Rule-shaped, global** → add one bullet inside the `<!-- janus:rules:start -->` / `<!-- janus:rules:end -->` sentinels in CLAUDE.md, suffixed with its ledger id, e.g. `- Never mock the database in integration tests. (L-007)`
   - **Rule-shaped, path-local** (only true for part of the codebase) → write `.claude/rules/<topic>.md` with `paths:` glob frontmatter and the rule as its body, citing the ledger id; mark the entry `promoted:rules/<topic>`.
   - **Procedure-shaped** → create or update a skill via `/add-skill`, then note the skill in the ledger entry.
   - **Stack-specific while this repo is still the template** → leave as candidate; children promote it after `/replicate`.
5. Apply retirements: rules contradicted by newer, better-evidenced entries get removed from CLAUDE.md and their ledger entry marked `Status: retired` with a one-line reason. Entries merged into another become `retired` with reason "merged into L-NNN". This authority extends to skills: an obsolete skill (or one blocking the 15-skill cap) gets a retirement proposal — deleting it still needs the user's yes.
6. Update ledger statuses: `promoted:CLAUDE.md` or `promoted:skill/<name>`.
7. Count concepts in CLAUDE.md (bullets across all sections) and the rules block (bullets inside sentinels).

## Before finishing

Print: concepts total (assert <= 20), rules-block count (assert <= 12), and
the number promoted / merged / retired this run. If either assertion fails,
fix it now by merging or retiring — do not finish over budget.
