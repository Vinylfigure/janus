# Adopt the Codex procedure candidate

`.agents/skills/janus-workflow/adoption/candidate.json` identifies `2026.10-codex-rc.2`: an additive,
procedure-only candidate for existing projects. Its file allowlist is the
complete payload. It reuses the shared procedure sources as versioned
snapshots inside one native skill directory. It is not a production release,
an installer, or evidence that any project's checks passed.

This revision includes the shared delivery contract required by the bundled
procedures. Prior rc.1 adoption receipts remain historical evidence for rc.1;
they do not certify this combined revision. Renew the source and installed-file
hashes and affected checks before adopting rc.2.

The original Janus layout still uses [CODEX.md](CODEX.md). For a new Claude
child, follow replicate/bootstrap with the ownership and automation gates
below. Do not overlay the entire template onto an existing project.

## Read-only assessment first

Save an assessment outside the target source tree before changing anything:

1. Bind a clean immutable Janus source commit and target baseline commit.
   Record dirty/untracked files and preserve them; use an isolated checkout.
   A dirty candidate, unknown ownership or overlapping local work holds the
   copy until resolved in the plan. Never reset a checkout to make it clean.
2. Inventory existing root and nested instructions, native skills, host
   settings, ledger location/format, actual aggregate/per-file checks, runtime
   versions and test dependencies. Read effective native configuration for
   the intended directory/invocation, including instruction fallbacks. Missing
   configuration evidence is UNVERIFIED; do not infer it from project files.
3. Record every allowlisted source-to-target mapping and SHA-256. Inspect each
   destination and ancestor for collisions and symbolic links (including case
   aliases on case-insensitive filesystems). Existing package files, linked
   paths or unexplained instruction conflicts hold the copy. Reconcile in a
   reviewed plan; never overwrite, follow a link, rename an existing lesson,
   or change permissions to get the package installed.
4. Keep all existing AGENTS/CLAUDE files, project skills, settings, workflows,
   verification scripts and learning history byte-for-byte. Review how the
   package fits their hierarchy. If existing rules conflict, preserve them and
   hold adoption until the owner resolves that specific conflict.

The assessment does not execute target commands, install tools, run models or
write into the target. Assessment is not approval or a readiness verdict.

## One reviewed adoption

Within an already authorized isolated target, copy only the manifest's files
to their listed destinations. Do not copy the template's `.github`, settings,
hooks, root instructions, ledger, source watermarks or Git history. Fill the
packaged PROJECT.md with the reviewed bindings. Keep the adapter as the entry
point; the shared references contain Claude mechanics that it explicitly
overrides. No custom runner or Codex hook is installed.

Save a receipt outside the payload: source/target commits, manifest hash,
source and installed file hashes, original tracked-file comparison, completed
binding hash, effective configuration evidence, and selected scope. Independently
review the diff. Native skill discovery can be checked without running a model;
discovery alone does not prove model compliance or automatic enforcement.

Prove the loop against the real application: run its existing aggregate check
and required behavioral checks, record actual execution counts and skips, then
make a deliberate bad edit in an isolated real source file. The applicable
quick check must fail for the expected reason. Restore the exact original bytes
and rerun the aggregate. Zero tests, unexpected skips, missing dependencies or
raw failing output prevent PASS even if a wrapper exits zero. Do not narrow a
project's aggregate to obtain green.

Keep command logs, negative controls and restored results. Record engineering
verification separately from human acceptance, semantic accuracy, real-world
evidence, permissions and production readiness. Synthetic fixtures do not
replace those gates. Report native hook/runtime enforcement as NOT INSTALLED;
report any unexecuted required check as UNVERIFIED. Bind review to the final
revision and diff. Changed evidence invalidates affected claims.

## New children and updates

New children require reviewed identity, rules and portable inheritance. A
template-looking title is a lead, not proof that a ledger is untouched. Never
retrofit an evolved project's IDs, statuses or source watermarks by guesswork.
After editing CLAUDE facts in a Janus-owned generated layout, regenerate
AGENTS with `scripts/generate-agents-md.sh`, then run its `--check` mode.
Never run that generator against an unowned AGENTS file.

Full-scaffold replication requires explicit selection of a coherent payload:
its checks depend on the declared workflows and Claude hooks/settings. If
those integrations are not selected and authorized, hold full replication;
do not create a partial scaffold that cannot pass its checks. This candidate
certifies only the additive existing-project path. `enabled: false` in a declaration does not disable cron, event
triggers or grants in copied workflow files. Review both surfaces; do not
change the parent repository's schedules during adoption.

Update by diffing the previous receipt against a newly reviewed source
revision, retaining project bindings and all project-owned files. No automatic
update or mass rollout is supported. Refresh hashes and affected checks after
any change. Keep existing lesson identities; inherited claims require review
and local evidence, not an imported promotion counter.

## Maintenance and publication

Choose a concrete downstream incident, reproduce the process failure, change
the smallest shared discipline, rerun the relevant adoption proof, and obtain
review at the resulting revision. A new mechanism needs demonstrated use.
Keep held work with its revision, reason, runnable done-means and next action;
do not create schedules or public issues merely to satisfy a procedure.

Before publication, verify repository identity, visibility, branch and exact
file scope. A public template must not receive private downstream names,
content, history or raw logs by accident. Publish only an explicitly reviewed
packet when authorized; local verification and a version label do not grant
that authority.
