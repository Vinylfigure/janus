---
name: recalibrate
description: Re-verify this repo's encoded conventions (skills, CLAUDE.md directives, ARCHITECTURE.md claims) against primary sources - Anthropic docs, changelog, the practitioners' own posts - and file drift as candidate LEARNINGS.md entries. Use when the session-start status says recalibration is stale, a documented practice misbehaves, or on the maintenance heartbeat.
---

The ecosystem-learning loop. `/reflect` learns from what happened in sessions;
this skill learns from what changed in the world. The scaffold's encoded
practices are claims about tools and methods that keep evolving — claims rot.
Founding example: this repo's worktree skill shipped with a manual script two
weeks after `claude --worktree` made it the fallback rather than the path.

## Hold in mind

1. Primary sources only: Anthropic docs/changelog and the practitioners' own posts. Aggregator and blog claims are leads to verify, never evidence.
2. Propose, never edit: your only outputs are `Status: candidate` ledger entries and the run stamp — `/evolve` keeps promotion authority, and the evidence discipline survives.
3. Verify drift in both directions: absence of confirmation is not deprecation — flag a convention only when a primary source contradicts or supersedes it — and presence in the scaffold is not currency — an encoded practice is a claim about a moving target, so re-verify it against primary sources before relying on it or "fixing" it.
4. Ledger rules apply: one concept per entry, dedupe by Evidence-bump, entries below the marker, source URL in the Trigger line.

## Steps

1. Enumerate the conventions this repo encodes: read each `.claude/skills/*/SKILL.md` (the practices its steps assume), the CLAUDE.md prime directives, and the claims in `docs/ARCHITECTURE.md`'s methodology and workspace tables. List them as short checkable claims.
2. Fetch current primary sources: the Claude Code docs (code.claude.com/docs — start from the changelog and llms.txt index), Anthropic's engineering blog, and the Claude Code team's own posts. If a source is unreachable, record nothing for the claims it covers — a failed fetch is "no data", never a confirmation.
3. Diff and classify each claim: **confirmed** (still current), **drifted** (a primary source contradicts or supersedes it — cite where), or **newly-available** (a capability the scaffold predates and could use).
4. For each drift or new capability, append a candidate entry to `.claude/memory/LEARNINGS.md` per its format spec: `Scope: portable`, `Evidence: 1`, source URL in the Trigger. If an equivalent entry exists, bump its Evidence instead.
5. Record the run: `date +%s > .claude/memory/recalibrated-at` (epoch in content — mtimes don't survive clones). Commit it alongside any drift entries; it resets the session-start staleness nudge locally and, once a heartbeat PR merges, everywhere.
6. Summarize: N claims checked, N confirmed, N drifted, N new — and if any entry is now at Evidence >= 2, recommend `/evolve`.

## Before finishing

State the counts from step 6 and read back each entry you wrote. Assert
explicitly that you edited no convention file — no skill, not CLAUDE.md, not
ARCHITECTURE.md — only the ledger and the run stamp. If you caught yourself
wanting to "just fix" a stale skill directly, that impulse goes in the
summary too: it is exactly what the evidence discipline exists to stop.
