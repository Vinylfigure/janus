---
name: replicate
description: Stamp a new project from this Janus template - create the child repo, carry portable learnings forward as inheritance, rewrite identity, and hand off to /bootstrap. Confirms name, visibility, and location before creating anything.
when_to_use: Use when the user wants to start a new project from this scaffold.
argument-hint: [new project name | retrofit]
effort: high
---

The lineage loop. Children start with the scaffold *plus* everything this
repository has learned that is true anywhere — heredity, not just copying.

## Hold in mind

1. Only `Scope: portable` knowledge crosses repositories — project-specific rules in a child are noise that erodes trust in the whole memory system.
2. Knowledge is inherited; verification state is not. Ledger entries cross; run stamps and source watermarks reset.
3. Inherited entries arrive as `Status: inherited`, not `candidate`: the child re-earns promotion with its own evidence. Rules entering the child's CLAUDE.md are the one exception — they arrive active, so each one is gated on the user's explicit yes at replicate time: the generation boundary is a review gate, because persisted rules files are an injection channel and a poisoned rule would otherwise propagate to every descendant unreviewed.
4. The child must not keep the template's identity: name, facts block, and README head must be rewritten before first commit.
5. The child's first session should run `/bootstrap` — say so explicitly in the handoff.

## Steps

1. Interview the user (skip anything already given in the argument): project name, one-line purpose, expected stack (or unknown), GitHub visibility (public/private) or local-only. Gate: restate name, visibility, and destination path, and wait for an explicit yes before creating anything.
2. Prepare the child locally first in a new, isolated directory. Full-scaffold
   replication requires a reviewed, coherent payload: its checks depend on the
   declared workflows and Claude hooks/settings. If those integrations have not
   been specifically selected and authorized, hold full-scaffold replication;
   do not create a partial scaffold that cannot pass its own checks. The
   existing-project package in `docs/ADOPTION.md` is the procedure-only path.
   Copy the selected files without the parent's Git metadata and initialize a
   fresh local repository. Do not create a remote from the raw
   template first: copied event/scheduled workflows can run before the later
   declaration reset. A remote destination is a separate authorized delivery
   step after the reviewed local candidate and its checks exist.
3. Apply heredity, in the child:
   - From the parent's CLAUDE.md `janus:rules` block, present each rule whose ledger entry is `Scope: portable` and copy it into the child's rules block only on the user's explicit yes (keep the `(L-NNN)` citations). A declined rule is not lost — its ledger entry still crosses as `inherited` below.
   - From the parent's `LEARNINGS.md`, copy every `Scope: portable` entry (any Status except `retired`) into the child's ledger, re-marking each `Status: inherited`.
   - Copy nothing project-scoped. When in doubt, leave it behind — heredity is selective.
   - Leave `.claude/memory/recalibrated-at` absent in the child: the stamp certifies a completed `/recalibrate` run, and a provisioning stamp is a false green (L-020) — absence makes the staleness nudge fire honestly once the child bootstraps.
   - Truncate the child's `.claude/memory/sources-seen.md` to its header and marker. A fresh repo has verified nothing; inheriting the parent's watermark would make it skip sources it has never read.
   - Reset the child's declarations: in `loops.yaml`, set every entry `enabled: false` and clear `armed_by` (arming is re-earned at bootstrap, L-048). A disabled declaration does not disable a copied workflow's schedule or event trigger. Before remote delivery, review the actual triggers and grants of every selected workflow against the authorized scope; unapproved execution holds delivery. Preserve the coherent payload and issue forms; rewrite `CODEOWNERS` to the child's owner. Do not alter the parent's automation.
4. Rewrite identity in the child: CLAUDE.md title + facts block (project name, purpose, `Stack: NOT BOOTSTRAPPED — run /bootstrap`), README title and first paragraph.
5. In a positively identified Janus-owned generated layout, regenerate `AGENTS.md` with `scripts/generate-agents-md.sh` and run `scripts/generate-agents-md.sh --check`. Do not overwrite custom or unowned instructions. Commit in the child: `chore: replicate from janus template (N learnings inherited)`.
6. If remote creation/publication is authorized, publish only the reviewed local candidate to the confirmed destination and visibility. Otherwise keep it local. Hand off: tell the user to open a session in the child and run `/bootstrap`, and list what was inherited and which host integrations were actually installed.

## Retrofit (a copy that skipped replication)

First inventory ownership and history using `docs/ADOPTION.md`. The following
fingerprint is only a lead, not authorization to reset an evolved child.
Require positive evidence of an untouched template copy; unknown ownership,
custom instructions or accumulated local learning holds retrofit for a reviewed
adoption plan. Never renumber existing IDs or discard downstream history.

The template-copy fingerprint: CLAUDE.md still titled `# Janus (template)`,
a ledger carrying the parent's `promoted:*` and retired statuses, a non-empty
`sources-seen.md`, and an origin that is not the template. GitHub's "Use this
template" button produces exactly this — it copies files and runs none of the
transforms above, leaving the memory loop wired but dead (L-039). On
`retrofit`, apply steps 3–5 in place instead of creating anything: re-mark
parent-authored entries `Status: inherited` (retired entries stay retired),
run the rules-block review gate from step 3, truncate `sources-seen.md`,
delete any `recalibrated-at` the copy carried, rewrite identity, and commit
`chore: retrofit heredity from janus template (L-039)`.

## Before finishing

List each inherited learning id with a one-line justification of why it is
portable. Confirm the child's CLAUDE.md carries the child's name (not
"Janus (template)") and that its rules block is within the cap of 12.
