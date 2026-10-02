# Codex compatibility

Open this repository in Codex and use `$janus-workflow`, or ask for the Janus
plan, verify, reflect or evolve workflow. The single repository skill loads
the existing procedures on demand. `AGENTS.md` is generated from a small
Codex pointer plus the verbatim `CLAUDE.md`; shared rules and learning history
keep one source. Claude's skills, hooks and settings keep their existing role.

For an existing project, use the versioned, additive candidate in
[ADOPTION.md](ADOPTION.md) and `.agents/skills/janus-workflow/adoption/candidate.json`. Its reviewed bindings
preserve the project's own instructions, ledger and verification commands.
That procedure-only package installs no Janus policy gate or native hooks.

Run quick checks explicitly after edits and full verification before closing a
Codex task. Until bootstrap specializes the dispatcher, green means scaffold
checks passed; application behavior needs its own tests. Missing `jq` makes a
JSON quick check fail instead of silently claiming success.

The adapter preserves the five-round retry bound, reflection in the originating
session, immutable existing ledger IDs, independent evidence counts and
revision-bound approval. It leaves Claude's signal file alone. When scope is
local-only, plans, verification output, held proposals and follow-up drafts stay
on disk; a headless procedure does not authorize external delivery.

Ledger reconciliation preserves legacy IDs and checks whole dated slugs for
uniqueness. Harvest compares lesson titles across both ID formats, so adopting
Codex does not split an existing lesson into a second history entry.

Native `AGENTS.md`, `AGENTS.override.md`, `.agents/` and `.codex/` changes are
machinery at every repository depth, with conservative case-insensitive matching.
They require current review unless a transformation is proven safe;
missing content holds the action. This is classification only: no sandbox,
permission, hook trust, signed approval, workflow or schedule is configured here.
Symbolic links at machinery paths are unsupported: either revision containing
one makes the shared reader hold the change, including a later edit to an
ordinary-path link target. This slice does not resolve linked instruction trees.

Before adopting this bridge, read the effective Codex configuration for the
intended working directory, profile and CLI overrides. Save its resolved
`project_doc_fallback_filenames` as a JSON array (`[]` for a verified default),
then run `node scripts/effect-policy-cli.mjs --codex-fallbacks=<array-file>`.
Unavailable effective configuration or a nonzero result means UNVERIFIED:
hold execution. Recheck when the directory or configuration changes. Arbitrary
fallback filenames are unsupported until their literal basenames are registered
in `CODEX_FALLBACK_FILENAMES` inside the reviewed policy module; its digest binds
the registration. GitHub classification cannot inspect a host's global, profile
or CLI settings and does not claim coverage of unregistered names.

Independent verification reports PASS only when every required acceptance
criterion has evidence at the identified revision. An observed failure is FAIL;
an unavailable required check is UNVERIFIED. Raw failing output overrides a
wrapper's zero exit. A local-only held artifact can record a non-required
follow-up, with revision, remaining work, blocker, runnable done-means and next
action, but cannot waive a required criterion or imply publication.

## Platform check — 2026-10-01

Official [skills documentation](https://developers.openai.com/codex/build-skills)
confirms repository discovery under `.agents/skills`, required name/description
metadata and loading full instructions on demand. One adapter is enough for
this slice; copying all Claude skills would also import their delivery and
tool assumptions.

Codex already provides [non-interactive execution](https://developers.openai.com/codex/noninteractive)
through `codex exec`, JSONL events through `--json`, final-message files through
`--output-last-message`, and optional schema-constrained output. Use these
native mechanisms when a CLI run is authorized. A saved final response does
not replace command evidence, current source authority or revision review.

Codex also has native [hooks](https://developers.openai.com/codex/hooks),
including project `.codex/hooks.json` and lifecycle events. Non-managed hooks
require trust in their current definitions. Janus's Claude post-edit hook
expects `tool_input.file_path` and `CLAUDE_PROJECT_DIR`; recognizing an Edit
matcher does not establish payload compatibility with Codex patch operations.
This slice installs no Codex hooks and claims no automatic per-edit or Stop
coverage. A future hook adoption needs representative payload fixtures and
explicit trust review, without changing the approval boundary.

Installed CLI observed: `codex-cli 0.153.4`. Its help exposes the native execution
flags. The read-only [app-server skills/list method](https://developers.openai.com/codex/app-server)
can check discovery without starting an agent run. Discovery is narrower than
end-to-end evidence that every model follows a procedure correctly.

## Scope of this slice

This is local workflow reuse. It adds no UI, orchestrator, worker loop or
scheduled consumer. Remote actor authorization is a separate review surface;
a green local suite cannot approve it. Recheck
platform facts before adding native integrations; keep dated vendor facts out
of durable learning rules.
