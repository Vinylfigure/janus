# Merge policy — the operator boundary, as data

Policy-version: 3
Engine-sha256: a97e128dd21db3f88f6a6ebd95e4e172fc84b076bd297f44107c126448e7b98f

Locked by DL-2026-08-25-merge-boundary (docs/DECISIONS.md). The operator's rule,
2026-08-25: **maintenance-grade work builds and merges itself; only work that needs a
human decision waits for one.** Every merge engine in the fleet reads THIS statement of
the boundary; a divergent copy is drift (L-007).

## What never self-merges (the operator boundary)

A PR stays the operator's when ANY of these hold:

1. **Intent-tier**: its linked issue is an Intent or a Goal (`intent:` or `goal:` label, `Intent Phase …`
   title, or a `### Review tier` of `Check`/`Digest`), or its head branch is `intent/*`
   or `heartbeat/*` (goal-review proposals exist to be read before they land).
2. **A change that widens agent authority or weakens a gate** — judged by what the
   diff *does*, not by which file it lives in. Operator-only:
   - widening a tool grant (`--allowedTools`, `permissions:`, a new `Bash(...)` verb,
     a bare runner) or adding a credential/secret reference;
   - removing, disabling, skipping or loosening a check, fixture, hook denial, gate
     threshold, or branch/ruleset protection;
   - changing this policy, the auto-merge engine's own eligibility, or anything else
     that decides what may self-merge.

   `scripts/effect-policy.mjs` is the shared effect classifier, run from the
   trusted default-branch policy by CI and the merger. It recognizes permission
   set narrowing and replacement of an existing literal schedule with other
   behavior unchanged. Arbitrary executable edits, aliases, renames, missing
   source and unsupported syntax remain UNKNOWN; keywords are never proof.
   All machinery under scripts, .github and .claude is covered, including helpers.
   A protected/unknown change requires an APPROVED GitHub review by an operator
   listed in POLICY_OPERATOR_IDS, bound to the complete repository, PR, base,
   head, diff and policy identity. New terms require a fresh review. The exact
   review body is generated from the classifier binding; free text is not authority.

3. **A human question is open**: the PR or its linked issue carries `question:`,
   `loop:hold`, or `human-check:`, or an open `human-check:` issue references the PR.
   `machinery-change` is a routing hint only: it neither waives CI nor grants or
   independently blocks merging. Current effects and revision-bound review decide.
4. **A review requested changes**, or the ruleset requires an approval
   (`reviewDecision: REVIEW_REQUIRED`) — an engine merges, it never approves (L-116).
