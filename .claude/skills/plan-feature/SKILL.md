---
name: plan-feature
description: The plan-first workflow for any non-trivial change - explore with subagents, write a plan with explicit "done means" verification criteria, get sign-off, implement, verify.
when_to_use: Use for features, refactors, or any change touching more than a couple of files.
argument-hint: [what to build or change]
effort: xhigh
---

The Cherny flow: plan mode first, code second, and a closed feedback loop at
the end. Exploration is delegated so this thread's workspace stays clean for
the actual reasoning.

## Hold in mind

1. No code until a plan exists — and a plan without verification criteria is not a plan.
2. "Done means" is an exact command or observation, not a vibe ("tests pass after `verify.sh full`", not "it works").
3. Subagents explore; this thread decides. Do not fill this context with file dumps.
4. Simple tasks skip ceremony: if this is genuinely a one-file, obvious change, say so and just do it with the inner verify loop.
5. The plan is an audit artifact: the Predicted-failure-modes section and its end-of-run accounting are how someone who wasn't in the room — the verifier included — confirms the adversarial pass actually ran.

## Steps

1. Restate the requirement in <= 3 sentences, then list the invariants at stake (what must not break, what must remain true). This is your working set — refer back to it.
2. Classify the known unknowns — everything the plan depends on that you don't yet know — and route each to its resolution: codebase question → an exploration subagent; requirement or preference → interview the user; feasibility → a small prototype or probe. In an unfamiliar domain, add a blind-spot pass: "what would an expert check that I haven't thought to?" — route those too. An unrouted unknown is a silent assumption.
3. Explore via subagents, in parallel where independent: a read-only exploration subagent to map the relevant code, and for large features a second subagent drafting an approach independently. Subagents return conclusions; file dumps stay out of this thread.
4. Write the plan: **Approach** (the design, the key tradeoff you made, and the alternative you rejected — one line on why), files to touch, sequencing, **Predicted failure modes:** 2–3 falsifiable predictions ranked by likelihood, drawn from ledger history and the task's shape ("the merge will conflict in X", never "merges are risky"), **Unknowns:** anything still open and the route that resolves it, **Deferred:** every part of the requirement not in this session's scope, each with a one-line done-means (deferred is captured, never dropped — L-037), and **Done means:** the exact command(s)/observation(s) that prove success.
5. Get sign-off — plan-mode exit or an explicit user OK. If the user redirects, that is a learning signal; remember it for `/reflect`. In a headless run there is no one to sign off: proceed on the plan as written, record the plan's Predicted-failure-modes and Done-means in the PR body so the operator reviews them there, and never widen scope beyond the task that dispatched the run.
6. Implement. The PostToolUse hook gives you per-edit feedback; fix failures as they surface rather than batching them.
7. Hand the "done means" criteria to `/verify-loop` and drive it to green. Hand the verifier the plan too: a missing Predicted-failure-modes section, or a finish that never accounts for those predictions, is a FAIL — the ritual is auditable, not optional.

## Before finishing

State: the invariants from step 1 and whether each held; which predicted
failure modes actually bit and which predictions were wrong (misses are
`/reflect` material); the "done means" command and its actual output. If you
cannot paste green output, the feature is not done — say exactly what is
still red.

Then the descope gate: every Deferred item, and every follow-up discovered
mid-implementation, is either filed as a `task:` issue in this repo — title
`task: <outcome>`, body carrying its done-means and a
`discovered-from: <plan/PR/issue ref>` line — or declared dead in one line.
A transcript is not a backlog (L-043).
