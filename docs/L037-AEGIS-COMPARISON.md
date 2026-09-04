# L-037 efficacy experiment — aegis-sentinel natural experiment (draft)

**Question:** does the Janus self-learning scaffold measurably change outcomes?
**Design:** within-repo before/after. Vinylfigure/aegis-sentinel was stamped from janus on
2026-07-27 via GitHub's template button, so /replicate's heredity pass never ran and the
memory loop was wired but dead for ~3 weeks (documented in the repo's own L-040 and PR #16's
body). PR #16 "Revive the Janus memory loop + first build milestone" merged 2026-08-16T16:58Z.

## Method

**Periods.**
- **Loop-dead:** 2026-07-27 (initial commit cb7b3a5) → 2026-08-16T16:58Z (PR #16 merge, eea6d15). ~20 days.
- **Loop-active:** 2026-08-16T16:58Z → 2026-08-25. ~9 days.

**Sources.** Full clone at /home/user/aegis-sentinel (git history; .claude/memory/LEARNINGS.md,
L-001..L-075 with observed:-notes; docs/EXECUTION-PLAN.md, HANDOFF.md, DECISIONS.md,
MEMORY-SKILLS-EVAL.md); GitHub PRs #5–#74 and issues #1–#73 for Vinylfigure/aegis-sentinel only.

**Confounds — stated up front, they bound every number below.**
1. **Unequal periods and unequal work.** 20 days vs 9 days, but the dead period produced almost
   no product code (scaffold hardening, dispatch guardrails, docs, a knowledge-bundle landing —
   ~19 non-merge commits); the active period is when the product was actually built (~100+
   commits, the whole Python pipeline and web UI). Defect *opportunities* differ by an order of
   magnitude. No rate comparison ("defects per PR") is meaningful.
2. **Operator attention coincided with the revival.** PRs #16–#39 (08-16→08-18) were an
   operator-attended build push. Throughput in that window attributes to attention, not to the
   loop. The cleanest loop-active evidence is the **autonomous segment**: 08-20→08-25, ~14 merged
   PRs (#40–#74) produced by unattended 4-hour heartbeat firings with the operator absent.
3. **Measurement asymmetry (the deepest confound).** The active period generates its own
   receipts — Reflect commits, observed:-notes, task-issue trails. The dead period's defects are
   visible only where they collided with CI or a PR body. Dead-period recurrences are therefore
   **undercounted by construction**; this biases dimension 1 *toward* the scaffold, and is why
   dimension 3 (a structural property: a trail exists or it doesn't) carries more verdict weight
   than dimension 1 (a rate).
4. Same operator, same underlying agent, same repo in both periods — that part is controlled.

## 1. Correction recurrence (same mistake twice)

**Loop-dead period.**
- **Turn-cap/denial-loop death (WO-C2):** the dispatched run for issue #7 died 2026-08-03 at
  the 50-turn cap with 35 permission denials and no PR (receipt: PR #9's body, which names run
  30839609045). Fixed same day (PR #9, verify.sh grows a YAML arm). The lesson was recorded as
  *code comments* and in overlord's ledger — **not** this repo's ledger; it entered the ledger
  only as backfilled L-039 on 08-16 (commit f01c2a9). The class (dispatch runs dying at the
  turn cap) resurfaced: commit 2d6018b / PR #36 (08-18) raised the cap 50→120 citing a
  cap-killed-at-delivery run in a sibling stream. Different sub-cause, same class; the dead
  period's fix was invisible to any future session that didn't happen to read claude.yml comments.
- **Allowlist fix-revert cycle:** allowedTools narrowing shipped 7d2d817 and was reverted hours
  later (1bf69a8, "GitHub App permission limit") — one incident, no ledger trace.
- **The headline recurrence is the loop-death itself:** L-040 records that for 3 weeks every
  session ignored the Stop-hook and session-start nudges to run /reflect — the same omission
  repeated across every session of the period, detected by nothing in the scaffold. The revival
  was operator-initiated (the memory-skills audit session), not self-detected.

**Loop-active period** — the ledger documents its own recurrences, so this list is honest in
both directions.

*Recurrences that lessons did NOT prevent (negative evidence):*
- **Concurrent-mint collision class** (L-058 → L-068 → L-070/L-072). B2 was built twice in
  parallel (PR #37 merged, PR #38 closed unmerged, 08-18 — a full build + adversarial-verify
  cycle wasted). Lesson L-058 filed and promoted to a session-start hook. The class then
  recurred at ledger-ID granularity anyway: duplicate `## L-062` headers, L-064 minted three
  times, and on 08-23 two PRs (#57, #60) landed one minute apart each carrying its own `L-070`.
  **Classification of the known 08-23 case: genuine recurrence** — the prose rule and even the
  hook did not prevent it, because concurrent sessions race on snapshots of main — **but
  fast-caught by the discipline**: issue #62 filed 04:29Z, PR #63 (renumber to L-072) merged
  05:44Z, ~75 minutes defect-to-fix, caught by the firing's own /reflect pass. Compare the dead
  period's detection latency for its structural defect: three weeks, and external.
- **L-008 (adversarial pre-mortem):** skipped on 5 consecutive autonomous build firings
  (#47, #48, #56, #59, #69), fired once on a propose-only firing (08-24); the 08-25 skip shipped
  a backwards docstring "correction" (D-U1 why-code) caught only by the dispatched verifier.
  The ledger itself concludes a prose promotion "isn't reaching autonomous firings."
- **L-069 (ScheduleWakeup misuse):** recurred after the lesson, *worse* the second time; the
  entry records "reading LEARNINGS.md is not the same as consulting it."
- **L-063 (container needs python3.12 venv):** 3 recurrences across cold containers; no
  mechanism yet, so every fresh firing re-pays the detour.
- **L-073:** the 08-25 firing regressed on the 08-24 refinement (re-attempted a
  branch-deletion op whose denial was already recorded in issue #65's comments).

*Where recurrence actually stopped (positive evidence):*
- **Mechanized promotions stopped recurring.** L-052 (cwd drift): 5 incidents including two
  after the rule was written as prose; after promotion to the post-edit-verify hook + the
  self-anchoring web-verify runner (08-18), no further cwd-caused failure appears in any later
  Reflect commit. L-058's hook demonstrably fired on 08-20 and routed the firing to inspect
  unmerged branches — which is what surfaced the stranded B3–C3 work (L-059) instead of a
  silent duplicate build.
- **L-005 (verify against primary source):** ~10 documented firings preventing wrong work —
  the stale heartbeat-prompt claim caught on three separate firings (avoided rebuilding
  already-done boxes), issue #69's false premise caught before coding, the list-endpoint
  `merged:false` artifact caught twice. One documented failure-to-fire (the D-U1 mixup) —
  logged against itself.
- **L-054 (commit baseline before revert probes):** 3 incidents, but the third was a subagent
  catching *itself* via the pattern the entry teaches.

**Honest summary of dimension 1:** the loop does not prevent first-recurrence of
concurrency-race classes or of judgment rules left at the prose tier — the ledger proves this
against itself. What changed measurably is (a) detection-and-repair latency (weeks-and-external
→ same-day-and-self-caught) and (b) that rules escalated to mechanisms stop recurring. Given
confound 3, no claim that the dead period had *more* recurrences can be made — only that it
could not see the ones it had.

## 2. Review-finding classes

**Loop-dead:** verification discipline existed and was real (PR #9's "proof the checks have
teeth" shows red-first evidence; PR #6 closed the bootstrap loop). Finding classes:
allowlist/permission design errors (PRs #5, #6, #9), dispatch-ops failures (turn cap), doc
drift ("CI runs the hook suite" claim, stale since b46cc6b, uncorrected until 08-16). No
adversarial-verifier reports; findings surfaced via CI or the operator.

**Loop-active:** adversarial verifier passes on essentially every build PR, plus falsifier
probes. New finding classes, mostly *vacuity-shaped* — defects no test suite fails on:
`as T` casts making tsc checks vacuous (L-053, caught by verifier mutation), hand-maintained
id-set drifting from what code invokes (L-065, PR #49), a done-means field plumbed but never
read (L-070, PR #57), hardcoded prose about state surviving deletion probes (L-056, B2),
harness-lies-not-code (L-054, L-055), and a primary-source inversion (D-U1 docstring, PR #72's
verifier). The review machinery that finds these — the verifier agent, value falsifiers, the
join-exactness-test discipline — is itself scaffold-carried, and several of its briefs are
promoted lessons (L-056 lives in the verifier's step 2).

## 3. Deferred-work evaporation

**Loop-dead — the strongest exhibit in the whole comparison:**
- **A full walking-skeleton build silently stranded.** `feat/web-flow-redesign` (~08-12)
  carried real product work plus an Evidence-3 lesson (macOS editable-install/UF_HIDDEN,
  now L-061) and never became a merged PR; nothing in the period noticed. It surfaced only
  after revival, via the claim-check the revived loop runs (issue #31 filed 08-16, lesson
  harvested by PR #44 on 08-20, commit f7d0faa). Work *and* a lesson evaporated for ~8 days
  with no trail pointing at them.
- Issue #4 (WO-E2 branch protection, 07-30): open 26 days, zero comments, never consumed
  (by design it awaits overlord-side dispatch, but nothing in-period tracked or aged it).
- Issue #10 ("task: Build", 08-05): vague operator order, effectively superseded by
  issue #12/EVALUATION.md but never closed or reconciled; its attachment is now unreachable
  (noted in L-074's triage).
- EVALUATION.md defined a "first build milestone" on 08-09 (PR #13); no session consumed it
  until the revival session itself, 7 days later.

**Loop-active:**
- **12 task: issues filed by heartbeat firings, each with a done-means and a discovered-from
  line** (#47, #48, #53, #54, #58, #59, #62, #64, #65, #68, #69, #73). **10 consumed by merged
  PRs within 1–3 days** (receipts: #47→PR49, #48→PR50, #53→PR56, #54→PR57, #58→PR60, #59→PR61,
  #62→PR63, #64→PR66, #68→PR71, #69→PR72). #65 is open-but-parked with the blocker (auto-mode
  tool-grant denial, L-073) recorded in its comments — held visibly, not evaporated. #73
  (filed 08-25) is the interesting marginal case: the missing work-loop skill path was noticed
  on 08-20 and re-confirmed on six firings before any firing filed the issue — a 5-day
  capture latency the ledger itself tracked and criticized (L-064, Evidence 6) until the
  gap became an issue. Slow, but never lost.
- The web/README Q-item ledger was systematically swept (Q9, Q10, Q11, Q11b, Q14, Q15, Q16,
  Q17 all resolved via the trail above), with L-066/L-074 encoding the check-before-refile and
  find-the-candidate halves of the sweep.
- Deferred-to-Owner work is parked as labeled question:/Owner-action issues (#20, #41, #46,
  #51, #52) instead of prose in a handoff doc.

This dimension survives the confounds: it measures whether a trail exists, not a rate. The
dead period demonstrably lost work silently; the active period's one at-risk item was tracked
across six firings until captured.

## 4. Throughput context (not a primary metric)

| | Loop-dead (20d) | Loop-active (9d) |
|---|---|---|
| PRs merged | 8 (#5,6,8,9,11,13 + boundary #14,#15 merged by the revival session) | 38 (#16–#74 range) |
| — of which autonomous (no operator in loop) | 0 | ~14 (#40–#74, heartbeat firings 08-20→08-25) |
| PRs closed unmerged | 0 | 1 (#38, the L-058 duplicate B2) |
| question:/Owner-action issues raised | 0 (stop-and-ask lived as HANDOFF prose) | 5 (#41, #46, #51, #52 + #20 at the boundary) — escalation functioning as designed |
| Stranded branches | 1, undetected in-period (feat/web-flow-redesign) | 0 new undetected; prior strandings actively managed (recovered via PR #40; 3 leftover branch names tracked in issue #65) |

Throughput is dominated by confound 2 (the operator's build push and the fact that building
started at the revival). The defensible throughput observation is narrower: **for five days the
repo ran unattended and kept delivering** — heartbeat firings consumed a self-filed backlog,
escalated what needed the Owner, and repaired their own ledger defect within ~75 minutes.
Nothing resembling that existed in the dead period.

## Verdict

**Verdict: supports** — with two hard scope limits.

The claim supported is *the loop, while alive, reduces work evaporation and shortens the life
of repeated mistakes*: deferred work stopped vanishing (dimension 3, the confound-robust
result), and defect classes that once died silently or lived for weeks are now caught same-day
by the loop's own receipts, with recurrence actually ending where lessons were escalated to
mechanisms (hooks, runners, fixtures) rather than prose.

What this experiment does **not** support: (1) prose-tier rules changing autonomous behavior —
L-008 was skipped on five consecutive build firings and L-069 recurred *after* its lesson; the
ledger honestly records both; and (2) the scaffold's robustness claim — the prior NEGATIVE
data point stands: the loop died silently for three weeks, no mechanism detected its own death,
and revival required operator initiative. Efficacy-when-alive and staying-alive are different
claims; this experiment supports the first and leaves the second negative.

**What one more period would settle:** a further operator-absent window (pure heartbeat, no
attended pushes) measuring (a) whether the L-008-class prose rules get mechanized (e.g. a
required pre-mortem section in PR bodies) and their skip-streaks end, and (b) whether the
L-063 venv detour gets a mechanism and stops recurring — if prose-tier recurrences persist
while mechanized ones stay at zero, the efficacy claim narrows to "the loop works exactly as
far up the enforcement ladder as it pushes its lessons," which is itself a measurable, falsifiable
refinement.

## Proposed ledger note for janus L-037

observed: 2026-08-25 — aegis-sentinel natural experiment (loop dead 07-27→08-16, alive 08-16→08-25): supports, narrowly — work evaporation ended (a stranded walking-skeleton build + Evidence-3 lesson vanished silently in the dead period vs 12 trail-carrying task: issues, 10 consumed, in the active period) and repeat-mistake latency collapsed (dup L-070 self-caught and renumbered in ~75 min via issue #62/PR #63 vs the 3-week undetected loop death), but prose-tier rules kept being skipped on autonomous firings (L-008 ×5, L-069) until mechanized, operator-attention confounds bar throughput attribution, and the silent 3-week death remains standing negative evidence on robustness.
