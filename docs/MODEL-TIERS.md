# Model and effort tiers

Which model and reasoning effort each skill and agent runs at, why, and who
maintains the mapping. Before this file every skill and every subagent ran at
whatever the session model happened to be, and the only control was the
operator remembering to type `/model` — a setting living in the operator's
head instead of in the repo.

Children inherit this file at `/replicate`. The **discipline** is portable and
should survive bootstrapping any stack; the one line a child may need to
re-verify is the working tier's model ID, which is what `/recalibrate` is for.
A child that adds skills assigns each a tier when it adds them — `/add-skill`
asks — rather than leaving new work to inherit the session by default.

## What tiering actually buys, stated honestly

On a Claude subscription there is **no per-token bill**. Choosing a cheaper
tier does not save dollars; it slows how fast the work burns the plan's usage
limits. The price table below is the ratio proxy for that burn rate, not an
invoice. Anyone reading this expecting a cost line item should expect a
headroom line item instead.

Cached from the `claude-api` skill, 2026-06-24 — a moving target, re-verified
by `/recalibrate`, never quoted from memory:

| Model | ID | Context | In / Out per MTok |
|---|---|---|---|
| Fable 5 | `claude-fable-5` | 1M | $10 / $50 |
| Opus 5 | `claude-opus-5` | 1M | $5 / $25 |
| Sonnet 5 | `claude-sonnet-5` | 1M | $3 / $15 (intro $2 / $10 through 2026-08-31) |
| Haiku 4.5 | `claude-haiku-4-5` | **200K** | $1 / $5 |

Two things in that table are counter-intuitive enough to state outright:

- **Fable 5 is the expensive escalation, not the smart default.** It costs
  *twice* Opus 5 for the same 1M context. "Use Fable for hard plans" is right
  about hard plans and wrong about standing posture: Opus 5 is the judgment
  default, and Fable 5 is a deliberate step up for the hardest planning.
- **Haiku's ceiling is context, not quality.** 200K against everyone else's
  1M. A descendant's survey skill reading a registry plus issues, PRs and
  branch lists across a portfolio of repos blows past 200K while looking
  entirely mechanical. Haiku is disqualified from anything that fans out,
  however mechanical it reads.

## The rule that decides every row: pin down, never up

A skill declares a **downgrade** and never an upgrade.

Pinning a cheap model on a mechanical skill saves real headroom. Pinning
`claude-opus-5` on a *judgment* skill does the opposite of what it looks like:
it **caps** a session the operator deliberately escalated to Fable 5, silently
turning their hard-plan escalation back into an ordinary one. So judgment-tier
work declares `effort: xhigh` and **no `model:` line at all** — it inherits
whatever the operator chose, which is at or above the judgment tier by
definition.

This also keeps the moving target small. Only the cheap tier's model ID
appears in frontmatter, so a model rename touches the working-tier files and
this table, not every gate in the fleet.

## Never cheapen a gate

Verification, planning, and promotion decide whether *other* work is correct.
A verifier on a cheap tier rubber-stamps, and a rubber-stamped green is worse
than no green at all — it is a false green with a signature on it, which is
the failure class this repo has already paid for (L-020).

The gates are `verify-loop`, `plan-feature`, `evolve`, and the `verifier`
agent — plus any a descendant adds (an overlord-shaped child adds
`goal-review` and `dispatch`, the one irreversible act in a conducting loop).
`scripts/test-hooks.sh` asserts that none of them declares a `model:` line and
that each declares `effort: xhigh`, skipping the names a given descendant does
not have — the top rung of the enforcement ladder, because a comment asking
nicely would not survive the next round of tidying.

## The mapping

| Tier | Model | Effort | Applies to |
|---|---|---|---|
| **Judgment** | *inherited* — Opus 5 by default, Fable 5 on the operator's escalation | `xhigh` | `verify-loop`, `plan-feature`, `evolve`, the `verifier` agent |
| **Working** | `claude-sonnet-5` | `high` | `work-loop`, `reflect`, `ship`, `recalibrate`, `replicate`, `bootstrap`, `add-skill`, `decision-lock`, `worktree-parallel`, the `memory-curator` agent |
| **Mechanical** | `claude-haiku-4-5` | `low` | ad-hoc subagents with a named, bounded input — single-file reads, extraction. No skill declares this tier; it is a choice made per `Agent` call. |

`memory-curator` is working tier because it *proposes* and `/evolve` disposes —
the propose/dispose separation already recorded in `docs/ARCHITECTURE.md` is
exactly what makes the downgrade safe. The verifier has no such backstop, so
it stays judgment.

## Verification status

The `model:` and `effort:` frontmatter fields are accepted by the platform's
skill and agent schemas (both allowlisted in `scripts/test-hooks.sh`, which
`/recalibrate` re-verifies against the skills docs). What this repo has
**not** yet observed is a declared field visibly changing the model of a live
run — that needs an interactive session, and this round was headless.

So: declared and CI-enforced, behaviorally unconfirmed. The first interactive
session that invokes a working-tier skill should confirm the switch actually
happens and date the observation here. Until then, treat the win as intended
rather than measured — recording it as verified would be precisely the
false-green move this file's own gate rule exists to prevent.
