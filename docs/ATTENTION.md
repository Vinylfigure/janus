# Janus Human Attention Protocol — Version 1

The formal contract for when and how a Janus repo involves its human. Every
machine-consumable issue and every human interruption in this repo follows
this protocol; overlord and any control-plane app parse it rather than
interpret prose. The protocol is deliberately small: sparse labels, stable
headings, canonical comments. GitHub stays the only source of work truth.

**The attention contract.** Every human interruption has one ask, one reason,
one consequence, and a bounded set of actions. An interruption that cannot
state all four is not ready to interrupt.

## Versioning

- The protocol version is the **`janus:v1` label**, applied automatically by
  every issue form. Identity is `janus:v1` + a type label. A hidden body
  comment cannot version form-created issues — GitHub Issue Forms display
  markdown elements in the form but do not submit them into the issue body —
  so the label, which GitHub can query structurally, is the identifier.
- Issues created by an app (not a form) MAY additionally carry
  `<!-- janus:attention:v1 -->` in the body for provenance. It is provenance,
  never the protocol identifier.
- Migration rules, locked now for a future v2: readers MUST tolerate the
  previous protocol version; migration MUST NOT silently alter an unresolved
  human decision; issues written under an old version remain interpretable.

## Type and state

**Type** says what a thing is; **state** says where it is in its life. Labels
stay sparse — most states are derived, not labeled.

| Type | Label | Meaning |
|---|---|---|
| idea | `inbox:` | a thought, not a spec — no done-means required |
| task | `task:` | a unit of ready work carrying its own done-means |
| question | `question:` | a decision only the operator can make |

States: `inbox` → (`ready` → `working` → `verifying` → [`human_check`] →
`done`), with `held` and `blocked` reachable from any working state.

| State | How it is expressed |
|---|---|
| inbox | the `inbox:` label |
| ready | `task:` + done-means present + no gating label + no open blocker |
| working | a `claude/*` branch or open PR references the issue |
| verifying | delivery PR open, checks running |
| human_check | the `human-check:` label |
| done | issue closed by a merged PR |
| held | the `loop:hold` label |
| blocked | `question:`, or an open issue named in `### Blocked by` |

**Legal label combinations.** A type label is required on every protocol
issue; state labels attach only where the table allows. Combinations outside
this table are protocol violations (e.g. `human-check:` on an `inbox:` issue
— an unspecced thought cannot be awaiting operator verification):

| | `loop:hold` | `human-check:` |
|---|---|---|
| `inbox:` | no | no |
| `task:` | yes | yes |
| `question:` | no | no |

`aging` / `overdue` are ladder annotations managed by `fleet-status.sh`, not
protocol state; they may appear on any operator-blocked item.

## The consumption gate

One list, mirrored verbatim in `.claude/skills/work-loop/SKILL.md` (Steps 1)
and enforced observably by `fleet-status.sh`'s "Consumable now" line, which
`test-hooks.sh` fixtures:

Consumable = labeled `task:` AND carries a done-means AND is within the
environment's tool grant AND carries **none** of `question:` / `loop:hold` /
`inbox:` / `human-check:` / `intent:` AND every issue named in its `### Blocked by` field
is closed or resolved AND the issue is **not already `working`**.

Intents live above tasks (overlord protocol `overlord:intent:v1`) and are
never consumable.

That last clause is the half this protocol defined and did not compute for
its first day of life. `working` means an open PR or a live delivery branch
already references the issue — derivable from closing keywords in an open
PR's title or body, and from the issue number embedded in a delivery branch
name. An issue another actor has already started reads "ready" to every
consumer until someone computes it; on 2026-08-21 two sessions built this
protocol nine seconds apart through exactly that hole, producing two
mutually contradictory "version 1"s (L-057). `fleet-status.sh` now computes
it and names the reason on each gated issue, and `scripts/check-ready.sh` is
the gate as one executable statement — it takes `--working` as an explicit
argument precisely so a caller that never asked GitHub has to say so by
omission.