5. **CI is not fully green**, the PR is a draft, or its merge state is not clean
   (`mergeStateStatus` BLOCKED / BEHIND / UNKNOWN hold; a conflicting-but-eligible PR
   gets one rebase-request comment per head SHA, never a wait on the operator — the
   standing rule from overlord-ui#23).
6. **A read the decision depends on could not be completed.** Every gate input is
   tri-state — the value, or UNKNOWN — and UNKNOWN holds with the reason on the
   report line: the open-PR list, the label set, the open `human-check:` list, the
   PR's own labels / draft state / head SHA / review field, the linked issue, the
   changed-file list (which must match the PR's own `changedFiles` count), the diff
   of a boundary file, the PR's comment thread (idempotency), and the checks. A
   failed read is never "none exist" (overlord#275, D1/D2: a failed changed-file
   listing used to skip the boundary gate; a failed human-check listing used to
   read as "no human is looking").

**Identity is not a signal.** Agent sessions push under the operator's own login, so
`Vinylfigure` and `app/claude` are the only authors in the fleet and neither
distinguishes a hand-typed PR from an agent-opened one. No engine gates on author:
eligibility rests on the head prefix, the labels, the boundary classifier, and the
linked issue's tier — the rules above — never on who opened the PR.

Standing waivers by ID, each scoped to what its lock says and nothing wider:
`DL-2026-08-25-intent-build-merge` — the conductor merges the green,
verifier-checked overlord-ui Intent v0.3 package PRs (A/B/C) of 2026-08-25;
rule 2 still holds for workflow files.

Everything else — surveys, reflect/ledger commits, registry bookkeeping, `task:`
deliveries, fixes — is maintenance-grade and merges itself once green.

## Engines — one body, pinned

`scripts/auto-merge.sh` is ONE engine body under a per-repo configuration block.
The block between `# janus:merge-config:start` and `# janus:merge-config:end` is
the only part that differs between repos (merge method, head-prefix allowlist,
whether a linked issue is required and which kinds count, the rebase hint).
Everything below the end sentinel is the shared engine, and `Engine-sha256:` at the
top of this file is the sha256 of that body: `scripts/test-hooks.sh` recomputes it
and fails when the two disagree. A repo whose copy drifts from the contract fails its
own fixture suite; a policy change is a body change, so it bumps the pin, touches
this file, and therefore crosses the operator in every repo it governs (rule 2).
Propagation is a copy of the body plus the new pin — no engine reads another
repo at runtime, so no engine can be held on a cross-repo read.

- **This repo**: run 6-hourly by the `auto-merge` workflow with the repo's own
  Actions token (which needs `checks: read`, `statuses: read`, `actions: read` to
  see checks at all — `--probe` reports whether it can — and `issues: read` for the
  rule-3 listing of open `human-check:` issues; a `permissions:` block that omits
  `issues` sets it to none, and rule 6 then holds every PR, #288). Eligibility is by head
  prefix because most PRs here close no issue; `LINKED_ISSUE=optional`. Fixtures,
  including injected read failures for every gate input, live in
  `scripts/test-hooks.sh`. **Arming is an operator act**: copy
  `docs/setup/auto-merge.workflow.yml` to `.github/workflows/auto-merge.yml` and
  commit — workflow writes are operator-only from sessions, here as everywhere.
- **overlord-ui**: the same body under its own block (`claude/*` heads,
  `LINKED_ISSUE=required` with `task:` / `tier:auto` kinds, squash merges), run from
  its fleet-status workflow; its `docs/MERGE-POLICY.md` points here and pins the
  same `Engine-sha256`.
- **Other streams**: inherit the body and an unarmed workflow template from the
  janus scaffold when it carries them; arming stays a per-child operator act.
- **The GitHub App installation token** (#168, deferred) is the eventual fleet-wide
  runner; the body above is already the one implementation it would call.

## Rules every engine obeys

- An engine never applies a label whose meaning is "a human decided" —
  `machinery-change`, `intent:active`, waivers (L-122).
- Every act and every skip is reported with its reason; a skip is never silent.
- Once per head SHA: state lives in the PR's own lifecycle comments
  (`<!-- janus:automerge:v1 -->`), never a file store.
- A merge engine merges; it never approves. Review-requiring rulesets stay a human
  affair (L-116: a required approval on single-owner repos deadlocks the queue —
  rulesets must not require approvals on repos an engine serves).

## Connected execution source checkpoint

A Goal task must carry a valid versioned execution contract bound to its current primary owner, task content, upstream approved Goals and Intentions, explicit Plan and relationship revisions. The PR must name the same execution generation. The merger rereads this source authority immediately before merging in addition to checking the matched PR head and CI. Changed or unreadable sources, a human-owned task, an unresolved prerequisite, or an uninstalled source gate holds that delivery. A closed question is not permission: only a current affirmative typed decision unblocks its explicit dependents. Proposed discussions and unrelated denied requests do not hold ordinary approved work.


The merger requires the repository Actions secret `EXECUTION_SOURCE_TOKEN` for
Goal-linked deliveries. Use a fine-grained token restricted to the registered
repositories that can occur in the task's source graph, with **Metadata read,
Issues read and Pull requests read** only. This includes the registry and the
current task repository as well as any shared Goal, Intent, Plan or prerequisite
repository. The token must be approved for those repositories by their owner.
Across different resource owners, a single fine-grained PAT may not cover the
whole graph: consolidate the selected repositories under the intended owner or
supply an equivalently restricted read credential that can read every source.
Do not give it content, Actions or issue write permission, and do not substitute
`FLEET_TOKEN` as a fallback. Missing or denied source access holds the Goal task.

The workflow keeps `GH_TOKEN: github.token` for PR reads, lifecycle comments,
rebase requests and merge writes. Only the execution-gate subprocess receives
the source token under both PAT aliases, with ambient App credentials cleared.
This avoids the shared reader's `GITHUB_TOKEN`/App precedence selecting the
repository token or minting another credential. Maintenance deliveries without
a Goal source contract retain their existing policy. No secret is provisioned
and no workflow is enabled by installing this change.

## Signed approval setup

The app authenticates the operator and signs with an Ed25519 private key kept
only on its server (`POLICY_APPROVAL_PRIVATE_KEY`, with `POLICY_APPROVAL_KEY_ID`).
Pin the corresponding public SPKI PEM and numeric operator ID in the trusted
`.github/policy-operators.json`. Never put the private key in Git or CI.
The shipped empty key list explicitly means this signing channel is unconfigured;
it does not mean the proposed change itself needs a new permission.
Native APPROVED GitHub reviews remain available for configured
`POLICY_OPERATOR_IDS` when the reviewer is allowed to review that PR.
The signed channel supports the single-owner case where GitHub forbids self-review.
`policy-approval.mjs` emits a canonical signed merge approval receipt. The receiver
checks the full binding, public key and operator before
merging. All ordinary CI, source freshness and human task holds still apply.

Signed comment receipts do not implement durable revocation: comments are mutable.
The app must not advertise a revoke control for this channel. Changed revision
bindings invalidate approvals, and existing human holds still stop the merger.
A future revoke action requires a separate trusted monotonic active-authorization
store; replayable comment ordering is insufficient.

## Required check migration

The trusted gate publishes commit status `effect-policy` to the evaluated PR
head. Its target URL identifies the actual trusted gate-integrity workflow run.
Branch rules must replace the former `seatbelt` / `gate-integrity` job context
with `effect-policy` where that old context is required. This repository-setting
change is an explicit external setup step; these commits do not change rulesets.
The workflow uses statuses:write solely to publish its bound result and never
runs candidate code. A status is an observation, not approval: the merger still
recomputes effects and verifies the full current authorization before merging.
