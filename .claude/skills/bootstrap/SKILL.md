---
name: bootstrap
description: Specialize this Janus scaffold to a real tech stack - detect or ask for the stack, wire scripts/verify.sh to real lint/test commands, update the project facts in CLAUDE.md, and prove the verification loop closes.
when_to_use: Use when the project facts say NOT BOOTSTRAPPED or when adopting Janus into an existing codebase.
argument-hint: [optional stack hint, e.g. "python uv" or "node pnpm"]
effort: high
---

Turns the stack-agnostic template into a project that verifies itself. The
hooks and skills only start earning their keep once `verify.sh` runs real
commands — this skill wires that up and proves it.

## Hold in mind

1. Hooks only help if wired to real commands — placeholder checks are worse than none because they teach false confidence.
2. `verify.sh quick` runs after every single edit: it must finish in well under 10 seconds or it will be resented and disabled.
3. `verify.sh full` is the definition of "healthy": if it passes while the project is broken, every loop built on it is lying.
4. CLAUDE.md's concept budget applies to the facts you write: stack, commands, run instructions — one line each.

## Steps

For an existing codebase, first follow `docs/ADOPTION.md`: inventory ownership,
preserve its instructions/ledger/checks, and hold collisions. The numbered
scaffold rewrites below apply only to positively identified Janus-owned files.
Native Codex adoption uses the additive package and bound project commands;
it does not install the Claude hooks described here.

1. Heredity gate first: if CLAUDE.md is still titled `# Janus (template)` and this repo's origin is not the template, stop — run `/replicate retrofit` before bootstrapping; wiring verification onto an un-replicated copy seeds a dead memory loop (L-039). Then detect the stack: look for manifests (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `mix.exs`, `pom.xml`, `build.gradle`, `*.csproj`). Use the argument as a hint. If nothing is found (fresh project), interview the user: language, package manager, test framework, formatter/linter. Scaffold the minimal stack files they choose.
2. Wire `scripts/verify.sh`:
   - Replace the block between `# janus:bootstrap:quick:start` and `:end` with per-file checks keyed on file extension (format check, lint, typecheck of the changed file). Budget: <10s. Keep the template's `*.sh`/`*.json` arms — hook scripts exist in every child and deserve the same loop.
   - Replace the block between `# janus:bootstrap:full:start` and `:end` with the real suite: lint all, typecheck all, tests, build if applicable.
3. Rewrite the block between `<!-- janus:facts:start -->` and `<!-- janus:facts:end -->` in CLAUDE.md: stack + package manager; how to run verify (quick/full); how to run the app. If AGENTS.md is the Janus-owned generated mirror, regenerate with `scripts/generate-agents-md.sh` and run its `--check` mode before handoff. Never overwrite an unowned instruction file.
4. Prove the loop closes, both ways:
   - Run `scripts/verify.sh full` — must exit 0 on the healthy project.
   - Make a deliberately bad edit to a real source file (e.g. introduce a syntax error), confirm `scripts/verify.sh quick <file>` exits nonzero with useful output, then revert the edit.
5. If this project was replicated from a parent, review inherited entries in `.claude/memory/LEARNINGS.md` (`Status: inherited`): any that are stack-relevant here get re-marked `candidate` so `/evolve` can promote them.
6. Record the loop decision before closing (L-012, L-048). Only within authorized scheduling/publication scope, offer **work-loop** (daily-ish ready-task delivery) and **maintenance** (weekly evolve/recalibrate). For a Janus-owned manifest, record the decision in `.github/loops.yaml`; arm only the specifically authorized routine. Inspect actual workflow triggers and grants too: `enabled: false` alone does not make copied automation inert. Under local-only scope, save the decision and held follow-up locally without scheduling, opening an issue or changing permissions. Declining is valid.

## Before finishing

Paste: the passing `verify.sh full` output, and the failing-then-reverted
quick-check output proving the command catches the bad edit. Claim PostToolUse
coverage only if that host's installed hook was separately exercised. State the new
facts block verbatim and confirm CLAUDE.md is still within its concept budget.
Where the manifest is owned and in scope, state what `.github/loops.yaml` declares for work-loop and maintenance
(`enabled` + `armed_by` per entry) and, for anything left unarmed, the
authorized `task:` issue or local held record that carries the decision.