`question:` is not `loop:hold`: hold means "not now"; question means "the
answer is not known yet", and building either branch of an unanswered
decision is wrong regardless of timing (#42).

**Dependencies are explicit.** A task blocked on a decision names it in its
`### Blocked by` field (issue refs: `#123`, `owner/repo#123`, or a full issue
URL). Executors evaluate that field only — never prose references. A
question's `Blocks` heading is for humans reading the question; the dependent
task's `### Blocked by` is what the executor checks.

## Inbox ≠ Ready

An `inbox:` issue is a thought, not a spec: one free-text field, no
done-means. The work loop never consumes it. Its idle arm triages: promote at
most 2 inbox items per firing into `task:` proposals with a drafted
done-means (or into a `question:` when a product decision is needed), and
never execute a promotion in the firing that created it — the gap between
firings is the operator's veto window.

## In plain words — required at filing (v1.1, additive)

Every `inbox:`, `task:`, and `question:` issue form opens with a required
`### In plain words` heading: one sentence, in the operator's own words,
stating what is being asked or what becomes true — no ids, file paths,
backticks, or protocol nouns, 160 characters or fewer. This is an ADDITION
to the v1 body API, not a rename: every existing heading string in this
document stays byte-identical, so a body written under the original
protocol is still fully valid v1 (the heading is simply absent, and a
reader treats that the same as "not yet in plain words").

The reading contract: a control surface renders `### In plain words`
verbatim as the card's headline. When it is absent, the surface falls back
to the first sentence of `### Decision` (questions) or the raw title —
and only as a fallback, never a substitute at filing time. A headline that
matches a jargon deny-list (fixture, reconcile, canonical, machine-decidable,
protocol vN, schema, drift, marker, orphan, sha256, a Pn/Rn/Ln/DL- id, a
`goal/N` ref, "Drone", or a backtick) renders muted with the label "not yet
in plain words" rather than showing the raw match — a plain line that reads
as machine prose is treated as no plain line at all.

Filers: this heading is REQUIRED on every `task:`/`question:`/`inbox:`
issue an agent or the conductor files, enforced by `scripts/check-record.sh`
at filing time (`.claude/skills/work-loop/SKILL.md`,
`.claude/skills/plan-feature/SKILL.md`, `.claude/skills/ship/SKILL.md`). A
"go and confirm" request is filed as a `Human check` task (below), never as
a `question:` — a question is for a decision only the operator can make,
not an observation the operator is asked to make on the machine's behalf.

`question.yml` additionally requires `### Options`: 2-4 named answers, one
per line, in the operator's own words. These become the control surface's
buttons; `### Recommended choice` must name one of them, verbatim — a
question without named options is not ready to file, and a surface with no
`### Options` falls back to the first sentence of `### Recommended choice`.

## Question schema — the v1 body API

`question.yml` renders these stable headings; they ARE the machine interface
(parsers key on heading text; a rename breaks a fixture, not an app,
silently):

`Decision` · `Recommended choice` · `Why` · `If you do nothing` ·
`Reversible?` · `Needed by` · `Blocks`

Three further headings — `Parent goal`, `Gates signal`, `Kind` — are
additive v1.1: all optional, appended after the seven above, never
renaming or reordering them. A body without them is still valid v1; a
parser must treat their absence as "no parent goal / no gated signal /
Kind = Decision". `Parent goal` is how a question joins the Goal graph
defined in Vinylfigure/overlord `docs/GOAL.md` (`overlord:goal:v1`).

Two more headings are additive v1.1, required for filers, optional for
readers (see "In plain words — required at filing" above): `In plain
words` (rendered first, before `Decision`) and `Options` (rendered between
`Decision` and `Recommended choice`). Neither renames nor reorders the
seven original headings; a reader must still treat their absence as valid
v1.

A question arrives with a recommendation — "what should I do?" with no
explored options is an unfinished exploration, not a decision request.

## Human check — the v1 task section

A task whose delivery needs the operator's eyes carries a `Human check`
section with stable sub-headings:

`Surface` · `Instruction` · `URL` · `Pass criteria`

Delivering such a task applies `human-check:` — machine work and automated
verification are done, and the operator's experiential check gates the merge.
A control surface renders `[Open preview] [Pass] [Something's wrong]` from
these fields.

## Lifecycle events for human actions

Human action results are protocol events, encoded as canonical comments plus
label transitions — no event bus. Consumers key on the marker line, never on
accompanying prose (prose is welcome; it is for humans).

- `decision_requested` — a `question:` issue opens (with the v1 headings).
- `decision_resolved` — a comment beginning:

  ```
  <!-- janus:decision:v1 -->
  Decision: accept-recommendation
  ```

  (or `Decision: <named option>`). The `question:` label is removed and the
  issue closed; tasks blocked on it become eligible.
- `human_check_requested` — the `human-check:` label is applied at delivery.
- `human_check_passed` — a comment beginning:

  ```
  <!-- janus:human-check:v1 -->
  Result: pass
  ```

  The `human-check:` label is removed; the task is verified and the repo's
  own delivery/merge process resumes. No external surface merges on the
  repo's behalf.
- `human_check_failed` — the same marker with `Result: fail` plus feedback;
  the `human-check:` label stays and the task returns to working with the
  comment as input.

"Yeah looks pretty good to me!" is a reply to a human; the marker comment is
the event. A surface that records the human's action writes both.

## Label vocabulary

Created idempotently by `fleet-status.sh` and declared in git by the forms in
`.github/ISSUE_TEMPLATE/`:

| Label | Kind | Meaning |
|---|---|---|
| `janus:v1` | protocol | this issue speaks Attention Protocol v1 |
| `task:` | type | unit of ready work — carries a done-means |
| `question:` | type | blocked on an operator decision |
| `inbox:` | type | a thought, not a spec |
| `human-check:` | state | operator's eyes required before merge |
| `loop:hold` | state | the work loop must not take this |
| `aging` / `overdue` | ladder | >3d / >7d without a response |
| `dashboard` | plumbing | the regenerated status dashboard issue |

The fleet dashboard renders `Blocked on operator` (questions), `Awaiting your
check` (`human-check:`), `Backlog` with its "Consumable now" gate line, and
`Inbox` (count and titles — informational, never urgent).
