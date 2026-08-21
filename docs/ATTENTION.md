# Janus Human Attention Protocol

Version: 1

The shared language that tells every consumer — the work loop, the fleet
dashboard, the overlord's portfolio view, and any operator UI — when and how a
repo involves its human. The operator's role is intent, judgment, and
verification; the system's job is to interrupt them only with items shaped by
this contract. GitHub issues and labels are the substrate: work truth never
lives anywhere else.

## The contract

Every human interruption has **one ask, one reason, one consequence, and a
bounded set of actions**. A consumer must never need to interpret prose to
learn whether an item needs the operator — the labels and the form headings
below carry that answer deterministically.

## Type vs. state

Type is what an item *is*; state is where it stands. Labels stay sparse —
most states are carried by the item's position in the delivery flow, not by a
label.

| Type | Carried by |
|---|---|
| idea | `inbox:` label (Inbox form) |
| task | `task:` label (Task form) |
| question | `question:` label (Question form) |

| State | Carried by |
|---|---|
| inbox | `inbox:` label — a thought, not a spec; no done-means required |
| ready | `task:` label + a `Done means` heading + no gating label |
| working | a `claude/*` branch and/or draft PR referencing the task |
| verifying | the PR's checks running |
| human_check | `human-check:` label — machine work done, operator verification before merge |
| done | the closing PR merged |
| held | `loop:hold` label — known work, intentionally paused |
| blocked | an open `question:` this item references |

Illegal combinations are refused at the gate, not adjudicated in prose: an
item carrying any of `question:` / `loop:hold` / `inbox:` / `human-check:` is
not consumable regardless of what else it carries.

## The consumption gate (#42)

`scripts/check-ready.sh` is the one executable statement of readiness:

    ready = labeled `task:`
        AND carries a `Done means` heading
        AND none of: `question:`, `loop:hold`, `inbox:`, `human-check:`
        AND references no open `question:`

The work loop runs it before committing to a candidate; its fixtures live in
`scripts/test-hooks.sh`, so weakening a label's meaning is a visible,
gate-blocked act. History: three views (the daily survey, the Status
dashboard, the label's own description) agreed a `question:`-labeled issue
was blocked on the operator, and the loop consumed it anyway, building a
branch the operator had never chosen (#42).

## Machine-readable shape

The issue forms under `.github/ISSUE_TEMPLATE/` are the v1 API. GitHub
renders each form field as a `### <label>` heading, so the headings are the
parse contract:

- **Task**: `Done means` (required) · `Discovered from` · `Human check`
  (optional; sub-lines `Surface:` `Instruction:` `URL:` `Pass:`) · `Priority`
- **Question**: `Decision` · `Recommended choice` · `If you do nothing` ·
  `Reversible?` · `Needed by` · `Blocks`
- **Inbox**: `Thought`

Renaming a heading is a protocol version bump, never a tidy-up: consumers
parse these strings, and the parser fixtures fail on drift. Human-filed forms
are v1-shaped by construction; a machine filing an issue outside the forms
MUST include the body line `<!-- janus:attention:v1 -->` and the same
headings. Structured JSON lifecycle events are deliberately deferred (L-014)
— the headings are enough for v1 consumers; when events earn their way in,
they arrive as version 2 alongside, never replacing, this shape.

## Human verification is a first-class state

Automated verification proves the implementation is internally consistent
with its specification. It cannot prove the outcome *feels like the product
the operator wanted* — and that judgment is the operator's stated role. A
task whose form carries a `Human check` section is not done at green CI:
delivery applies `human-check:`, the PR says so, and the merge waits for the
operator's check. CODE COMPLETE ≠ DONE.

## Where attention surfaces

- `scripts/fleet-status.sh` renders `question:` items under **Blocked on
  operator**, `human-check:` items under **Awaiting your check**, and the
  `inbox:` count — the repo-local view.
- The overlord dashboard and any operator app aggregate the same labels and
  headings across repos. They consume this protocol; they never define their
  own attention semantics on top of it.
- Only four events deserve a push notification: a decision blocking work, a
  human check becoming ready, a permission/authorization need, and an
  automation failure that cannot self-recover. Everything else is activity,
  not attention.
