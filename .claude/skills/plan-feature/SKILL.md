---
name: plan-feature
description: The plan-first workflow for any non-trivial change - explore with subagents, write a plan with explicit "done means" verification criteria, get sign-off, implement, verify. Use for features, refactors, or any change touching more than a couple of files.
argument-hint: [what to build or change]
---

The Cherny flow: plan mode first, code second, and a closed feedback loop at
the end. Exploration is delegated so this thread's workspace stays clean for
the actual reasoning.

## Hold in mind

1. No code until a plan exists — and a plan without verification criteria is not a plan.
2. "Done means" is an exact command or observation, not a vibe ("tests pass after `verify.sh full`", not "it works").
3. Subagents explore; this thread decides. Do not fill this context with file dumps.
4. Simple tasks skip ceremony: if this is genuinely a one-file, obvious change, say so and just do it with the inner verify loop.

## Steps

1. Restate the requirement in <= 3 sentences, then list the 3-5 invariants at stake (what must not break, what must remain true). This is your working set — refer back to it.
2. Explore via subagents, in parallel where independent:
   - `explorer` to map the relevant code (if a Graphify graph exists — check for `graph.json` or the `graphify` command — tell the explorer to query it first; graph answers are concept-dense and cheaper than file dumps).
   - `planner` as well, for large features, to draft an approach independently.
3. Write the plan: approach, files to touch, sequencing, risks, and **Done means:** the exact command(s)/observation(s) that prove success.
4. Get sign-off — plan-mode exit or an explicit user OK. If the user redirects, that is a learning signal; remember it for `/reflect`.
5. Implement. The PostToolUse hook gives you per-edit feedback; fix failures as they surface rather than batching them.
6. Hand the "done means" criteria to `/verify-loop` and drive it to green.

## Before finishing

State: the invariants from step 1 and whether each held; the "done means"
command and its actual output. If you cannot paste green output, the feature
is not done — say exactly what is still red.
