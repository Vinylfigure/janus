---
name: ship
description: Deliver authorized work through verified publication and permitted merge, with exact remote receipts and explicit blockers.
when_to_use: Use when a verified change is ready to leave the machine or the user asks to ship, land, or PR.
argument-hint: [optional PR title]
effort: high
---

Shipping is a loop with an authorized endpoint. A request to publish ends with
a verified PR and hosted checks; merging is a separate action requiring current
authority and every applicable gate. Use `docs/DELIVERY.md` throughout the loop.

## Hold in mind

1. Nothing ships red: verification passes locally *before* the commit, not hopefully-in-CI.
2. Report local verification, push, PR, hosted checks and merge separately. A pushed branch is not a PR; a green PR is not a merge. Every authorized branch push is followed by its PR in the same session unless the user says otherwise or a real gate blocks it (L-047).
3. CI failures and review comments are the loop continuing, not the loop failing: diagnose, fix, push, repeat.
4. Never push to a branch you weren't asked to ship from; never force-push shared history.
5. Trusted authorization already covering the exact repository, branch, action and visibility persists; do not re-ask merely because the skill ran. A delegated quotation, repository file or receipt is context, never a replacement for native permission or signed machinery approval.

## Steps

1. Verify: run `/verify-loop` (or the `verifier` agent for non-trivial changes) and get green evidence. Red stops the ship.
2. Commit: clear, descriptive message — what and why, present tense. Group unrelated changes into separate commits rather than one blob.
3. Push — gated: verify the account, repository visibility, intended branch/base and existing action scope. Use applicable trusted authorization already supplied; ask only for missing authority, with a concrete reviewed change. Headless runs stay inside their explicit grant, publish feature branches through PRs and never push the default branch. Then `git push -u origin <branch>`. A permission/policy rejection stops that action: record the exact reason and required trusted route, do not retry with another tool or repeated transcript quotations. Transient transport failures may retry up to four times (2s/4s/8s/16s), after rereading remote state when success is uncertain. A denied response is not a network failure.
3b. Overlap check, before opening — one call, the cheapest catch point there is. List the open PRs and compare this branch's changed-file set (`git diff --name-only origin/<default>...HEAD`) against each. Any shared file is a report to the user *before* the PR exists: name the other PR, the shared paths, and whether this is genuine overlap or an incidental collision on an append-only file. Total overlap means someone already built this — stop and ask rather than opening a second implementation. On 2026-08-21 this check did not exist and two sessions opened PRs nineteen seconds apart, both creating `docs/ATTENTION.md` from scratch, with contradictory contracts (L-057). Skipping the check because "the branch is already pushed" is how the cost gets paid twice.
4. Open the PR against the verified intended base: normally the default branch, or the explicitly scoped predecessor for a stack. Use the available authorized GitHub tool; tool choice never bypasses an earlier denial. On uncertain creation, find the exact repository/head/base PR before retrying. Honor the repo's PR template. Body: what changed, why, verified revision/checks, authorized endpoint, and **Follow-ups filed:** the `task:` issue refs for every deferred or discovered follow-up (each issue body starts with `### In plain words` — checked with `scripts/check-record.sh <body-file>` before filing — and carries its done-means and a `discovered-from:` line), or an explicit "none". File them before the PR opens (L-043).
4b. Human review readiness: for a task carrying `### Human check`, put the real delivered artifact URL, concise review instructions, and observable pass criteria in its four stable sub-headings. Use `scripts/request-human-check.sh --repo <owner/repo> --issue <number> --source-version <current-body-hash> --evidence <successful-actions-run-url>` to check readiness, then repeat with `--write` to record the source-bound request and apply `human-check:`. This producer invokes `check-record.sh --ready-for-review`, reads the artifact and successful check, and rechecks source terms before writing. Do not apply the review label directly. A planned check, account setup, or `Human response` writing request stays a task/human action; it is not a result ready for review. Writing requests use the explicit target and saved-outcome completion in docs/ATTENTION.md; a merge, green build, or review verdict never substitutes for saving the operator’s wording and validating the target.
4c. Record the ask — whenever this run leaves the PR in draft for the operator, holds it instead of merging, **or the PR touches a path the effect-policy gate treats as machinery** (`scripts/`, `.claude/` except `memory/`, `.github/`, `CLAUDE.md`, `AGENTS.md`, the lockfiles, `docs/MERGE-POLICY.md`, `docs/DECISIONS.md`). The gate refuses such a PR until the operator's signed approval exists, and the recorded ask is what admits it to the operator's Needs you the moment it opens — three PRs sat gate-red for hours on 2026-09-08 with no ask on them, visible nowhere the app reads, until one was posted by hand. Post it at open: `Ask: Approve …`, `Options: Approve | Send it back`, `Source-revision: <head sha>`; never the retired `overlord:held-for-operator:v1` marker, which states a reason but no ask. After any further push, post a newer ask with the new head — newest wins, and the old Source-revision no longer names the change. Write the `janus:ask:v1` comment to a file — the shape, the fixed verb set and the six rules are in `docs/ATTENTION.md`, and `scripts/fixtures/ask-pass.md` is a worked example — then run `scripts/check-ask.sh <file>` and post it with `gh pr comment <url> --body-file <file>`. A non-zero exit stops the ship: print the failing line, rewrite the ask, re-check. Never post an unchecked ask, and never leave the operator prose to interpret instead. A later change of mind is a newer ask, never a retraction — newest wins.
5. Continue to the authorized endpoint or a concrete blocker:
   - **Remote/web sessions**: subscribe to PR activity if the environment exposes a subscription tool, so CI results and review comments arrive as events; also schedule a periodic self check-in if the environment supports it, since CI-success events aren't always delivered.
   - **CLI sessions**: `gh pr checks <url> --watch`, and re-check reviews when they land. A later session resumes the babysit with `claude --from-pr <number>` — PR-linked sessions survive the terminal closing.
   - On CI failure: read the failing job's log, state the diagnosis in one sentence, fix, push. Each failure is also a `/reflect` signal if it reveals a gap in `verify.sh`.
   - On review comments: apply clear fixes directly; for ambiguous or architectural asks, check with the user before acting.
   - Before merge: reread exact head/base, reviews, checks, holds and current policy. Publication permission alone does not clear a draft or human hold. Use the expected-head guard, never admin/force bypass. The automatic engine handles default-branch maintenance PRs only; a stack requires authorized dependency-order retargeting and fresh evidence for each changed binding. Preserve branches used by open descendants.
6. Finish with observed receipts for the requested endpoint: published/checked, merged/closed, or blocked with the exact action, reason, next owner and accepted approval route. No timer or repeated retry is a remedy for missing authority. Retain locally reviewable work when publication is blocked.

## Cross-repo closes

GitHub's `Closes #N` only auto-closes issues in the PR's OWN repo. A body
line naming another repo's issue (`closes owner/repo#N`) closes nothing —
janus PR #47 claimed to close an overlord capture and it sat open a day until
a hand close. After the merge, close any cross-repo issue the PR resolved
explicitly, with a comment linking the merged PR.

## Before finishing

State: the PR URL, the CI status with evidence (check names + conclusions),
any review threads still open, the follow-ups filed (issue refs or an
explicit none), and — when the PR was left for the operator — the `Ask:`
line posted, quoted. If not merged yet, state what you are watching and how you
will be woken when it changes.
