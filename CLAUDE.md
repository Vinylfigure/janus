# Janus (template)

Concept budget: 1 bullet = 1 concept, ≤20 concepts in this file. `/evolve` must
merge or retire a rule before adding past the cap. Details live in skills — they
load on demand; this file is always in context, so every line must earn it.

## Prime directives

- Plan before code: for non-trivial work, use plan mode or `/plan-feature`.
- Never claim done without a closed loop: run `/verify-loop` or the `verifier` agent.
- When corrected, or when verification fails, a lesson exists — run `/reflect` before the session ends.
- Before any complex task, verbalize the 3–5 invariants you must hold in mind.
- Delegate exploration and verification to subagents; keep this thread's workspace clean.
- Parallel experiments go in git worktrees (`/worktree-parallel`), never on the main checkout.
- Keep this file concept-dense; procedures belong in skills, facts belong here.

## Project facts

<!-- janus:facts:start -->
- Stack: NOT BOOTSTRAPPED — run /bootstrap to specialize this scaffold.
<!-- janus:facts:end -->

## Learned rules

<!-- janus:rules:start -->
<!-- Populated only by /evolve. Cap: 12 rules. Each cites a LEARNINGS.md id. -->
<!-- janus:rules:end -->

## Map

- Skills: `.claude/skills/` — bootstrap, replicate, reflect, evolve, plan-feature, verify-loop, worktree-parallel, add-skill
- Agents: `.claude/agents/` — explorer, planner, verifier, memory-curator
- Memory: `.claude/memory/LEARNINGS.md` · Verify: `scripts/verify.sh` · Docs: `docs/`
