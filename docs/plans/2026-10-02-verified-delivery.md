# Verified delivery across projects

## Requirement and invariants

Carry authorized work from local verification to a verifiable PR, hosted checks,
and an explicitly permitted merge. Reuse applicable trusted authority; do not
mistake a delegated quotation or a local receipt for a native platform grant.
Keep publication, merge permission, and signed machinery approval separate.

No new credential, scheduler, branch-prefix eligibility, tool grant, protection
bypass or default-branch push. Preserve public/private boundaries. A failing or
unreadable gate cannot become permission. Preserve dependencies and exact heads.
The owner requested this shared delivery improvement; routine implementation
proceeds under that instruction, with independent verification and the existing
machinery approval gate before any merge.

## Approach

Use the existing ship/work-loop and scheduled merge engine. Add a shared delivery
contract for authority scope, delegation, separate progress states, denial handling,
stack retargeting and observed receipts. Repair three source-inspected engine
defects with executable mocked-GitHub regressions: ready stacks bypass the ready
step's base restriction; a final linked-task reread holds even on `eligible`; and
a recorded policy hold suppresses later reevaluation on the same head.

The engine must merge only into the current default branch, retain dependency
branches, and recheck target/head before mutation. Reevaluate an old hold only
through all current gates; suppress repeated hold/rebase comments separately from
successful merge idempotency. No new generalized publishing service or fabricated
authorization token: the platform already owns those permissions and transports.

Files: ship, plan-feature, work-loop and side-effect-skill guidance; delivery
contract; auto-merge engine and pin; mocked engine tests wired into the existing
full aggregate; this plan and one sanitized reflection entry.

## Predicted failure modes

1. High: the final linked-task read returns the success sentinel and is still
   treated as a hold. RED fixture must show no merge; repaired fixture must merge
   only when both reads remain eligible, while a changed/failed second read holds.
2. High: a ready stacked PR bypasses draft readiness and deletes a dependency
   branch. RED fixture must show the wrong merge; repaired fixture must make no
   merge/delete call. A base change between reads must also stop.
3. Medium: a previously held head never resumes, or a naive repair floods comments
   or skips current policy. Tests must show fresh policy/CI evaluation, one hold
   comment per head, unchanged failures still held and terminal merge deduplication.

Adversarial pass: multiple PRs share branches, targets change concurrently, a
headless session cannot ask, and reads may fail. Preserve branches; re-read
head/base/default and head-match the merge; leave unsupported authority blocked
with one actionable receipt; deny every unreadable gate. Native GitHub APIs do
not offer an atomic expected-base guard here; the final read narrows that race
but does not claim to eliminate it.

## Additional finding during implementation

A successful merge command is not proof of a completed merge: a native queue may
accept the request without merging. Add a RED regression and observed state
readback. Emit a terminal merged receipt only for an actual merged state with the
same expected head, target branch and readable merge commit. Failed or pending
readback remains unconfirmed; do not change queue policy or widen merge scope.
Reject malformed linked-task fields on either read as well: fixing the success
sentinel must not turn a partial payload into a newly permitted merge.

## Unknowns and routes

- Engine behavior: reproduce with stubbed `gh` subprocesses before implementation.
- Existing platform capability: native Git/GitHub already supply publication and
  checks; Janus supplies workflow discipline. Native approval rejection cannot be
  overridden by repository code or a second tool.
- Overlap: existing resume-agent work is PR #78; do not duplicate its transport.
  Ledger edits overlap the append-only file in PR #80; use a unique new entry.
- Verification side effects: inspect full aggregate; run in an isolated checkout
  with temporary fixtures and denied network before publication.

## Deferred

- Child rollout and delivery monitoring beyond the current `claude/` detector:
  tracked in [task #84](https://github.com/Vinylfigure/janus/issues/84), held with done-means covering paginated/unknown reads, visible
  `codex/` branches, unchanged merge eligibility and per-child reviewed adoption.
  Existing PR #80 also touches the detector; do not overwrite that work here.
- A pre-existing malformed changed-file row can evade path classification:
  tracked in [task #85](https://github.com/Vinylfigure/janus/issues/85), reproduced
  offline on both base and candidate. It needs strict row validation and separate
  verification; this change does not claim universal malformed-input rejection.
- Creating a native authorization bridge from transcript quotes: declared dead
  for this repository. Only the execution platform can supply trusted authority.
- Automatic merge of arbitrary stacked branches: declared dead for this slice.
  Stacks stay held until explicitly retargeted and reverified in dependency order.

## Done means

`bash scripts/verify.sh full` passes including real engine execution against
mocked `gh`, with no network or remote writes. An independent verifier runs the
same aggregate and targeted counterexamples, audits this plan and reports all
uncovered claims. New history contains no private project names, paths or task
transcripts. Publish a feature PR, read exact remote head and actual hosted
checks, and post a checked revision-bound ask if machinery approval remains held.
Report local, pushed, PR-open, CI and merged/blocked states separately. Do not
claim cross-project rollout merely because the template PR exists.

## Outcome accounting

All three original predictions reproduced in actual engine execution with mocked
GitHub: the first RED aggregate ran 22 engine methods with 36 failing assertions
or subcases. The initial repair passed those 22 methods. Added result-readback
regressions produced a second RED of 24 methods with 8 failing subcases; malformed
linked-task tests then reproduced unsafe partial responses on both reads. The
final repaired engine aggregate passed all 25 methods and printed
`ALL SCAFFOLD TESTS PASSED` with operating-system network denial.

The old documented shared-body hash also disagreed with the actual body; the new
suite now enforces the corrected pin. No original prediction was falsified.
Final integrated and independent verification, exact source revision and hosted
results travel with the PR receipt. Local ledger-aging tests skip when GNU
`date -d` is unavailable; Linux hosted CI must cover that leg. No live merge,
platform authorization bridge or cross-project rollout is claimed from synthetic
checks. Follow-up #84 owns measured monitoring/adoption after acceptance.

Independent review passed the engine and three extra probe families, but rejected
the first documentation pass: evolve steps and README/USAGE summaries retained
superseded confirmation and until-merged wording. Those occurrences were
reconciled, and the existing L-007 lesson records the missed first sweep. The
pre-existing malformed-file-row counterexample is captured in task #85; it is
not evidence of a live unauthorized merge.
