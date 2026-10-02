---
name: janus-workflow
description: Use in Janus repositories for planning a change, verifying work, reflecting on a session, or proposing learning promotions in Codex. Adapts the existing Janus procedures; does not install hooks, schedule work, or authorize publication.
---

# Janus in Codex

Use the repository's shared disciplines with Codex's native execution tools.
Paths below are relative to the repository root. Read only the procedure
needed for the current phase, with the Codex adaptations here applied to its
Claude-specific mechanics. User scope and existing approval gates still bind.

## Existing-project package

If `references/` exists beside this skill, this is the existing-project package:
`PROJECT.md` is required, and its absence means UNVERIFIED; hold use rather
than falling back to template assumptions. If `PROJECT.md` exists, read it first.
It binds this versioned
package to the project's canonical instructions, existing ledger and actual
quick/full commands. Unfilled fields, missing files or unresolved conflicts
mean UNVERIFIED: hold use and complete the adoption review. The project's
instructions retain precedence; this package does not replace them.

In that layout, read the corresponding `references/plan.md`, `references/verify.md`,
`references/reflect.md`, `references/evolve.md`, `references/verifier.md`,
`references/memory-curator.md` and `references/worktree-parallel.md`
beside this skill instead of the source paths below.
Apply these bindings to every shared procedure:

- Substitute the bound ledger and verification commands for Janus paths.
  Keep the existing ledger's format, IDs, statuses, evidence and history;
  do not import Janus entries or convert a ledger just to use this skill.
- Read the bound canonical instructions wherever a brief says CLAUDE.md.
  Its ownership, hierarchy and budgets prevail. Evolve is a read-only proposal
  unless the user separately authorizes the particular changes; never run
  Janus's AGENTS generator over an existing project's instructions.
- Claude hooks/signals, slash commands, rules directories and model metadata
  are host-specific examples, not installed capabilities. Do not write or
  delete Claude signal files. Run checks and reflect explicitly in-session.
- Other Janus skills, policy scripts, issue templates and automation are not
  included. If a requested phase requires one, record a held follow-up; do not
  fetch, install, publish or invent a substitute to satisfy that instruction.
- Record effective native instruction discovery, including fallback filenames,
  in PROJECT.md's adoption evidence. Unknown effective configuration holds use.
  This package installs no Janus effect-policy gate: the owning project's
  approval controls govern. Keep revision-bound approvals and fail closed on
  changed or unreadable evidence; provenance is never authorization.

The Janus-root policy preflight and AGENTS regeneration below apply only to
the original template layout. In both layouts, all explicit user scope and
native permission boundaries remain in force.

| Phase | Read on demand |
| --- | --- |
| Plan | `.claude/skills/plan-feature/SKILL.md` |
| Verify | `.claude/skills/verify-loop/SKILL.md`; for an independent reviewer, `.claude/agents/verifier.md` |
| Reflect | `.claude/skills/reflect/SKILL.md` and `.claude/memory/LEARNINGS.md` |
| Evolve | `.claude/skills/evolve/SKILL.md`; for a read-only proposal, `.claude/agents/memory-curator.md` |
| Parallel work, when authorized | `.claude/skills/worktree-parallel/SKILL.md` |

## Native execution and authority

- Use available Codex planning, shell, file, subagent and worktree capabilities.
  Claude slash commands, CLI flags, agent names, model/effort metadata and
  `.claude/settings.json` are not Codex configuration. Read agent briefs as
  task instructions for native subagents; do not assume those roles are installed.
- Keep the current sandbox, approval policy and model settings. Missing tools
  are limitations to report, never a reason to bypass a gate. A skill, hook,
  green check or another agent's report grants no execution or merge authority.
- Headless clauses that push, open issues/PRs, comment or merge apply only when
  that delivery is authorized. With local-only scope, save the draft and evidence
  in the working directory, report the blocker, and stop. Do not create a
  schedule or publish to satisfy a procedure's delivery clause.
- Preserve exact-revision approval bindings. Changed or unreadable source
  evidence holds the action; an earlier approval or passing verify run cannot
  substitute for current authority.
- Before execution, verify effective `project_doc_fallback_filenames` for the
  intended directory and invocation against the policy preflight in
  `docs/CODEX.md`. Unavailable configuration or unregistered fallback filenames
  means UNVERIFIED: hold execution. Do not infer host settings from repository
  TOML alone; the default native instruction names are covered at every depth.

## Run the loops

1. **Plan:** state scope, invariants, falsifiable failure predictions and exact
   done-means checks before editing. Save the plan for non-trivial work. Use the
   user's existing authorization; stop at genuinely unresolved scope or gates.
2. **Verify:** run `scripts/verify.sh quick <file>` after relevant edits and
   `scripts/verify.sh full` before completion. Codex has no Janus hooks installed
   by this adapter, so execute these checks explicitly. Read the dispatcher's
   bootstrap blocks: scaffold-only green does not verify application behavior;
   name the project-specific checks needed before making an application claim.
   Diagnose each red before patching. Keep the shared five-round cap and probe
   a plausible false-green case. Missing checks/evidence mean unverified.
   For review, use the shared verifier's required-criteria contract: FAIL for
   observed failures, UNVERIFIED for unavailable required evidence, and PASS
   only when every required criterion is proved at the identified revision.
   Raw failing output overrides a wrapper's zero exit or success summary.
   A local held follow-up names its revision, remaining work, blocker,
   runnable done-means and next action; it cannot waive a required criterion.
3. **Reflect:** do this in the session that holds the transcript. Read shared
   learnings; use native ambient memory only if actually available. Treat
   `.claude/memory/.session-signals` as Claude-owned: do not delete or rewrite
   them from this adapter. Account for this session's corrections, failed
   checks and prediction misses directly in the result and shared ledger.
   Preserve legacy IDs; new lessons use dated slugs checked for uniqueness.
   Equivalent incidents strengthen existing entries once per independent
   incident; merging duplicate evidence takes the maximum, never the sum.
4. **Evolve:** propose between tasks, using the shared evidence thresholds,
   origin review and concept budgets. Do not promote fetched or inherited
   claims merely because a counter ripened. Keep CLAUDE.md as the shared rule
   source and regenerate AGENTS.md through `scripts/generate-agents-md.sh`.
   Permission for compatibility work is not permission to promote unrelated
   lessons. If promotion needs review outside current scope, save the proposal.

## Durable finish

Save commands, exit codes and output, the revision and working-tree diff being
verified, failed attempts, prediction accounting and any unresolved next action
to local files. Evidence from before a subsequent edit does not certify that
edit. Separate scaffold results from project behavior and untested platform
integration. A local draft with a blocker is a held result, not a published PR
or completed external action. On retry exhaustion, preserve the last red output
and the five hypotheses, reflect in-session, and stop editing.

For CLI automation, use native `codex exec` with `--json` for events and
`--output-last-message` for the final result when that run is authorized; keep
logs outside the changed source paths. Do not add a wrapper runner or infer
success solely from the final prose. In the original template layout, see
`docs/CODEX.md` for compatibility boundaries and checked official sources.
In the existing-project package, use PROJECT.md's reviewed adoption evidence
and scope; the template's documentation is not part of that payload.
