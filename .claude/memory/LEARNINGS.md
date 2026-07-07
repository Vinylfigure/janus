# Learnings ledger (active)

The bounded working set of lessons — memory's RAM. Written by `/reflect`
(session lessons) and `/recalibrate` (ecosystem drift), curated by `/evolve`,
inherited across projects by `/replicate`. Holds at most **25 active entries**.
Entries are never deleted: when resolved (promoted, retired, merged, expired),
`/evolve` relocates them to `ARCHIVE.md`, where history stays queryable via
targeted grep without re-entering context wholesale.

## Entry format

```
## L-NNN · YYYY-MM-DD · <imperative rule title, one concept>
- Trigger: <the concrete event that taught this — session, failure, correction>
- Rule: <imperative, testable, one concept — a rule, not a story>
- Scope: project | portable      # portable = true in any repo, inherited by /replicate
- Evidence: 1                    # incremented by /reflect on recurrence
- Status: candidate              # candidate | promoted:CLAUDE.md | promoted:skill/<name> | inherited | retired
```

Rules for writers (`/reflect`, `/recalibrate`):
- One entry = one concept. If the lesson needs two sentences of rule, it is two entries.
- Before appending, grep BOTH this file and `ARCHIVE.md` for an equivalent. Active equivalent → bump its Evidence. Archived equivalent → write a fresh active entry citing the archived id.
- IDs are sequential across both files: highest L-NNN in this file or `ARCHIVE.md`, plus 1.
- If a write would take the active count past 25, warn that `/evolve` is needed.

Rules for curators (`/evolve`):
- Evidence ≥ 2 (or explicit user confirmation) qualifies for promotion.
- Rule-shaped → CLAUDE.md `janus:rules` block. Procedure-shaped → a skill via /add-skill.
- Mark resolved entries (`promoted:<target>` / `retired`), then MOVE them to `ARCHIVE.md` — never delete. Keep this file ≤25 active entries; the overflow policy lives in the evolve skill.

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

## L-004 · 2026-07-07 · Re-verify encoded practices against primary sources before trusting them
- Trigger: the worktree-parallel skill shipped using a manual script while `claude --worktree` already existed natively; found by re-checking Cherny's own posts (https://x.com/bcherny/status/2017742743125299476) when the user asked if terminal-tab advice was stale (janus refinement session)
- Rule: a practice encoded in scaffold files is a claim about a moving target — re-verify it against primary sources before relying on or extending it
- Scope: portable
- Evidence: 1
- Status: candidate

## L-006 · 2026-07-07 · Distinguish context bloat from dependency bloat when judging a tool
- Trigger: user corrected the "keep Graphify optional" recommendation — offloading structure to an external queryable store REDUCES the bloat the workspace budget guards; only the install dependency is a cost (janus refinement session)
- Rule: a tool that moves knowledge out of always-loaded context into on-demand external memory should default ON with graceful degradation; weigh its dependency cost separately from its context benefit
- Scope: portable
- Evidence: 1
- Status: retired (2026-07-06: owner reversed the default-on decision — the template ships tool-agnostic, with no third-party mechanism in the genome before dogfooding proves need; external memory returns as a per-project choice)

## L-007 · 2026-07-07 · When changing a convention, sweep every mention of it, not just planned edit sites
- Trigger: the adversarial verifier failed the refinement diff because docs/USAGE.md's day-1 section still said "optional Graphify" after the convention changed to default-on; the planned edit list had missed that mention (janus refinement session)
- Rule: after changing a convention, grep the whole repo for the old wording and reconcile every hit before claiming consistency
- Scope: portable
- Evidence: 1
- Status: candidate

## L-008 · 2026-07-06 · Stress-test a plan against scale, concurrency, and headless modes before presenting it
- Trigger: user rejected the round-3 plan approval asking "will this perform under stress and scaling?"; the resulting review found 4 real design bugs the plan had missed — ledger cap deadlock, worktree ID collisions, headless gates with no user, mtime loss across clones (janus round-3 session)
- Rule: before presenting a plan, run an adversarial pass over its behavior at scale, under concurrent use, and with no user present — and pair every failure found with a fix, not just a risk note
- Scope: portable
- Evidence: 1
- Status: candidate

## L-009 · 2026-07-06 · Seed behavioral fixtures with controlled data, never the repo's live content
- Trigger: bumping L-005 to Evidence 2 broke two session-start fixtures that asserted against the shipped ledger's real entry counts (janus round-3 session)
- Rule: a behavioral fixture must create the data it asserts against (truncate and seed in the sandbox); asserting against live repo content couples tests to unrelated edits
- Scope: portable
- Evidence: 1
- Status: candidate

## L-010 · 2026-07-06 · Store cross-clone state in file content, never in file mtimes
- Trigger: the recalibration staleness design first used a gitignored marker checked via find -mtime; gitignored files never sync between clones, and git does not preserve mtimes on committed files either — both halves were broken (janus round-3 session)
- Rule: any timestamp or state that must survive a git clone boundary goes in the file's content (e.g. epoch seconds) and is committed; mtimes are per-checkout artifacts
- Scope: portable
- Evidence: 1
- Status: candidate

## L-012 · 2026-07-06 · Propose the maintenance heartbeat at the end of /bootstrap
- Trigger: user asked why the weekly heartbeat isn't on by default for every project; auto-creating a billed cloud routine silently would violate the escalation-is-proposed rule, but the end of session zero is the natural moment to offer it (janus round-3 evolve session)
- Rule: when a project finishes bootstrapping, propose creating the maintenance heartbeat (one yes, PR-delivery only) instead of waiting for the user to discover it
- Scope: portable
- Evidence: 1
- Status: candidate
